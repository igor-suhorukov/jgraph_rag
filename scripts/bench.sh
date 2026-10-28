#!/usr/bin/env bash
# Runs the experiment (jgraphrag.Bench, its arguments passed on) in a container on the network jgraph-rag of the
# memory scripts/db.sh starts; the memory server reaches PostgreSQL there by the name jgraph-db and the embedding model
# by jgraph-ollama, the models over the internet.
#   ENV_FILE   a file with OPENROUTER_API_KEY=..., or with the key alone (not printed, not copied: a bare key goes
#              to the container through docker's environment)
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
env_file=${ENV_FILE:?set ENV_FILE to a file with OPENROUTER_API_KEY}
if grep -q '=' "$env_file"; then
  key=(--env-file "$env_file")
else
  OPENROUTER_API_KEY=$(tr -d '[:space:]' <"$env_file")
  export OPENROUTER_API_KEY
  key=(-e OPENROUTER_API_KEY)
fi
docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp \
  --network jgraph-rag \
  "${key[@]}" \
  -e 'JGRAPH_JDBC=jdbc:postgresql://jgraph-db:5432/kb_{lang}' \
  -e 'JGRAPH_CORPUS_JDBC=jdbc:postgresql://jgraph-db:5432/habr' \
  -e 'JGRAPH_OLLAMA=http://jgraph-ollama:11434' \
  -v "$here:/app" -w /app \
  eclipse-temurin:25-jdk java -jar target/jgraph-rag.jar "$@"
