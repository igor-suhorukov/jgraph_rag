#!/usr/bin/env bash
# mvn verify in a container: the unit tests, then the integration tests, which build pg_knowledge_base from its
# repository (the first time: the engine's crates and a Rust build, then Docker's cache) and start it with
# Testcontainers. The container reaches Docker through its socket and the started containers on the host's network.
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
docker run --rm -u "$(id -u):$(id -g)" --group-add "$(stat -c %g /var/run/docker.sock)" \
  --network host -v /var/run/docker.sock:/var/run/docker.sock \
  -e TESTCONTAINERS_HOST_OVERRIDE=localhost -e HOME=/tmp \
  -e MAVEN_CONFIG=/var/maven/.m2 -v "$HOME/.m2:/var/maven/.m2" \
  -v "$here:/src" -w /src \
  maven:3.9.11-eclipse-temurin-21 mvn -B -Duser.home=/var/maven verify "$@"
