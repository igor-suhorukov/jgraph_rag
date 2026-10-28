-- The corpus of the classic RAG: the articles of Habr that github.com/igor-suhorukov/semantic_and_structured_search
-- searches (habr.com/ru/articles/1036594), what an LLM said of each of them, and the EmbeddingGemma vectors of those
-- texts. The tables are Lance datasets (lance_tam), each row of text_embeddings carrying the article's fields a search
-- filters by, so that Lance filters before it searches. jgraphrag.Corpus fills them from the parquet files on GitHub
-- Pages through DuckDB. Run as a superuser in a database where pgvector and lance_tam are installed and lance_tam is
-- preloaded.

CREATE SCHEMA corpus;
COMMENT ON SCHEMA corpus IS 'Статьи Хабра и векторы их текстов: коллекция семантического поиска semantic_and_structured_search';

CREATE TABLE corpus.indexed_text (
    task_id bigint NOT NULL,
    habr_id integer NOT NULL,
    url text NOT NULL,
    title text,
    llm_title text,
    author text,
    published timestamp,
    post_type text,
    hubs text[],
    tags text[],
    score integer,
    votes_plus integer,
    votes_minus integer,
    votes_count integer,
    reading_count integer,
    comments_count integer,
    favorites_count integer,
    author_score integer,
    author_votes integer,
    summary text,
    meaning text,
    audience_level text,
    audience_description text,
    primary_genre text,
    secondary_genres text[],
    topic_names text[],
    topic_descriptions text[],
    themes text[],
    key_insights text[],
    keywords text[],
    keyword_notes text[],
    nsfw boolean,
    nsfw_reasons text[],
    polarity text,
    sentiment_confidence double precision,
    tone text,
    sentiment_explanation text,
    completeness_score double precision,
    completeness_level text,
    missing_elements text[],
    contradictory_statements text[],
    demagoguery_techniques text[],
    demagoguery_severity text,
    demagoguery_explanation text,
    advertising boolean,
    advertising_items text[],
    advertising_confidence double precision,
    advertising_explanation text
) USING lance;

