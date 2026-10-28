package jgraphrag;

import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class ScorerTest {

    static final Scorer SCORER = new Scorer(List.of("первая строка", "Он сказал: «Так не бывает. Либо надежно, либо быстро!»"));

    static Agent.Answer values(String... kv) {
        List<Map<String, String>> v = new java.util.ArrayList<>();
        for (int i = 0; i + 1 < kv.length; i += 2) {
            v.add(GoldQueriesIT.entry(kv[i], kv[i + 1]));
        }
        return new Agent.Answer("", v, List.of(), List.of(), false, true);
    }

    @Test
    void anIdCountsInEveryForm() {
        for (String id : List.of("s2", "sec/s2", "<sec/s2>", MemoryServer.BASE + "sec/s2", "S2")) {
            assertEquals("s2", Scorer.norm(id), id);
        }
    }

    @Test
    void anArticleCountsByItsNumberOrItsAddress() {
        for (String id : List.of("707474", "https://habr.com/ru/articles/707474/", "habr.com/ru/articles/707474")) {
            assertEquals("707474", Scorer.norm(id), id);
        }
        Map<String, Object> gold = Map.of("kind", "set", "ids", List.of(707474),
                "labels", List.of("«Мутные» перспективы производителя ламп Thomson на примере лампочки 24Вт с цоколем е27"));
        assertTrue(SCORER.score(gold, values("https://habr.com/ru/articles/707474/", "")).correct());
        assertTrue(SCORER.score(gold, values("x", "«Мутные» перспективы производителя ламп Thomson на примере лампочки 24Вт с цоколем Е27")).correct());
        assertFalse(SCORER.score(gold, values("707474", "", "714704", "")).correct());
    }

    @Test
    void aSetMustBeExactAndMayNameNodesByLabel() {
        Map<String, Object> gold = Map.of("kind", "set", "ids", List.of("postgresql", "mongodb"),
                "labels", List.of("PostgreSQL", "MongoDB"));
        assertTrue(SCORER.score(gold, values("postgresql", "", "MongoDB", "")).correct());
        assertTrue(SCORER.score(gold, values("<postgresql>", "PostgreSQL", "x", "MongoDB")).correct());
        assertFalse(SCORER.score(gold, values("postgresql", "")).correct());
        assertFalse(SCORER.score(gold, values("postgresql", "", "mongodb", "", "clickhouse", "")).correct());
    }

    @Test
    void countsResolveLabels() {
        Map<String, Object> gold = Map.of("kind", "counts", "counts", Map.of("igor_suhorukov", 9, "architect_friend", 8),
                "labels", Map.of("igor_suhorukov", List.of("автор"), "architect_friend", List.of("знакомый архитектор")));
        assertTrue(SCORER.score(gold, values("автор", "9", "Знакомый архитектор", "8")).correct());
        assertFalse(SCORER.score(gold, values("автор", "8", "Знакомый архитектор", "9")).correct());
    }

    @Test
    void aZeroCountIsANodeNotCounted() {
        Map<String, Object> gold = Map.of("kind", "counts", "counts", Map.of("igor_suhorukov", 5),
                "labels", Map.of("igor_suhorukov", List.of("автор"), "architect_friend", List.of("знакомый архитектор")));
        assertTrue(SCORER.score(gold, values("igor_suhorukov", "5", "architect_friend", "0")).correct());
        assertFalse(SCORER.score(gold, values("igor_suhorukov", "5", "architect_friend", "1")).correct());
    }

    @Test
    void contextIsNotChecked() {
        Map<String, Object> gold = Map.of("kind", "set", "ids", List.of("proc_lazy_scan.t4"));
        Agent.Answer a = new Agent.Answer("", List.of(GoldQueriesIT.entry("proc_lazy_scan.t4", "")),
                List.of(GoldQueriesIT.entry("proc_lazy_scan", ""), GoldQueriesIT.entry("lazy_column_read", "")),
                List.of(), false, true);
        assertTrue(SCORER.score(gold, a).correct());
    }

    @Test
    void aNumberCountsWithinTheTolerance() {
        Map<String, Object> gold = Map.of("kind", "number", "value", 49.9, "tolerance", 0);
        assertTrue(SCORER.score(gold, values("obs", "49,9 мс")).correct());
        assertFalse(SCORER.score(gold, values("obs", "50")).correct());
    }

    @Test
    void aQuoteMustStandVerbatimOnItsLine() {
        Map<String, Object> gold = Map.of("kind", "quote", "line", 2, "must_contain", "Либо надежно, либо быстро");
        assertTrue(SCORER.score(gold, quote("Так не бывает. Либо надежно, либо быстро!", 2)).correct());
        assertFalse(SCORER.score(gold, quote("Так не бывает. Либо надежно, либо быстро!", 1)).correct());
        assertFalse(SCORER.score(gold, quote("Либо надёжно, либо быстро, третьего не дано", 2)).correct());
    }

    static Agent.Answer quote(String q, int line) {
        return new Agent.Answer("", List.of(), List.of(), List.of(Map.of("quote", q, "line", line)), false, true);
    }

    @Test
    void onlyNoAnswerAnswersAQuestionWithoutOne() {
        Map<String, Object> gold = Map.of("kind", "none");
        assertTrue(SCORER.score(gold, new Agent.Answer("в памяти нет", List.of(), List.of(), List.of(), true, true)).correct());
        assertFalse(SCORER.score(gold, values("cpu", "Ryzen 9")).correct());
    }

    @Test
    void aRecordTakesFalseInWords() {
        Map<String, Object> gold = Map.of("kind", "record", "fields", Map.of("attacked", "claim_a", "rebutted", false));
        assertTrue(SCORER.score(gold, values("attacked", "claim_a", "опровергнуто", "нет")).correct());
        assertFalse(SCORER.score(gold, values("attacked", "claim_a")).correct());
    }
}
