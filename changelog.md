# Change Log

This file documents all significant changes made to the Ballerina `ai.pinecone` package across releases.

## [1.0.0] - 2025-07-11

### Added
- Initial implementation of `VectorStore` integration with Pinecone, supporting:
  - Dense vector search
  - Sparse vector search
  - Hybrid (dense + sparse) vector search
- Methods for:
  - Upserting vectors (`add`)
  - Querying vectors (`query`)
  - Deleting vectors (`delete`)
