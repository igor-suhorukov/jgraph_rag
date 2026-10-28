package jgraphrag;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.exc.MismatchedInputException;
import com.fasterxml.jackson.databind.node.MissingNode;
import dev.langchain4j.agent.tool.ToolExecutionRequest;
import dev.langchain4j.agent.tool.ToolSpecification;
import dev.langchain4j.data.message.AiMessage;
import dev.langchain4j.data.message.ChatMessage;
import dev.langchain4j.data.message.SystemMessage;
import dev.langchain4j.data.message.ToolExecutionResultMessage;
import dev.langchain4j.data.message.UserMessage;
import dev.langchain4j.exception.RetriableException;
import dev.langchain4j.exception.UnresolvedModelServerException;
import dev.langchain4j.http.client.SuccessfulHttpResponse;
import dev.langchain4j.mcp.client.McpApplicationErrorException;
import dev.langchain4j.mcp.client.McpClient;
import dev.langchain4j.model.chat.ChatModel;
import dev.langchain4j.model.chat.request.ChatRequest;
import dev.langchain4j.model.chat.request.json.JsonArraySchema;
import dev.langchain4j.model.chat.request.json.JsonObjectSchema;
import dev.langchain4j.model.chat.response.ChatResponse;
import dev.langchain4j.model.chat.response.ChatResponseMetadata;
import dev.langchain4j.model.openai.OpenAiChatResponseMetadata;
import dev.langchain4j.model.openai.OpenAiTokenUsage;
import dev.langchain4j.model.output.TokenUsage;
import dev.langchain4j.service.tool.ToolExecutionResult;

import java.security.SecureRandom;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;

final class Agent {

    static final int MAX_TOOL_CALLS = 12;
    static final int MAX_MODEL_CALLS = 16;
    static final String SUBMIT = "submit_answer";
    static final int[] BACKOFF_SECONDS = {2, 5, 10, 20, 40, 60, 60, 60};

    private static final String ANSWER = "answer";
    private static final String VALUES = "values";
    private static final String VALUE = "value";
    private static final String EVIDENCE = "evidence";
    private static final String QUOTE = "quote";
    private static final String NO_ANSWER = "no_answer";
    private static final String ERROR = "error";
    private static final String PROVIDER = "provider";
    private static final String ARGUMENTS = "arguments";
    private static final ObjectMapper JSON = new ObjectMapper();
    private static final SecureRandom JITTER = new SecureRandom();

    record Answer(String answer, List<Map<String, String>> values, List<Map<String, String>> context,
                  List<Map<String, Object>> evidence, boolean noAnswer, boolean submitted) {
    }

    record Outcome(Answer answer, String stop, int modelCalls, int toolCalls, int toolErrors, int retries,
                   long inputTokens, long cachedTokens, long outputTokens, long reasoningTokens, Double costUsd,
                   List<String> providers, long millis, List<Map<String, Object>> trace) {
    }

    record ToolAnswer(String text, boolean error) {
    }

    record Usage(int in, int cached, int out, int reasoning) {

        static Usage of(TokenUsage usage) {
            int in = usage == null || usage.inputTokenCount() == null ? 0 : usage.inputTokenCount();
            int out = usage == null || usage.outputTokenCount() == null ? 0 : usage.outputTokenCount();
            if (!(usage instanceof OpenAiTokenUsage u)) {
                return new Usage(in, 0, out, 0);
            }
            int cached = u.inputTokensDetails() != null && u.inputTokensDetails().cachedTokens() != null
                    ? u.inputTokensDetails().cachedTokens() : 0;
            int reasoning = u.outputTokensDetails() != null && u.outputTokensDetails().reasoningTokens() != null
                    ? u.outputTokensDetails().reasoningTokens() : 0;
            return new Usage(in, cached, out, reasoning);
        }
    }

    record Billing(String provider, Double cost) {

