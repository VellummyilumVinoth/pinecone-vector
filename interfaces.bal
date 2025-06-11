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

# Core Vector Store interface that all vector store implementations must implement
public type VectorStore isolated object {
    # Add vectors to the store
    # + entries - Array of vector entries to be added
    # + return - Error if operation fails
    public isolated function add(VectorEntry[] entries) returns error?;
    
    # Query vectors from the store
    # + queryEmbedding - Query parameters including vector, filters, and search mode  
    # + similarityTopK - parameter description  
    # + params - parameter description
    # + return - Array of matching vectors or error
    public isolated function query(float[] queryEmbedding, int similarityTopK) returns VectorMatch[]|error;
    
    # Delete vectors from the store
    # + refDocId - Reference document ID to delete
    # + return - Error if operation fails
    public isolated function delete(string refDocId) returns error?;
};
