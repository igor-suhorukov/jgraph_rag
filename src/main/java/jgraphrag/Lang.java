package jgraphrag;

import java.util.Locale;

enum Lang {
    RU, EN;

    static Lang of(String code) {
        return valueOf(code.toUpperCase(Locale.ROOT));
    }

    String code() {
        return name().toLowerCase(Locale.ROOT);
    }

    String database() {
        return "kb_" + code();
    }

    String sqlDescription() {
        return this == RU
                ? "SQL-запрос (PostgreSQL 19) к таблицам памяти. Схема habr_1097022 уже стоит в search_path. "
                + "Только чтение, не дольше 5 секунд; возвращаются первые 200 строк."
                : "An SQL query (PostgreSQL 19) to the tables of the memory. Schema habr_1097022 is already on the "
                + "search_path. Read-only, at most 5 seconds; the first 200 rows come back.";
    }

    String sparqlDescription() {
        return this == RU
                ? "SPARQL 1.1 запрос к графу памяти. Базовый IRI https://example.org/story-kg/id/habr-1097022/ уже задан: "
                + "узел статьи можно писать <claim_x>. Стандартные префиксы (schema:, kgo:, kgc:, oa:, skos:, prov:, qb:, "
                + "bbo:, rdf:, rdfs:, xsd: и другие) объявлены заранее. Запрос без GRAPH видит все графы сразу. "
                + "Только чтение, не дольше 5 секунд; возвращаются первые 200 строк."
                : "A SPARQL 1.1 query to the graph of the memory. The base IRI https://example.org/story-kg/id/habr-1097022/ "
                + "is set: a node of the article can be written <claim_x>. The standard prefixes (schema:, kgo:, kgc:, oa:, "
                + "skos:, prov:, qb:, bbo:, rdf:, rdfs:, xsd: and others) are declared in advance. A query without GRAPH "
                + "sees all the graphs at once. Read-only, at most 5 seconds; the first 200 rows come back.";
    }

    String corpusSqlDescription() {
        return this == RU
                ? "SQL-запрос (PostgreSQL 19) к таблицам коллекции статей Хабра. Схема corpus уже стоит в search_path. "
                + "Только чтение, не дольше 5 секунд; возвращаются первые 200 строк."
                : "An SQL query (PostgreSQL 19) to the tables of the collection of Habr articles. Schema corpus is already on "
                + "the search_path. Read-only, at most 5 seconds; the first 200 rows come back.";
    }

    String semanticDescription() {
        return this == RU
                ? "Поиск по смыслу в коллекции статей Хабра: k текстов статей из таблицы text_embeddings, ближайших по "
                + "смыслу к query, с косинусным расстоянием distance (0 — тот же смысл; чем больше, тем дальше). Условие "
                + "where над колонками text_embeddings сужает поиск. Только чтение, не дольше 5 секунд."
                : "A search by meaning in the collection of Habr articles: the k texts of articles from the table "
                + "text_embeddings nearest in meaning to query, with the cosine distance distance (0: the same meaning; the "
                + "larger, the farther). A condition where over the columns of text_embeddings narrows the search. "
                + "Read-only, at most 5 seconds.";
    }

    String searchQuery() {
        return this == RU ? "Что искать: текст, близкие по смыслу к которому тексты статей нужны"
                : "What to look for: the text whose neighbours in meaning among the texts of the articles are wanted";
    }

    String searchWhere() {
        return this == RU
                ? "Необязательное условие SQL над колонками text_embeddings, без слова WHERE, например "
                + "primary_genre = 'opinion' AND published >= '2023-06-01'"
                : "An optional SQL condition over the columns of text_embeddings, without the word WHERE, for example "
                + "primary_genre = 'opinion' AND published >= '2023-06-01'";
    }

    String searchK(int byDefault, int max) {
        return this == RU ? "Сколько текстов вернуть: от 1 до " + max + ", по умолчанию " + byDefault
                : "How many texts to return: 1 to " + max + ", " + byDefault + " by default";
    }

