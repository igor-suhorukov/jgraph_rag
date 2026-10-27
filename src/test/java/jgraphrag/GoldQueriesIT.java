package jgraphrag;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.dataformat.yaml.YAMLFactory;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;

import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Stream;

import static org.junit.jupiter.api.Assertions.assertTrue;

class GoldQueriesIT {

    @SuppressWarnings("unchecked")
    static Stream<Arguments> cases() throws Exception {
        List<Arguments> out = new ArrayList<>();
        for (Lang lang : Lang.values()) {
            Map<String, Object> doc = new ObjectMapper(new YAMLFactory())
                    .readValue(Path.of("questions/questions." + lang.code() + ".yaml").toFile(), Map.class);
            for (String set : List.of("questions", "pilot")) {
                for (Map<String, Object> q : (List<Map<String, Object>>) doc.get(set)) {
                    for (String language : List.of("sql", "sparql")) {
                        out.add(Arguments.of(lang, q.get("id"), language, q));
                    }
                }
            }
        }
        return out.stream();
    }

    @SuppressWarnings("unchecked")
    @ParameterizedTest(name = "{0} {1} {2}")
    @MethodSource("cases")
    void theGoldQueryAnswersTheQuestion(Lang lang, String id, String language, Map<String, Object> q) throws Exception {
        String query = ((Map<String, String>) q.get("gold")).get(language);
        List<List<String>> rows = "sql".equals(language) ? sql(lang, query) : sparql(lang, query);
        Map<String, Object> gold = (Map<String, Object>) q.get("answer");
        Scorer.Verdict v = new Scorer(Files.readAllLines(Path.of("data/1097022.md"))).score(gold, answer((String) gold.get("kind"), rows));
        assertTrue(v.correct(), () -> lang + " " + id + " " + language + ": " + v.reason() + "; rows " + rows);
    }

    static List<List<String>> sql(Lang lang, String query) throws Exception {
        List<List<String>> rows = new ArrayList<>();
        try (Connection c = KbDatabase.connect(lang, "agent_sql"); Statement st = c.createStatement();
             ResultSet rs = st.executeQuery(query.strip().replaceAll(";$", ""))) {
            int n = rs.getMetaData().getColumnCount();
            while (rs.next()) {
                List<String> row = new ArrayList<>();
                for (int i = 1; i <= n; i++) {
                    row.add(String.valueOf(rs.getObject(i)));
                }
                rows.add(row);
            }
        }
        return rows;
    }

    static List<List<String>> sparql(Lang lang, String query) throws Exception {
        List<List<String>> rows = new ArrayList<>();
        try (Connection c = KbDatabase.connect(lang, "agent_sparql")) {
            JsonNode res = KbDatabase.sparql(c, query);
            List<String> vars = new ArrayList<>();
            res.path("head").path("vars").forEach(v -> vars.add(v.asText()));
            for (JsonNode b : res.path("results").path("bindings")) {
                List<String> row = new ArrayList<>();
                for (String v : vars) {
                    row.add(b.has(v) ? b.get(v).path("value").asText() : "");
                }
                rows.add(row);
            }
        }
        return rows;
    }

    static Agent.Answer answer(String kind, List<List<String>> rows) {
        List<Map<String, String>> values = new ArrayList<>();
        List<Map<String, Object>> evidence = new ArrayList<>();
        for (List<String> row : rows) {
            switch (kind) {
                case "quote" -> evidence.add(Map.of("quote", row.get(row.size() - 1),
                        "line", (int) Double.parseDouble(row.get(row.size() - 2))));
                case "counts" -> values.add(entry(row.get(0), row.get(row.size() - 1)));
                case "numbers" -> values.add(entry(row.get(0), row.subList(1, row.size()).stream()
                        .filter(s -> !Scorer.numbersIn(s).isEmpty()).findFirst().orElse("")));
                case "set" -> values.add(entry(row.get(0), ""));
                default -> row.forEach(cell -> values.add(entry(cell, cell)));
            }
        }
        return new Agent.Answer("", values, List.of(), evidence, "none".equals(kind) && rows.isEmpty(), true);
    }

    static Map<String, String> entry(String key, String value) {
        Map<String, String> m = new LinkedHashMap<>();
        m.put("key", key);
        m.put("value", value);
        return m;
    }
}
