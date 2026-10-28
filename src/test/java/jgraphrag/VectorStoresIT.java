package jgraphrag;

import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.postgresql.util.PGobject;
import org.testcontainers.containers.Container;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class VectorStoresIT {

    static final int K = 10;
    static final int RUNS = 3;
    static final Path REPORT = Path.of("target/vector-stores.md");
    static final String HEAP = "heap_store";
    static final String LANCE = "lance_store";

    record Filter(String name, String where, boolean pushed) {
    }

    record Hits(int rows, double recall, long nanos) {
    }

    record Cell(double medianMs, double p95Ms, double recall, int minRows) {
    }

    record Config(String name, String schema, String settings) {
    }

    static final List<String> QUERIES = List.of(
            "как ускорить медленные запросы в PostgreSQL",
            "колоночное хранилище для аналитики",
            "векторный поиск по эмбеддингам",
            "выгорание программиста и смена работы",
            "собеседование на позицию junior-разработчика",
            "ChatGPT пишет код вместо разработчика",
            "уязвимость в роутере и взлом домашней сети",
            "разработка инди-игры в одиночку",
            "переезд айтишника в другую страну",
            "Kubernetes в продакшене: ошибки и грабли",
            "микросервисы или монолит",
            "квантовые компьютеры простым языком",
            "история советской вычислительной техники",
            "Rust вместо C++",
            "скорость загрузки веб-страницы",
            "запуск ракет и освоение космоса",
            "импортозамещение после ухода западных вендоров",
            "печать деталей на 3D-принтере",
            "домашний сервер на Linux",
            "красивое доказательство математической задачи");

    static final List<Filter> FILTERS = List.of(
            new Filter("no filter", "true", true),
            new Filter("embedding_name = 'summary'", "embedding_name = 'summary'", true),
            new Filter("primary_genre = 'technical'", "primary_genre = 'technical'", true),
            new Filter("primary_genre = 'opinion'", "primary_genre = 'opinion'", true),
            new Filter("published in March 2023", "published BETWEEN DATE '2023-03-01' AND DATE '2023-03-31'", true),
            new Filter("polarity = 'negative'", "polarity = 'negative'", true),
            new Filter("score >= 100", "score >= 100", true),
            new Filter("nsfw", "nsfw", true),
            new Filter("news, negative", "post_type = 'news' AND polarity = 'negative'", true),
            new Filter("primary_genre = 'fiction'", "primary_genre = 'fiction'", true),
            new Filter("hub PostgreSQL (an array)", "hubs @> ARRAY['PostgreSQL']", true));

    private static Connection pg;
    private static List<PGobject> queries;
    private static final Map<String, Long> matching = new LinkedHashMap<>();
    private static final Map<String, double[]> tenth = new LinkedHashMap<>();
    private static final Map<String, Cell> exactHeap = new LinkedHashMap<>();
    private static final StringBuilder report = new StringBuilder();
    private static final StringBuilder plans = new StringBuilder();

    @BeforeAll
    static void sameRowsInTwoStores() throws Exception {
        List<Corpus.Copied> load = KbDatabase.corpus();
        pg = KbDatabase.connect(KbDatabase.CORPUS, "postgres");
        report.append("# pgvector and Lance on the same rows\n\n")
                .append("corpus.text_embeddings: 147,432 texts of the Habr corpus with EmbeddingGemma vectors (768 float32), ")
                .append("loaded by Corpus from GitHub Pages through DuckDB 2.0 JDBC into a lance table and copied into a heap one. ")
                .append("PostgreSQL 19rc1, pgvector 0.8.7, lance_tam ").append(KbDatabase.LANCE_TAM_COMMIT, 0, 7)
                .append(" (Lance ").append(KbDatabase.LANCE_COMMIT, 0, 7)
                .append("); shared_buffers 2GB, maintenance_work_mem 2GB, 4 parallel maintenance workers.\n\n")
                .append("## Writing the rows\n\n| step | rows | s |\n|---|---:|---:|\n");
        for (Corpus.Copied c : load) {
            row("DuckDB JDBC from GitHub Pages → COPY into lance " + c.table(), c.rows(), c.millis() / 1000.0);
        }
        execute("CREATE SCHEMA heap_store", "CREATE SCHEMA lance_store",
                "CREATE TABLE heap_store.text_embeddings (LIKE corpus.text_embeddings INCLUDING COMMENTS) USING heap",
                "CREATE TABLE lance_store.text_embeddings (LIKE corpus.text_embeddings INCLUDING COMMENTS) USING lance");
        row("INSERT … SELECT into heap", update("INSERT INTO heap_store.text_embeddings SELECT * FROM corpus.text_embeddings"),
                lastSeconds);
        row("INSERT … SELECT into lance", update("INSERT INTO lance_store.text_embeddings SELECT * FROM corpus.text_embeddings"),
                lastSeconds);
        execute("VACUUM ANALYZE heap_store.text_embeddings", "ANALYZE lance_store.text_embeddings");

        report.append("\n## Scalar indexes\n\n| store | index | s | MB |\n|---|---|---:|---:|\n");
        for (String column : List.of("embedding_name", "primary_genre", "polarity", "post_type", "nsfw", "published", "score")) {
            build("pgvector (heap)", "btree (" + column + ")",
                    "CREATE INDEX heap_" + column + " ON heap_store.text_embeddings (" + column + ")");
            String type = List.of("published", "score").contains(column) ? "btree" : "bitmap";
            build("Lance", type + " (" + column + ")", "CREATE INDEX lance_" + column
                    + " ON lance_store.text_embeddings USING lance_index (" + column + ") WITH (type = '" + type + "')");
        }
        build("pgvector (heap)", "gin (hubs)", "CREATE INDEX heap_hubs ON heap_store.text_embeddings USING gin (hubs)");
        build("Lance", "label_list (hubs)", "CREATE INDEX lance_hubs ON lance_store.text_embeddings USING lance_index (hubs)"
                + " WITH (type = 'label_list')");
        sizes();

        Embedder embedder = new Embedder(KbDatabase.ollama());
        queries = new ArrayList<>();
        for (String q : QUERIES) {
            queries.add(vector(embedder.embed(q)));
        }
        for (Filter f : FILTERS) {
            matching.put(f.name(), count("SELECT count(*) FROM heap_store.text_embeddings WHERE " + f.where()));
            double[] d = new double[queries.size()];
            double[] ms = new double[queries.size()];
            int minRows = Integer.MAX_VALUE;
            for (int i = 0; i < queries.size(); i++) {
                long t0 = System.nanoTime();
                List<Double> exact = distances(HEAP, f, queries.get(i));
                ms[i] = (System.nanoTime() - t0) / 1e6;
                d[i] = exact.isEmpty() ? Double.NaN : exact.get(exact.size() - 1);
                minRows = Math.min(minRows, exact.size());
            }
            tenth.put(f.name(), d);
            Arrays.sort(ms);
            exactHeap.put(f.name(), new Cell(ms[ms.length / 2], ms[(int) Math.ceil(ms.length * 0.95) - 1], 1, minRows));
        }
    }

    @Test
    void theStoresHoldTheSameRows() throws Exception {
        String digest = "SELECT count(*), md5(string_agg(md5(task_id || '/' || embedding_name || '/' || index || '/' || text"
                + " || '/' || embedding_vector::text || '/' || habr_id || '/' || coalesce(title, '') || '/'"
                + " || coalesce(published::text, '') || '/' || coalesce(post_type, '') || '/' || coalesce(primary_genre, '')"
                + " || '/' || coalesce(polarity, '') || '/' || coalesce(audience_level, '') || '/'"
                + " || coalesce(demagoguery_severity, '') || '/' || coalesce(nsfw::text, '') || '/'"
                + " || coalesce(advertising::text, '') || '/' || coalesce(score::text, '') || '/'"
                + " || coalesce(array_to_string(hubs, ','), '')), '' ORDER BY task_id, embedding_name, index))"
                + " FROM %s.text_embeddings";
        assertEquals(text(digest.formatted(LANCE)), text(digest.formatted(HEAP)));
        assertEquals(text(digest.formatted("corpus")), text(digest.formatted(HEAP)));
        assertEquals(147_432L, count("SELECT count(*) FROM corpus.text_embeddings"));
        assertEquals(13_275L, count("SELECT count(*) FROM corpus.indexed_text"));
        assertEquals(0L, count("SELECT count(*) FROM heap_store.text_embeddings WHERE abs(vector_norm(embedding_vector) - 1) > 1e-5"));
    }

    @Test
    void theQueriesShareTheCorpusSpace() throws Exception {
        Embedder embedder = new Embedder(KbDatabase.ollama());
        try (Statement st = pg.createStatement(); ResultSet rs = st.executeQuery("""
                SELECT DISTINCT ON (embedding_name) embedding_name, text, embedding_vector::text
                FROM heap_store.text_embeddings WHERE task_id % 97 = 5 ORDER BY embedding_name, task_id, index""")) {
            int n = 0;
            while (rs.next()) {
                float[] mine = embedder.embed(rs.getString(2));
                String[] theirs = rs.getString(3).replaceAll("[\\[\\]]", "").split(",");
                double dot = 0;
                for (int i = 0; i < mine.length; i++) {
                    dot += mine[i] * Double.parseDouble(theirs[i]);
                }
                assertTrue(dot > 0.999, rs.getString(1) + ": cosine " + dot + " of " + rs.getString(2));
                n++;
            }
            assertTrue(n >= 6, n + " fields");
        }
    }

    @Test
    void searchesOnBothStores() throws Exception {
        Map<String, Map<String, Cell>> table = new LinkedHashMap<>();
        report.append("\n## Vector indexes\n\n| store | index | s | MB |\n|---|---|---:|---:|\n");
        table.put("pgvector, exact (no vector index)", exactHeap);
        table.put("Lance, exact (flat search)", run(new Config("Lance, exact (flat search)", LANCE, "")));
        build("pgvector (heap)", "hnsw (m 16, ef_construction 64)",
                "CREATE INDEX heap_hnsw ON heap_store.text_embeddings USING hnsw (embedding_vector vector_cosine_ops)");
        build("Lance", "ivf_hnsw_sq (16 partitions)", "CREATE INDEX lance_hnsw ON lance_store.text_embeddings USING lance_index"
                + " (embedding_vector) WITH (type = 'ivf_hnsw_sq', metric = 'cosine', num_partitions = 16)");
        for (Config c : List.of(new Config("pgvector hnsw, ef_search 40", HEAP, "SET hnsw.ef_search = 40"),
                new Config("pgvector hnsw, ef_search 40, iterative scan", HEAP,
                        "SET hnsw.ef_search = 40; SET hnsw.iterative_scan = relaxed_order"),
                new Config("pgvector hnsw, ef_search 200", HEAP, "SET hnsw.ef_search = 200"),
                new Config("Lance ivf_hnsw_sq", LANCE, ""),
                new Config("Lance ivf_hnsw_sq, refine 10", LANCE, "SET lance.refine_factor = 10"),
                new Config("Lance ivf_hnsw_sq, nprobes 4, refine 10", LANCE, "SET lance.nprobes = 4; SET lance.refine_factor = 10"),
                new Config("Lance ivf_hnsw_sq, all 16 partitions, refine 10", LANCE,
                        "SET lance.nprobes = 16; SET lance.refine_factor = 10"))) {
            table.put(c.name(), run(c));
        }
        explain("pgvector hnsw", HEAP, "polarity = 'negative'");
        explain("Lance ivf_hnsw_sq", LANCE, "polarity = 'negative'");
        execute("DROP INDEX heap_store.heap_hnsw", "DROP INDEX lance_store.lance_hnsw");

        build("pgvector (heap)", "ivfflat (150 lists)", "CREATE INDEX heap_ivf ON heap_store.text_embeddings USING ivfflat"
                + " (embedding_vector vector_cosine_ops) WITH (lists = 150)");
        build("Lance", "ivf_pq (150 partitions, 48 sub-vectors)", "CREATE INDEX lance_pq ON lance_store.text_embeddings USING"
                + " lance_index (embedding_vector) WITH (type = 'ivf_pq', metric = 'cosine', num_partitions = 150,"
                + " num_sub_vectors = 48)");
        for (Config c : List.of(new Config("pgvector ivfflat, probes 1", HEAP, "SET ivfflat.probes = 1"),
                new Config("pgvector ivfflat, probes 10, iterative scan", HEAP,
                        "SET ivfflat.probes = 10; SET ivfflat.iterative_scan = relaxed_order"),
                new Config("Lance ivf_pq", LANCE, ""),
                new Config("Lance ivf_pq, refine 10", LANCE, "SET lance.refine_factor = 10"))) {
            table.put(c.name(), run(c));
        }
        execute("DROP INDEX heap_store.heap_ivf", "DROP INDEX lance_store.lance_pq");
        searches(table);
        report.append(plans);
        Files.createDirectories(REPORT.getParent());
        Files.writeString(REPORT, report, StandardCharsets.UTF_8);
        System.out.println(report);

        for (Filter f : FILTERS) {
            if (!f.pushed()) {
                continue;
            }
            Cell flat = table.get("Lance, exact (flat search)").get(f.name());
            assertTrue(flat.recall() >= 0.99, f.name() + ": Lance's flat search found " + flat.recall() + " of the exact");
            for (Map.Entry<String, Map<String, Cell>> c : table.entrySet()) {
                if (c.getKey().startsWith("Lance") && !c.getKey().contains("nprobes")) {
                    assertEquals(Math.min(K, matching.get(f.name())), c.getValue().get(f.name()).minRows(),
                            c.getKey() + ", " + f.name() + ": a search Lance filters first gives k rows");
                }
            }
        }
    }

    private static Map<String, Cell> run(Config c) throws SQLException {
        execute("RESET ALL");
        for (String s : c.settings().split(";")) {
            if (!s.isBlank()) {
                execute(s.strip());
            }
        }
        Map<String, Cell> cells = new LinkedHashMap<>();
        boolean exact = c.name().contains("exact");
        for (Filter f : FILTERS) {
            double[] ms = new double[queries.size()];
            double recall = 0;
            int minRows = Integer.MAX_VALUE;
            for (int i = 0; i < queries.size(); i++) {
                Hits h = null;
                long[] t = new long[exact ? 1 : RUNS];
                if (!exact) {
                    search(c.schema(), f, queries.get(i), i);
                }
                for (int r = 0; r < t.length; r++) {
                    h = search(c.schema(), f, queries.get(i), i);
                    t[r] = h.nanos();
                }
                Arrays.sort(t);
                ms[i] = t[t.length / 2] / 1e6;
                recall += h.recall();
                minRows = Math.min(minRows, h.rows());
            }
            Arrays.sort(ms);
            cells.put(f.name(), new Cell(ms[ms.length / 2], ms[(int) Math.ceil(ms.length * 0.95) - 1],
                    recall / queries.size(), minRows));
        }
        execute("RESET ALL");
        return cells;
    }

    private static Hits search(String schema, Filter f, PGobject q, int i) throws SQLException {
        double limit = tenth.get(f.name())[i] + 1e-6;
        long t0 = System.nanoTime();
        int rows = 0;
        int hits = 0;
        try (PreparedStatement ps = pg.prepareStatement("SELECT embedding_vector <=> ? AS d FROM " + schema
                + ".text_embeddings WHERE " + f.where() + " ORDER BY embedding_vector <=> ? LIMIT " + K)) {
            ps.setObject(1, q);
            ps.setObject(2, q);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    rows++;
                    hits += rs.getDouble(1) <= limit ? 1 : 0;
                }
            }
        }
        long nanos = System.nanoTime() - t0;
        long expected = Math.min(K, matching.get(f.name()));
        return new Hits(rows, expected == 0 ? 1 : (double) hits / expected, nanos);
    }

    private static List<Double> distances(String schema, Filter f, PGobject q) throws SQLException {
        List<Double> out = new ArrayList<>();
        try (PreparedStatement ps = pg.prepareStatement("SELECT embedding_vector <=> ? FROM " + schema
                + ".text_embeddings WHERE " + f.where() + " ORDER BY 1 LIMIT " + K)) {
            ps.setObject(1, q);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    out.add(rs.getDouble(1));
                }
            }
        }
        return out;
    }

    private static void explain(String name, String schema, String where) throws SQLException {
        plans.append("\n## Plan: ").append(name).append(", WHERE ").append(where).append("\n\n```\n");
        try (PreparedStatement ps = pg.prepareStatement("EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY OFF) "
                + "SELECT task_id, text FROM " + schema + ".text_embeddings WHERE " + where
                + " ORDER BY embedding_vector <=> ? LIMIT " + K)) {
            ps.setObject(1, queries.get(0));
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    plans.append(rs.getString(1).replaceAll("'\\[[-0-9.,eE]+\\]'::vector", "\\$1")).append('\n');
                }
            }
        }
        plans.append("```\n");
    }

    private static void sizes() throws Exception {
        String uri = text("SELECT lance.table_info('lance_store.text_embeddings')->>'uri'");
        Container.ExecResult du = KbDatabase.get().execInContainer("du", "-sb", uri + "/data");
        report.append("\n## Size on disk\n\n| store | rows | scalar indexes |\n|---|---:|---:|\n")
                .append("| pgvector (heap): the heap and its TOAST | ")
                .append(mb(count("SELECT pg_table_size('heap_store.text_embeddings')"))).append(" MB | ")
                .append(mb(count("SELECT sum(pg_relation_size(indexrelid)) FROM pg_index"
                        + " WHERE indrelid = 'heap_store.text_embeddings'::regclass"))).append(" MB |\n")
                .append("| Lance: the dataset's data files | ").append(mb(Long.parseLong(du.getStdout().strip().split("\\s+")[0])))
                .append(" MB | ").append(mb(indexFiles())).append(" MB |\n");
    }

    private static void searches(Map<String, Map<String, Cell>> table) {
        report.append("\n## Searches: the ten nearest, ").append(queries.size())
                .append(" queries per filter\n\nEach cell: median ms of a search (p95 over the queries) · recall@10 against")
                .append(" the exact ten · the fewest rows a search gave.\n\n| configuration |");
        StringBuilder rule = new StringBuilder("|---|");
        for (Filter f : FILTERS) {
            report.append(' ').append(f.name()).append(" (").append(String.format(Locale.ROOT, "%,d", matching.get(f.name())))
                    .append(" rows) |");
            rule.append("---|");
        }
        report.append('\n').append(rule).append('\n');
        for (Map.Entry<String, Map<String, Cell>> c : table.entrySet()) {
            report.append("| ").append(c.getKey()).append(" |");
            for (Filter f : FILTERS) {
                Cell cell = c.getValue().get(f.name());
                report.append(String.format(Locale.ROOT, " %.1f (%.1f) · %.2f · %d |", cell.medianMs(), cell.p95Ms(),
                        cell.recall(), cell.minRows()));
            }
            report.append('\n');
        }
    }

    private static void build(String store, String index, String sql) throws Exception {
        boolean lance = store.startsWith("Lance");
        long before = lance ? indexFiles() : 0;
        long t0 = System.currentTimeMillis();
        execute(sql);
        double s = (System.currentTimeMillis() - t0) / 1000.0;
        long bytes = lance ? indexFiles() - before : count("SELECT pg_relation_size('heap_store." + sql.split("\\s+")[2] + "')");
        report.append(String.format(Locale.ROOT, "| %s | %s | %.1f | %s |%n", store, index, s, mb(bytes)));
    }

    private static long indexFiles() throws Exception {
        String uri = text("SELECT lance.table_info('lance_store.text_embeddings')->>'uri'");
        Container.ExecResult du = KbDatabase.get().execInContainer("sh", "-c", "du -sb '" + uri + "/_indices' 2>/dev/null || echo 0");
        return Long.parseLong(du.getStdout().strip().split("\\s+")[0]);
    }

    private static PGobject vector(float[] v) throws SQLException {
        PGobject o = new PGobject();
        o.setType("vector");
        o.setValue(Embedder.literal(v));
        return o;
    }

    private static double lastSeconds;

    private static long update(String sql) throws SQLException {
        long t0 = System.currentTimeMillis();
        try (Statement st = pg.createStatement()) {
            long n = st.executeLargeUpdate(sql);
            lastSeconds = (System.currentTimeMillis() - t0) / 1000.0;
            return n;
        }
    }

    private static void row(String step, long rows, double seconds) {
        report.append(String.format(Locale.ROOT, "| %s | %,d | %.1f |%n", step, rows, seconds));
    }

    private static void execute(String... sql) throws SQLException {
        try (Statement st = pg.createStatement()) {
            for (String s : sql) {
                st.execute(s);
            }
        }
    }

    private static long count(String sql) throws SQLException {
        try (Statement st = pg.createStatement(); ResultSet rs = st.executeQuery(sql)) {
            rs.next();
            return rs.getLong(1);
        }
    }

    private static String text(String sql) throws SQLException {
        try (Statement st = pg.createStatement(); ResultSet rs = st.executeQuery(sql)) {
            rs.next();
            return rs.getString(1) + (rs.getMetaData().getColumnCount() > 1 ? " " + rs.getString(2) : "");
        }
    }

    private static String mb(long bytes) {
        return String.format(Locale.ROOT, "%.0f", bytes / 1048576.0);
    }
}
