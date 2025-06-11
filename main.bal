// // Copyright (c) 2025 WSO2 LLC (http://www.wso2.com).
// //
// // WSO2 LLC. licenses this file to you under the Apache License,
// // Version 2.0 (the "License"); you may not use this file except
// // in compliance with the License.
// // You may obtain a copy of the License at
// //
// // http://www.apache.org/licenses/LICENSE-2.0
// //
// // Unless required by applicable law or agreed to in writing,
// // software distributed under the License is distributed on an
// // "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// // KIND, either express or implied.  See the License for the
// // specific language governing permissions and limitations
// // under the License.

// import ballerina/io;
// import ballerina/random;
// configurable string apiKey = "pcsk_2PrJaL_JvwhNPaSPtywcPF5YHsqHwSJZ2eu2oBLLoJ8xi9Bo8mCFvBamvxSitueXMw6iY9";
// configurable string serviceUrl= "https://workplace-ke91x94.svc.aped-4627-b74a.pinecone.io";
// configurable boolean enableHybridSearch = false;
// public function main() returns error? {
//     // Initialize Pinecone Vector Store
//     PineconeConfigs config = {
//         namespace: "example-namespace", 
//         batchSize: 50, 
//         defaultAlpha: 0.7 
//     };

//     PineconeVectorStore vectorStore = check new(apiKey, serviceUrl, enableHybridSearch, config);
    
//     check addVectorExamples(vectorStore);
//     check queryVectorExamples(vectorStore);
//     check deleteVectorExamples(vectorStore);
// }

// // ADD Examples
// function addVectorExamples(PineconeVectorStore vectorStore) returns error? {
//     io:println("ADD VECTOR EXAMPLES");
    
//     // Example 1: Add simple dense vectors
//     VectorEntry[] denseVectors = [
//         {
//             embedding: generateRandomVector(1536),
//             document: "Document about machine learning fundamentals",
//             metadata: {
//                 "category": "education",
//                 "topic": "machine-learning",
//                 "difficulty": "beginner",
//                 "author": "John Doe"
//             }
//         },
//         {
//             embedding: generateRandomVector(1536),
//             document: "Advanced neural network architectures",
//             metadata: {
//                 "category": "research",
//                 "topic": "deep-learning",
//                 "difficulty": "advanced",
//                 "author": "Jane Smith",
//                 "year": 2024
//             }
//         },
//         {
//             embedding: generateRandomVector(1536),
//             document: "Introduction to natural language processing",
//             metadata: {
//                 "category": "education",
//                 "topic": "nlp",
//                 "difficulty": "intermediate",
//                 "author": "Bob Johnson"
//             }
//         }
//     ];
    
//     check vectorStore.add(denseVectors);
//     io:println("✓ Added 3 dense vectors successfully");
    
//     // Example 2: Add vectors with sparse components (for hybrid search)
//     VectorEntry[] hybridVectors = [
//         {
//             embedding: generateRandomVector(1536),
//             document: "Hybrid search techniques in information retrieval",
//             metadata: {
//                 "category": "research",
//                 "topic": "information-retrieval",
//                 "difficulty": "advanced"
//             },
//             sparseVector: {
//                 indices: [10, 25, 100, 500, 1000],
//                 values: [0.8, 0.6, 0.9, 0.4, 0.7]
//             }
//         },
//         {
//             embedding: generateRandomVector(1536),
//             document: "Semantic search with vector databases",
//             metadata: {
//                 "category": "tutorial",
//                 "topic": "vector-search",
//                 "difficulty": "intermediate"
//             },
//             sparseVector: {
//                 indices: [5, 50, 150, 300, 800],
//                 values: [0.9, 0.5, 0.8, 0.6, 0.3]
//             }
//         }
//     ];
    
//     check vectorStore.add(hybridVectors);
//     io:println("✓ Added 2 hybrid vectors (dense + sparse) successfully");
    
//     // Example 3: Add vectors in batches
//     VectorEntry[] largeBatch = [];
//     int i = 0;
//     while i < 10 {
//         largeBatch.push({
//             embedding: generateRandomVector(1536),
//             document: string `Batch document ${i + 1}`,
//             metadata: {
//                 "batch_id": "batch_001",
//                 "index": i,
//                 "type": "generated"
//             }
//         });
//         i += 1;
//     }
    
//     check vectorStore.add(largeBatch);
//     io:println("✓ Added 10 vectors in batch successfully");
// }

// // QUERY Examples
// function queryVectorExamples(PineconeVectorStore vectorStore) returns error? {
//     io:println("\n=== QUERY VECTOR EXAMPLES ===");
    
//     // Example 1: Basic dense vector similarity search
//     QueryParams basicQuery = {
//         queryEmbedding: generateRandomVector(1536),
//         similarityTopK: 5,
//         mode: DEFAULT
//     };
    
