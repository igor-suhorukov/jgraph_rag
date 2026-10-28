package jgraphrag;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.dataformat.yaml.YAMLFactory;
import dev.langchain4j.agent.tool.ToolSpecification;
import dev.langchain4j.mcp.client.DefaultMcpClient;
import dev.langchain4j.mcp.client.McpClient;
import dev.langchain4j.mcp.client.transport.stdio.StdioMcpTransport;
import dev.langchain4j.model.chat.ChatModel;
import dev.langchain4j.model.openai.OpenAiChatModel;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.BufferedWriter;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Queue;
import java.util.Set;
import java.util.TreeMap;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

public final class Bench {

    private static final Logger LOG = LoggerFactory.getLogger(Bench.class);

    static final String SQL = "sql";
    static final String SPARQL = "sparql";
    static final String BOTH = "both";
    static final String BOTH_SPARQL_FIRST = "both_sparql_first";
    static final String CORPUS_SQL = "corpus_sql";
    static final String VECTOR = "vector";
    static final String VECTOR_SQL = "vector_sql";
    static final String CORPUS = "corpus";

    private static final String ANSWER = "answer";
    private static final String QUESTION = "question";
    private static final String QUESTIONS = "questions";
    private static final String MODEL = "model";
    private static final String CONDITION = "condition";
    private static final String REPEAT = "repeat";

    record Model(String key, String id, List<String> endpoints) {
    }

    static final List<Model> MODELS = List.of(
            new Model("deepseek", "deepseek/deepseek-v4.1-flash-1017", List.of("deepinfra/fp8", "nebius/fp8")),
            new Model("gemma", "google/gemma-4-31b-it", List.of("deepinfra/fp8", "parasail/fp8")),
            new Model("qwen", "qwen/qwen3.8-27b", List.of("deepinfra/bf16", "cerebras/fp16")));

    static final Map<String, String> CONDITION_TOOLS = Map.of(SQL, SQL, SPARQL, SPARQL, BOTH, "sql,sparql",
            BOTH_SPARQL_FIRST, "sparql,sql", CORPUS_SQL, CORPUS, VECTOR, "semantic", VECTOR_SQL, "semantic,corpus");

    private static final ObjectMapper JSON = new ObjectMapper();

    record Task(Map<String, Object> question, int repeat) {
    }

    record Settings(Lang lang, String set, List<String> conditions, int repeats, int workers, Set<String> only,
                    Path out, List<Model> models, Path questions, Path article, boolean dryRun) {

        static Settings of(Map<String, String> opt) {
            Lang lang = Lang.of(opt.getOrDefault("lang", "ru"));
            String set = opt.getOrDefault("set", "main");
            List<Model> models = new ArrayList<>();
            for (String k : opt.getOrDefault("models", "deepseek,gemma,qwen").split(",")) {
                models.add(MODELS.stream().filter(m -> m.key().equals(k)).findFirst()
                        .orElseThrow(() -> new IllegalArgumentException("model " + k)));
            }
            boolean corpus = CORPUS.equals(set);
            if (corpus && lang != Lang.RU) {
                throw new IllegalArgumentException("the corpus is Russian: --set corpus runs with --lang ru");
            }
            return new Settings(lang, set,
                    List.of(opt.getOrDefault("conditions", corpus ? "corpus_sql,vector,vector_sql" : "sql,sparql,both").split(",")),
                    Integer.parseInt(opt.getOrDefault("repeats", "3")),
                    Integer.parseInt(opt.getOrDefault("workers", "8")),
                    opt.containsKey("only") ? Set.of(opt.get("only").split(",")) : Set.of(),
                    Path.of(opt.getOrDefault("out", "results/" + set + "." + lang.code() + ".jsonl")),
                    models,
                    Path.of(opt.getOrDefault(QUESTIONS, QUESTIONS + "/" + (corpus ? CORPUS : QUESTIONS) + "." + lang.code()
                            + ".yaml")),
                    Path.of(opt.getOrDefault("article", "data/1097022.md")),
                    opt.containsKey("dry-run"));
        }
    }

    record Job(Model model, ChatModel chat, Lang lang, String set, String condition, String system, Scorer scorer,
               Sink sink) {
    }

    static final class Sink {
        private final BufferedWriter writer;

        Sink(BufferedWriter writer) {
            this.writer = writer;
        }

        synchronized void write(String line) throws IOException {
            writer.write(line);
            writer.newLine();
            writer.flush();
        }
    }

