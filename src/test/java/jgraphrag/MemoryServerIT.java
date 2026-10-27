package jgraphrag;

import com.fasterxml.jackson.databind.ObjectMapper;
import dev.langchain4j.agent.tool.ToolExecutionRequest;
import dev.langchain4j.agent.tool.ToolSpecification;
import dev.langchain4j.mcp.client.McpClient;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class MemoryServerIT {

    static McpClient sql;
    static McpClient sparql;
    static McpClient both;
    static McpClient sparqlFirst;
    static McpClient english;

    @BeforeAll
    static void start() throws Exception {
        String classpath = System.getProperty("java.class.path");
        String ru = KbDatabase.jdbcUrl(Lang.RU);
        sql = Bench.memory("sql", Lang.RU, classpath, ru);
        sparql = Bench.memory("sparql", Lang.RU, classpath, ru);
        both = Bench.memory("both", Lang.RU, classpath, ru);
        sparqlFirst = Bench.memory("both_sparql_first", Lang.RU, classpath, ru);
        english = Bench.memory("both", Lang.EN, classpath, KbDatabase.jdbcUrl(Lang.EN));
    }

    @AfterAll
    static void stop() throws Exception {
        for (McpClient c : new McpClient[] {sql, sparql, both, sparqlFirst, english}) {
            if (c != null) {
                c.close();
            }
        }
    }

    static Set<String> tools(McpClient c) {
        return c.listTools().stream().map(ToolSpecification::name).collect(Collectors.toSet());
    }

    static Agent.ToolAnswer call(McpClient c, Lang lang, String tool, String query) throws Exception {
        return Agent.callTool(c, ToolExecutionRequest.builder().id("1").name(tool)
                .arguments(new ObjectMapper().writeValueAsString(Map.of("query", query))).build(), lang);
    }

    static Agent.ToolAnswer call(McpClient c, String tool, String query) throws Exception {
        return call(c, Lang.RU, tool, query);
    }

    @Test
    void eachConditionHasItsTools() {
        assertEquals(Set.of("sql_query"), tools(sql));
        assertEquals(Set.of("sparql_query"), tools(sparql));
        assertEquals(Set.of("sql_query", "sparql_query"), tools(both));
        assertEquals(Set.of("sql_query", "sparql_query"), tools(english));
        assertEquals(List.of("sql_query", "sparql_query"), both.listTools().stream().map(ToolSpecification::name).toList());
        assertEquals(List.of("sparql_query", "sql_query"), sparqlFirst.listTools().stream().map(ToolSpecification::name).toList());
    }

    @Test
    void sqlAnswersWithAHeaderAndRows() throws Exception {
        Agent.ToolAnswer r = call(sql, "sql_query", "SELECT id, text FROM claims WHERE id = 'claim_reliable_or_fast'");
        assertFalse(r.error(), r.text());
        assertEquals("""
                id\ttext
                claim_reliable_or_fast\tНадёжность и скорость несовместимы: система бывает либо надёжной, либо быстрой
                (строк: 1)""", r.text());
    }

    @Test
    void sparqlAnswersInTheTermsOfAQuery() throws Exception {
        Agent.ToolAnswer r = call(sparql, "sparql_query", """
                PREFIX schema: <http://schema.org/>
                SELECT ?c ?type ?text WHERE { BIND(<claim_reliable_or_fast> AS ?c) ?c a ?type ; schema:text ?text }
                ORDER BY ?type""");
        assertFalse(r.error(), r.text());
        assertTrue(r.text().startsWith("""
                c\ttype\ttext
                <claim_reliable_or_fast>\tschema:Claim\t"Надёжность и скорость несовместимы: система бывает либо надёжной, либо быстрой"@ru
                """), r.text());
    }

    @Test
    void sparqlSeesEveryGraphWithoutGraph() throws Exception {
        Agent.ToolAnswer r = call(sparql, "sparql_query",
                "PREFIX schema: <http://schema.org/> SELECT (COUNT(DISTINCT ?c) AS ?n) WHERE { ?c a schema:Claim }");
        assertEquals("n\n30\n(строк: 1)", r.text());
    }

    @Test
    void sparqlNeedsNoDeclarationOfTheStandardPrefixes() throws Exception {
        Agent.ToolAnswer r = call(sparql, "sparql_query", "SELECT (COUNT(DISTINCT ?a) AS ?n) WHERE { ?a a oa:Annotation }");
        assertEquals("n\n317\n(строк: 1)", r.text());
    }

    @Test
    void longAnswersAreCutAt200Rows() throws Exception {
        String s = call(sql, "sql_query", "SELECT generate_series(1, 500) AS n").text();
        assertTrue(s.endsWith("200\n(показаны первые 200 строк, есть ещё)"), s.substring(s.length() - 80));
        String p = call(sparql, "sparql_query", "SELECT ?s ?p ?o WHERE { ?s ?p ?o }").text();
        assertTrue(p.endsWith("(показаны первые 200 строк, есть ещё)"), p.substring(p.length() - 80));
        assertEquals(202, p.split("\n").length);
    }

    @Test
    void errorsComeBackAsErrors() throws Exception {
        Agent.ToolAnswer s = call(sql, "sql_query", "SELEC 1");
        assertTrue(s.error() && s.text().startsWith("Ошибка: "), s.text());
        Agent.ToolAnswer p = call(sparql, "sparql_query", "SELECT WHERE {");
        assertTrue(p.error() && p.text().startsWith("Ошибка: "), p.text());
    }

    @Test
    void theSqlRoleReachesNeitherSparqlNorWrites() throws Exception {
        Agent.ToolAnswer viaSql = call(sql, "sql_query", "SELECT kb.sparql_json('SELECT * WHERE { ?s ?p ?o } LIMIT 1')");
        assertTrue(viaSql.error() && viaSql.text().contains("permission denied"), viaSql.text());
        Agent.ToolAnswer write = call(sql, "sql_query", "CREATE TABLE habr_1097022.t (a int)");
        assertTrue(write.error() && write.text().contains("read-only"), write.text());
        Agent.ToolAnswer update = call(sparql, "sparql_query", "INSERT DATA { <a> <b> <c> }");
        assertTrue(update.error(), update.text());
    }

    @Test
    void theEnglishMemorySpeaksEnglish() throws Exception {
        assertTrue(english.listTools().stream().allMatch(t -> t.description().startsWith("A")), "English descriptions");
        Agent.ToolAnswer s = call(english, Lang.EN, "sql_query", "SELECT text FROM claims WHERE id = 'claim_reliable_or_fast'");
        assertEquals("text\nReliability and speed are incompatible: a system is either reliable or fast\n(rows: 1)", s.text());
        Agent.ToolAnswer p = call(english, Lang.EN, "sparql_query",
                "PREFIX schema: <http://schema.org/> SELECT ?t WHERE { <claim_reliable_or_fast> schema:text ?t }");
        assertEquals("t\n\"Reliability and speed are incompatible: a system is either reliable or fast\"@en\n(rows: 1)", p.text());
        Agent.ToolAnswer e = call(english, Lang.EN, "sql_query", "SELEC 1");
        assertTrue(e.error() && e.text().startsWith("Error: "), e.text());
        String more = call(english, Lang.EN, "sql_query", "SELECT generate_series(1, 500) AS n").text();
        assertTrue(more.endsWith("(the first 200 rows shown, there are more)"), more.substring(more.length() - 80));
    }
}
