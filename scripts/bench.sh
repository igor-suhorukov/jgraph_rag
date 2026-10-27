#!/usr/bin/env bash
# Runs the experiment (jgraphrag.Bench, its arguments passed on) in a container on the network jgraph-rag of the
# database scripts/db.sh starts; the memory server reaches PostgreSQL there by the name jgraph-db, the models over the
# internet.
#   ENV_FILE   a file with OPENROUTER_API_KEY=... (not printed, not copied)
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
env_file=${ENV_FILE:?set ENV_FILE to a file with OPENROUTER_API_KEY}
docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp \
  --network jgraph-rag \
  --env-file "$env_file" \
  -e 'JGRAPH_JDBC=jdbc:postgresql://jgraph-db:5432/kb_{lang}' \
  -v "$here:/app" -w /app \
  eclipse-temurin:25-jdk java -jar target/jgraph-rag.jar "$@"
