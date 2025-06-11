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

// Default batch size for operations
const int DEFAULT_BATCH_SIZE = 100;

// Pinecone Vector Store implementation with hybrid search support
public isolated class PineconeVectorStore {
    *ai:VectorStore;

    private final vector:Client pineconeClient;

    private final SparseVector sparseVector;
    private final VectorStoreQueryMode mode;
    private final string namespace;
    private final int batchSize;
    private final float defaultAlpha;
    private final MetadataFilters filters;

    public isolated function init(string apiKey, string serviceUrl, VectorStoreQueryMode mode, PineconeConfigs conf = {}) returns ai:Error? {
        vector:Client|error pineconeIndexClient = new ({apiKey: apiKey}, serviceUrl);
        if pineconeIndexClient is error {
            return error ai:Error("Failed to initialize Pinecone vector store", pineconeIndexClient);
        }

        self.pineconeClient = pineconeIndexClient;
        self.namespace = conf?.namespace ?: "";
        self.batchSize = conf?.batchSize ?: DEFAULT_BATCH_SIZE;
        self.filters = conf.filters.clone() ?: {};
        self.defaultAlpha = conf.alpha;
        self.sparseVector = conf.sparseVector.clone() ?: {indices: [], values: []};
        self.mode = mode;
    }

    // Add vector entries to the index with sparse vector support and batch processing
    public isolated function add(ai:VectorEntry[] entries) returns ai:Error? {
        if entries.length() == 0 {
            return;
        }

        // Process entries in batches
        int totalEntries = entries.length();
        int processed = 0;

        while processed < totalEntries {
            int endIndex = processed + self.batchSize;
            if endIndex > totalEntries {
                endIndex = totalEntries;
            }

            ai:VectorEntry[] batch = entries.slice(processed, endIndex);

            vector:Vector[] vectors = [];
            foreach ai:VectorEntry entry in batch {
                // Validate sparse vector if present
                if entry.sparseVector is SparseVector {
                    check validateSparseVector(entry.sparseVector);
                }

                map<anydata> metadata = entry?.document.metadata ?: {};
                metadata["document"] = entry.document.content;

                vector:Vector vectorRecord = {
                    id: uuid:createRandomUuid(),
                    values: entry.embedding,
                    metadata: metadata
                };

                // Add sparse values if present
                if entry.sparseVector is SparseVector {
                    vectorRecord.sparseValues = entry.sparseVector;
                }

                vectors.push(vectorRecord);
            }

            vector:UpsertRequest request = {
                vectors: vectors
            };

            request.namespace = self.namespace;

            vector:UpsertResponse|error response = self.pineconeClient->/vectors/upsert.post(request);
            if response is error {
                log:printError("Failed to add vector entries", response);
            }

            processed = endIndex;
        }
    }

    // Query vectors from the index with hybrid search support
    public isolated function query(float[] queryEmbedding, int similarityTopK) returns ai:VectorMatch[]|ai:Error {
        vector:QueryRequest request = {
            topK: similarityTopK,
            includeValues: true,
            includeMetadata: true,
            vector: queryEmbedding
        };

        // Set sparse vector for sparse/hybrid search
        SparseVector localSparse;
        lock {
            localSparse = self.sparseVector.clone();
        }
        check validateSparseVector(localSparse);
        request.sparseVector = localSparse;

        // Handle hybrid search with alpha parameter
        if self.mode == HYBRID {
            float alpha = self.defaultAlpha;

            // Scale dense and sparse vectors based on alpha
            if request.vector is float[] && request.sparseVector is SparseVector {
                request.vector = scaleVector(request.vector ?: [], alpha);
                request.sparseVector = scaleSparseVector(request.sparseVector ?: {indices: [], values: []}, 1.0 - alpha);
            }
        } else if self.mode == SPARSE {
            request.vector = ();
        } else if self.mode == DENSE {
            request.sparseVector = ();
        }

        // Add namespace if specified
        request.namespace = self.namespace;

        // Add filters if specified
        map<anydata> localFilterMap = {};
        lock {
            localFilterMap = check convertFilters(self.filters.clone());
        }
        if localFilterMap.length() > 0 {
            request.filter = localFilterMap;
        }

        vector:QueryResponse|error response = self.pineconeClient->/query.post(request);
        if response is error {
            return error ai:Error("Failed to query matching vectors", response);
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

    // Delete vectors by reference document ID
    public isolated function delete(string refDocId) returns ai:Error? {
        map<anydata> filter = {
            "document": {
                "$eq": refDocId
            }
        };

        vector:DeleteRequest request = {
            filter: filter
        };

        request.namespace = self.namespace;

        vector:DeleteResponse|error response = self.pineconeClient->/vectors/delete.post(request);
        if response is error {
            log:printError("Failed to delete vectors", response);
            return error ai:Error("Failed to delete vectors", response);
        }
    }
}