    String badWhere() {
        return this == RU ? "аргумент where — строка с условием SQL" : "the argument where is a string with an SQL condition";
    }

    String badK(int max) {
        return this == RU ? "аргумент k — целое число от 1 до " + max : "the argument k is an integer from 1 to " + max;
    }

    String queryArgument() {
        return this == RU ? "Текст запроса" : "The text of the query";
    }

    String error() {
        return this == RU ? "Ошибка: " : "Error: ";
    }

    String noQuery() {
        return this == RU ? "нужен аргумент query: текст запроса" : "the argument query is needed: the text of the query";
    }

    String noRows() {
        return this == RU ? "Запрос выполнен и строк не вернул." : "The query ran and returned no rows.";
    }

    String rows(int n) {
        return this == RU ? "(строк: " + n + ")" : "(rows: " + n + ")";
    }

    String more(int shown) {
        return this == RU ? "(показаны первые " + shown + " строк, есть ещё)"
                : "(the first " + shown + " rows shown, there are more)";
    }

    String cut(int shown, int chars) {
        return this == RU ? "(показано строк: " + shown + "; ответ обрезан до " + chars + " символов)"
                : "(rows shown: " + shown + "; the answer is cut at " + chars + " characters)";
    }

    String clipped(int chars) {
        return this == RU ? "(ответ обрезан до " + chars + " символов)" : "(the answer is cut at " + chars + " characters)";
    }

    String submitDescription() {
        return this == RU ? "Сдать ответ на вопрос. Вызывается один раз, в самом конце."
                : "Hand in the answer to the question. Called once, at the very end.";
    }

    String submitAnswer() {
        return this == RU ? "Краткий ответ словами" : "A short answer in words";
    }

    String submitValues() {
        return this == RU
                ? "Узлы и числа, которые и есть ответ, без промежуточных узлов, через которые ты к нему пришёл. key — "
                + "идентификатор узла (значение колонки id или key таблицы, или IRI узла без базового префикса), value — его "
                + "название, число или значение; для подсчётов value — число"
                : "The nodes and numbers that are the answer, without the nodes you passed on the way to it. key is the id of "
                + "a node (the value of the column id or key of a table, or the node's IRI without the base prefix), value "
                + "its name, a number or a value; for counts value is the number";
    }

    String submitContext() {
        return this == RU
                ? "Узлы, через которые ты пришёл к ответу, но которые им не являются: процесс, понятие, тезис, связь, "
                + "раздел. В проверке ответа не участвуют. key и value — как в values"
                : "The nodes you passed on the way to the answer that are not the answer: a process, a concept, a thesis, a "
                + "relation, a section. They are not checked. key and value as in values";
    }

    String format(String kind) {
        return switch (kind) {
            case "number" -> this == RU
                    ? "Формат ответа: в values — один элемент: key — идентификатор узла с числом, value — только число."
                    : "Answer format: one element in values: key is the id of the node holding the number, value only the number.";
            case "numbers" -> this == RU
                    ? "Формат ответа: в values — по элементу на каждое найденное число: key — идентификатор узла, value — только число."
                    : "Answer format: an element in values for every number found: key is the id of the node, value only the number.";
            case "set" -> this == RU
                    ? "Формат ответа: в values — только узлы, которые и есть ответ, по элементу на узел: key — идентификатор, value — название."
                    : "Answer format: in values only the nodes that are the answer, an element per node: key is the id, value the name.";
            case "counts" -> this == RU
                    ? "Формат ответа: в values — по элементу на каждый подсчитанный узел: key — идентификатор узла, value — только число."
                    : "Answer format: an element in values for every node counted: key is the id of the node, value only the number.";
            case "record" -> this == RU
                    ? "Формат ответа: в values — узлы и значения, из которых состоит ответ: key — идентификатор узла или имя поля, value — значение."
                    : "Answer format: in values the nodes and values the answer consists of: key is the id of a node or the name of a field, value the value.";
            case "quote" -> this == RU
                    ? "Формат ответа: в evidence — дословная цитата статьи и номер её строки."
                    : "Answer format: in evidence the verbatim quote of the article and its line number.";
            case "articles" -> this == RU
                    ? "Формат ответа: в values — по элементу на статью, которая и есть ответ: key — habr_id статьи, value — её заголовок."
                    : "Answer format: an element in values for every article that is the answer: key is the article's habr_id, value its title.";
            case "tally" -> this == RU
                    ? "Формат ответа: в values — один элемент: key — что посчитано, value — только число."
                    : "Answer format: one element in values: key is what was counted, value only the number.";
            case "codes" -> this == RU
                    ? "Формат ответа: в values — по элементу на каждое значение, которое и есть ответ: key — значение так, как оно записано в памяти."
                    : "Answer format: an element in values for every value that is the answer: key is the value as the memory writes it.";
            case "tallies" -> this == RU
                    ? "Формат ответа: в values — по элементу на каждое посчитанное значение: key — значение, value — только число."
                    : "Answer format: an element in values for every value counted: key is the value, value only the number.";
            default -> throw new IllegalArgumentException("no answer format for " + kind);
        };
    }

