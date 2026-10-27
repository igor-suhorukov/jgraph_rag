package jgraphrag;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class MemoryServerFormatTest {

    static String term(String json) throws Exception {
        return MemoryServer.term(new ObjectMapper().readTree(json));
    }

    @Test
    void termsReadAsInAQuery() throws Exception {
        assertEquals("<sec/s2>", term("{\"type\": \"uri\", \"value\": \"" + MemoryServer.BASE + "sec/s2\"}"));
        assertEquals("schema:Claim", term("{\"type\": \"uri\", \"value\": \"http://schema.org/Claim\"}"));
        assertEquals("kgo:claimRole", term("{\"type\": \"uri\", \"value\": \"https://example.org/story-kg/ontology#claimRole\"}"));
        assertEquals("<https://example.org/story-kg/concept/stance/irony>",
                term("{\"type\": \"uri\", \"value\": \"https://example.org/story-kg/concept/stance/irony\"}"));
        assertEquals("<https://github.com/igor-suhorukov/pg_vexec>",
                term("{\"type\": \"uri\", \"value\": \"https://github.com/igor-suhorukov/pg_vexec\"}"));
        assertEquals("\"текст\"@ru", term("{\"type\": \"literal\", \"value\": \"текст\", \"xml:lang\": \"ru\"}"));
        assertEquals("28", term("{\"type\": \"literal\", \"value\": \"28\", \"datatype\": \"http://www.w3.org/2001/XMLSchema#integer\"}"));
        assertEquals("_:b1", term("{\"type\": \"bnode\", \"value\": \"b1\"}"));
    }

    @Test
    void theStandardPrefixesAreDeclaredWhenTheQueryLeavesThemOut() {
        String q = "SELECT ?c WHERE {\n  ?c a schema:Claim\n}";
        String with = MemoryServer.withPrefixes(q);
        assertTrue(with.startsWith("PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> "), with);
        assertTrue(with.contains("PREFIX schema: <http://schema.org/> "), with);
        assertTrue(with.endsWith(q), with);
        assertEquals(q.split("\n").length, with.split("\n").length, "the query's lines stay where they were");
        String own = "prefix schema: <https://schema.org/> SELECT ?c WHERE { ?c a schema:Claim }";
        assertEquals(1, MemoryServer.withPrefixes(own).split("(?i)PREFIX\\s+schema:").length - 1, "its own declaration is kept");
    }

    @Test
    void aTableIsCutAtTheRowLimit() {
        List<List<String>> rows = new ArrayList<>();
        for (int i = 0; i <= MemoryServer.MAX_ROWS; i++) {
            rows.add(List.of(String.valueOf(i), "a\tb\nc"));
        }
        String t = MemoryServer.table(List.of("n", "v"), rows, Lang.RU);
        String[] lines = t.split("\n");
        assertEquals(MemoryServer.MAX_ROWS + 2, lines.length);
        assertEquals("0\ta b c", lines[1]);
        assertEquals("(показаны первые 200 строк, есть ещё)", lines[lines.length - 1]);
        assertEquals("n\n(строк: 0)", MemoryServer.table(List.of("n"), List.of(), Lang.RU));
        assertEquals("n\n(rows: 0)", MemoryServer.table(List.of("n"), List.of(), Lang.EN));
        assertTrue(MemoryServer.table(List.of("n", "v"), rows, Lang.EN).endsWith("(the first 200 rows shown, there are more)"));
    }

    @Test
    void aTableIsCutAtTheCharacterLimit() {
        List<List<String>> rows = new ArrayList<>();
        for (int i = 0; i < 100; i++) {
            rows.add(List.of("x".repeat(500)));
        }
        String t = MemoryServer.table(List.of("v"), rows, Lang.RU);
        assertTrue(t.length() <= MemoryServer.MAX_CHARS + 100);
        assertTrue(t.endsWith("ответ обрезан до 20000 символов)"), t.substring(t.length() - 60));
        assertTrue(MemoryServer.table(List.of("v"), rows, Lang.EN).endsWith("the answer is cut at 20000 characters)"));
    }
}