        static Billing of(ChatResponseMetadata metadata) {
            if (!(metadata instanceof OpenAiChatResponseMetadata md) || md.rawHttpResponse() == null) {
                return new Billing(null, null);
            }
            JsonNode body = body(md.rawHttpResponse());
            JsonNode provider = body.path(PROVIDER);
            JsonNode cost = body.path("usage").path("cost");
            return new Billing(provider.isTextual() ? provider.asText() : null, cost.isNumber() ? cost.asDouble() : null);
        }

        static JsonNode body(SuccessfulHttpResponse response) {
            try {
                JsonNode node = JSON.readTree(response.body());
                return node == null ? MissingNode.getInstance() : node;
            } catch (JsonProcessingException | RuntimeException e) {
                return MissingNode.getInstance();
            }
        }
    }

    private static final class Tally {
        final long start = System.currentTimeMillis();
        final List<Map<String, Object>> trace = new ArrayList<>();
        final Set<String> providers = new LinkedHashSet<>();
        int modelCalls;
        int toolCalls;
        int toolErrors;
        int retries;
        long in;
        long cached;
        long out;
        long reasoning;
        Double cost;
        boolean reminded;

        void add(Usage usage, Billing billing) {
            in += usage.in();
            cached += usage.cached();
            out += usage.out();
            reasoning += usage.reasoning();
            if (billing.provider() != null) {
                providers.add(billing.provider());
            }
            if (billing.cost() != null) {
                cost = (cost == null ? 0 : cost) + billing.cost();
            }
        }

        Outcome end(Answer answer, String stop) {
            return new Outcome(answer, stop, modelCalls, toolCalls, toolErrors, retries, in, cached, out, reasoning, cost,
                    List.copyOf(providers), System.currentTimeMillis() - start, trace);
        }
    }

    static ToolSpecification submitSpec(Lang lang) {
        return ToolSpecification.builder()
                .name(SUBMIT)
                .description(lang.submitDescription())
                .parameters(JsonObjectSchema.builder()
                        .addStringProperty(ANSWER, lang.submitAnswer())
                        .addProperty(VALUES, entriesSchema(lang.submitValues(), lang))
                        .addProperty("context", entriesSchema(lang.submitContext(), lang))
                        .addProperty(EVIDENCE, JsonArraySchema.builder()
                                .description(lang.submitEvidence())
                                .items(JsonObjectSchema.builder()
                                        .addStringProperty(QUOTE, lang.submitQuote())
                                        .addIntegerProperty("line", lang.submitLine())
                                        .required(QUOTE, "line")
                                        .build())
                                .build())
                        .addBooleanProperty(NO_ANSWER, lang.submitNoAnswer())
                        .required(ANSWER, VALUES, EVIDENCE, NO_ANSWER)
                        .build())
                .build();
    }

    private static JsonArraySchema entriesSchema(String description, Lang lang) {
        return JsonArraySchema.builder()
                .description(description)
                .items(JsonObjectSchema.builder()
                        .addStringProperty("key", lang.submitKey())
                        .addStringProperty(VALUE, lang.submitValue())
                        .required("key")
                        .build())
                .build();
    }

    private final ChatModel model;
    private final McpClient memory;
    private final Lang lang;
    private final List<ToolSpecification> tools;

    Agent(ChatModel model, McpClient memory, Lang lang) {
        this.model = model;
        this.memory = memory;
        this.lang = lang;
        this.tools = new ArrayList<>(memory.listTools());
        this.tools.add(submitSpec(lang));
    }

    Outcome run(String system, String question) {
        List<ChatMessage> messages = new ArrayList<>(List.of(SystemMessage.from(system), UserMessage.from(question)));
        Tally t = new Tally();
        while (t.modelCalls < MAX_MODEL_CALLS) {
            Optional<Outcome> end = turn(messages, t);
            if (end.isPresent()) {
                return end.get();
            }
        }
        return t.end(null, "turn_limit");
    }

