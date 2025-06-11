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

// Pinecone Vector Store implementation with hybrid search support
public isolated class PineconeVectorStore {
    *ai:VectorStore;

    private final vector:Client pineconeClient;
    private final ai:VectorStoreQueryMode queryMode;
    private final string namespace;
    private final MetadataFilters filters;

    public isolated function init(string apiKey, string serviceUrl, ai:VectorStoreQueryMode queryMode = ai:DENSE, PineconeConfigs conf = {}) returns ai:Error? {
        vector:Client|error pineconeIndexClient = new ({apiKey}, serviceUrl);
        if pineconeIndexClient is error {
            return error ai:Error("Failed to initialize pinecone vector store", pineconeIndexClient);
        }
        
        self.pineconeClient = pineconeIndexClient;
        self.queryMode = queryMode;
        self.namespace = conf?.namespace ?: "";
        self.filters = conf.filters.clone() ?: {};
    }

    public isolated function add(ai:VectorEntry[] entries) returns ai:Error? {
        if entries.length() == 0 {
            return;
        }

        vector:Vector[] vectors = [];
        foreach ai:VectorEntry entry in entries {
            map<anydata> metadata = entry.document?.metadata ?: {};
            metadata["document"] = entry.document.content;
            float[]|ai:SparseVector embedding = entry.embedding;

            if self.queryMode == ai:DENSE && embedding !is float[] {
                return error ai:Error("Dense query mode requires float[] embedding, but sparse vector provided");
            }

            if self.queryMode == ai:SPARSE && embedding !is ai:SparseVector {
                return error ai:Error("Sparse query mode requires sparse vector embedding, but dense vector provided");
            }
            
            vector:Vector vec = embedding is float[] ? {
                    id: uuid:createRandomUuid(),
                    values: embedding,
                    metadata
                } : {
                    id: uuid:createRandomUuid(),
                    sparseValues: embedding,
                    metadata
                };

            if self.queryMode == ai:HYBRID && embedding !is ai:SparseVector {
                vec.sparseValues = bm25(entry.document.content);
            }

            vectors.push(vec);
        }

        vector:UpsertRequest request = {
            vectors: vectors
        };

        // Add namespace if specified
        if self.namespace != "" {
            request.namespace = self.namespace;
        }

        vector:UpsertResponse|error response = self.pineconeClient->/vectors/upsert.post(request);
        if response is error {
            log:printError("Failed to add vector entry", response);
            return error ai:Error("Failed to add vector entry", response);
        }
    }

    public isolated function query(ai:QueryVector queryVector) returns ai:VectorMatch[]|ai:Error {
        float[]? embedding = queryVector.embedding;
        ai:SparseVector|string? sparseVector = queryVector.sparseVectorOrQuery;
        
        if sparseVector is string {
            sparseVector = bm25(sparseVector);
        }

        vector:QueryRequest request = {
            topK: 2
        };

        if embedding is float[] {
            request.vector = embedding;
        }
        
        if sparseVector is ai:SparseVector && self.queryMode == ai:SPARSE {
            request.sparseVector = sparseVector;
        }
        
        if self.queryMode == ai:HYBRID {
            if embedding !is float[] || sparseVector !is ai:SparseVector {
                return error ai:Error("sparse and dense values are not provided");
            }
            request.vector = embedding;
            request.sparseVector = sparseVector;
        }

        // Add namespace if specified
        if self.namespace != "" {
            request.namespace = self.namespace;
        }

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
