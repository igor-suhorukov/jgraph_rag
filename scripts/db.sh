#!/usr/bin/env bash
# Starts the experiment's memory on the Docker network jgraph-rag of its own, with no port published:
#   jgraph-db      PostgreSQL 19 with pg_knowledge_base, pgvector and lance_tam built from their repositories at the
#                  commits of pom.xml (the image the integration tests build, built here if missing), the article's
#                  knowledge base in both languages (kb_ru, kb_en), the corpus of articles (habr) and the agent's roles
#   jgraph-ollama  ollama with the corpus's embedding model, which embeds the queries of semantic_search
# The corpus is loaded by jgraphrag.Corpus (target/jgraph-rag.jar: scripts/build.sh), DuckDB reading its parquet files
# straight from GitHub Pages. scripts/bench.sh joins the network. The roles log in without a password there.
# max_connections is 200: 72 memory servers at once (Bench --workers 8) hold up to 96 connections.
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
prop() { sed -n "s:.*<$1>\(.*\)</$1>.*:\1:p" "$here/pom.xml"; }
kb=$(prop kb.commit)
lt=$(prop lance_tam.commit)
lance=$(prop lance.commit)
image="jgraph-rag/pg-memory:${kb:0:12}-${lt:0:12}"
ollama_image="jgraph-rag/ollama-embeddinggemma:0.40.11"
if [ ! -f "$here/target/jgraph-rag.jar" ]; then
  echo "no target/jgraph-rag.jar: run scripts/build.sh" >&2
  exit 1
fi
if ! docker image inspect "$image" >/dev/null 2>&1; then
  docker build -t "$image" --build-arg "KB_COMMIT=$kb" --build-arg "LT_COMMIT=$lt" --build-arg "LANCE_COMMIT=$lance" \
    "$here/src/test/resources/pg_memory"
fi
if ! docker image inspect "$ollama_image" >/dev/null 2>&1; then
  docker build -t "$ollama_image" "$here/src/test/resources/ollama"
fi
docker network inspect jgraph-rag >/dev/null 2>&1 || docker network create jgraph-rag >/dev/null
for c in jgraph-db jgraph-ollama; do
  if docker container inspect "$c" >/dev/null 2>&1; then
    echo "$c exists already; remove it with: docker rm -f $c" >&2
    exit 1
  fi
done
docker run -d --name jgraph-ollama --network jgraph-rag "$ollama_image" >/dev/null
docker run -d --name jgraph-db --network jgraph-rag --shm-size 4g \
  -e POSTGRES_PASSWORD=postgres -e POSTGRES_HOST_AUTH_METHOD=trust \
  -v "$here/data:/load/data:ro" -v "$here/db:/load/db:ro" \
  "$image" postgres -c shared_preload_libraries=pg_knowledge_base,lance_tam -c max_connections=200 \
  -c shared_buffers=2GB -c maintenance_work_mem=2GB >/dev/null
for _ in $(seq 60); do
  if docker exec jgraph-db pg_isready -q -U postgres -h 127.0.0.1 2>/dev/null; then
    break
  fi
  sleep 1
done
psql() { docker exec -i jgraph-db psql -X -q -v ON_ERROR_STOP=1 -U postgres -h 127.0.0.1 "$@"; }
for lang in ru en; do
  psql -d postgres -c "CREATE DATABASE kb_$lang"
  psql -d "kb_$lang" -c 'CREATE EXTENSION pg_knowledge_base' \
    -f "/load/data/habr_1097022.$lang.sql" -f /load/db/agent_roles.sql -c 'ANALYZE' >/dev/null
  echo "kb_$lang: $(psql -d "kb_$lang" -At -c "SELECT count(*) FROM habr_1097022.evidence") evidence rows"
done
psql -d postgres -c "CREATE DATABASE habr"
psql -d habr -c 'CREATE EXTENSION vector' -c 'CREATE EXTENSION lance_tam' -f /load/db/corpus.sql >/dev/null
docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp --network jgraph-rag -v "$here:/app:ro" -w /app \
  eclipse-temurin:25-jdk java --enable-native-access=ALL-UNNAMED -cp target/jgraph-rag.jar jgraphrag.Corpus \
  --jdbc jdbc:postgresql://jgraph-db:5432/habr
psql -d habr -f /load/db/corpus_indexes.sql -f /load/db/corpus_roles.sql -c 'ANALYZE' >/dev/null
echo "habr: $(psql -d habr -At -c "SELECT count(*) FROM corpus.indexed_text") articles, $(psql -d habr -At \
  -c "SELECT count(*) FROM corpus.text_embeddings") texts with vectors"
echo "jgraph-db is up on the network jgraph-rag ($image), and jgraph-ollama ($ollama_image)"