    String submitKey() {
        return this == RU ? "Идентификатор узла или имя поля" : "The id of a node or the name of a field";
    }

    String submitValue() {
        return this == RU ? "Название, число или значение" : "A name, a number or a value";
    }

    String submitEvidence() {
        return this == RU ? "Дословные цитаты статьи с номером строки, если вопрос просит цитату"
                : "Verbatim quotes of the article with the line number, if the question asks for a quote";
    }

    String submitQuote() {
        return this == RU ? "Цитата дословно" : "The quote, verbatim";
    }

    String submitLine() {
        return this == RU ? "Номер строки статьи" : "The line number in the article";
    }

    String submitNoAnswer() {
        return this == RU ? "true, только если в памяти нет ответа на вопрос"
                : "true only if the memory holds no answer to the question";
    }

    String remind() {
        return this == RU ? "Ответ нужно сдать вызовом submit_answer." : "Hand in the answer by calling submit_answer.";
    }

    String limit(int calls) {
        return this == RU
                ? "Ошибка: лимит в " + calls + " вызовов памяти исчерпан. Сдай ответ вызовом submit_answer."
                : "Error: the limit of " + calls + " calls to the memory is used up. Hand in the answer by calling submit_answer.";
    }

    String tools(String condition) {
        return switch (condition) {
            case "sql" -> this == RU ? "инструментом sql_query — SQL-запросами к таблицам"
                    : "with the tool sql_query: SQL queries to the tables";
            case "sparql" -> this == RU ? "инструментом sparql_query — SPARQL-запросами к графу"
                    : "with the tool sparql_query: SPARQL queries to the graph";
            case "both" -> this == RU
                    ? "двумя инструментами: sql_query — SQL-запросами к таблицам и sparql_query — SPARQL-запросами к графу тех же знаний"
                    : "with two tools: sql_query, SQL queries to the tables, and sparql_query, SPARQL queries to the graph of the same knowledge";
            case "both_sparql_first" -> this == RU
                    ? "двумя инструментами: sparql_query — SPARQL-запросами к графу и sql_query — SQL-запросами к таблицам тех же знаний"
                    : "with two tools: sparql_query, SPARQL queries to the graph, and sql_query, SQL queries to the tables of the same knowledge";
            case "corpus_sql" -> this == RU ? "инструментом sql_query — SQL-запросами к таблицам коллекции"
                    : "with the tool sql_query: SQL queries to the tables of the collection";
            case "vector" -> this == RU ? "инструментом semantic_search — поиском текстов статей по смыслу"
                    : "with the tool semantic_search: a search of the texts of the articles by meaning";
            case "vector_sql" -> this == RU
                    ? "двумя инструментами: semantic_search — поиском текстов статей по смыслу и sql_query — SQL-запросами к таблицам коллекции"
                    : "with two tools: semantic_search, a search of the texts of the articles by meaning, and sql_query, SQL queries to the tables of the collection";
            default -> throw new IllegalArgumentException("condition " + condition);
        };
    }
}
