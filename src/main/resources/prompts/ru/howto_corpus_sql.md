Инструмент sql_query выполняет SQL (PostgreSQL 19) над таблицами схемы corpus, она уже стоит в search_path.
- indexed_text — статьи, по строке на статью; text_embeddings — тексты статей с векторами, по строке на текст; связь — task_id.
- Колонки text[] — массивы: ищи через `= ANY (колонка)`, `колонка @> ARRAY['…']` или `unnest(колонка)`.
- Коды (technical, negative, beginner…) лежат текстом, по-английски; остальные тексты — по-русски.
- Таблицы и число строк в них: indexed_text 13275, text_embeddings 147432.
