# pgvector and Lance on the same rows

corpus.text_embeddings: 147,432 texts of the Habr corpus with EmbeddingGemma vectors (768 float32), loaded by Corpus from GitHub Pages through DuckDB 2.0 JDBC into a lance table and copied into a heap one. PostgreSQL 19rc1, pgvector 0.8.7, lance_tam f4026d4 (Lance dc53d5d); shared_buffers 2GB, maintenance_work_mem 2GB, 4 parallel maintenance workers.

## Writing the rows

| step | rows | s |
|---|---:|---:|
| DuckDB JDBC from GitHub Pages → COPY into lance corpus.indexed_text | 13,275 | 8.6 |
| DuckDB JDBC from GitHub Pages → COPY into lance corpus.text_embeddings | 147,432 | 154.1 |
| INSERT … SELECT into heap | 147,432 | 1.3 |
| INSERT … SELECT into lance | 147,432 | 1.1 |

## Scalar indexes

| store | index | s | MB |
|---|---|---:|---:|
| pgvector (heap) | btree (embedding_name) | 0.0 | 1 |
| Lance | bitmap (embedding_name) | 0.0 | 0 |
| pgvector (heap) | btree (primary_genre) | 0.0 | 1 |
| Lance | bitmap (primary_genre) | 0.0 | 0 |
| pgvector (heap) | btree (polarity) | 0.0 | 1 |
| Lance | bitmap (polarity) | 0.0 | 0 |
| pgvector (heap) | btree (post_type) | 0.0 | 1 |
| Lance | bitmap (post_type) | 0.0 | 0 |
| pgvector (heap) | btree (nsfw) | 0.0 | 1 |
| Lance | bitmap (nsfw) | 0.0 | 0 |
| pgvector (heap) | btree (published) | 0.0 | 1 |
| Lance | btree (published) | 0.0 | 1 |
| pgvector (heap) | btree (score) | 0.0 | 1 |
| Lance | btree (score) | 0.0 | 1 |
| pgvector (heap) | gin (hubs) | 0.1 | 1 |

## Size on disk

| store | rows | scalar indexes |
|---|---:|---:|
| pgvector (heap): the heap and its TOAST | 677 MB | 8 MB |
| Lance: the dataset's data files | 453 MB | 1 MB |

## Vector indexes

| store | index | s | MB |
|---|---|---:|---:|
| pgvector (heap) | hnsw (m 16, ef_construction 64) | 30.7 | 575 |
| Lance | ivf_hnsw_sq (16 partitions) | 2.8 | 136 |
| pgvector (heap) | ivfflat (150 lists) | 2.0 | 577 |
| Lance | ivf_pq (150 partitions, 48 sub-vectors) | 12.1 | 9 |

## Searches: the ten nearest, 20 queries per filter

Each cell: median ms of a search (p95 over the queries) · recall@10 against the exact ten · the fewest rows a search gave.

