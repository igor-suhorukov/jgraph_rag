package jgraphrag;

import dev.langchain4j.agent.tool.ToolExecutionRequest;
import dev.langchain4j.agent.tool.ToolSpecification;
import dev.langchain4j.data.message.AiMessage;
import dev.langchain4j.data.message.ChatMessage;
import dev.langchain4j.data.message.ToolExecutionResultMessage;
import dev.langchain4j.data.message.UserMessage;
import dev.langchain4j.http.client.SuccessfulHttpResponse;
import dev.langchain4j.mcp.client.McpClient;
import dev.langchain4j.model.chat.ChatModel;
import dev.langchain4j.model.chat.request.ChatRequest;
import dev.langchain4j.model.chat.response.ChatResponse;
import dev.langchain4j.model.openai.OpenAiChatResponseMetadata;
import dev.langchain4j.model.openai.OpenAiTokenUsage;
import dev.langchain4j.model.output.FinishReason;
import dev.langchain4j.service.tool.ToolExecutionResult;
import org.junit.jupiter.api.Test;

import java.lang.reflect.Proxy;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Deque;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.function.Function;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertInstanceOf;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

class AgentTest {

    static final String SUBMIT_ARGS = """
            {"answer": "s2, 9", "values": [{"key": "s2", "value": "9"}], "context": [{"key": "sec/s2"}],
             "evidence": [{"quote": "9 наборов", "line": 44}], "no_answer": false}""";

    static final class Scripted implements ChatModel {
        final Deque<Object> script = new ArrayDeque<>();
        final List<ChatRequest> requests = new ArrayList<>();

        Scripted then(Object next) {
            script.add(next);
            return this;
        }

        @Override
        public ChatResponse doChat(ChatRequest request) {
            requests.add(request);
            Object next = script.poll();
            if (next instanceof RuntimeException e) {
                throw e;
            }
            return (ChatResponse) next;
        }
    }

    static McpClient memory(Function<ToolExecutionRequest, ToolExecutionResult> exec) {
        List<ToolSpecification> tools = List.of(ToolSpecification.builder().name("sql_query").description("SQL").build());
        return (McpClient) Proxy.newProxyInstance(McpClient.class.getClassLoader(), new Class<?>[] {McpClient.class},
                (proxy, method, args) -> switch (method.getName()) {
                    case "listTools" -> tools;
                    case "executeTool" -> exec.apply((ToolExecutionRequest) args[0]);
                    default -> throw new UnsupportedOperationException(method.getName());
                });
    }

    static McpClient answering(String text, boolean error, AtomicInteger calls) {
        return memory(r -> {
            calls.incrementAndGet();
            return ToolExecutionResult.builder().resultText(text).isError(error).build();
        });
    }

    static ToolExecutionRequest request(String id, String name, String arguments) {
        return ToolExecutionRequest.builder().id(id).name(name).arguments(arguments).build();
    }

    static ChatResponse response(AiMessage ai, int in, int cached, int out, int reasoning, String body, FinishReason finish) {
        OpenAiTokenUsage usage = OpenAiTokenUsage.builder().inputTokenCount(in).outputTokenCount(out)
                .inputTokensDetails(OpenAiTokenUsage.InputTokensDetails.builder().cachedTokens(cached).build())
                .outputTokensDetails(OpenAiTokenUsage.OutputTokensDetails.builder().reasoningTokens(reasoning).build())
                .build();
        OpenAiChatResponseMetadata.Builder md = OpenAiChatResponseMetadata.builder().tokenUsage(usage).finishReason(finish);
        if (body != null) {
            md.rawHttpResponse(SuccessfulHttpResponse.builder().statusCode(200).body(body).build());
        }
        return ChatResponse.builder().aiMessage(ai).metadata(md.build()).build();
    }

    static ChatResponse tools(ToolExecutionRequest... requests) {
        return response(AiMessage.builder().toolExecutionRequests(List.of(requests)).build(), 10, 0, 1, 0, null,
                FinishReason.TOOL_EXECUTION);
    }

    static ChatResponse text(String text) {
        return response(AiMessage.from(text), 10, 0, 1, 0, null, FinishReason.STOP);
    }

    static List<Object> events(Agent.Outcome o) {
        return o.trace().stream().map(e -> e.get("event")).toList();
    }

    record Run(Agent.Outcome outcome, Scripted model, int memoryCalls) {
    }

