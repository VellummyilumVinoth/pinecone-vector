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

// Error type for vector store operations
public type Error distinct error;

// Sparse vector representation with indices and values
public type SparseVector record {
    int[] indices;
    float[] values;
};

// Vector store query modes supporting hybrid search
public enum VectorStoreQueryMode {
    DENSE,
    SPARSE,
    HYBRID
};

// Document match result with score
public type DocumentMatch record {
    string document;
    float score;
};

// Metadata filter for vector search
public type MetadataFilter record {
    string key;
    string operator?; // "==", "!=", ">", "<", ">=", "<=", "in", "nin"
    anydata value;
};

// Container for multiple metadata filters
public type MetadataFilters record {
    MetadataFilter[] filter?;
    string condition?; // "and", "or"
};

public type Document record {
    string content;
    map<anydata> metadata?;
};

public type VectorEntry record {|
    float[] embedding;
    Document document;
    SparseVector sparseVector?;

|};

// Vector match result from query
public type VectorMatch record {|
    *VectorEntry;
    float score;
    string id?;
|};

// Query parameters for vector store operations
public type QueryParams record {|
    SparseVector sparseVector?;
    MetadataFilters filters?;
    string namespace?;
    VectorStoreQueryMode mode?;
    float alpha?; 
|};

// Vector store query configuration
public type VectorStoreQuery record {
    float[] queryEmbedding?;
    string queryStr?;
    int similarityTopK?;
    VectorStoreQueryMode mode?;
    MetadataFilters filters?;
    float alpha?;
    SparseVector sparseVector?;
};
