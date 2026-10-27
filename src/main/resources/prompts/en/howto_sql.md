The tool sql_query runs SQL (PostgreSQL 19) over the tables of schema habr_1097022, which is already on the search_path.
- Tables refer to each other by text ids and keys. Columns of type text[] are arrays of ids: search them with `= ANY (column)` or `unnest(column)`.
- Codes (thesis, irony, disputed…) are stored as text, without a namespace.
- For SQL the notes "RDF: …" in the descriptions of the columns can be ignored.
- The quotes of the article (evidence.quote, prefix, suffix) are in Russian; everything else is in English.
- The tables and their row counts: {{inventory}}.
