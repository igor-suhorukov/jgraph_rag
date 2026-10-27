# Data

What one article is known as, frozen on 2026-10-27: «Мой PostgreSQL быстрее твоего и почти догнал ClickHouse»
("My PostgreSQL is faster than yours and has almost caught up with ClickHouse"; igor_suhorukov,
habr.com/ru/articles/1097022, 2026-10-21). The knowledge comes from the Story-KG knowledge graph (frames extracted from
the text and frames derived from them by rules), as built on 2026-10-27 (9,686,890 quads).

The knowledge base comes in two languages, a dump each. A dump holds the schema `habr_1097022` (34 tables written for
people, a comment on every table and column naming its RDF predicate), the 676 rows, and the R2RML mapping that reads
the tables as a knowledge graph, registered with `kb.add_mapping()`. It loads into a database where pg_knowledge_base is
installed and preloaded:

```sh
psql -d kb_ru -c 'CREATE EXTENSION pg_knowledge_base' -f habr_1097022.ru.sql
psql -d kb_en -c 'CREATE EXTENSION pg_knowledge_base' -f habr_1097022.en.sql
```

| File | What it holds |
|---|---|
| `habr_1097022.ru.sql` | the knowledge base in Russian: the Story-KG tables as they are |
| `habr_1097022.en.sql` | the same rows in English: names, descriptions, claims, replies, conditions, the comments of the schema and the texts of the mapping translated; literals tagged `@en` |
| `i18n/ru-en.tsv` | the translation memory the English dump is made with: 934 pairs, each with where it is used |
| `1097022.md` | the article; the quotes and line numbers of the knowledge base refer to this file |
| `source.nq` | the article's quads out of Story-KG: 10,154 quads in 37 graphs |

In both languages the quotes of the article (`evidence.quote`, `prefix`, `suffix`; `oa:exact`, `oa:prefix`,
`oa:suffix`) are the verbatim Russian text: the line numbers and the character offsets of the W3C selectors point into
the Russian article. A reply of the dispute is translated in `quotations.text`; its original wording is in the evidence
quote of that reply.

The Russian mapping gives back exactly the quads of `source.nq`: compared with blank nodes matched by their paths, none
is missing and none is extra; 670 literals differ in their lexical form only (`"1.4"` and `"1.4E0"^^xsd:double`,
`nonNegativeInteger` and `integer`, `+00:00` and `Z`), because pg_knowledge_base's store keeps literals as values. The
English mapping gives the same graph with English text: with the literals masked, the same quads; 10,153 of them, as
two Russian forms of a unit («раза», «раз») are one English word. A SPARQL query without `GRAPH` sees the 37 graphs only
with `kb.union_default_graph = on`.

`tools/make_dumps.py` makes both dumps from the Story-KG tables (`schema.sql`, `data.sql`, `mapping.ttl`) and the
translation memory.

SHA-256:

```
61c608f8417e8b389ddd9a265a0fa01d9c07bdf71cb3df9831d0252e2cbc4ac5  1097022.md
eb7cfd23a2515dcf956766324861a70135391927503d593c858830862a5e2137  habr_1097022.ru.sql
e93bf67d7769a8b2c6720c9bfcc7dfe708f3b58aa37869a2aed02e1ac849aecd  habr_1097022.en.sql
908676ad9d90f39b8d06a95bf73a2e0914ccdaa4f63e04f1afa3e77825c0680c  source.nq
61e2db5f8bbf6c8b2d09f04d7f80b6375e50487da85057220b4066b59e11923c  i18n/ru-en.tsv
```