    static Run toolThenSubmit() {
        AtomicInteger calls = new AtomicInteger();
        Scripted model = new Scripted()
                .then(response(AiMessage.builder().thinking("look").toolExecutionRequests(
                                List.of(request("1", "sql_query", "{\"query\": \"SELECT 1\"}"))).build(),
                        100, 80, 10, 3, "{\"provider\": \"DeepInfra\", \"usage\": {\"cost\": 0.001}}",
                        FinishReason.TOOL_EXECUTION))
                .then(response(AiMessage.builder().toolExecutionRequests(
                                List.of(request("2", Agent.SUBMIT, SUBMIT_ARGS))).build(),
                        200, 150, 20, 5, "{\"provider\": \"Nebius\", \"usage\": {\"cost\": 0.002}}",
                        FinishReason.TOOL_EXECUTION));
        Agent.Outcome o = new Agent(model, answering("n\n1\n(строк: 1)", false, calls), Lang.RU).run("system", "question");
        return new Run(o, model, calls.get());
    }

    @Test
    void aToolCallAndASubmitMakeARun() {
        Run run = toolThenSubmit();
        Agent.Outcome o = run.outcome();
        assertEquals("submitted", o.stop());
        assertEquals(List.of("model", "tool", "model", "submit"), events(o));
        assertEquals(2, o.modelCalls());
        assertEquals(1, o.toolCalls());
        assertEquals(1, run.memoryCalls());
        assertEquals(0, o.toolErrors());
        assertEquals(0, o.retries());
    }

    @Test
    void tokensCostAndProvidersAddUp() {
        Agent.Outcome o = toolThenSubmit().outcome();
        assertEquals(300, o.inputTokens());
        assertEquals(230, o.cachedTokens());
        assertEquals(30, o.outputTokens());
        assertEquals(8, o.reasoningTokens());
        assertEquals(0.003, o.costUsd(), 1e-12);
        assertEquals(List.of("DeepInfra", "Nebius"), o.providers());
    }

    @Test
    void aModelTurnIsTraced() {
        Map<String, Object> first = toolThenSubmit().outcome().trace().get(0);
        assertEquals(List.of("event", "turn", "millis", "provider", "cost_usd", "input_tokens", "cached_tokens",
                "output_tokens", "reasoning_tokens", "finish", "thinking", "text", "tool_calls"), List.copyOf(first.keySet()));
        assertEquals(1, first.get("turn"));
        assertEquals("DeepInfra", first.get("provider"));
        assertEquals(0.001, first.get("cost_usd"));
        assertEquals(100, first.get("input_tokens"));
        assertEquals(80, first.get("cached_tokens"));
        assertEquals(10, first.get("output_tokens"));
        assertEquals(3, first.get("reasoning_tokens"));
        assertEquals("TOOL_EXECUTION", first.get("finish"));
        assertEquals("look", first.get("thinking"));
        assertEquals(List.of(Map.of("event", "call", "name", "sql_query", "arguments", "{\"query\": \"SELECT 1\"}")),
                first.get("tool_calls"));
    }

    @Test
    void aToolCallAndTheSubmitAreTraced() {
        Agent.Outcome o = toolThenSubmit().outcome();
        Map<String, Object> tool = o.trace().get(1);
        assertEquals(List.of("event", "name", "arguments", "error", "millis", "result"), List.copyOf(tool.keySet()));
        assertEquals(false, tool.get("error"));
        assertEquals("n\n1\n(строк: 1)", tool.get("result"));
        assertEquals(Map.of("event", "submit", "arguments", SUBMIT_ARGS), o.trace().get(3));
    }

    @Test
    void theSubmittedAnswerIsRead() {
        Agent.Answer a = toolThenSubmit().outcome().answer();
        assertEquals("s2, 9", a.answer());
        assertEquals(List.of(Map.of("key", "s2", "value", "9")), a.values());
        assertEquals(List.of(Map.of("key", "sec/s2", "value", "")), a.context());
        assertEquals(List.of(Map.of("quote", "9 наборов", "line", 44)), a.evidence());
        assertFalse(a.noAnswer());
        assertTrue(a.submitted());
    }

    @Test
    void theToolResultGoesBackToTheModel() {
        Scripted model = toolThenSubmit().model();
        List<ChatMessage> second = model.requests.get(1).messages();
        assertEquals(4, second.size());
        ToolExecutionResultMessage result = assertInstanceOf(ToolExecutionResultMessage.class, second.get(3));
        assertEquals("n\n1\n(строк: 1)", result.text());
        assertEquals(List.of("sql_query", Agent.SUBMIT),
                model.requests.get(0).toolSpecifications().stream().map(ToolSpecification::name).toList());
    }

    @Test
    void anAnswerInTextCountsAfterOneReminder() {
        Scripted model = new Scripted().then(text("Думаю, s2."))
                .then(text("Ответ: {\"answer\": \"нет\", \"values\": [], \"evidence\": [], \"no_answer\": true}"));
        Agent.Outcome o = new Agent(model, answering("", false, new AtomicInteger()), Lang.RU).run("system", "question");

        assertEquals("text_answer", o.stop());
        assertEquals(List.of("model", "model"), events(o));
        assertTrue(o.answer().noAnswer());
        assertFalse(o.answer().submitted());
        List<ChatMessage> second = model.requests.get(1).messages();
        assertEquals(UserMessage.from(Lang.RU.remind()), second.get(second.size() - 1));
        assertNull(o.costUsd());
        assertEquals(List.of(), o.providers());
    }