| configuration | no filter (147,432 rows) | embedding_name = 'summary' (13,275 rows) | primary_genre = 'technical' (110,059 rows) | primary_genre = 'opinion' (16,895 rows) | published in March 2023 (18,394 rows) | polarity = 'negative' (6,101 rows) | score >= 100 (4,144 rows) | nsfw (1,120 rows) | news, negative (474 rows) | primary_genre = 'fiction' (252 rows) | hub PostgreSQL (an array) (1,660 rows) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| pgvector, exact (no vector index) | 117.3 (122.2) · 1.00 · 10 | 42.1 (45.3) · 1.00 · 10 | 96.8 (100.5) · 1.00 · 10 | 35.9 (39.9) · 1.00 · 10 | 39.5 (42.0) · 1.00 · 10 | 12.8 (15.8) · 1.00 · 10 | 7.1 (9.6) · 1.00 · 10 | 1.5 (2.0) · 1.00 · 10 | 0.8 (0.9) · 1.00 · 10 | 0.5 (0.6) · 1.00 · 10 | 2.3 (3.3) · 1.00 · 10 |
| Lance, exact (flat search) | 134.9 (151.0) · 1.00 · 10 | 44.2 (47.3) · 1.00 · 10 | 72.5 (81.6) · 1.00 · 10 | 14.1 (19.3) · 1.00 · 10 | 16.3 (21.6) · 1.00 · 10 | 6.1 (8.1) · 1.00 · 10 | 4.9 (5.5) · 1.00 · 10 | 2.3 (3.2) · 1.00 · 10 | 2.0 (2.4) · 1.00 · 10 | 1.2 (1.6) · 1.00 · 10 | 134.5 (144.0) · 0.16 · 0 |
| pgvector hnsw, ef_search 40 | 0.3 (0.4) · 0.95 · 10 | 0.3 (0.3) · 0.27 · 0 | 0.3 (0.4) · 0.91 · 7 | 0.3 (0.9) · 0.31 · 0 | 0.3 (0.5) · 0.51 · 1 | 0.3 (0.6) · 0.09 · 0 | 0.3 (0.5) · 0.16 · 0 | 2.9 (4.0) · 1.00 · 10 | 1.4 (1.6) · 1.00 · 10 | 0.7 (0.9) · 1.00 · 10 | 0.3 (0.5) · 0.11 · 0 |
| pgvector hnsw, ef_search 40, iterative scan | 0.4 (1.0) · 0.95 · 10 | 1.9 (7.9) · 0.98 · 10 | 0.4 (1.2) · 0.92 · 10 | 1.5 (11.7) · 0.96 · 10 | 0.7 (3.0) · 0.92 · 10 | 7.6 (15.4) · 0.95 · 10 | 3.3 (13.1) · 0.95 · 10 | 2.8 (3.7) · 1.00 · 10 | 1.4 (1.5) · 1.00 · 10 | 0.7 (0.8) · 1.00 · 10 | 15.5 (24.6) · 0.89 · 10 |
| pgvector hnsw, ef_search 200 | 1.2 (1.7) · 1.00 · 10 | 1.3 (6.0) · 0.80 · 2 | 1.1 (1.6) · 0.99 · 10 | 1.3 (5.9) · 0.74 · 0 | 1.3 (5.1) · 0.95 · 8 | 1.2 (1.8) · 0.39 · 0 | 1.3 (4.8) · 0.53 · 1 | 2.8 (3.4) · 1.00 · 10 | 1.4 (1.5) · 1.00 · 10 | 0.7 (0.9) · 1.00 · 10 | 1.3 (2.9) · 0.23 · 0 |
| Lance ivf_hnsw_sq | 1.1 (1.7) · 0.94 · 10 | 1.5 (3.0) · 0.99 · 10 | 1.2 (1.6) · 0.93 · 10 | 1.4 (3.3) · 0.97 · 10 | 2.7 (3.9) · 0.95 · 10 | 1.4 (1.6) · 0.95 · 10 | 1.7 (2.2) · 0.95 · 10 | 1.2 (1.6) · 0.95 · 10 | 1.3 (1.5) · 0.89 · 10 | 1.2 (1.6) · 0.94 · 10 | 2.2 (4.3) · 0.17 · 0 |
| Lance ivf_hnsw_sq, refine 10 | 1.9 (3.3) · 0.99 · 10 | 3.4 (4.8) · 1.00 · 10 | 3.2 (4.5) · 0.98 · 10 | 4.2 (5.5) · 0.98 · 10 | 6.0 (7.7) · 0.97 · 10 | 3.3 (4.7) · 0.96 · 10 | 2.4 (2.9) · 0.96 · 10 | 2.3 (2.8) · 0.97 · 10 | 2.1 (2.7) · 0.89 · 10 | 1.9 (2.2) · 0.95 · 10 | 10.2 (12.1) · 0.16 · 0 |
| Lance ivf_hnsw_sq, nprobes 4, refine 10 | 2.1 (3.0) · 0.64 · 10 | 2.8 (4.9) · 0.42 · 10 | 2.6 (4.0) · 0.63 · 10 | 3.0 (4.8) · 0.51 · 10 | 4.8 (9.8) · 0.62 · 10 | 2.9 (6.3) · 0.44 · 10 | 3.5 (4.7) · 0.61 · 10 | 2.3 (3.6) · 0.62 · 10 | 3.0 (4.5) · 0.39 · 10 | 1.8 (2.7) · 0.43 · 10 | 9.7 (12.5) · 0.14 · 0 |
| Lance ivf_hnsw_sq, all 16 partitions, refine 10 | 2.5 (3.6) · 1.00 · 10 | 3.7 (4.9) · 1.00 · 10 | 3.6 (4.3) · 1.00 · 10 | 4.8 (5.9) · 1.00 · 10 | 6.1 (7.2) · 1.00 · 10 | 3.8 (5.1) · 1.00 · 10 | 2.6 (4.0) · 1.00 · 10 | 2.2 (3.2) · 1.00 · 10 | 2.3 (2.9) · 1.00 · 10 | 2.3 (2.7) · 1.00 · 10 | 10.0 (12.4) · 0.16 · 0 |
| pgvector ivfflat, probes 1 | 0.3 (0.5) · 0.36 · 10 | 0.3 (0.5) · 0.33 · 10 | 0.3 (0.4) · 0.33 · 10 | 0.4 (0.6) · 0.22 · 0 | 0.3 (0.4) · 0.27 · 10 | 0.4 (1.1) · 0.15 · 0 | 0.4 (0.5) · 0.22 · 3 | 3.0 (3.4) · 1.00 · 10 | 1.4 (1.7) · 1.00 · 10 | 0.7 (0.8) · 1.00 · 10 | 0.6 (1.7) · 0.16 · 0 |
| pgvector ivfflat, probes 10, iterative scan | 5.0 (6.3) · 0.73 · 10 | 4.7 (7.5) · 0.70 · 10 | 5.1 (6.5) · 0.68 · 10 | 5.0 (7.3) · 0.49 · 10 | 4.7 (6.9) · 0.64 · 10 | 5.2 (7.8) · 0.45 · 10 | 5.1 (7.5) · 0.64 · 10 | 2.9 (4.5) · 1.00 · 10 | 1.4 (1.5) · 1.00 · 10 | 0.7 (0.7) · 1.00 · 10 | 6.0 (8.3) · 0.50 · 10 |
| Lance ivf_pq | 2.0 (4.1) · 0.46 · 10 | 2.2 (4.0) · 0.52 · 10 | 2.7 (6.7) · 0.43 · 10 | 1.9 (3.9) · 0.44 · 10 | 3.0 (6.1) · 0.47 · 10 | 2.3 (4.5) · 0.38 · 10 | 2.3 (5.4) · 0.43 · 10 | 2.1 (4.0) · 0.40 · 10 | 2.3 (4.0) · 0.20 · 10 | 2.0 (3.5) · 0.32 · 10 | 4.6 (5.9) · 0.06 · 0 |
| Lance ivf_pq, refine 10 | 2.8 (4.9) · 0.79 · 10 | 3.5 (5.1) · 0.87 · 10 | 4.1 (7.4) · 0.77 · 10 | 2.9 (5.5) · 0.71 · 10 | 4.3 (7.8) · 0.78 · 10 | 3.2 (6.3) · 0.62 · 10 | 3.6 (6.5) · 0.70 · 10 | 3.0 (5.3) · 0.59 · 10 | 3.1 (4.9) · 0.39 · 10 | 2.8 (4.7) · 0.44 · 10 | 9.8 (10.7) · 0.17 · 0 |

## Plan: pgvector hnsw, WHERE polarity = 'negative'

```
Limit (actual rows=1.00 loops=1)
  Buffers: shared hit=838
  ->  Index Scan using heap_hnsw on text_embeddings (actual rows=1.00 loops=1)
        Order By: (embedding_vector <=> $1)
        Filter: (polarity = 'negative'::text)
        Rows Removed by Filter: 39
        Index Searches: 1
        Buffers: shared hit=838
Planning:
  Buffers: shared hit=1
```

## Plan: Lance ivf_hnsw_sq, WHERE polarity = 'negative'

```
Limit (actual rows=10.00 loops=1)
  Buffers: shared hit=2
  ->  Result (actual rows=10.00 loops=1)
        Buffers: shared hit=2
        ->  Custom Scan (LanceScan) on text_embeddings (actual rows=10.00 loops=1)
              Filter: (polarity = 'negative'::text)
              Lance Columns: task_id, text, embedding_vector, polarity
              Lance Filter: (`polarity` = 'negative')
              Lance Search: embedding_vector <=> $query, k=10, metric=cosine, prefilter
              Lance Version: 13
              Lance Batches: 1
              Buffers: shared hit=2
Planning:
  Buffers: shared hit=4
```
