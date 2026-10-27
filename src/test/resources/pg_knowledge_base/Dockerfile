# pg_knowledge_base from its public repository at one commit, built as its README builds it: the engine library with
# Rust's image (oxigraph's crates are git dependencies at pinned commits), the extension with PGXS of PostgreSQL 19's
# official image. The image the tests start is the official one with the extension installed.
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
