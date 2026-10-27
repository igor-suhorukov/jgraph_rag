-- The two roles the memory server connects as: agent_sql reads the article's tables and nothing of pg_knowledge_base,
-- so a question under the SQL condition cannot reach SPARQL through kb.sparql(); agent_sparql runs kb.sparql_json() over
-- the R2RML mapping of the same tables. Both are read-only, with a statement timeout.
-- Run as a superuser in the database that holds the tables (schema habr_1097022) and the mapping.

DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'agent_sql') THEN
    CREATE ROLE agent_sql LOGIN;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'agent_sparql') THEN
    CREATE ROLE agent_sparql LOGIN;
  END IF;
END
$$;

GRANT USAGE ON SCHEMA habr_1097022 TO agent_sql, agent_sparql;
GRANT SELECT ON ALL TABLES IN SCHEMA habr_1097022 TO agent_sql, agent_sparql;

-- the store's tables are read by kb.sparql_json() with the caller's rights
GRANT USAGE ON SCHEMA kb TO agent_sparql;
GRANT SELECT ON ALL TABLES IN SCHEMA kb TO agent_sparql;
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA kb FROM PUBLIC;
GRANT EXECUTE ON FUNCTION kb.sparql_json(text, text, text[], text[]) TO agent_sparql;

ALTER ROLE agent_sql SET search_path = habr_1097022;
ALTER ROLE agent_sql SET default_transaction_read_only = on;
ALTER ROLE agent_sql SET statement_timeout = '5s';
ALTER ROLE agent_sparql SET default_transaction_read_only = on;
ALTER ROLE agent_sparql SET statement_timeout = '5s';
ALTER ROLE agent_sparql SET kb.union_default_graph = on;
