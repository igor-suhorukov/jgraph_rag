package jgraphrag;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.dataformat.yaml.YAMLFactory;
import org.junit.jupiter.api.Test;

import java.nio.file.Path;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class QuestionsTest {

    @SuppressWarnings("unchecked")
    @Test
    void everyQuestionComesWithItsAnswerFormat() throws Exception {
        for (Lang lang : Lang.values()) {
            Map<String, Object> doc = new ObjectMapper(new YAMLFactory())
                    .readValue(Path.of("questions/questions." + lang.code() + ".yaml").toFile(), Map.class);
            int n = 0;
            for (String set : List.of("questions", "pilot")) {
                for (Map<String, Object> q : (List<Map<String, Object>>) doc.get(set)) {
                    String asked = Bench.ask(q, lang);
                    assertTrue(asked.startsWith((String) q.get("question") + "\n\n"), lang + " " + q.get("id"));
                    String kind = (String) ((Map<String, Object>) q.get("answer")).get("kind");
                    String format = q.containsKey("format") ? (String) q.get("format") : kind;
                    assertEquals(lang.format(format), asked.substring(asked.lastIndexOf("\n\n") + 2), lang + " " + q.get("id"));
                    n++;
                }
            }
            assertEquals(18, n, lang + ": 15 questions and 3 pilot ones");
        }
    }

    @Test
    void aQuestionWithoutAnAnswerMustNotSayItsKind() {
        Map<String, Object> q = Map.of("id", "U9", "question", "?", "answer", Map.of("kind", "none"));
        assertThrows(IllegalArgumentException.class, () -> Bench.ask(q, Lang.RU));
    }
}
