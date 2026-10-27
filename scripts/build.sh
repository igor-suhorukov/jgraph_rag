#!/usr/bin/env bash
# Builds target/jgraph-rag.jar with Maven in a container, as the host user, with the host's Maven repository.
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
docker run --rm -u "$(id -u):$(id -g)" \
  -e MAVEN_CONFIG=/var/maven/.m2 -v "$HOME/.m2:/var/maven/.m2" \
  -v "$here:/src" -w /src \
  maven:3.9.11-eclipse-temurin-21 mvn -B -q -Duser.home=/var/maven package "$@"
ls -la "$here/target/jgraph-rag.jar"
