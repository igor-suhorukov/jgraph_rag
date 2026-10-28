package jgraphrag;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.modelcontextprotocol.json.jackson2.JacksonMcpJsonMapper;
import io.modelcontextprotocol.server.McpServer;
import io.modelcontextprotocol.server.McpSyncServer;
import io.modelcontextprotocol.server.transport.StdioServerTransportProvider;
import io.modelcontextprotocol.spec.McpSchema;
import org.postgresql.util.PGobject;

import java.io.IOException;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Properties;
import java.util.concurrent.CountDownLatch;
import java.util.regex.Pattern;

public final class MemoryServer {

    static final String BASE = "https://example.org/story-kg/id/habr-1097022/";
    static final int MAX_ROWS = 200;
    static final int MAX_CHARS = 20_000;
    static final String SQL_QUERY = "sql_query";
    static final int MAX_K = 50;
    static final int DEFAULT_K = 10;

    static final Map<String, String> PREFIXES = new LinkedHashMap<>();

    static {
        PREFIXES.put("rdf", "http://www.w3.org/1999/02/22-rdf-syntax-ns#");
        PREFIXES.put("rdfs", "http://www.w3.org/2000/01/rdf-schema#");
        PREFIXES.put("xsd", "http://www.w3.org/2001/XMLSchema#");
        PREFIXES.put("owl", "http://www.w3.org/2002/07/owl#");
        PREFIXES.put("schema", "http://schema.org/");
        PREFIXES.put("kgo", "https://example.org/story-kg/ontology#");
        PREFIXES.put("kgt", "https://example.org/story-kg/ontology/tech#");
        PREFIXES.put("kgg", "https://example.org/story-kg/graph/");
        PREFIXES.put("kge", "https://example.org/story-kg/id/global/");
        PREFIXES.put("kgc", "https://example.org/story-kg/concept/");
        PREFIXES.put("oa", "http://www.w3.org/ns/oa#");
        PREFIXES.put("skos", "http://www.w3.org/2004/02/skos/core#");
        PREFIXES.put("prov", "http://www.w3.org/ns/prov#");
        PREFIXES.put("dcterms", "http://purl.org/dc/terms/");
        PREFIXES.put("foaf", "http://xmlns.com/foaf/0.1/");
        PREFIXES.put("sioc", "http://rdfs.org/sioc/ns#");
        PREFIXES.put("vcard", "http://www.w3.org/2006/vcard/ns#");
        PREFIXES.put("bbo", "https://www.irit.fr/recherches/MELODI/ontologies/BBO#");
        PREFIXES.put("eso", "http://www.newsreader-project.eu/domain-ontology#");
        PREFIXES.put("qb", "http://purl.org/linked-data/cube#");
    }

    private final String jdbcUrl;
    private final Lang lang;
    private final Embedder embedder;
    private final ObjectMapper json = new ObjectMapper();
    private final Map<String, Connection> connections = new HashMap<>();

    MemoryServer(String jdbcUrl, Lang lang, Embedder embedder) {
        this.jdbcUrl = jdbcUrl;
        this.lang = lang;
        this.embedder = embedder;
    }

