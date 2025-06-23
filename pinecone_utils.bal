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

# Converts standard comparison operators to Pinecone filter operators
#
# + operator - The standard operator to convert (!=, ==, >, <, >=, <=, in, nin)
# + return - The corresponding Pinecone operator string or an error if unsupported
public isolated function convertPineconeOperator(ai:MetadataFilterOperator operator) returns string|ai:Error {
    match operator {
        ai:NOT_EQUAL => {
            return "$ne"; // Not equal
        }
        ai:EQUAL => {
            return "$eq"; // Equal
        }
        ai:GREATER_THAN => {
            return "$gt"; // Greater than
        }
        ai:LESS_THAN => {
            return "$lt"; // Less than
        }
        ai:GREATER_THAN_OR_EQUAL => {
            return "$gte"; // Greater than or equal
        }
        ai:LESS_THAN_OR_EQUAL => {
            return "$lte"; // Less than or equal
        }
        ai:IN => {
            return "$in"; // Value exists in array
        }
        ai:NOT_IN => {
            return "$nin"; // Value does not exist in array
        }
        _ => {
            return error ai:Error(string `Unsupported filter operator: ${operator}`);
        }
    }
}

# Converts logical condition operators to Pinecone condition operators
#
# + condition - The logical condition to convert (and, or)
# + return - The corresponding Pinecone condition string or an error if unsupported
public isolated function convertPineconeCondition(ai:MetadataFilterCondition condition) returns string|ai:Error {
    match condition {
        ai:AND => {
            return "$and"; // Logical AND operation
        }
        ai:OR => {
            return "$or"; // Logical OR operation
        }
        _ => {
            return error ai:Error(string `Unsupported filter condition: ${condition}`);
        }
    }
}

# Converts metadata filters to Pinecone compatible filter format
#
# + filters - The metadata filters containing filter conditions and logical operators
# + return - A map representing the converted filter structure or an error if conversion fails
public isolated function convertPineconeFilters(ai:MetadataFilters filters) returns map<anydata>|ai:Error {
    (ai:MetadataFilters|ai:MetadataFilter)[]? rawFilters = filters.filters;

    if rawFilters is () || rawFilters.length() == 0 {
        return {};
    }

    map<anydata>[] filterList = [];

    foreach (ai:MetadataFilters|ai:MetadataFilter) filter in rawFilters {
        if filter is ai:MetadataFilter {
            map<anydata> filterMap = {};

            if filter.operator != ai:EQUAL {
                string pineconeOp = check convertPineconeOperator(filter.operator);
                map<anydata> operatorMap = {};
                operatorMap[pineconeOp] = filter.value;
                filterMap[filter.key] = operatorMap;
            } else {
                filterMap[filter.key] = filter.value;
            }

            filterList.push(filterMap);
        } else {
            map<anydata> nestedFilter = check convertPineconeFilters(filter);
            if nestedFilter.length() > 0 {
                filterList.push(nestedFilter);
            }
        }
    }

    if filterList.length() == 0 {
        return {};
    } else if filterList.length() == 1 {
        return filterList[0];
    } else {
        string pineconeCondition = check convertPineconeCondition(filters.condition);
        map<anydata> result = {};
        result[pineconeCondition] = filterList;
        return result;
    }
}

# Extracts the document content from the metadata
#
# + metadata - The metadata map that may contain document content
# + return - The document content as a string, or a default message if not found
public isolated function getDocumentContent(map<anydata>? metadata) returns string {
    if metadata is () {
        return "No metadata provided";
    }

    anydata documentContent = metadata["document"];
    if documentContent is string {
        return documentContent;
    } else if documentContent is () {
        return "Document field not found in metadata";
    } else {
        return "Document field is not a string: " + documentContent.toString();
    }
}
