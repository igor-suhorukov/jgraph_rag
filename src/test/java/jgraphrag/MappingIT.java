package jgraphrag;

import com.fasterxml.jackson.databind.JsonNode;
import org.junit.jupiter.api.Test;

import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class MappingIT {

    static final String DEFAULT = "(default graph)";
    static final Pattern LITERAL = Pattern.compile("\"(?:[^\"\\\\]|\\\\.)*\"(@[A-Za-z-]+|\\^\\^<[^>]*>)?");
    static final Pattern CYRILLIC = Pattern.compile("[А-Яа-яЁё]");
    static final Pattern QUOTE = Pattern.compile("<http://www\\.w3\\.org/ns/oa#(exact|prefix|suffix)>");

    @Test
    void theRussianMappingGivesTheQuadsOfSourceNq() throws Exception {
        Map<String, Long> expected = new TreeMap<>();
        for (String line : Files.readAllLines(Path.of("data/source.nq"))) {
            if (!line.isBlank()) {
                List<String> t = terms(line);
                expected.merge(t.size() == 4 ? t.get(3) : DEFAULT, 1L, Long::sum);
            }
        }
        Map<String, Long> mapped = new TreeMap<>();
        try (Connection c = KbDatabase.connect(Lang.RU, "postgres")) {
            for (JsonNode b : KbDatabase.sparql(c, "SELECT ?g (COUNT(*) AS ?n) WHERE { GRAPH ?g { ?s ?p ?o } } GROUP BY ?g")
                    .path("results").path("bindings")) {
                mapped.put("<" + b.path("g").path("value").asText() + ">", b.path("n").path("value").asLong());
            }
            JsonNode d = KbDatabase.sparql(c, "SELECT (COUNT(*) AS ?n) WHERE { ?s ?p ?o }").path("results").path("bindings");
            long inDefault = d.get(0).path("n").path("value").asLong();
            if (inDefault > 0) {
                mapped.put(DEFAULT, inDefault);
            }
        }
        assertEquals(10_154L, expected.values().stream().mapToLong(Long::longValue).sum());
        assertEquals(37, expected.size());
        assertEquals(expected, mapped);
    }

    @Test
    void theEnglishMappingGivesTheSameGraphInEnglish() throws Exception {
        String ru = KbDatabase.dump(Lang.RU);
        String en = KbDatabase.dump(Lang.EN);
        assertEquals(10_154, ru.lines().filter(l -> !l.isBlank()).count());
        assertEquals(10_153, en.lines().filter(l -> !l.isBlank()).count(), "«раза» and «раз» are one English word");
        assertEquals(shape(ru), shape(en));
        List<String> russian = en.lines().filter(l -> CYRILLIC.matcher(l).find() && !QUOTE.matcher(l).find()).toList();
        assertTrue(russian.isEmpty(), () -> "Russian in the English graph: " + russian.subList(0, Math.min(5, russian.size())));
    }

    static Set<String> shape(String nquads) {
        Set<String> out = new HashSet<>();
        nquads.lines().filter(l -> !l.isBlank()).forEach(l -> out.add(LITERAL.matcher(l).replaceAll(m -> {
            String tag = m.group(1) == null ? "" : m.group(1);
            return Matcher.quoteReplacement("\"…\"" + (tag.startsWith("@") ? "@lang" : tag));
        })));
        return out;
    }

    static List<String> terms(String line) {
        List<String> out = new ArrayList<>();
        int i = 0, n = line.length();
        while (i < n) {
            char ch = line.charAt(i);
            if (Character.isWhitespace(ch)) {
                i++;
            } else if (ch == '<') {
                int j = line.indexOf('>', i);
                out.add(line.substring(i, j + 1));
                i = j + 1;
            } else if (ch == '"') {
                int j = i + 1;
                while (line.charAt(j) != '"') {
                    j += line.charAt(j) == '\\' ? 2 : 1;
                }
                j++;
                if (j < n && line.charAt(j) == '@') {
                    while (j < n && !Character.isWhitespace(line.charAt(j))) {
                        j++;
                    }
                } else if (line.startsWith("^^<", j)) {
                    j = line.indexOf('>', j) + 1;
                }
                out.add(line.substring(i, j));
                i = j;
            } else if (ch == '.') {
                break;
            } else {
                int j = i;
                while (j < n && !Character.isWhitespace(line.charAt(j))) {
                    j++;
                }
                out.add(line.substring(i, j));
                i = j;
            }
        }
        return out;
    }
}
