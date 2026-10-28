package jgraphrag;

import org.postgresql.PGConnection;
import org.postgresql.copy.CopyIn;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;
import java.sql.Array;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Properties;
import java.util.stream.Collectors;
import java.util.stream.IntStream;

public final class Corpus {

    private static final Logger LOG = LoggerFactory.getLogger(Corpus.class);

    static final String SOURCE = "https://igor-suhorukov.github.io/semantic_and_structured_search/assets/";
    static final int PARTITIONS = 43;
    static final int FLUSH_BYTES = 1 << 20;

    record Copied(String table, long rows, long millis) {
    }

    private record Copy(CopyIn in) implements AutoCloseable {

        @Override
        public void close() throws SQLException {
            if (in.isActive()) {
                in.cancelCopy();
            }
        }
    }

    private Corpus() {
    }

    public static void main(String[] args) throws Exception {
        Map<String, String> opt = Bench.options(args);
        String url = opt.getOrDefault("jdbc", System.getenv().getOrDefault("JGRAPH_CORPUS_JDBC",
                "jdbc:postgresql://127.0.0.1:5432/habr"));
        Properties p = new Properties();
        p.setProperty("user", opt.getOrDefault("user", "postgres"));
        p.setProperty("ApplicationName", "jgraph-rag corpus");
        try (Connection pg = DriverManager.getConnection(url, p)) {
            for (Copied c : load(pg, opt.getOrDefault("source", SOURCE), PARTITIONS)) {
                LOG.atInfo().log(() -> String.format("%s: %,d rows in %.1f s", c.table(), c.rows(), c.millis() / 1000.0));
            }
        }
    }

    static List<Copied> load(Connection pg, String source, int partitions) throws SQLException {
        Properties streamed = new Properties();
        streamed.setProperty("jdbc_stream_results", "true");
        try (Connection duck = DriverManager.getConnection("jdbc:duckdb:", streamed)) {
            return List.of(copy(duck, articles(source), pg, "corpus.indexed_text"),
                    copy(duck, embeddings(source, partitions), pg, "corpus.text_embeddings"));
        }
    }

    static String articles(String source) {
        return """
                SELECT task_id, metadata_int['id'] AS habr_id, url, metadata_string['title'] AS title, title AS llm_title,
                       metadata_string['author'] AS author, CAST(metadata_string['published'] AS TIMESTAMP) AS published,
                       metadata_string['postType'] AS post_type,
                       metadata_list['hub_tags'] AS hubs, metadata_list['user_tags'] AS tags,
                       metadata_int['score'] AS score, metadata_int['votesCountPlus'] AS votes_plus,
                       metadata_int['votesCountMinus'] AS votes_minus, metadata_int['votesCount'] AS votes_count,
                       metadata_int['readingCount'] AS reading_count, metadata_int['commentsCount'] AS comments_count,
                       metadata_int['favoritesCount'] AS favorites_count, metadata_int['authorScore'] AS author_score,
                       metadata_int['authorVotesCount'] AS author_votes,
                       summary, meaning,
                       target_audience['level'] AS audience_level, target_audience['audience_description'] AS audience_description,
                       genre['primary_genre'] AS primary_genre, genre['secondary_genres'] AS secondary_genres,
                       list_transform(topics, lambda t: t['name']) AS topic_names,
                       list_transform(topics, lambda t: t['topic_description']) AS topic_descriptions,
                       themes, key_insights, keywords, keyword_taxonomy AS keyword_notes,
                       is_not_safe_for_work AS nsfw, nsfw_reasons,
                       sentiment['polarity'] AS polarity, sentiment['confidence'] AS sentiment_confidence,
                       sentiment['tone'] AS tone, sentiment['explanation'] AS sentiment_explanation,
                       completeness['score'] AS completeness_score, completeness['level'] AS completeness_level,
                       completeness['missing_elements'] AS missing_elements,
                       contradictory_statements,
                       demagoguery_analysis['detected_techniques_used_in_this_text'] AS demagoguery_techniques,
                       demagoguery_analysis['severity'] AS demagoguery_severity,
                       demagoguery_analysis['explanation'] AS demagoguery_explanation,
                       presence_of_advertising AS advertising, advertising_details['advertising_items'] AS advertising_items,
                       advertising_details['confidence'] AS advertising_confidence,
                       advertising_details['explanation'] AS advertising_explanation
                FROM read_parquet('%sindexed_text.parquet')
                ORDER BY task_id""".formatted(source);
    }

