package jgraphrag;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.dataformat.yaml.YAMLFactory;
import dev.langchain4j.agent.tool.ToolExecutionRequest;
import dev.langchain4j.mcp.client.McpClient;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;

import java.nio.file.Path;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;
import java.util.stream.Stream;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class CorpusGoldIT {

    static McpClient vector;

    @BeforeAll
    static void start() throws Exception {
        KbDatabase.corpus();
        vector = Bench.memory("vector", Lang.RU, System.getProperty("java.class.path"), KbDatabase.jdbcUrl(KbDatabase.CORPUS),
                KbDatabase.ollama());
    }

    @AfterAll
    static void stop() throws Exception {
        if (vector != null) {
            vector.close();
        }
    }

    @SuppressWarnings("unchecked")
    static Stream<Arguments> questions() throws Exception {
        Map<String, Object> doc = new ObjectMapper(new YAMLFactory()).readValue(Path.of("questions/corpus.ru.yaml").toFile(), Map.class);
        return ((List<Map<String, Object>>) doc.get("questions")).stream().map(q -> Arguments.of(q.get("id"), q));
    }

    @SuppressWarnings("unchecked")
    @ParameterizedTest(name = "{0}")
    @MethodSource("questions")
    void theGoldQueryAnswersTheQuestion(String id, Map<String, Object> q) throws Exception {
        Map<String, Object> gold = (Map<String, Object>) q.get("answer");
        List<List<String>> rows = new ArrayList<>();
        try (Connection c = KbDatabase.connect(KbDatabase.CORPUS, "agent_sql"); Statement st = c.createStatement();
             ResultSet rs = st.executeQuery(((String) ((Map<String, Object>) q.get("gold")).get("sql")).strip().replaceAll(";$", ""))) {
            while (rs.next()) {
                List<String> row = new ArrayList<>();
                for (int i = 1; i <= rs.getMetaData().getColumnCount(); i++) {
                    row.add(String.valueOf(rs.getObject(i)));
                }
                rows.add(row);
            }
        }
        Scorer.Verdict v = new Scorer(List.of()).score(gold, GoldQueriesIT.answer((String) gold.get("kind"), rows));
        assertTrue(v.correct(), () -> id + ": " + v.reason() + "; rows " + rows);
    }

    @SuppressWarnings("unchecked")
    @ParameterizedTest(name = "{0}")
    @MethodSource("questions")
    void semanticSearchFindsTheArticles(String id, Map<String, Object> q) throws Exception {
        Map<String, Object> search = (Map<String, Object>) ((Map<String, Object>) q.get("gold")).get("search");
        if (search == null) {
            return;
        }
        Map<String, Object> gold = (Map<String, Object>) q.get("answer");
        Set<String> want = search.containsKey("article") ? Set.of(String.valueOf(search.get("article")))
                : ((List<Object>) gold.get("ids")).stream().map(String::valueOf).collect(Collectors.toSet());
        Map<String, Object> args = new LinkedHashMap<>();
        args.put("query", search.get("query"));
        if (search.containsKey("where")) {
            args.put("where", search.get("where"));
        }
        args.put("k", search.get("within"));
        Agent.ToolAnswer a = Agent.callTool(vector, ToolExecutionRequest.builder().id("1").name("semantic_search")
                .arguments(new ObjectMapper().writeValueAsString(args)).build(), Lang.RU);
        assertFalse(a.error(), a.text());
        Set<String> found = a.text().lines().skip(1).filter(l -> l.contains("\t")).map(l -> l.split("\t")[1])
                .collect(Collectors.toSet());
        assertTrue(found.containsAll(want), () -> id + ": " + want + " not all among " + found + "\n" + a.text());
    }
}
