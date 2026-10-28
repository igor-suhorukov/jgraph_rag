-- The memory server's roles in the corpus's database, read-only and with a statement timeout:
--   agent_sql     sql_query: reads the tables of schema corpus as it reads the article's tables in kb_ru and kb_en
--                 (db/agent_roles.sql makes it there)
--   agent_vector  semantic_search: reads text_embeddings alone. The agent's condition is SQL, and a condition can hold a
--                 subquery: under agent_sql it read indexed_text, the counters of the articles too, through a
--                 subquery and through the text of a cast's error; under agent_vector it sees what the search shows.
-- pgvector's operators are in schema public, hence public on the search_path. The searches through the IVF_HNSW_SQ
-- index probe all its 16 partitions and re-rank ten times k candidates by their full vectors: so they found every one of
-- the exact ten nearest in VectorStoresIT under every filter Lance applies, in 2 to 6 ms, where Lance's adaptive probing
-- with the 8-bit codes alone found 0.86 to 0.99 of them.
-- Run as a superuser in the database that holds schema corpus.

DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'agent_sql') THEN
    CREATE ROLE agent_sql LOGIN;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'agent_vector') THEN
    CREATE ROLE agent_vector LOGIN;
  END IF;
END
$$;

GRANT USAGE ON SCHEMA corpus TO agent_sql, agent_vector;
GRANT SELECT ON ALL TABLES IN SCHEMA corpus TO agent_sql;
GRANT SELECT ON corpus.text_embeddings TO agent_vector;
ALTER ROLE agent_sql IN DATABASE habr SET search_path = corpus, public;
ALTER ROLE agent_vector IN DATABASE habr SET search_path = corpus, public;
ALTER ROLE agent_sql IN DATABASE habr SET lance.nprobes = 16;
ALTER ROLE agent_vector IN DATABASE habr SET lance.nprobes = 16;
ALTER ROLE agent_sql IN DATABASE habr SET lance.refine_factor = 10;
ALTER ROLE agent_vector IN DATABASE habr SET lance.refine_factor = 10;
ALTER ROLE agent_sql SET default_transaction_read_only = on;
ALTER ROLE agent_vector SET default_transaction_read_only = on;
ALTER ROLE agent_sql SET statement_timeout = '5s';
ALTER ROLE agent_vector SET statement_timeout = '5s';
