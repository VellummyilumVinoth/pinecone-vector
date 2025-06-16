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

# Converts standard comparison operators to MongoDB/Pinecone filter operators
#
# + operator - The standard operator to convert (!=, ==, >, <, >=, <=, in, nin)
# + return - The corresponding MongoDB/Pinecone operator string or an error if unsupported
public isolated function convertOperator(string operator) returns string|ai:Error {
    match operator {
        "!=" => {
            return "$ne"; // Not equal
        }
        "==" => {
            return "$eq"; // Equal
        }
        ">" => {
            return "$gt"; // Greater than
        }
        "<" => {
            return "$lt"; // Less than
        }
        ">=" => {
            return "$gte"; // Greater than or equal
        }
        "<=" => {
            return "$lte"; // Less than or equal
        }
        "in" => {
            return "$in"; // Value exists in array
        }
        "nin" => {
            return "$nin"; // Value does not exist in array
        }
        _ => {
            // Return error for unsupported operators
            return error ai:Error(string `Unsupported filter operator: ${operator}`);
        }
    }
}

# Converts logical condition operators to MongoDB/Pinecone condition operators
#
# + condition - The logical condition to convert (and, or)
# + return - The corresponding MongoDB/Pinecone condition string or an error if unsupported
public isolated function convertCondition(string condition) returns string|ai:Error {
    match condition {
        "and" => {
            return "$and"; // Logical AND operation
        }
        "or" => {
            return "$or"; // Logical OR operation
        }
        _ => {
            // Return error for unsupported conditions
            return error ai:Error(string `Unsupported filter condition: ${condition}`);
        }
    }
}

# Converts metadata filters to MongoDB/Pinecone compatible filter format
#
# + filters - The metadata filters containing filter conditions and logical operators
# + return - A map representing the converted filter structure or an error if conversion fails
public isolated function convertFilters(MetadataFilters filters) returns map<anydata>|ai:Error {
    MetadataFilter[]? rawFilters = filters.filter;

    // Return empty map if no filters are provided
    if rawFilters is () || rawFilters.length() == 0 {
        return {};
    }

    map<anydata> result = {};
    map<anydata>[] filterList = [];

    // Process each individual filter
    foreach MetadataFilter filter in rawFilters {
        map<anydata> filterMap = {};

        // Convert operator-based filters
        if filter.operator is string {
            string pineconeOp = check convertOperator(filter.operator ?: "");
            filterMap[filter.key] = {[pineconeOp]: filter.value};
        } else {
            // Direct value assignment for non-operator filters
            filterMap[filter.key] = filter.value;
        }

        filterList.push(filterMap);
    }

    // Handle single filter case - return the filter directly
    if filterList.length() == 1 {
        return filterList[0];
    } else if filterList.length() > 1 {
        // Handle multiple filters - wrap with logical condition
        string condition = filters.condition ?: "and"; // Default to AND condition
        string pineconeCondition = check convertCondition(condition);
        result[pineconeCondition] = filterList;
    }

    return result;
}

# Placeholder function for BM25 (Best Matching 25) algorithm implementation
# Currently returns an empty sparse vector structure
#
# + document - The document text to process for BM25 scoring
# + return - A sparse vector with empty indices and values arrays
public isolated function bm25(string document) returns ai:SparseVector {
    // TODO: Implement actual BM25 algorithm
    // BM25 is a ranking function used for document retrieval and text analysis
    return {indices: [], values: []};
}

# Helper function to safely extract document content from metadata
#
# + metadata - The metadata map that may contain document content
# + return - The document content as a string, or a default message if not found
public isolated function getDocumentContent(map<anydata>? metadata) returns string {
    if metadata is () {
        return "No document content available";
    }

    anydata documentContent = metadata["document"];
    if documentContent is string {
        return documentContent;
    } else if documentContent is () {
        return "No document content available";
    } else {
        return documentContent.toString();
    }
}
