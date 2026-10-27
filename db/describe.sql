-- What the agent is told about its memory, written from the catalog: the tables of habr_1097022 with their columns,
-- comments and foreign keys (memory.md, the same for every condition), the tables with their row counts
-- (inventory_sql.md) and the classes of the mapped graph with their node counts (inventory_sparql.md).
--   psql -X -v outdir=/work -v fk='foreign key' -f describe.sql kb_en     (as a superuser: it reads the graph
--   through kb.sparql; fk is how a foreign key is called: 'внешний ключ' for kb_ru)
\set ON_ERROR_STOP on
\pset format unaligned
\pset tuples_only on
\pset footer off

\o :outdir/memory.md
SELECT string_agg(doc, E'\n\n' ORDER BY relname COLLATE "C")
FROM (
  SELECT c.relname,
         '### ' || c.relname || E'\n' || coalesce(obj_description(c.oid, 'pg_class'), '') || E'\n' ||
         (SELECT string_agg('- ' || a.attname || ' ' || format_type(a.atttypid, a.atttypmod)
                            || coalesce(' — ' || col_description(a.attrelid, a.attnum), ''), E'\n' ORDER BY a.attnum)
            FROM pg_attribute a
           WHERE a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped)
         || coalesce(E'\n' || (SELECT string_agg('- ' || :'fk' || ': ' || pg_get_constraintdef(k.oid), E'\n' ORDER BY k.conname)
                                 FROM pg_constraint k
                                WHERE k.conrelid = c.oid AND k.contype = 'f'), '') AS doc
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'habr_1097022' AND c.relkind = 'r'
) t;

\o :outdir/inventory_sql.md
SELECT string_agg(relname || ' ' || rows, ', ' ORDER BY rows DESC, relname COLLATE "C")
FROM (
  SELECT c.relname,
         (xpath('/row/n/text()', query_to_xml(format('SELECT count(*) AS n FROM habr_1097022.%I', c.relname),
                                              false, true, '')))[1]::text::int AS rows
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'habr_1097022' AND c.relkind = 'r'
) t;

\o :outdir/inventory_sparql.md
SET kb.union_default_graph = on;
SELECT string_agg(name || ' ' || n, ', ' ORDER BY n DESC, name COLLATE "C")
FROM (
  SELECT replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(class,
           'http://schema.org/', 'schema:'),
           'https://example.org/story-kg/ontology#', 'kgo:'),
           'http://www.w3.org/ns/oa#', 'oa:'),
           'http://purl.org/linked-data/cube#', 'qb:'),
           'http://www.w3.org/2004/02/skos/core#', 'skos:'),
           'https://www.irit.fr/recherches/MELODI/ontologies/BBO#', 'bbo:'),
           'http://www.w3.org/1999/02/22-rdf-syntax-ns#', 'rdf:'),
           'http://rdfs.org/sioc/ns#', 'sioc:'),
           'http://www.newsreader-project.eu/domain-ontology#', 'eso:'),
           'http://xmlns.com/foaf/0.1/', 'foaf:'),
           'http://purl.org/dc/terms/', 'dcterms:'),
           'http://www.w3.org/2006/vcard/ns#', 'vcard:'),
           'http://www.w3.org/ns/prov#', 'prov:') AS name, n
    FROM kb.sparql($q$SELECT ?class (COUNT(DISTINCT ?s) AS ?n) WHERE { ?s a ?class } GROUP BY ?class$q$)
         AS t(class text, n bigint)
) t;
\o
