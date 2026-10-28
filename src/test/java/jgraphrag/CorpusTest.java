package jgraphrag;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class CorpusTest {

    static String escaped(String v) {
        StringBuilder s = new StringBuilder();
        Corpus.escape(s, v);
        return s.toString();
    }

    @Test
    void aValueKeepsItsBackslashesTabsAndLinesInCopy() {
        assertEquals("a\\\\b\\tc\\nd\\re", escaped("a\\b\tc\nd\re"));
        assertEquals("\\\\N", escaped("\\N"), "a text that reads \\N is no NULL");
    }

    @Test
    void anArrayIsQuotedElementByElement() {
        assertEquals("{\"Java\",\"SQL\"}", Corpus.array(new Object[] {"Java", "SQL"}));
        assertEquals("{\"say \\\"hi\\\"\",\"a\\\\b\",NULL}", Corpus.array(new Object[] {"say \"hi\"", "a\\b", null}));
        assertEquals("{}", Corpus.array(new Object[0]));
    }

    @Test
    void aVectorReadsBackAsTheSameFloats() {
        float[] values = {0.1f, -2.5e-8f, 1f, 0.026893448f};
        Object[] boxed = {values[0], values[1], values[2], values[3]};
        StringBuilder s = new StringBuilder();
        Corpus.vector(s, boxed);
        assertEquals("[0.1,-2.5E-8,1.0,0.026893448]", s.toString());
        String[] parts = s.substring(1, s.length() - 1).split(",");
        for (int i = 0; i < values.length; i++) {
            assertEquals(values[i], Float.parseFloat(parts[i]), parts[i]);
        }
    }

    @Test
    void theEmbeddingsQueryReadsEveryPartition() {
        String q = Corpus.embeddings(Corpus.SOURCE, Corpus.PARTITIONS);
        assertTrue(q.contains("text_embeddings_partitions/data_0.parquet'"), q);
        assertTrue(q.contains("text_embeddings_partitions/data_42.parquet'"), q);
        assertTrue(q.contains("a.topics[e.index + 1]['name'] || ' ' || a.topics[e.index + 1]['topic_description']"),
                "a topic's vector is of its name and its description");
    }
}
