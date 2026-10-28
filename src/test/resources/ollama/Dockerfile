# ollama with the model the corpus was embedded with, pulled into the image, so that a container answers /api/embed at
# once and with no network: EmbeddingGemma 300M in unsloth's Q4_0 GGUF, the file the browser search loads too.
ARG OLLAMA_IMAGE=ollama/ollama:0.40.11
FROM ${OLLAMA_IMAGE}
ARG MODEL=hf.co/unsloth/embeddinggemma-300m-GGUF:Q4_0
RUN ollama serve >/tmp/serve.log 2>&1 & pid=$!; \
    for _ in $(seq 60); do ollama list >/dev/null 2>&1 && break; sleep 1; done; \
    ollama pull "$MODEL" && ollama list && kill "$pid"
ENV OLLAMA_KEEP_ALIVE=-1 OLLAMA_NUM_PARALLEL=4