    @Test
    void twoTextsWithoutAnAnswerEndTheRun() {
        Scripted model = new Scripted().then(text("s2")).then(text("s2, 9"));
        Agent.Outcome o = new Agent(model, answering("", false, new AtomicInteger()), Lang.RU).run("system", "question");

        assertEquals("no_submit", o.stop());
        assertEquals(new Agent.Answer("s2, 9", List.of(), List.of(), List.of(), false, false), o.answer());
    }

    @Test
    void callsPastTheLimitAnswerWithAnError() {
        AtomicInteger calls = new AtomicInteger();
        ToolExecutionRequest[] many = new ToolExecutionRequest[Agent.MAX_TOOL_CALLS + 1];
        for (int i = 0; i < many.length; i++) {
            many[i] = request(String.valueOf(i), "sql_query", "{\"query\": \"SELECT " + i + "\"}");
        }
        Scripted model = new Scripted().then(tools(many)).then(tools(request("s", Agent.SUBMIT, SUBMIT_ARGS)));
        Agent.Outcome o = new Agent(model, answering("ok", false, calls), Lang.RU).run("system", "question");

        assertEquals("submitted", o.stop());
        assertEquals(Agent.MAX_TOOL_CALLS, o.toolCalls());
        assertEquals(Agent.MAX_TOOL_CALLS, calls.get());
        assertEquals(1, o.toolErrors());
        Map<String, Object> last = o.trace().get(Agent.MAX_TOOL_CALLS + 1);
        assertEquals(true, last.get("error"));
        assertEquals(Lang.RU.limit(Agent.MAX_TOOL_CALLS), last.get("result"));
    }

    @Test
    void aToolErrorIsCounted() {
        Scripted model = new Scripted().then(tools(request("1", "sql_query", "{\"query\": \"SELEC 1\"}")))
                .then(tools(request("2", Agent.SUBMIT, SUBMIT_ARGS)));
        Agent.Outcome o = new Agent(model, answering("Ошибка: syntax error", true, new AtomicInteger()), Lang.RU)
                .run("system", "question");

        assertEquals(1, o.toolErrors());
        assertEquals(true, o.trace().get(1).get("error"));
    }

    @Test
    void aModelErrorEndsTheRun() {
        Scripted model = new Scripted().then(new IllegalStateException("boom"));
        Agent.Outcome o = new Agent(model, answering("", false, new AtomicInteger()), Lang.RU).run("system", "question");

        assertEquals("model_error", o.stop());
        assertNull(o.answer());
        assertEquals(0, o.modelCalls());
        Map<String, Object> e = o.trace().get(0);
        assertEquals("model_error", e.get("event"));
        assertEquals(0, e.get("turn"));
        assertTrue(((String) e.get("error")).startsWith("java.lang.IllegalStateException: boom at "), (String) e.get("error"));
    }

    @Test
    void theTurnLimitEndsTheRun() {
        Scripted model = new Scripted();
        for (int i = 0; i < Agent.MAX_MODEL_CALLS; i++) {
            model.then(tools(request(String.valueOf(i), "sql_query", "{\"query\": \"SELECT 1\"}")));
        }
        Agent.Outcome o = new Agent(model, answering("ok", false, new AtomicInteger()), Lang.RU).run("system", "question");

        assertEquals("turn_limit", o.stop());
        assertEquals(Agent.MAX_MODEL_CALLS, o.modelCalls());
        assertEquals(Agent.MAX_TOOL_CALLS, o.toolCalls());
        assertEquals(Agent.MAX_MODEL_CALLS - Agent.MAX_TOOL_CALLS, o.toolErrors());
    }

    @Test
    void aSubmitThatIsNotJsonIsABadSubmit() {
        Scripted model = new Scripted().then(tools(request("1", Agent.SUBMIT, "s2, 9")));
        Agent.Outcome o = new Agent(model, answering("", false, new AtomicInteger()), Lang.RU).run("system", "question");

        assertEquals("bad_submit", o.stop());
        assertNull(o.answer());
    }

    @Test
    void aBodyThatIsNotJsonLeavesProviderAndCostUnknown() {
        Scripted model = new Scripted().then(response(AiMessage.builder().toolExecutionRequests(
                List.of(request("1", Agent.SUBMIT, SUBMIT_ARGS))).build(), 5, 0, 1, 0, "<html>", FinishReason.TOOL_EXECUTION));
        Agent.Outcome o = new Agent(model, answering("", false, new AtomicInteger()), Lang.RU).run("system", "question");

        assertEquals("submitted", o.stop());
        assertNull(o.costUsd());
        assertNull(o.trace().get(0).get("provider"));
        assertEquals(List.of(), o.providers());
    }
}