    private Optional<Outcome> turn(List<ChatMessage> messages, Tally t) {
        long t0 = System.currentTimeMillis();
        ChatResponse response;
        try {
            response = chat(ChatRequest.builder().messages(messages).toolSpecifications(tools).build(), t);
        } catch (RuntimeException e) {
            t.trace.add(event("model_error", "turn", t.modelCalls, ERROR, describe(e)));
            return Optional.of(t.end(null, "model_error"));
        }
        AiMessage ai = account(response, t0, t);
        messages.add(ai);
        if (!ai.hasToolExecutionRequests()) {
            return answerInText(ai, messages, t);
        }
        Optional<Outcome> submitted = submitted(ai, t);
        if (submitted.isEmpty()) {
            useTools(ai, messages, t);
        }
        return submitted;
    }

    private static AiMessage account(ChatResponse response, long t0, Tally t) {
        t.modelCalls++;
        AiMessage ai = response.aiMessage();
        Usage usage = Usage.of(response.tokenUsage());
        Billing billing = Billing.of(response.metadata());
        t.add(usage, billing);
        t.trace.add(event("model", "turn", t.modelCalls, "millis", System.currentTimeMillis() - t0,
                PROVIDER, billing.provider(), "cost_usd", billing.cost(),
                "input_tokens", usage.in(), "cached_tokens", usage.cached(), "output_tokens", usage.out(),
                "reasoning_tokens", usage.reasoning(),
                "finish", response.finishReason() == null ? null : response.finishReason().name(),
                "thinking", ai.thinking(), "text", ai.text(), "tool_calls", calls(ai)));
        return ai;
    }

    private static List<Map<String, Object>> calls(AiMessage ai) {
        List<Map<String, Object>> calls = new ArrayList<>();
        if (ai.hasToolExecutionRequests()) {
            for (ToolExecutionRequest r : ai.toolExecutionRequests()) {
                calls.add(event("call", "name", r.name(), ARGUMENTS, r.arguments()));
            }
        }
        return calls;
    }

    private Optional<Outcome> answerInText(AiMessage ai, List<ChatMessage> messages, Tally t) {
        Answer parsed = fromText(ai.text());
        if (parsed != null) {
            return Optional.of(t.end(parsed, "text_answer"));
        }
        if (t.reminded) {
            return Optional.of(t.end(new Answer(ai.text(), List.of(), List.of(), List.of(), false, false), "no_submit"));
        }
        t.reminded = true;
        messages.add(UserMessage.from(lang.remind()));
        return Optional.empty();
    }

    private static Optional<Outcome> submitted(AiMessage ai, Tally t) {
        for (ToolExecutionRequest r : ai.toolExecutionRequests()) {
            if (SUBMIT.equals(r.name())) {
                Answer answer = fromArguments(r.arguments());
                t.trace.add(event("submit", ARGUMENTS, r.arguments()));
                return Optional.of(t.end(answer, answer == null ? "bad_submit" : "submitted"));
            }
        }
        return Optional.empty();
    }

    private void useTools(AiMessage ai, List<ChatMessage> messages, Tally t) {
        for (ToolExecutionRequest r : ai.toolExecutionRequests()) {
            long t1 = System.currentTimeMillis();
            ToolAnswer a = useTool(r, t);
            if (a.error()) {
                t.toolErrors++;
            }
            messages.add(ToolExecutionResultMessage.from(r, a.text()));
            t.trace.add(event("tool", "name", r.name(), ARGUMENTS, r.arguments(), ERROR, a.error(),
                    "millis", System.currentTimeMillis() - t1, "result", a.text()));
        }
    }

    private ToolAnswer useTool(ToolExecutionRequest r, Tally t) {
        if (t.toolCalls >= MAX_TOOL_CALLS) {
            return new ToolAnswer(lang.limit(MAX_TOOL_CALLS), true);
        }
        t.toolCalls++;
        return callTool(memory, r, lang);
    }