COMMENT ON TABLE corpus.indexed_text IS 'Статьи Хабра, по строке на статью: 13 275 статей, почти все опубликованы с декабря 2022 по январь 2024 года, без корпоративных блогов. Счётчики Хабра и то, что LLM извлекла из текста статьи: краткое содержание, смысл, жанр, темы, выводы, тональность, демагогия, реклама. Самого текста статей здесь нет. Тексты, по которым ищут по смыслу, и их векторы — в text_embeddings';
COMMENT ON COLUMN corpus.indexed_text.task_id IS 'Номер статьи в коллекции, от 1 до 13275';
COMMENT ON COLUMN corpus.indexed_text.habr_id IS 'Номер статьи на Хабре; адрес статьи https://habr.com/ru/articles/{habr_id}/';
COMMENT ON COLUMN corpus.indexed_text.url IS 'Адрес статьи';
COMMENT ON COLUMN corpus.indexed_text.title IS 'Заголовок статьи на Хабре';
COMMENT ON COLUMN corpus.indexed_text.llm_title IS 'Заголовок, который дала статье LLM';
COMMENT ON COLUMN corpus.indexed_text.author IS 'Ник автора на Хабре';
COMMENT ON COLUMN corpus.indexed_text.published IS 'Время публикации';
COMMENT ON COLUMN corpus.indexed_text.post_type IS 'Тип публикации: article, news, megaproject';
COMMENT ON COLUMN corpus.indexed_text.hubs IS 'Хабы статьи';
COMMENT ON COLUMN corpus.indexed_text.tags IS 'Теги, которые поставил автор';
COMMENT ON COLUMN corpus.indexed_text.score IS 'Рейтинг статьи: плюсы минус минусы';
COMMENT ON COLUMN corpus.indexed_text.votes_plus IS 'Плюсы';
COMMENT ON COLUMN corpus.indexed_text.votes_minus IS 'Минусы';
COMMENT ON COLUMN corpus.indexed_text.votes_count IS 'Голоса';
COMMENT ON COLUMN corpus.indexed_text.reading_count IS 'Просмотры';
COMMENT ON COLUMN corpus.indexed_text.comments_count IS 'Комментарии';
COMMENT ON COLUMN corpus.indexed_text.favorites_count IS 'Добавления в закладки';
COMMENT ON COLUMN corpus.indexed_text.author_score IS 'Карма автора';
COMMENT ON COLUMN corpus.indexed_text.author_votes IS 'Голоса за карму автора';
COMMENT ON COLUMN corpus.indexed_text.summary IS 'Краткое содержание, 1–5 предложений (LLM)';
COMMENT ON COLUMN corpus.indexed_text.meaning IS 'Главный смысл статьи, 1–10 предложений (LLM)';
COMMENT ON COLUMN corpus.indexed_text.audience_level IS 'Уровень читателя, на которого рассчитана статья: beginner, intermediate, advanced';
COMMENT ON COLUMN corpus.indexed_text.audience_description IS 'Кому адресована статья (LLM)';
COMMENT ON COLUMN corpus.indexed_text.primary_genre IS 'Основной жанр: technical, opinion, news, marketing, academic, biographical, fiction, other';
COMMENT ON COLUMN corpus.indexed_text.secondary_genres IS 'Дополнительные жанры, по-английски (LLM)';
COMMENT ON COLUMN corpus.indexed_text.topic_names IS 'Темы статьи: названия (LLM)';
COMMENT ON COLUMN corpus.indexed_text.topic_descriptions IS 'Темы статьи: описания, в порядке topic_names';
COMMENT ON COLUMN corpus.indexed_text.themes IS 'Идейные мотивы статьи (LLM)';
COMMENT ON COLUMN corpus.indexed_text.key_insights IS 'Ключевые выводы статьи (LLM)';
COMMENT ON COLUMN corpus.indexed_text.keywords IS 'Ключевые слова, в нижнем регистре (LLM)';
COMMENT ON COLUMN corpus.indexed_text.keyword_notes IS 'Пояснения ключевых слов, в порядке keywords';
COMMENT ON COLUMN corpus.indexed_text.nsfw IS 'Статья небезопасна для просмотра на работе (NSFW), по оценке LLM';
COMMENT ON COLUMN corpus.indexed_text.nsfw_reasons IS 'Почему статья NSFW';
COMMENT ON COLUMN corpus.indexed_text.polarity IS 'Тональность: positive, negative, neutral, mixed';
COMMENT ON COLUMN corpus.indexed_text.sentiment_confidence IS 'Уверенность в тональности, от 0 до 1';
COMMENT ON COLUMN corpus.indexed_text.tone IS 'Тон статьи словами';
COMMENT ON COLUMN corpus.indexed_text.sentiment_explanation IS 'Пояснение тональности';
COMMENT ON COLUMN corpus.indexed_text.completeness_score IS 'Полнота изложения, от 0 до 1';
COMMENT ON COLUMN corpus.indexed_text.completeness_level IS 'Полнота изложения: comprehensive, moderate, superficial';
COMMENT ON COLUMN corpus.indexed_text.missing_elements IS 'Чего не хватает статье';
COMMENT ON COLUMN corpus.indexed_text.contradictory_statements IS 'Утверждения статьи, которые противоречат друг другу';
COMMENT ON COLUMN corpus.indexed_text.demagoguery_techniques IS 'Демагогические приёмы, найденные в тексте';
COMMENT ON COLUMN corpus.indexed_text.demagoguery_severity IS 'Степень демагогии: none, low, medium';
COMMENT ON COLUMN corpus.indexed_text.demagoguery_explanation IS 'Пояснение оценки демагогии';
COMMENT ON COLUMN corpus.indexed_text.advertising IS 'В статье есть реклама';
COMMENT ON COLUMN corpus.indexed_text.advertising_items IS 'Что рекламирует статья';
COMMENT ON COLUMN corpus.indexed_text.advertising_confidence IS 'Уверенность в том, что реклама есть, от 0 до 1';
COMMENT ON COLUMN corpus.indexed_text.advertising_explanation IS 'Пояснение оценки рекламы';

