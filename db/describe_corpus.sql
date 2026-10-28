-- What the agent is told about the corpus, written from the catalog: the tables of schema corpus with their columns and
-- comments (src/main/resources/prompts/ru/corpus.md, the same under every condition of the corpus).
--   psql -X -v outdir=/work -f describe_corpus.sql habr
\set ON_ERROR_STOP on
\pset format unaligned
\pset tuples_only on
\pset footer off

\o :outdir/corpus.md
SELECT string_agg(doc, E'\n\n' ORDER BY relname COLLATE "C")
FROM (
  SELECT c.relname,
         '### ' || c.relname || E'\n' || coalesce(obj_description(c.oid, 'pg_class'), '') || E'\n' ||
         (SELECT string_agg('- ' || a.attname || ' ' || format_type(a.atttypid, a.atttypmod)
                            || coalesce(' — ' || col_description(a.attrelid, a.attnum), ''), E'\n' ORDER BY a.attnum)
            FROM pg_attribute a
           WHERE a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped) AS doc
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'corpus' AND c.relkind = 'r'
) t;
\o
