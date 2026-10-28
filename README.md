# jgraph_rag

An AI agent's memory as a database it queries itself: the same knowledge, one article's knowledge graph, kept as
human-readable PostgreSQL tables and read as RDF through an R2RML mapping of
[pg_knowledge_base](https://github.com/igor-suhorukov/pg_knowledge_base).
The agent gets its tools over MCP and answers questions about the article through SQL, through SPARQL, or with
both; three models from OpenRouter run the same questions, and every answer is checked by rules against a gold
answer. The knowledge base, the questions and all the agent is told come in Russian and in English.

Beside the graph, a classic RAG over embeddings: the corpus of
[semantic_and_structured_search](https://github.com/igor-suhorukov/semantic_and_structured_search)
(habr.com/ru/articles/1036594), 13,275 articles of Habr with what an LLM said of each and 147,432 EmbeddingGemma
vectors of those texts, in the same PostgreSQL as tables of [lance_tam](https://github.com/igor-suhorukov/pg_lance_tam),
whose rows live in Lance datasets: Lance filters by the articles' fields before it searches by vector. DuckDB 2.0 reads
the corpus's parquet files through its JDBC driver straight from GitHub Pages. The agent searches it by meaning with
`semantic_search`, by SQL, or both; an integration test compares Lance and pgvector, and their indexes, on the same rows.

## Layout

| Path | What it holds |
|---|---|
| `data/habr_1097022.{ru,en}.sql` | the knowledge base, a dump per language: the schema with its comments, the rows and the R2RML mapping; see `data/README.md` |
| `data/` | also the article (`1097022.md`), the quads the Russian mapping must give (`source.nq`) and the translation memory (`i18n/ru-en.tsv`) |
| `questions/questions.{ru,en}.yaml` | 15 questions and 3 pilot ones, each with its gold answer and a gold SQL and SPARQL query, in each language |
| `db/agent_roles.sql` | the read-only roles the memory server connects as: `agent_sql` reaches the tables only, `agent_sparql` runs `kb.sparql_json` |
| `db/describe.sql` | writes what the agent is told about its memory (`src/main/resources/prompts/{lang}/memory.md` and the inventories) from the catalog |
| `db/corpus.sql` | the corpus's tables, `USING lance`: `corpus.indexed_text` (an article a row, the nested fields as columns) and `corpus.text_embeddings` (a text a row: its vector, its text and the article's fields a search filters by), a comment on every column |
| `db/corpus_indexes.sql`, `db/corpus_roles.sql` | Lance's indexes of the corpus (IVF_HNSW_SQ for the vectors, BTREE, BITMAP and LABEL_LIST for the filters) and the roles in the corpus's database `habr`: `agent_sql` reads its tables, `agent_vector`, which `semantic_search` runs as, `text_embeddings` alone |
| `db/describe_corpus.sql` | writes `src/main/resources/prompts/ru/corpus.md`, what the agent is told about the corpus, from the catalog |
| `results/` | the runs as JSONL with their traces: the article's knowledge base (`main.{ru,en}`, the control, the pilots) and the corpus (`corpus.ru`, and `corpus-1.ru`, the first run, when `semantic_search` ran as `agent_sql`); `vector-stores.md`, the report of `VectorStoresIT` the article quotes |
| `questions/corpus.ru.yaml` | 12 questions about the corpus: articles found by meaning, with filters and without, counts, fields of an article found by meaning, two with no answer; each with its gold answer, a gold SQL query and a gold search |
| `src/main/resources/prompts/{ru,en}/` | the system prompt, the notes on SQL and SPARQL and the description of the memory, per language |
| `tools/make_dumps.py` | makes the two dumps from the Story-KG tables and the translation memory |
| `src/main/java/jgraphrag/MemoryServer.java` | the memory: an MCP server over stdio with the tools `sql_query` and `sparql_query`, and over the corpus `sql_query` and `semantic_search` |
| `src/main/java/jgraphrag/Corpus.java` | loads the corpus: DuckDB's JDBC driver reads the parquet files from GitHub Pages, COPY writes them into the lance tables |
| `src/main/java/jgraphrag/Embedder.java` | the vector of a query, from the model the corpus was embedded with (EmbeddingGemma 300M Q4_0 through ollama) |
| `src/main/java/jgraphrag/Agent.java` | the agent's own loop over a langchain4j `ChatModel`, the answer handed in through `submit_answer` |
| `src/main/java/jgraphrag/Scorer.java` | the rules an answer is checked by |
| `src/main/java/jgraphrag/Bench.java` | the experiment: questions × conditions × models × repeats, each run a line of JSONL with its trace |
| `src/main/java/jgraphrag/Lang.java` | the language of a knowledge base: its database `kb_{lang}` and what the memory and the agent say |
| `src/test` | unit tests, and integration tests by Testcontainers on PostgreSQL 19 with pg_knowledge_base, pgvector and lance_tam built from their repositories (`src/test/resources/pg_memory`) and on ollama with the embedding model in its image (`src/test/resources/ollama`) |

## Conditions and models

The memory is described to the agent in the same words under every condition: the tables and their columns, each
column's comment naming its RDF predicate. The conditions differ in the tools and a short note on how to use them.

| Condition | Tools |
|---|---|
| `sql` | `sql_query` |
| `sparql` | `sparql_query` |
| `both` | `sql_query`, `sparql_query` |
| `both_sparql_first` (control) | `sparql_query`, `sql_query` |

Under `both` all three models began with SQL in every run of the main set. The control `both_sparql_first` is `both`
with SPARQL first wherever the agent meets the two tools: the tool list, the prompt's sentence on them, and the order of
the two notes. It asks whether the order made the choice; the memory's description stays the same.

| Model | OpenRouter id | Endpoints, in order |
|---|---|---|
| DeepSeek V4.1 Flash, the 2026-10-17 snapshot | `deepseek/deepseek-v4.1-flash-1017` | `deepinfra/fp8`, `nebius/fp8` |
| Gemma 4 31B | `google/gemma-4-31b-it` | `deepinfra/fp8`, `parasail/fp8` |
| Qwen 3.8 27B | `qwen/qwen3.8-27b` | `deepinfra/bf16`, `cerebras/fp16` |

Each model is served only by its endpoints, the second when the first fails, never another. DeepSeek and Qwen run at
the precision of their own weights (DeepSeek's official weights are FP8; Qwen bf16, or fp16 on Cerebras); Gemma runs at
FP8, quantized from bf16, because its bf16 endpoints did not serve the pilot (Crusoe's shared pool answered 429, Novita's
context did not hold the prompt); every model call records the provider that served it and the
cost OpenRouter reports. Reasoning at the medium effort, the reasoning text sent back with the history. A model call
that fails for a while (429, 5xx, a timeout, an empty body in place of the answer) is tried again after pauses of 2 to
60 seconds, eight times at most.

`sparql_query` declares the standard prefixes (`schema:`, `kgo:`, `oa:`, `skos:`…) a query leaves undeclared, as
many SPARQL endpoints do; the pilot showed agents forgetting them.

The corpus has conditions of its own (`--set corpus`, Russian only, as the corpus is): the same description of its two
tables under each, the tools and their notes differing.

| Condition | Tools |
|---|---|
| `corpus_sql` | `sql_query` over the corpus |
| `vector` | `semantic_search` |
| `vector_sql` | `semantic_search`, `sql_query` over the corpus |

`semantic_search(query, where, k)` embeds `query` as the corpus was embedded (EmbeddingGemma 300M Q4_0 through ollama,
the text as it is) and returns the `k` texts nearest to it (10 by default, 50 at most), each with its article and its
cosine distance: `ORDER BY embedding_vector <=> $1 LIMIT k` over `corpus.text_embeddings`, with the agent's `where`, an
SQL condition over the table's columns, as `agent_vector`, which reads that table alone: in the first run of the corpus
(`results/corpus-1.ru.jsonl`), as `agent_sql`, DeepSeek read the counters of `indexed_text` through `where` under
`vector`, by a subquery and by the text of a cast's error. On the lance table Lance applies a condition on text, integer,
boolean and date columns before the search, and one on the array `hubs` by `@>`, `&&` or `= ANY`
(`hubs @> ARRAY['PostgreSQL']`), which its LABEL_LIST index answers; another condition on `hubs` PostgreSQL applies
after it. The agent's searches probe all 16 partitions of the IVF_HNSW_SQ index and re-rank ten times `k` candidates
by their full vectors (`lance.nprobes`, `lance.refine_factor` of the roles in `habr`): in `VectorStoresIT` they found
all the exact ten nearest under every filter Lance applied, in 2 to 6 ms (`results/vector-stores.md`, lance_tam
f4026d4, before Lance applied the one on `hubs`).

## Build and test

```sh
scripts/build.sh     # target/jgraph-rag.jar and the unit tests, Maven in a container
scripts/test.sh      # mvn verify: the integration tests build the database image at the commits of pom.xml
scripts/test.sh -Dit.test=VectorStoresIT   # Lance against pgvector alone: target/vector-stores.md
```

The unit tests drive the agent's loop with a scripted model and a fake memory (turns, tool calls, the limits, tokens,
cost and providers, the trace), and check the scorer, the answer formats and the prompts of the conditions.

The integration tests load both dumps, `kb_ru` and `kb_en`, and check: that the Russian mapping gives the quads of
`data/source.nq` graph by graph and the English one the same graph with English text; that every gold query of both
languages answers its question under the agent's roles; and the memory server through MCP's stdio transport: the tools
of each condition, the format of the answers, the cut at 200 rows, the errors, the English answers, and that
`agent_sql` neither reaches SPARQL nor writes. The first run builds the engines' Rust crates (pg_knowledge_base's, and
lance_tam's with Lance's checkout at `lance.commit`); Docker keeps the image for the next ones.

The corpus's tests load it as `scripts/db.sh` does, from GitHub Pages, and check: that every gold query answers its
question and every gold search finds its articles (`CorpusGoldIT`); the corpus's tools through MCP (`CorpusMemoryIT`);
and `VectorStoresIT`, Lance against pgvector on the same rows: `corpus.text_embeddings` copied into a lance table and a
heap one, the scalar indexes of each store, then their vector indexes a pair at a time (pgvector's HNSW and IVFFlat,
Lance's IVF_HNSW_SQ and IVF_PQ), and twenty queries embedded by ollama under eleven filters, from none to a few hundred
rows, on each: the loads, the builds, the sizes, the times of the searches and their recall@10 against the exact
search. It checks that both stores hold the same rows, that the queries' vectors are in the corpus's space, that
Lance's flat search agrees with the exact one and that a search Lance filters first gives k rows; the numbers go to
`target/vector-stores.md`.

## Run

`scripts/db.sh` starts the memory on a Docker network `jgraph-rag` of its own with no port published: the container
`jgraph-db`, PostgreSQL 19 with pg_knowledge_base, pgvector and lance_tam (the image of the integration tests), both
knowledge bases (`kb_ru`, `kb_en`), the corpus (`habr`, loaded by `jgraphrag.Corpus` from GitHub Pages) and the
agent's roles; and `jgraph-ollama`, which embeds the queries of `semantic_search`. Then, with `OPENROUTER_API_KEY=…` in a file, or
the key alone:

```sh
scripts/build.sh && scripts/db.sh
ENV_FILE=~/.openrouter.env scripts/bench.sh --lang en --dry-run
ENV_FILE=~/.openrouter.env scripts/bench.sh --lang ru --set pilot --repeats 1
ENV_FILE=~/.openrouter.env scripts/bench.sh --lang ru --set main --repeats 3
ENV_FILE=~/.openrouter.env scripts/bench.sh --lang ru --set corpus --models deepseek --repeats 3
```

`scripts/bench.sh` runs the jar in a container on that network. `--lang` picks the knowledge base, the questions and
the prompts; `--workers` (8 by default) how many runs of a model under a condition go at once, each with a memory
server of its own: 72 at once for three models under three conditions.
The runs go to `results/<set>.<lang>.jsonl`; a run already there is not run again, unless it ended in a model error.
To load the dumps into a PostgreSQL of your own instead:

```sh
for lang in ru en; do
  createdb kb_$lang
  psql -d kb_$lang -c 'CREATE EXTENSION pg_knowledge_base' -f data/habr_1097022.$lang.sql -f db/agent_roles.sql
done
JGRAPH_JDBC='jdbc:postgresql://<host>:5432/kb_{lang}' java -jar target/jgraph-rag.jar --lang ru --set pilot
```