    public static void main(String[] args) throws Exception {
        Settings s = Settings.of(options(args));
        List<Map<String, Object>> questions = questions(s);
        Scorer scorer = new Scorer(Files.readAllLines(s.article()));
        Map<String, String> systems = new HashMap<>();
        for (String c : s.conditions()) {
            systems.put(c, system(c, s.lang()));
        }
        if (s.dryRun()) {
            dryRun(s, systems);
            return;
        }
        String key = System.getenv("OPENROUTER_API_KEY");
        if (key == null || key.isBlank()) {
            throw new IllegalStateException("OPENROUTER_API_KEY is not set");
        }
        run(s, questions, systems, scorer, key);
        summary(s.out());
    }

    @SuppressWarnings("unchecked")
    static List<Map<String, Object>> questions(Settings s) throws IOException {
        Map<String, Object> doc = new ObjectMapper(new YAMLFactory()).readValue(s.questions().toFile(), Map.class);
        List<Map<String, Object>> questions =
                new ArrayList<>((List<Map<String, Object>>) doc.get("pilot".equals(s.set()) ? "pilot" : QUESTIONS));
        if (!s.only().isEmpty()) {
            questions.removeIf(q -> !s.only().contains(q.get("id")));
        }
        return questions;
    }

    static void dryRun(Settings s, Map<String, String> systems) {
        for (String c : s.conditions()) {
            try (DefaultMcpClient client = memory(c, s.lang())) {
                List<String> tools = client.listTools().stream().map(ToolSpecification::name).toList();
                LOG.atInfo().log(() -> String.format("%-6s system prompt %,d chars; tools %s", c, systems.get(c).length(),
                        tools));
            }
        }
    }

    static void run(Settings s, List<Map<String, Object>> questions, Map<String, String> systems, Scorer scorer,
                    String key) throws IOException, InterruptedException, ExecutionException {
        Set<String> done = done(s.out());
        Files.createDirectories(s.out().toAbsolutePath().getParent());
        try (BufferedWriter w = Files.newBufferedWriter(s.out(), StandardCharsets.UTF_8, StandardOpenOption.CREATE,
                StandardOpenOption.APPEND);
             ExecutorService pool = Executors.newFixedThreadPool(s.models().size() * s.conditions().size() * s.workers())) {
            Sink sink = new Sink(w);
            List<Future<?>> jobs = new ArrayList<>();
            for (Model m : s.models()) {
                ChatModel chat = chatModel(m, key);
                for (String c : s.conditions()) {
                    Job job = new Job(m, chat, s.lang(), s.set(), c, systems.get(c), scorer, sink);
                    Queue<Task> queue = queue(s, questions, done, m, c);
                    for (int i = 0; i < s.workers(); i++) {
                        jobs.add(pool.submit(() -> {
                            work(job, queue);
                            return null;
                        }));
                    }
                }
            }
            for (Future<?> j : jobs) {
                j.get();
            }
        }
    }

    static Queue<Task> queue(Settings s, List<Map<String, Object>> questions, Set<String> done, Model m,
                             String condition) {
        Queue<Task> queue = new ConcurrentLinkedQueue<>();
        for (int r = 1; r <= s.repeats(); r++) {
            for (Map<String, Object> q : questions) {
                if (!done.contains(runKey(s.lang().code(), s.set(), (String) q.get("id"), m.key(), condition, r))) {
                    queue.add(new Task(q, r));
                }
            }
        }
        return queue;
    }

    static ChatModel chatModel(Model m, String key) {
        return OpenAiChatModel.builder()
                .baseUrl("https://openrouter.ai/api/v1")
                .apiKey(key)
                .modelName(m.id())
                .customParameters(Map.of(
                        "provider", Map.of("order", m.endpoints(), "allow_fallbacks", false, "require_parameters", true),
                        "reasoning", Map.of("effort", "medium")))
                .returnThinking(true)
                .sendThinking(true, "reasoning")
                .maxTokens(16384)
                .timeout(Duration.ofMinutes(4))
                .maxRetries(0)
                .build();
    }

    static void work(Job job, Queue<Task> queue) throws IOException {
        DefaultMcpClient client = null;
        try {
            for (Task task = queue.poll(); task != null; task = queue.poll()) {
                if (client == null) {
                    client = memory(job.condition(), job.lang());
                }
                runOne(job, client, task);
            }
        } finally {
            if (client != null) {
                client.close();
            }
        }
    }

    static void runOne(Job job, McpClient client, Task task) throws IOException {
        Map<String, Object> q = task.question();
        Instant started = Instant.now();
        String asked = ask(q, job.lang());
        Agent.Outcome o = new Agent(job.chat(), client, job.lang()).run(job.system(), asked);
        Scorer.Verdict v = verdict(job.scorer(), q, o);
        job.sink().write(JSON.writeValueAsString(entry(job, task, started, asked, o, v)));
        LOG.atInfo().log(() -> progress(job, task, o, v));
    }