    static String embeddings(String source, int partitions) {
        String files = IntStream.range(0, partitions)
                .mapToObj(i -> "'" + source + "text_embeddings_partitions/data_" + i + ".parquet'")
                .collect(Collectors.joining(", "));
        return """
                SELECT e.task_id, e.embedding_name, e.index,
                       CASE e.embedding_name
                         WHEN 'summary' THEN a.summary
                         WHEN 'meaning' THEN a.meaning
                         WHEN 'insight' THEN a.key_insights[e.index + 1]
                         WHEN 'theme' THEN a.themes[e.index + 1]
                         WHEN 'topic' THEN a.topics[e.index + 1]['name'] || ' ' || a.topics[e.index + 1]['topic_description']
                         WHEN 'audience' THEN a.target_audience['audience_description']
                         WHEN 'contradictory' THEN a.contradictory_statements[e.index + 1]
                         WHEN 'nsfwReason' THEN a.nsfw_reasons[e.index + 1]
                       END AS text,
                       e.embedding_vector,
                       a.metadata_int['id'] AS habr_id, a.metadata_string['title'] AS title,
                       CAST(CAST(a.metadata_string['published'] AS TIMESTAMP) AS DATE) AS published,
                       a.metadata_string['postType'] AS post_type, a.genre['primary_genre'] AS primary_genre,
                       a.sentiment['polarity'] AS polarity, a.target_audience['level'] AS audience_level,
                       a.demagoguery_analysis['severity'] AS demagoguery_severity, a.is_not_safe_for_work AS nsfw,
                       a.presence_of_advertising AS advertising, a.metadata_int['score'] AS score,
                       a.metadata_list['hub_tags'] AS hubs
                FROM read_parquet([%s]) e
                JOIN read_parquet('%sindexed_text.parquet') a USING (task_id)
                ORDER BY e.task_id, e.embedding_name, e.index""".formatted(files, source);
    }

    static Copied copy(Connection duck, String query, Connection pg, String table) throws SQLException {
        long t0 = System.currentTimeMillis();
        try (Statement st = duck.createStatement(); ResultSet rs = st.executeQuery(query)) {
            ResultSetMetaData md = rs.getMetaData();
            List<String> columns = new ArrayList<>();
            for (int i = 1; i <= md.getColumnCount(); i++) {
                columns.add(md.getColumnLabel(i));
            }
            long rows = 0;
            try (Copy copy = new Copy(pg.unwrap(PGConnection.class).getCopyAPI()
                    .copyIn("COPY " + table + " (" + String.join(", ", columns) + ") FROM STDIN"))) {
                ByteArrayOutputStream buf = new ByteArrayOutputStream(2 * FLUSH_BYTES);
                StringBuilder line = new StringBuilder();
                while (rs.next()) {
                    line.setLength(0);
                    for (int i = 1; i <= columns.size(); i++) {
                        if (i > 1) {
                            line.append('\t');
                        }
                        field(line, rs, i, md.getColumnTypeName(i));
                    }
                    buf.writeBytes(line.append('\n').toString().getBytes(StandardCharsets.UTF_8));
                    rows++;
                    if (buf.size() >= FLUSH_BYTES) {
                        copy.in().writeToCopy(buf.toByteArray(), 0, buf.size());
                        buf.reset();
                    }
                }
                copy.in().writeToCopy(buf.toByteArray(), 0, buf.size());
                copy.in().endCopy();
            }
            return new Copied(table, rows, System.currentTimeMillis() - t0);
        }
    }

    private static void field(StringBuilder out, ResultSet rs, int i, String type) throws SQLException {
        if (type.endsWith("[]")) {
            Array a = rs.getArray(i);
            if (a == null) {
                out.append("\\N");
            } else if (type.startsWith("FLOAT")) {
                vector(out, (Object[]) a.getArray());
            } else {
                escape(out, array((Object[]) a.getArray()));
            }
            return;
        }
        String v = rs.getString(i);
        if (v == null) {
            out.append("\\N");
        } else {
            escape(out, v);
        }
    }

    static void vector(StringBuilder out, Object[] values) {
        out.append('[');
        for (int j = 0; j < values.length; j++) {
            if (j > 0) {
                out.append(',');
            }
            out.append(((Number) values[j]).floatValue());
        }
        out.append(']');
    }

    static String array(Object[] values) {
        StringBuilder s = new StringBuilder("{");
        for (int j = 0; j < values.length; j++) {
            if (j > 0) {
                s.append(',');
            }
            if (values[j] == null) {
                s.append("NULL");
            } else {
                s.append('"').append(values[j].toString().replace("\\", "\\\\").replace("\"", "\\\"")).append('"');
            }
        }
        return s.append('}').toString();
    }

    static void escape(StringBuilder out, String v) {
        for (int j = 0; j < v.length(); j++) {
            char ch = v.charAt(j);
            switch (ch) {
                case '\\' -> out.append("\\\\");
                case '\t' -> out.append("\\t");
                case '\n' -> out.append("\\n");
                case '\r' -> out.append("\\r");
                default -> out.append(ch);
            }
        }
    }
}
