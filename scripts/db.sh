#!/usr/bin/env bash
# Starts the experiment's database, the container jgraph-db: PostgreSQL 19 with pg_knowledge_base built from its
# repository at the commit kb.commit of pom.xml (the image the integration tests build, built here if missing), the
# knowledge base in both languages (kb_ru, kb_en) and the agent's roles. It is on the Docker network jgraph-rag of its
# own, with no port published; scripts/bench.sh joins that network. The roles log in without a password there.
# max_connections is 200: 72 memory servers at once (Bench --workers 8) hold up to 96 connections.
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
commit=$(sed -n 's:.*<kb.commit>\(.*\)</kb.commit>.*:\1:p' "$here/pom.xml")
image="jgraph-rag/pg-knowledge-base:${commit:0:12}"
if ! docker image inspect "$image" >/dev/null 2>&1; then
  docker build -t "$image" --build-arg "KB_COMMIT=$commit" "$here/src/test/resources/pg_knowledge_base"
fi
docker network inspect jgraph-rag >/dev/null 2>&1 || docker network create jgraph-rag >/dev/null
if docker container inspect jgraph-db >/dev/null 2>&1; then
  echo "jgraph-db exists already; remove it with: docker rm -f jgraph-db" >&2
  exit 1
fi
docker run -d --name jgraph-db --network jgraph-rag \
  -e POSTGRES_PASSWORD=postgres -e POSTGRES_HOST_AUTH_METHOD=trust \
  -v "$here/data:/load/data:ro" -v "$here/db:/load/db:ro" \
  "$image" postgres -c shared_preload_libraries=pg_knowledge_base -c max_connections=200 >/dev/null
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
echo "jgraph-db is up on the network jgraph-rag ($image)"