    private ChatResponse chat(ChatRequest request, Tally t) {
        for (int attempt = 0; ; attempt++) {
            try {
                return model.chat(request);
            } catch (RuntimeException e) {
                if (!passing(e) || attempt >= BACKOFF_SECONDS.length) {
                    throw e;
                }
                long wait = BACKOFF_SECONDS[attempt] * 1000L + JITTER.nextLong(1000);
                t.retries++;
                t.trace.add(event("retry", "turn", t.modelCalls + 1, "attempt", attempt + 1, "wait_ms", wait,
                        ERROR, describe(e)));
                try {
                    Thread.sleep(wait);
                } catch (InterruptedException ie) {
                    Thread.currentThread().interrupt();
                    throw e;
                }
            }
        }
    }

    static boolean passing(RuntimeException e) {
        if (e instanceof RetriableException || e instanceof UnresolvedModelServerException) {
            return true;
        }
        for (Throwable c = e; c != null; c = c.getCause() == c ? null : c.getCause()) {
            if (c instanceof MismatchedInputException m && m.getMessage() != null
                    && m.getMessage().startsWith("No content to map due to end-of-input")) {
                return true;
            }
        }
        return false;
    }

    static String describe(Throwable e) {
        if (e == null) {
            return "";
        }
        StringBuilder s = new StringBuilder();
        for (Throwable c = e; c != null; c = c.getCause() == c ? null : c.getCause()) {
            s.append(s.isEmpty() ? "" : " <- ").append(c.getClass().getName()).append(": ").append(c.getMessage());
        }
        StackTraceElement[] at = e.getStackTrace();
        return at.length == 0 ? s.toString() : s + " at " + at[0];
    }

    static ToolAnswer callTool(McpClient memory, ToolExecutionRequest request, Lang lang) {
        try {
            ToolExecutionResult res = memory.executeTool(request);
            return new ToolAnswer(res.resultText(), res.isError());
        } catch (McpApplicationErrorException e) {
            return new ToolAnswer(e.getMessage().strip(), true);
        } catch (RuntimeException e) {
            return new ToolAnswer(lang.error() + e.getMessage(), true);
        }
    }

    static Answer fromArguments(String arguments) {
        try {
            return fromJson(JSON.readTree(arguments), true);
        } catch (Exception e) {
            return null;
        }
    }

    static Answer fromText(String text) {
        if (text == null) {
            return null;
        }
        int a = text.indexOf('{');
        int b = text.lastIndexOf('}');
        if (a < 0 || b <= a) {
            return null;
        }
        try {
            JsonNode node = JSON.readTree(text.substring(a, b + 1));
            return node.has(ANSWER) ? fromJson(node, false) : null;
        } catch (Exception e) {
            return null;
        }
    }

    static Answer fromJson(JsonNode n, boolean submitted) {
        List<Map<String, Object>> evidence = new ArrayList<>();
        for (JsonNode e : n.path(EVIDENCE)) {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put(QUOTE, e.path(QUOTE).asText(""));
            m.put("line", e.path("line").asInt(-1));
            evidence.add(m);
        }
        return new Answer(n.path(ANSWER).asText(""), entries(n.path(VALUES)), entries(n.path("context")), evidence,
                n.path(NO_ANSWER).asBoolean(false), submitted);
    }

    static List<Map<String, String>> entries(JsonNode array) {
        List<Map<String, String>> out = new ArrayList<>();
        for (JsonNode v : array) {
            JsonNode value = v.path(VALUE);
            Map<String, String> m = new LinkedHashMap<>();
            m.put("key", v.path("key").asText(""));
            m.put(VALUE, value.isMissingNode() || value.isNull() ? "" : value.asText(""));
            out.add(m);
        }
        return out;
    }

    static Map<String, Object> event(String kind, Object... kv) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("event", kind);
        for (int i = 0; i + 1 < kv.length; i += 2) {
            m.put((String) kv[i], kv[i + 1]);
        }
        return m;
    }
}
