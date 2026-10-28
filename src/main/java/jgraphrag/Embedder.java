package jgraphrag;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.Map;

final class Embedder {

    static final String MODEL = "hf.co/unsloth/embeddinggemma-300m-GGUF:Q4_0";
    static final int DIMENSIONS = 768;

    private static final ObjectMapper JSON = new ObjectMapper();

    private final URI endpoint;
    private final HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build();

    Embedder(String ollama) {
        this.endpoint = URI.create(Scorer.withoutTrailingSlashes(ollama) + "/api/embed");
    }

    float[] embed(String text) throws IOException, InterruptedException {
        String body = JSON.writeValueAsString(Map.of("model", MODEL, "input", text));
        HttpResponse<String> r = http.send(HttpRequest.newBuilder(endpoint)
                        .timeout(Duration.ofSeconds(60))
                        .header("Content-Type", "application/json")
                        .POST(HttpRequest.BodyPublishers.ofString(body)).build(),
                HttpResponse.BodyHandlers.ofString());
        if (r.statusCode() != 200) {
            throw new IOException("ollama answered " + r.statusCode() + ": " + r.body());
        }
        JsonNode v = JSON.readTree(r.body()).path("embeddings").path(0);
        if (v.size() != DIMENSIONS) {
            throw new IOException("ollama gave " + v.size() + " numbers, not " + DIMENSIONS);
        }
        float[] out = new float[DIMENSIONS];
        double norm = 0;
        for (int i = 0; i < DIMENSIONS; i++) {
            out[i] = (float) v.get(i).asDouble();
            norm += (double) out[i] * out[i];
        }
        float scale = (float) (1 / Math.sqrt(norm));
        for (int i = 0; i < DIMENSIONS; i++) {
            out[i] *= scale;
        }
        return out;
    }

    static String literal(float[] v) {
        StringBuilder s = new StringBuilder(v.length * 12).append('[');
        for (int i = 0; i < v.length; i++) {
            s.append(i > 0 ? "," : "").append(v[i]);
        }
        return s.append(']').toString();
    }
}
