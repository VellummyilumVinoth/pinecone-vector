// Copyright (c) 2025 WSO2 LLC (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/ai;
import ballerina/log;
import ballerina/uuid;
import ballerinax/pinecone.vector;

# Pinecone Vector Store implementation with support for Dense, Sparse, and Hybrid vector search modes.
# 
# This class implements the ai:VectorStore interface and integrates with the Pinecone vector database
# to provide functionality for vector upsert, query, and deletion.
# 
# - pineconeClient: Underlying client used to communicate with Pinecone.
# - queryMode: The search mode (DENSE, SPARSE, or HYBRID).
# - namespace: Optional namespace to isolate vectors within Pinecone.
# - filters: Metadata filters applied during search.
public isolated class PineconeVectorStore {
    *ai:VectorStore;

    private final vector:Client pineconeClient;
    private final ai:VectorStoreQueryMode queryMode;
    private final string namespace;
    private final MetadataFilters filters;

    # Initializes the PineconeVectorStore with the given configuration.
    #
    # + serviceUrl - URL of the Pinecone API service.
    # + apiKey - Pinecone API key for authentication.
    # + queryMode - Vector query mode (defaults to ai:DENSE).
    # + conf - Additional Pinecone configurations like namespace and filters.
    #
    # + return - An ai:Error if the initialization fails, else ().
    public isolated function init(string serviceUrl, string apiKey, ai:VectorStoreQueryMode queryMode = ai:DENSE,
            PineconeConfigs conf = {}) returns ai:Error? {
        vector:Client|error pineconeIndexClient = new ({apiKey}, serviceUrl);
        if pineconeIndexClient is error {
            return error ai:Error("Failed to initialize pinecone vector store", pineconeIndexClient);
        }

        self.pineconeClient = pineconeIndexClient;
        self.queryMode = queryMode;
        self.namespace = conf?.namespace ?: "";
        self.filters = conf.filters.clone() ?: {};
    }

    # Adds the given vector entries to the Pinecone vector store.
    #
    # + entries - An array of ai:VectorEntry values to be added.
    #
    # + return - An ai:Error if vector addition fails, else ().
    public isolated function add(ai:VectorEntry[] entries) returns ai:Error? {
        if entries.length() == 0 {
            return;
        }

        vector:Vector[] vectors = [];
        foreach ai:VectorEntry entry in entries {
            map<anydata> metadata = entry.document?.metadata ?: {};
            metadata["document"] = entry.document.content;
            ai:EmbeddingVector embedding = entry.embedding;

            vector:Vector vec;

            if self.queryMode == ai:DENSE {
                if embedding is ai:DenseVector {
                    vec = {
                        id: uuid:createRandomUuid(),
                        values: embedding,
                        metadata
                    };
                } else {
                    return error ai:Error("Dense mode requires DenseVector embedding.");
                }
            } else if self.queryMode == ai:SPARSE {
                if embedding is ai:SparseVector {
                    vec = {
                        id: uuid:createRandomUuid(),
                        sparseValues: embedding,
                        metadata
                    };
                } else {
                    return error ai:Error("Sparse mode requires SparseVector embedding.");
                }
            } else if self.queryMode == ai:HYBRID {
                if embedding is ai:HybridEmbedding {
                    if embedding.dense.length() == 0 && embedding.sparse.indices.length() == 0 {
                        return error ai:Error("Hybrid mode requires both dense and sparse vectors, but one or both are missing.");
                    }
                    vec = {
                        id: uuid:createRandomUuid(),
                        values: embedding.dense,
                        sparseValues: embedding.sparse,
                        metadata
                    };
                } else if embedding is ai:DenseVector {
                    // Accept DenseVector but warn if sparse is expected for hybrid effectiveness
                    vec = {
                        id: uuid:createRandomUuid(),
                        values: embedding,
                        sparseValues: bm25(entry.document.content), // Auto-generate sparse if needed
                        metadata
                    };
                } else {
                    return error ai:Error("Hybrid mode requires either HybridEmbedding or DenseVector with auto-generated sparse values.");
                }
            } else {
                return error ai:Error("Unsupported query mode.");
            }

            vectors.push(vec);
        }

        vector:UpsertRequest request = {
            vectors: vectors
        };

        if self.namespace != "" {
            request.namespace = self.namespace;
        }

        vector:UpsertResponse|error response = self.pineconeClient->/vectors/upsert.post(request);
        if response is error {
            log:printError("Failed to add vector entry", response);
            return error ai:Error("Failed to add vector entry", response);
        }
    }

    # Queries Pinecone using the provided embedding vector and returns the top matches.
    #
    # + queryVector - The embedding vector to query against. Should match the configured query mode.
    #
    # + return - A list of matching ai:VectorMatch values, or an ai:Error on failure.
    public isolated function query(ai:EmbeddingVector queryVector) returns ai:VectorMatch[]|ai:Error {
        vector:QueryRequest request = {
            topK: 2,
            includeMetadata: true,
            includeValues: true
        };

        if queryVector is ai:DenseVector {
            if self.queryMode == ai:HYBRID {
                return error ai:Error("Hybrid search requires both dense and sparse vectors, but only dense vector provided.");
            }
            request.vector = queryVector;
        } else if queryVector is ai:SparseVector {
            if self.queryMode == ai:HYBRID {
                return error ai:Error("Hybrid search requires both dense and sparse vectors, but only sparse vector provided.");
            }
            request.sparseVector = queryVector;
        } else {
            if self.queryMode != ai:HYBRID {
                return error ai:Error("Hybrid embedding provided, but query mode is not set to HYBRID.");
            }
            if queryVector.dense.length() == 0 || queryVector.sparse.indices.length() == 0 {
                return error ai:Error("Both dense and sparse vectors must be present for hybrid search.");
            }
            request.vector = queryVector.dense;
            request.sparseVector = queryVector.sparse;
        }

        if self.namespace != "" {
            request.namespace = self.namespace;
        }

        map<anydata> localFilterMap = {};
        lock {
            localFilterMap = check convertFilters(self.filters.clone());
        }
        if localFilterMap.length() > 0 {
            request.filter = localFilterMap;
        }

        vector:QueryResponse|error response = self.pineconeClient->/query.post(request);
        if response is error {
            return error ai:Error("Failed to obtain matching vectors", response);
        }

        vector:QueryMatch[]? matches = response?.matches;
        if matches is () {
            return [];
        }

        return from vector:QueryMatch item in matches
            select {
                score: item?.score ?: 0.0,
                document: {
                    content: (item?.metadata ?: {"document": "No Data"}).get("document").toString(),
                    metadata: item.metadata
                },
                embedding: item?.values ?: []
            };
    }

    # Deletes vector entries from the store that match the given reference document ID.
    #
    # + refDocId - The document ID to match against the metadata field "document".
    #
    # + return - An ai:Error if the deletion fails, else ().
    public isolated function delete(string refDocId) returns ai:Error? {
        map<anydata> filter = {
            "document": {
                "$eq": refDocId
            }
        };

        vector:DeleteRequest request = {
            filter: filter
        };

        if self.namespace != "" {
            request.namespace = self.namespace;
        }

        vector:DeleteResponse|error response = self.pineconeClient->/vectors/delete.post(request);
        if response is error {
            log:printError("Failed to delete vectors", response);
            return error ai:Error("Failed to delete vectors", response);
        }
    }
}
