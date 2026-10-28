package jgraphrag;

import org.junit.jupiter.api.Test;

import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class ConditionsTest {

    @Test
    void sparqlFirstIsBothInTheOtherOrder() throws Exception {
        for (Lang lang : Lang.values()) {
            String both = Bench.system("both", lang);
            String first = Bench.system("both_sparql_first", lang);
            String sqlSection = Bench.resource(lang.code() + "/howto_sql.md").lines().findFirst().orElseThrow();
            String sparqlSection = Bench.resource(lang.code() + "/howto_sparql.md").lines().findFirst().orElseThrow();
            assertTrue(both.indexOf(sqlSection) < both.indexOf(sparqlSection), lang + " both: SQL first");
            assertTrue(first.indexOf(sparqlSection) < first.indexOf(sqlSection), lang + " both_sparql_first: SPARQL first");
            assertTrue(both.indexOf("sql_query") < both.indexOf("sparql_query"), lang + " both names sql_query first");
            assertTrue(first.indexOf("sparql_query") < first.indexOf("sql_query"), lang + " both_sparql_first names sparql_query first");

            assertEquals(both.length(), first.length(), lang + ": the same text");
            Set<String> changed = new HashSet<>(both.lines().toList());
            changed.removeAll(first.lines().toList());
            assertFalse(changed.isEmpty());
            for (String line : changed) {
                assertTrue(line.contains("sql_query") && line.contains("sparql_query"), lang + ": only the sentence on the tools moves: " + line);
            }
        }
        assertEquals(List.of("sql", "sparql"), List.of(Bench.CONDITION_TOOLS.get("both").split(",")));
        assertEquals(List.of("sparql", "sql"), List.of(Bench.CONDITION_TOOLS.get("both_sparql_first").split(",")));
    }

    @Test
    void theCorpusConditionsDifferInTheirToolsAlone() throws Exception {
        String sql = Bench.system("corpus_sql", Lang.RU);
        String vector = Bench.system("vector", Lang.RU);
        String both = Bench.system("vector_sql", Lang.RU);
        String memory = Bench.resource("ru/corpus.md").strip();
        for (String s : List.of(sql, vector, both)) {
            assertTrue(s.contains(memory), "the same description of the corpus");
            assertFalse(s.contains("{{"), s);
        }
        assertTrue(sql.contains("sql_query") && !sql.contains("semantic_search"));
        assertTrue(vector.contains("semantic_search") && !vector.contains("sql_query"));
        assertTrue(both.indexOf("Инструмент semantic_search") < both.indexOf("Инструмент sql_query"));
        assertEquals("corpus", Bench.CONDITION_TOOLS.get("corpus_sql"));
        assertEquals(List.of("semantic", "corpus"), List.of(Bench.CONDITION_TOOLS.get("vector_sql").split(",")));
        assertTrue(Bench.isCorpus("vector") && !Bench.isCorpus("both"));
        assertEquals(List.of("corpus_sql", "vector", "vector_sql"), Bench.Settings.of(Map.of("set", "corpus")).conditions());
        Map<String, String> english = Map.of("set", "corpus", "lang", "en");
        assertThrows(IllegalArgumentException.class, () -> Bench.Settings.of(english));
    }

    @Test
    void anUnknownConditionIsAnError() {
        assertThrows(IllegalArgumentException.class, () -> Bench.system("sql_first", Lang.RU));
        assertThrows(IllegalArgumentException.class, () -> Lang.EN.tools("sql_first"));
    }
}
