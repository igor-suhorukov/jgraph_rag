# The agent's memory, one PostgreSQL 19 with three extensions, each from its public repository at one commit:
# pg_knowledge_base (SPARQL over the tables through R2RML), pgvector (the vector types and HNSW) and lance_tam (tables
# whose rows live in Lance datasets, Lance's vector and scalar indexes behind them). The two engine libraries are built
# with Rust's image as their READMEs build them: pg_knowledge_base's (oxigraph's crates are git dependencies at pinned
# commits), and lance_tam's, which links Lance from Lance's checkout at /lance. The extensions are built with PGXS of
# PostgreSQL 19's official image, and the image the tests start is the official one with them installed.
ARG PG_IMAGE=postgres:19rc1-trixie

FROM rust:1.99-trixie AS engine
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        pkg-config git file binutils clang libclang-dev \
    && rm -rf /var/lib/apt/lists/*
ARG KB_REPO=https://github.com/igor-suhorukov/pg_knowledge_base.git
ARG KB_COMMIT
RUN test -n "$KB_COMMIT" \
    && git init -q /src \
    && git -C /src fetch -q --depth 1 "$KB_REPO" "$KB_COMMIT" \
    && git -C /src checkout -q FETCH_HEAD
WORKDIR /src/engine
RUN cargo fetch --locked \
    && cargo build --offline --locked --release \
    && cp target/release/libkb_engine.so /libkb_engine.so \
    && rm -rf target

# lance_tam's engine: its lockfile pins the crates; Lance's build scripts compile its protobuf definitions with protoc
FROM rust:1.99-trixie AS lance-engine
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        protobuf-compiler libprotobuf-dev cmake clang libclang-dev pkg-config git file binutils \
    && rm -rf /var/lib/apt/lists/*
ARG LANCE_REPO=https://github.com/lance-format/lance.git
ARG LANCE_COMMIT
ARG LT_REPO=https://github.com/igor-suhorukov/pg_lance_tam.git
ARG LT_COMMIT
RUN test -n "$LANCE_COMMIT" && test -n "$LT_COMMIT" \
    && git init -q /lance \
    && git -C /lance fetch -q --depth 1 "$LANCE_REPO" "$LANCE_COMMIT" \
    && git -C /lance checkout -q FETCH_HEAD \
    && git init -q /lt \
    && git -C /lt fetch -q --depth 1 "$LT_REPO" "$LT_COMMIT" \
    && git -C /lt checkout -q FETCH_HEAD
WORKDIR /lt/engine
ARG CARGO_JOBS=24
RUN cargo fetch \
    && cargo build --offline --release -j "$CARGO_JOBS" \
    && cp target/release/liblance_engine.so /liblance_engine.so \
    && rm -rf target

FROM ${PG_IMAGE}
USER root
RUN set -eu; \
    pkgs="postgresql-server-dev-$PG_MAJOR=$PG_VERSION gcc make libc6-dev libssl-dev libkrb5-dev"; \
    export DEBIAN_FRONTEND=noninteractive; \
    apt-get update; \
    if ! apt-get install -y --no-install-recommends $pkgs; then \
        apt-get install -y --no-install-recommends ca-certificates; \
        . /etc/os-release; \
        echo "deb [ signed-by=/usr/local/share/keyrings/postgres.gpg.asc ] https://apt-archive.postgresql.org/pub/repos/apt $VERSION_CODENAME-pgdg-archive main" \
            >/etc/apt/sources.list.d/pgdg-archive.list; \
        apt-get update; \
        apt-get install -y --no-install-recommends $pkgs; \
    fi; \
    rm -rf /var/lib/apt/lists/*
COPY --from=engine /src /src
COPY --from=engine /libkb_engine.so /tmp/libkb_engine.so
RUN make -C /src -s install PG_CONFIG=/usr/lib/postgresql/$PG_MAJOR/bin/pg_config \
    && make -C /src -s install-engine PG_CONFIG=/usr/lib/postgresql/$PG_MAJOR/bin/pg_config KB_ENGINE=/tmp/libkb_engine.so \
    && rm -rf /src /tmp/libkb_engine.so
ARG PGVECTOR_REF=v0.8.7
COPY --from=lance-engine /lt /lt
COPY --from=lance-engine /liblance_engine.so /tmp/liblance_engine.so
RUN set -eu; \
    export DEBIAN_FRONTEND=noninteractive; \
    apt-get update; \
    apt-get install -y --no-install-recommends git ca-certificates; \
    git clone -q --depth 1 --branch "$PGVECTOR_REF" https://github.com/pgvector/pgvector.git /tmp/pgvector; \
    pg_config=/usr/lib/postgresql/$PG_MAJOR/bin/pg_config; \
    make -C /tmp/pgvector -s PG_CONFIG=$pg_config OPTFLAGS="" -j8; \
    make -C /tmp/pgvector -s PG_CONFIG=$pg_config install; \
    make -C /lt -s -j8 PG_CONFIG=$pg_config; \
    make -C /lt -s install PG_CONFIG=$pg_config; \
    make -C /lt -s install-engine PG_CONFIG=$pg_config LT_ENGINE=/tmp/liblance_engine.so; \
    rm -rf /tmp/pgvector /lt /tmp/liblance_engine.so /var/lib/apt/lists/*
