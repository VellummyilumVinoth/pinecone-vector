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

public isolated function convertOperator(string operator) returns string|ai:Error {
    match operator {
        "!=" => {
            return "$ne";
        }
        "==" => {
            return "$eq";
        }
        ">" => {
            return "$gt";
        }
        "<" => {
            return "$lt";
        }
        ">=" => {
            return "$gte";
        }
        "<=" => {
            return "$lte";
        }
        "in" => {
            return "$in";
        }
        "nin" => {
            return "$nin";
        }
        _ => {
            return error ai:Error(string `Unsupported filter operator: ${operator}`);
        }
    }
}

public isolated function convertCondition(string condition) returns string|ai:Error {
    match condition {
        "and" => {
            return "$and";
        }
        "or" => {
            return "$or";
        }
        _ => {
            return error ai:Error(string `Unsupported filter condition: ${condition}`);
        }
    }
}

public isolated function convertFilters(MetadataFilters filters) returns map<anydata>|ai:Error {
    MetadataFilter[]? rawFilters = filters.filter;

    if rawFilters is () || rawFilters.length() == 0 {
        return {};
    }
    
    map<anydata> result = {};
    map<anydata>[] filterList = [];
    
    foreach MetadataFilter filter in rawFilters {
        map<anydata> filterMap = {};
        
        if filter.operator is string {
            string pineconeOp = check convertOperator(filter.operator ?: "");
            filterMap[filter.key] = {[pineconeOp]: filter.value};
        } else {
            filterMap[filter.key] = filter.value;
        }
        
        filterList.push(filterMap);
    }
    
    if filterList.length() == 1 {
        return filterList[0];
    } else if filterList.length() > 1 {
        string condition = filters.condition ?: "and";
        string pineconeCondition = check convertCondition(condition);
        result[pineconeCondition] = filterList;
    }
    
    return result;
}

// Validate sparse vector
public isolated function validateSparseVector(SparseVector? sparseVector) returns ai:Error? {
    if sparseVector is () {
        return ();
    }
    if sparseVector.indices.length() != sparseVector.values.length() {
        return error ai:Error("Sparse vector indices and values arrays must have the same length");
    }
    
    if sparseVector.indices.length() > 1000 {
        return error ai:Error("Sparse vector cannot have more than 1000 non-zero values");
    }
    
    // Check if indices are sorted and unique
    int[] indices = sparseVector.indices;
    int i = 0;
    while i < indices.length() - 1 {
        if indices[i] >= indices[i + 1] {
            return error ai:Error("Sparse vector indices must be sorted in ascending order and unique");
        }
        i += 1;
    }
    
    return ();
}

// Scale dense vector for hybrid search
public isolated function scaleVector(float[] vector, float scale) returns float[] {
    return from float value in vector
           select value * scale;
}

// Scale sparse vector for hybrid search
public isolated function scaleSparseVector(SparseVector sparseValues, float scale) returns SparseVector {
    float[] scaledValues = from float value in sparseValues.values
                            select value * scale;
        
    return {
        indices: sparseValues.indices,
        values: scaledValues
    };
}