    @SuppressWarnings("unchecked")
    static Scorer.Verdict verdict(Scorer scorer, Map<String, Object> q, Agent.Outcome o) {
        return o.answer() == null ? new Scorer.Verdict(false, o.stop())
                : scorer.score((Map<String, Object>) q.get(ANSWER), o.answer());
    }

    static Map<String, Object> entry(Job job, Task task, Instant started, String asked, Agent.Outcome o,
                                     Scorer.Verdict v) {
        Map<String, Object> rec = new LinkedHashMap<>();
        rec.put("lang", job.lang().code());
        rec.put("set", job.set());
        rec.put(QUESTION, task.question().get("id"));
        rec.put("type", task.question().get("type"));
        rec.put("asked", asked);
        rec.put(MODEL, job.model().key());
        rec.put("model_id", job.model().id());
        rec.put("endpoints", job.model().endpoints());
        rec.put("providers", o.providers());
        rec.put(CONDITION, job.condition());
        rec.put(REPEAT, task.repeat());
        rec.put("started", started.toString());
        rec.put("correct", v.correct());
        rec.put("reason", v.reason());
        rec.put("stop", o.stop());
        rec.put(ANSWER, o.answer());
        rec.put("model_calls", o.modelCalls());
        rec.put("tool_calls", o.toolCalls());
        rec.put("tool_errors", o.toolErrors());
        rec.put("retries", o.retries());
        rec.put("input_tokens", o.inputTokens());
        rec.put("cached_tokens", o.cachedTokens());
        rec.put("output_tokens", o.outputTokens());
        rec.put("reasoning_tokens", o.reasoningTokens());
        rec.put("cost_usd", o.costUsd());
        rec.put("millis", o.millis());
        rec.put("trace", o.trace());
        return rec;
    }

    static String progress(Job job, Task task, Agent.Outcome o, Scorer.Verdict v) {
        return String.format("%s %s %-8s %-6s r%d %-3s %-5s %-11s tools %2d (err %d) retries %d %6.1fs %s %s %s",
                job.lang().code(), job.set(), job.model().key(), job.condition(), task.repeat(), task.question().get("id"),
                v.correct() ? "OK" : "wrong", o.stop(), o.toolCalls(), o.toolErrors(), o.retries(), o.millis() / 1000.0,
                o.costUsd() == null ? "$?" : String.format("$%.4f", o.costUsd()), o.providers(),
                v.correct() ? "" : v.reason());
    }

    @SuppressWarnings("unchecked")
    static String ask(Map<String, Object> q, Lang lang) {
        Object format = q.get("format");
        String kind = format != null ? (String) format : (String) ((Map<String, Object>) q.get(ANSWER)).get("kind");
        if ("none".equals(kind)) {
            throw new IllegalArgumentException("question " + q.get("id") + " needs a format: its answer is none");
        }
        return q.get(QUESTION) + "\n\n" + lang.format(kind);
    }

    static boolean isCorpus(String condition) {
        return Set.of(CORPUS_SQL, VECTOR, VECTOR_SQL).contains(condition);
    }

    static DefaultMcpClient memory(String condition, Lang lang) {
        String jdbc = isCorpus(condition)
                ? System.getenv().getOrDefault("JGRAPH_CORPUS_JDBC", "jdbc:postgresql://127.0.0.1:5432/habr")
                : System.getenv().getOrDefault("JGRAPH_JDBC", "jdbc:postgresql://127.0.0.1:5432/kb_{lang}");
        return memory(condition, lang, System.getProperty("java.class.path"), jdbc.replace("{lang}", lang.code()),
                System.getenv().getOrDefault("JGRAPH_OLLAMA", "http://127.0.0.1:11434"));
    }

    static DefaultMcpClient memory(String condition, Lang lang, String classpath, String jdbcUrl) {
        return memory(condition, lang, classpath, jdbcUrl, "http://127.0.0.1:11434");
    }

    static DefaultMcpClient memory(String condition, Lang lang, String classpath, String jdbcUrl, String ollama) {
        String java = ProcessHandle.current().info().command().orElse("java");
        StdioMcpTransport transport = new StdioMcpTransport.Builder()
                .command(List.of(java, "-Xmx256m", "-XX:+UseSerialGC", "-cp", classpath, "jgraphrag.MemoryServer",
                        CONDITION_TOOLS.get(condition), lang.code()))
                .environment(Map.of("JGRAPH_JDBC", jdbcUrl, "JGRAPH_OLLAMA", ollama))
                .logEvents(false)
                .build();
        return new DefaultMcpClient.Builder()
                .key("memory-" + condition + "-" + lang.code())
                .transport(transport)
                .toolExecutionTimeout(Duration.ofSeconds(30))
                .build();
    }