    public static void main(String[] args) throws Exception {
        List<String> tools = Arrays.asList((args.length > 0 ? args[0] : "sql,sparql").split(","));
        Lang lang = Lang.of(args.length > 1 ? args[1] : "ru");
        String jdbc = System.getenv().getOrDefault("JGRAPH_JDBC", "jdbc:postgresql://127.0.0.1:5432/" + lang.database());
        MemoryServer memory = new MemoryServer(jdbc, lang,
                new Embedder(System.getenv().getOrDefault("JGRAPH_OLLAMA", "http://127.0.0.1:11434")));
        JacksonMcpJsonMapper mapper = new JacksonMcpJsonMapper(new ObjectMapper());
        String input = """
                {"type": "object",
                 "properties": {"query": {"type": "string", "description": "%s"}},
                 "required": ["query"]}""".formatted(lang.queryArgument());
        String search = """
                {"type": "object",
                 "properties": {"query": {"type": "string", "description": "%s"},
                                "where": {"type": "string", "description": "%s"},
                                "k": {"type": "integer", "minimum": 1, "maximum": %d, "description": "%s"}},
                 "required": ["query"]}""".formatted(lang.searchQuery(), lang.searchWhere().replace("\"", "\\\""), MAX_K,
                lang.searchK(DEFAULT_K, MAX_K));
        var spec = McpServer.sync(new StdioServerTransportProvider(mapper))
                .serverInfo("jgraph-rag-memory", "0.1.0")
                .capabilities(McpSchema.ServerCapabilities.builder().tools(false).build());
        for (String tool : tools) {
            switch (tool) {
                case "sql" -> spec.toolCall(McpSchema.Tool.builder(SQL_QUERY, mapper, input).description(lang.sqlDescription()).build(),
                        (exchange, request) -> memory.call(request, true));
                case "sparql" -> spec.toolCall(McpSchema.Tool.builder("sparql_query", mapper, input).description(lang.sparqlDescription()).build(),
                        (exchange, request) -> memory.call(request, false));
                case "corpus" -> spec.toolCall(McpSchema.Tool.builder(SQL_QUERY, mapper, input).description(lang.corpusSqlDescription()).build(),
                        (exchange, request) -> memory.call(request, true));
                case "semantic" -> spec.toolCall(McpSchema.Tool.builder("semantic_search", mapper, search)
                                .description(lang.semanticDescription()).build(),
                        (exchange, request) -> memory.search(request));
                default -> throw new IllegalArgumentException("tool " + tool);
            }
        }
        McpSyncServer server = spec.build();
        CountDownLatch stop = new CountDownLatch(1);
        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            server.closeGracefully();
            stop.countDown();
        }));
        stop.await();
    }

    synchronized McpSchema.CallToolResult call(McpSchema.CallToolRequest request, boolean isSql) {
        Object q = request.arguments() == null ? null : request.arguments().get("query");
        if (!(q instanceof String query) || query.isBlank()) {
            return error(lang.noQuery());
        }
        try {
            return McpSchema.CallToolResult.builder().addTextContent(isSql ? runSql(query) : runSparql(query))
                    .isError(false).build();
        } catch (SQLException e) {
            return error(e.getMessage());
        } catch (Exception e) {
            return error(e.getClass().getSimpleName() + ": " + e.getMessage());
        }
    }

    synchronized McpSchema.CallToolResult search(McpSchema.CallToolRequest request) {
        Map<String, Object> args = request.arguments() == null ? Map.of() : request.arguments();
        if (!(args.get("query") instanceof String query) || query.isBlank()) {
            return error(lang.noQuery());
        }
        Object where = args.get("where");
        if (where != null && !(where instanceof String)) {
            return error(lang.badWhere());
        }
        Object k = args.getOrDefault("k", DEFAULT_K);
        if (!(k instanceof Number n) || n.doubleValue() != Math.rint(n.doubleValue()) || n.intValue() < 1 || n.intValue() > MAX_K) {
            return error(lang.badK(MAX_K));
        }
        try {
            return McpSchema.CallToolResult.builder().addTextContent(runSearch(query, (String) where, n.intValue()))
                    .isError(false).build();
        } catch (SQLException e) {
            return error(e.getMessage());
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            return error(e.getClass().getSimpleName() + ": " + e.getMessage());
        } catch (Exception e) {
            return error(e.getClass().getSimpleName() + ": " + e.getMessage());
        }
    }

    McpSchema.CallToolResult error(String message) {
        return McpSchema.CallToolResult.builder().addTextContent(lang.error() + message).isError(true).build();
    }

    private Connection connection(String role, String tool) throws SQLException {
        Connection c = connections.get(role);
        if (c == null || c.isClosed() || !c.isValid(2)) {
            c = open(role, tool);
            connections.put(role, c);
        }
        return c;
    }

    private Connection connection(boolean isSql) throws SQLException {
        return isSql ? connection("agent_sql", SQL_QUERY) : connection("agent_sparql", "sparql_query");
    }

    private Connection open(String role, String tool) throws SQLException {
        Properties p = new Properties();
        p.setProperty("user", role);
        p.setProperty("ApplicationName", "jgraph-rag " + tool);
        Connection c = DriverManager.getConnection(jdbcUrl, p);
        try {
            c.setReadOnly(true);
            return c;
        } catch (SQLException e) {
            c.close();
            throw e;
        }
    }

    String runSql(String query) throws SQLException {
        try (Statement st = connection(true).createStatement()) {
            st.setMaxRows(MAX_ROWS + 1);
            if (!st.execute(query)) {
                return lang.noRows();
            }
            try (ResultSet rs = st.getResultSet()) {
                return table(rs);
            }
        }
    }

    @SuppressWarnings("java:S2077")
    String runSearch(String query, String where, int k) throws SQLException, IOException, InterruptedException {
        PGobject q = new PGobject();
        q.setType("vector");
        q.setValue(Embedder.literal(embedder.embed(query)));
        String sql = "SELECT task_id, habr_id, title, embedding_name, index, text,"
                + " round((embedding_vector <=> ?)::numeric, 4) AS distance FROM text_embeddings"
                + (where == null || where.isBlank() ? "" : " WHERE (" + where + ")")
                + " ORDER BY embedding_vector <=> ? LIMIT " + k;
        try (PreparedStatement ps = connection("agent_vector", "semantic_search").prepareStatement(sql)) {
            ps.setObject(1, q);
            ps.setObject(2, q);
            try (ResultSet rs = ps.executeQuery()) {
                return table(rs);
            }
        }
    }

    private String table(ResultSet rs) throws SQLException {
        ResultSetMetaData md = rs.getMetaData();
        List<String> header = new ArrayList<>();
        for (int i = 1; i <= md.getColumnCount(); i++) {
            header.add(md.getColumnLabel(i));
        }
        List<List<String>> rows = new ArrayList<>();
        while (rs.next() && rows.size() <= MAX_ROWS) {
            List<String> row = new ArrayList<>();
            for (int i = 1; i <= header.size(); i++) {
                String v = rs.getString(i);
                row.add(v == null ? "NULL" : v);
            }
            rows.add(row);
        }
        return table(header, rows, lang);
    }

    String runSparql(String query) throws SQLException, JsonProcessingException {
        try (PreparedStatement ps = connection(false).prepareStatement("SELECT kb.sparql_json(?, ?)::text")) {
            ps.setString(1, withPrefixes(query));
            ps.setString(2, BASE);
            try (ResultSet rs = ps.executeQuery()) {
                rs.next();
                JsonNode res = json.readTree(rs.getString(1));
                if (res.has("boolean")) {
                    return "ASK\n" + res.get("boolean").asText();
                }
                JsonNode vars = res.path("head").path("vars");
                if (!vars.isArray()) {
                    return clip(res.toString(), lang);
                }
                List<String> header = new ArrayList<>();
                vars.forEach(v -> header.add(v.asText()));
                List<List<String>> rows = new ArrayList<>();
                for (JsonNode b : res.path("results").path("bindings")) {
                    List<String> row = new ArrayList<>();
                    for (String v : header) {
                        row.add(term(b.get(v)));
                    }
                    rows.add(row);
                    if (rows.size() > MAX_ROWS) {
                        break;
                    }
                }
                return table(header, rows, lang);
            }
        }
    }

    static String withPrefixes(String query) {
        StringBuilder head = new StringBuilder();
        for (Map.Entry<String, String> p : PREFIXES.entrySet()) {
            if (!Pattern.compile("(?i)\\bPREFIX\\s+" + Pattern.quote(p.getKey()) + "\\s*:").matcher(query).find()) {
                head.append("PREFIX ").append(p.getKey()).append(": <").append(p.getValue()).append("> ");
            }
        }
        return head + query;
    }

    static String term(JsonNode t) {
        if (t == null || t.isNull()) {
            return "";
        }
        String value = t.path("value").asText();
        return switch (t.path("type").asText()) {
            case "uri" -> iri(value);
            case "bnode" -> "_:" + value;
            default -> t.has("xml:lang") ? "\"" + value + "\"@" + t.get("xml:lang").asText() : value;
        };
    }

    static String iri(String value) {
        if (value.startsWith(BASE)) {
            return "<" + value.substring(BASE.length()) + ">";
        }
        String best = null;
        int length = 0;
        for (Map.Entry<String, String> p : PREFIXES.entrySet()) {
            if (value.startsWith(p.getValue()) && p.getValue().length() > length) {
                best = p.getKey();
                length = p.getValue().length();
            }
        }
        String local = best == null ? null : value.substring(length);
        return local != null && local.matches("[\\p{L}\\p{N}_.\\-]*") ? best + ":" + local : "<" + value + ">";
    }

    static String table(List<String> header, List<List<String>> rows, Lang lang) {
        if (rows.isEmpty()) {
            return String.join("\t", header) + "\n" + lang.rows(0);
        }
        boolean more = rows.size() > MAX_ROWS;
        StringBuilder out = new StringBuilder(String.join("\t", header)).append('\n');
        int shown = 0;
        for (List<String> row : more ? rows.subList(0, MAX_ROWS) : rows) {
            String line = String.join("\t", row.stream().map(v -> v.replace('\t', ' ').replace('\n', ' ')).toList());
            if (out.length() + line.length() + 1 > MAX_CHARS) {
                return out.append(lang.cut(shown, MAX_CHARS)).toString();
            }
            out.append(line).append('\n');
            shown++;
        }
        return out.append(more ? lang.more(MAX_ROWS) : lang.rows(shown)).toString();
    }

    static String clip(String s, Lang lang) {
        return s.length() <= MAX_CHARS ? s : s.substring(0, MAX_CHARS) + "\n" + lang.clipped(MAX_CHARS);
    }
}