CREATE TABLE corpus.text_embeddings (
    task_id bigint NOT NULL,
    embedding_name text NOT NULL,
    index integer NOT NULL,
    text text NOT NULL,
    embedding_vector vector(768) NOT NULL,
    habr_id integer NOT NULL,
    title text,
    published date,
    post_type text,
    primary_genre text,
    polarity text,
    audience_level text,
    demagoguery_severity text,
    nsfw boolean,
    advertising boolean,
    score integer,
    hubs text[]
) USING lance;

COMMENT ON TABLE corpus.text_embeddings IS 'Тексты статей, по которым ищут по смыслу, и их векторы: 147 432 строки, по строке на текст. Каждый текст — значение поля статьи из indexed_text (краткое содержание, смысл, вывод, мотив, тема, аудитория, противоречие, причина NSFW). В строке повторены поля статьи для фильтров поиска, их значения — те же, что в indexed_text';
COMMENT ON COLUMN corpus.text_embeddings.task_id IS 'Статья: indexed_text.task_id';
COMMENT ON COLUMN corpus.text_embeddings.embedding_name IS 'Из какого поля статьи текст: summary (summary), meaning (meaning), insight (key_insights), theme (themes), topic (topic_names и topic_descriptions), audience (audience_description), contradictory (contradictory_statements), nsfwReason (nsfw_reasons)';
COMMENT ON COLUMN corpus.text_embeddings.index IS 'Номер элемента в массиве поля, с 0: index = 2 у insight — key_insights[3]; у summary, meaning и audience всегда 0';
COMMENT ON COLUMN corpus.text_embeddings.text IS 'Текст, по которому посчитан вектор: значение поля; у topic — название темы и через пробел её описание';
COMMENT ON COLUMN corpus.text_embeddings.embedding_vector IS 'Вектор текста: EmbeddingGemma 300M (Q4_0), 768 чисел, длина 1. Близость текстов — косинусное расстояние embedding_vector <=> вектор, от 0 (то же) до 2';
COMMENT ON COLUMN corpus.text_embeddings.habr_id IS 'Номер статьи на Хабре: indexed_text.habr_id';
COMMENT ON COLUMN corpus.text_embeddings.title IS 'Заголовок статьи на Хабре: indexed_text.title';
COMMENT ON COLUMN corpus.text_embeddings.published IS 'Дата публикации статьи: indexed_text.published';
COMMENT ON COLUMN corpus.text_embeddings.post_type IS 'Тип публикации: indexed_text.post_type';
COMMENT ON COLUMN corpus.text_embeddings.primary_genre IS 'Основной жанр статьи: indexed_text.primary_genre';
COMMENT ON COLUMN corpus.text_embeddings.polarity IS 'Тональность статьи: indexed_text.polarity';
COMMENT ON COLUMN corpus.text_embeddings.audience_level IS 'Уровень читателя: indexed_text.audience_level';
COMMENT ON COLUMN corpus.text_embeddings.demagoguery_severity IS 'Степень демагогии: indexed_text.demagoguery_severity';
COMMENT ON COLUMN corpus.text_embeddings.nsfw IS 'NSFW: indexed_text.nsfw';
COMMENT ON COLUMN corpus.text_embeddings.advertising IS 'Есть реклама: indexed_text.advertising';
COMMENT ON COLUMN corpus.text_embeddings.score IS 'Рейтинг статьи: indexed_text.score';
COMMENT ON COLUMN corpus.text_embeddings.hubs IS 'Хабы статьи: indexed_text.hubs';
