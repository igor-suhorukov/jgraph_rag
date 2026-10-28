-- The indexes of the corpus the agent searches: Lance's own, in the datasets of the lance tables. The vector index is
-- IVF_HNSW_SQ over cosine distance, the metric of semantic_search, in 16 partitions, which the agent's searches all
-- probe (db/corpus_roles.sql); the scalar ones answer the filters the agent puts
-- in where (BITMAP for a few distinct values, BTREE for ranges, LABEL_LIST for the array hubs: @>, && and = ANY), so
-- that Lance filters before it searches, and the lookups of the agent's SQL by task_id and habr_id.
-- Run as a superuser in the database that holds schema corpus, after Corpus has filled it.

CREATE INDEX text_embeddings_vector ON corpus.text_embeddings USING lance_index (embedding_vector)
    WITH (type = 'ivf_hnsw_sq', metric = 'cosine', num_partitions = 16);
CREATE INDEX text_embeddings_task ON corpus.text_embeddings USING lance_index (task_id) WITH (type = 'btree');
CREATE INDEX text_embeddings_habr ON corpus.text_embeddings USING lance_index (habr_id) WITH (type = 'btree');
CREATE INDEX text_embeddings_name ON corpus.text_embeddings USING lance_index (embedding_name) WITH (type = 'bitmap');
CREATE INDEX text_embeddings_published ON corpus.text_embeddings USING lance_index (published) WITH (type = 'btree');
CREATE INDEX text_embeddings_post_type ON corpus.text_embeddings USING lance_index (post_type) WITH (type = 'bitmap');
CREATE INDEX text_embeddings_genre ON corpus.text_embeddings USING lance_index (primary_genre) WITH (type = 'bitmap');
CREATE INDEX text_embeddings_polarity ON corpus.text_embeddings USING lance_index (polarity) WITH (type = 'bitmap');
CREATE INDEX text_embeddings_audience ON corpus.text_embeddings USING lance_index (audience_level) WITH (type = 'bitmap');
CREATE INDEX text_embeddings_demagoguery ON corpus.text_embeddings USING lance_index (demagoguery_severity) WITH (type = 'bitmap');
CREATE INDEX text_embeddings_nsfw ON corpus.text_embeddings USING lance_index (nsfw) WITH (type = 'bitmap');
CREATE INDEX text_embeddings_advertising ON corpus.text_embeddings USING lance_index (advertising) WITH (type = 'bitmap');
CREATE INDEX text_embeddings_score ON corpus.text_embeddings USING lance_index (score) WITH (type = 'btree');
CREATE INDEX text_embeddings_hubs ON corpus.text_embeddings USING lance_index (hubs) WITH (type = 'label_list');

CREATE INDEX indexed_text_task ON corpus.indexed_text USING lance_index (task_id) WITH (type = 'btree');
CREATE INDEX indexed_text_habr ON corpus.indexed_text USING lance_index (habr_id) WITH (type = 'btree');
CREATE INDEX indexed_text_author ON corpus.indexed_text USING lance_index (author) WITH (type = 'btree');
CREATE INDEX indexed_text_post_type ON corpus.indexed_text USING lance_index (post_type) WITH (type = 'bitmap');
CREATE INDEX indexed_text_genre ON corpus.indexed_text USING lance_index (primary_genre) WITH (type = 'bitmap');
CREATE INDEX indexed_text_polarity ON corpus.indexed_text USING lance_index (polarity) WITH (type = 'bitmap');