    static String system(String condition, Lang lang) throws IOException {
        String dir = lang.code() + "/";
        if (isCorpus(condition)) {
            String sql = resource(dir + "howto_corpus_sql.md");
            String vector = resource(dir + "howto_vector.md");
            String howto = switch (condition) {
                case CORPUS_SQL -> sql;
                case VECTOR -> vector;
                case VECTOR_SQL -> vector.strip() + "\n\n" + sql;
                default -> throw new IllegalArgumentException("condition " + condition);
            };
            return resource(dir + "corpus_system.md").replace("{{tools}}", lang.tools(condition))
                    .replace("{{howto}}", howto.strip()).replace("{{memory}}", resource(dir + "corpus.md").strip());
        }
        String sql = resource(dir + "howto_sql.md").replace("{{inventory}}", resource("inventory_sql.md").strip());
        String sparql = resource(dir + "howto_sparql.md").replace("{{inventory}}", resource("inventory_sparql.md").strip());
        String howto = switch (condition) {
            case SQL -> sql;
            case SPARQL -> sparql;
            case BOTH -> sql.strip() + "\n\n" + sparql;
            case BOTH_SPARQL_FIRST -> sparql.strip() + "\n\n" + sql;
            default -> throw new IllegalArgumentException("condition " + condition);
        };
        return resource(dir + "system.md").replace("{{tools}}", lang.tools(condition)).replace("{{howto}}", howto.strip())
                .replace("{{memory}}", resource(dir + "memory.md").strip());
    }

    static String resource(String name) throws IOException {
        try (InputStream in = Bench.class.getResourceAsStream("/prompts/" + name)) {
            if (in == null) {
                throw new IOException("no resource prompts/" + name);
            }
            return new String(in.readAllBytes(), StandardCharsets.UTF_8);
        }
    }

    static String runKey(String lang, String set, String question, String model, String condition, int repeat) {
        return String.join("|", lang, set, question, model, condition, String.valueOf(repeat));
    }

    static String runKey(JsonNode n) {
        return runKey(n.path("lang").asText(), n.path("set").asText(), n.path(QUESTION).asText(), n.path(MODEL).asText(),
                n.path(CONDITION).asText(), n.path(REPEAT).asInt());
    }

    static Set<String> done(Path out) throws IOException {
        Set<String> keys = new HashSet<>();
        if (Files.exists(out)) {
            for (String line : Files.readAllLines(out)) {
                if (line.isBlank()) {
                    continue;
                }
                JsonNode n = JSON.readTree(line);
                if (!"model_error".equals(n.path("stop").asText())) {
                    keys.add(runKey(n));
                }
            }
        }
        return keys;
    }

    static void summary(Path out) throws IOException {
        Map<String, JsonNode> latest = new LinkedHashMap<>();
        for (String line : Files.readAllLines(out)) {
            if (!line.isBlank()) {
                JsonNode n = JSON.readTree(line);
                latest.put(runKey(n), n);
            }
        }
        Map<String, int[]> acc = new TreeMap<>();
        double cost = 0;
        for (JsonNode n : latest.values()) {
            int[] a = acc.computeIfAbsent(n.path(MODEL).asText() + " " + n.path(CONDITION).asText(), k -> new int[2]);
            a[0] += n.path("correct").asBoolean() ? 1 : 0;
            a[1]++;
            cost += n.path("cost_usd").asDouble(0);
        }
        LOG.info("model    condition  right");
        acc.forEach((k, a) -> LOG.atInfo().log(() -> String.format("%-18s %3d / %3d", k, a[0], a[1])));
        double total = cost;
        LOG.atInfo().log(() -> String.format("runs %d, cost $%.2f", latest.size(), total));
    }

    static Map<String, String> options(String[] args) {
        Map<String, String> opt = new HashMap<>();
        int i = 0;
        while (i < args.length) {
            if (!args[i].startsWith("--")) {
                throw new IllegalArgumentException("unexpected " + args[i]);
            }
            boolean valued = i + 1 < args.length && !args[i + 1].startsWith("--");
            opt.put(args[i].substring(2), valued ? args[i + 1] : "true");
            i += valued ? 2 : 1;
        }
        return opt;
    }
}
