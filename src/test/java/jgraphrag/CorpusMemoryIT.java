package jgraphrag;

import com.fasterxml.jackson.databind.ObjectMapper;
import dev.langchain4j.agent.tool.ToolExecutionRequest;
import dev.langchain4j.agent.tool.ToolSpecification;
import dev.langchain4j.mcp.client.McpClient;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class CorpusMemoryIT {

    static McpClient sql;
    static McpClient vector;
    static McpClient both;

    @BeforeAll
    static void start() throws Exception {
        KbDatabase.corpus();
        String classpath = System.getProperty("java.class.path");
        String habr = KbDatabase.jdbcUrl(KbDatabase.CORPUS);
        String ollama = KbDatabase.ollama();
        sql = Bench.memory("corpus_sql", Lang.RU, classpath, habr, ollama);
        vector = Bench.memory("vector", Lang.RU, classpath, habr, ollama);
        both = Bench.memory("vector_sql", Lang.RU, classpath, habr, ollama);
    }

    @AfterAll
    static void stop() throws Exception {
        for (McpClient c : new McpClient[] {sql, vector, both}) {
            if (c != null) {
                c.close();
            }
        }
    }

    static Agent.ToolAnswer call(McpClient c, String tool, Map<String, Object> args) throws Exception {
        return Agent.callTool(c, ToolExecutionRequest.builder().id("1").name(tool)
                .arguments(new ObjectMapper().writeValueAsString(args)).build(), Lang.RU);
    }

    static Map<String, Object> search(Object... kv) {
        Map<String, Object> m = new LinkedHashMap<>();
        for (int i = 0; i + 1 < kv.length; i += 2) {
            m.put((String) kv[i], kv[i + 1]);
        }
        return m;
    }

    @Test
    void eachConditionHasItsTools() {
        assertEquals(List.of("sql_query"), sql.listTools().stream().map(ToolSpecification::name).toList());
        assertEquals(List.of("semantic_search"), vector.listTools().stream().map(ToolSpecification::name).toList());
        assertEquals(List.of("semantic_search", "sql_query"), both.listTools().stream().map(ToolSpecification::name).toList());
    }

    @Test
    void aSearchGivesTheNearestTextsWithTheirArticles() throws Exception {
        Agent.ToolAnswer r = call(vector, "semantic_search", search("query", "самодельная велодрезина для Кругобайкальской железной дороги", "k", 3));
        assertFalse(r.error(), r.text());
        List<String> lines = r.text().lines().toList();
        assertEquals("task_id\thabr_id\ttitle\tembedding_name\tindex\ttext\tdistance", lines.get(0));
        assertEquals("(строк: 3)", lines.get(lines.size() - 1));
        assertTrue(lines.get(1).contains("\t752284\tКак я построил велодрезину\t"), r.text());
        double previous = -1;
        for (String line : lines.subList(1, 4)) {
            double d = Double.parseDouble(line.substring(line.lastIndexOf('\t') + 1));
            assertTrue(d >= previous && d < 1, line);
            previous = d;
        }
    }

    @Test
    void aConditionNarrowsTheSearch() throws Exception {
        Agent.ToolAnswer r = call(vector, "semantic_search", search("query", "чат-бот ошибся в демонстрации",
                "where", "post_type = 'news' AND published < '2023-03-01' AND embedding_name = 'summary'", "k", 50));
        assertFalse(r.error(), r.text());
        List<String> rows = r.text().lines().skip(1).filter(l -> l.contains("\t")).toList();
        assertEquals(50, rows.size(), r.text());
        for (String row : rows) {
            assertEquals("summary", row.split("\t")[3], row);
        }
    }

    @Test
    void aWrongArgumentIsAnErrorTheAgentReads() throws Exception {
        Agent.ToolAnswer many = call(vector, "semantic_search", search("query", "x", "k", 51));
        assertTrue(many.error() && many.text().contains("50"), "the tool's schema bounds k: " + many.text());
        assertTrue(call(vector, "semantic_search", search("query", "x", "k", 2.5)).error());
        assertTrue(call(vector, "semantic_search", search("query", " ")).error());
        Agent.ToolAnswer bad = call(vector, "semantic_search", search("query", "x", "where", "genre = 'fiction'"));
        assertTrue(bad.error() && bad.text().startsWith("Ошибка: ") && bad.text().contains("genre"), bad.text());
    }

    @Test
    void aSearchSeesNoOtherTable() throws Exception {
        Agent.ToolAnswer r = call(vector, "semantic_search", search("query", "x", "k", 1,
                "where", "task_id IN (SELECT task_id FROM indexed_text ORDER BY reading_count DESC LIMIT 1)"));
        assertTrue(r.error() && r.text().contains("permission denied for table indexed_text"), r.text());
        Agent.ToolAnswer cast = call(vector, "semantic_search", search("query", "x", "k", 1,
                "where", "(SELECT ('views=' || reading_count)::int FROM indexed_text WHERE habr_id = 757486) > 0"));
        assertTrue(cast.error() && !cast.text().contains("views="), "no counter leaks through an error: " + cast.text());
    }

    @Test
    void sqlReadsTheCorpusAndWritesNothing() throws Exception {
        Agent.ToolAnswer r = call(sql, "sql_query", search("query", "SELECT count(*) FROM indexed_text WHERE primary_genre = 'fiction'"));
        assertEquals("count\n23\n(строк: 1)", r.text());
        Agent.ToolAnswer w = call(sql, "sql_query", search("query", "DELETE FROM indexed_text WHERE task_id = 1"));
        assertTrue(w.error() && w.text().contains("read-only"), w.text());
        Agent.ToolAnswer kb = call(sql, "sql_query", search("query", "SELECT count(*) FROM habr_1097022.claims"));
        assertTrue(kb.error(), "the corpus's database holds no knowledge base: " + kb.text());
    }
}