//     VectorMatch[] basicResults = check vectorStore.query(basicQuery);
//     io:println(string `✓ Basic query returned ${basicResults.length()} results`);
//     foreach VectorMatch 'match in basicResults {
//         io:println(string `  - Document: ${'match.document}, Score: ${'match.score}`);
//     }
    
//     // Example 2: Query with metadata filters
//     MetadataFilter[] filters = [
//         {key: "category", operator: "==", value: "education"},
//         {key: "difficulty", operator: "!=", value: "advanced"}
//     ];
    
//     QueryParams filteredQuery = {
//         queryEmbedding: generateRandomVector(1536),
//         similarityTopK: 3,
//         filters: {filter: filters, condition: "and"},
//         mode: DEFAULT
//     };
    
//     VectorMatch[] filteredResults = check vectorStore.query(filteredQuery);
//     io:println(string `✓ Filtered query returned ${filteredResults.length()} results`);
//     foreach VectorMatch 'match in filteredResults {
//         io:println(string `  - Document: ${'match.document}, Score: ${'match.score}`);
//         io:println(string `    Metadata: ${'match.metadata.toString()}`);
//     }
    
//     // Example 3: Hybrid search (dense + sparse)
//     QueryParams hybridQuery = {
//         queryEmbedding: generateRandomVector(1536),
//         sparseVector: {
//             indices: [15, 75, 200, 400, 900],
//             values: [0.7, 0.8, 0.6, 0.9, 0.5]
//         },
//         similarityTopK: 4,
//         mode: HYBRID,
//         alpha: 0.7 
//     };
    
//     VectorMatch[] hybridResults = check vectorStore.query(hybridQuery);
//     io:println(string `✓ Hybrid query returned ${hybridResults.length()} results`);
//     foreach VectorMatch 'match in hybridResults {
//         io:println(string `  - Document: ${'match.document}, Score: ${'match.score}`);
//         SparseVector? sparseVec = 'match.sparseVector;
//         if sparseVec is SparseVector {
//             io:println(string `    Has sparse vector with ${sparseVec.indices.length()} components`);
//         }
//     }
    
//     // Example 4: Pure sparse search
//     QueryParams sparseQuery = {
//         sparseVector: {
//             indices: [20, 80, 250, 600, 1200],
//             values: [0.9, 0.7, 0.8, 0.6, 0.4]
//         },
//         similarityTopK: 3,
//         mode: SPARSE
//     };
    
//     VectorMatch[] sparseResults = check vectorStore.query(sparseQuery);
//     io:println(string `✓ Sparse-only query returned ${sparseResults.length()} results`);
    
//     // Example 5: Query with complex metadata filters
//     MetadataFilter[] complexFilters = [
//         {key: "difficulty", operator: "in", value: ["intermediate", "advanced"]},
//         {key: "year", operator: ">=", value: 2023}
//     ];
    
//     QueryParams complexQuery = {
//         queryEmbedding: generateRandomVector(1536),
//         similarityTopK: 5,
//         filters: {filter: complexFilters, condition: "or"},
//         mode: DEFAULT
//     };
    
//     VectorMatch[] complexResults = check vectorStore.query(complexQuery);
//     io:println(string `✓ Complex filtered query returned ${complexResults.length()} results`);
    
//     // Example 6: Query with namespace (if using namespaces)
//     QueryParams namespacedQuery = {
//         queryEmbedding: generateRandomVector(1536),
//         similarityTopK: 3,
//         namespace: "specific-namespace",
//         mode: DEFAULT
//     };
    
//     VectorMatch[] namespacedResults = check vectorStore.query(namespacedQuery);
//     io:println(string `✓ Namespaced query returned ${namespacedResults.length()} results`);
// }

// // DELETE Examples
// function deleteVectorExamples(PineconeVectorStore vectorStore) returns error? {
//     io:println("\n DELETE VECTOR EXAMPLES ");
    
//     // Example 1: Delete by document reference
//     check vectorStore.delete("Document about machine learning fundamentals");
//     io:println("✓ Deleted vectors for 'Document about machine learning fundamentals'");
    
//     // Example 2: Delete multiple documents
//     string[] documentsToDelete = [
//         "Advanced neural network architectures",
//         "Introduction to natural language processing"
//     ];
    
//     foreach string doc in documentsToDelete {
//         check vectorStore.delete(doc);
//         io:println(string `✓ Deleted vectors for '${doc}'`);
//     }
    
//     // Example 3: Delete batch documents
//     int j = 0;
//     while j < 5 {
//         string docId = string `Batch document ${j + 1}`;
//         check vectorStore.delete(docId);
//         j += 1;
//     }
//     io:println("✓ Deleted 5 batch documents");
// }

// // Generate a random 1536-dimensional vector for testing
// function generateRandomVector(int dimensions) returns float[] {
//     float[] vector = [];
//     int i = 0;
//     while i < dimensions {
//         // Generate random float between -1.0 and 1.0
//         float randomValue = (random:createDecimal() * 2.0) - 1.0;
//         vector.push(randomValue);
//         i += 1;
//     }
//     return vector;
// }
