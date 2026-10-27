-- База знаний статьи «Мой PostgreSQL быстрее твоего и почти догнал ClickHouse» (habr.com/ru/articles/1097022)
-- на русском: схема habr_1097022 с комментариями, строки и отображение R2RML, которое читает их как граф знаний.
-- Загружается в базу, где установлен pg_knowledge_base (CREATE EXTENSION pg_knowledge_base) и он есть в
-- shared_preload_libraries:  psql -v ON_ERROR_STOP=1 -f habr_1097022.ru.sql
-- Собран tools/make_dumps.py из таблиц Story-KG; английский двойник — habr_1097022.en.sql.

-- Story-KG: статья habr/1097022.md «Мой PostgreSQL быстрее твоего и почти догнал ClickHouse» —
-- её фреймы и граф знаний в таблицах, которые читаются людьми.
--
-- Принципы:
--   * таблица — фрейм (раздел спецификации kg/extract/habr-1097022.yaml или выведенный фрейм derived-*);
--   * строка — узел графа, колонка — его свойство, список — массив в той же строке (таблиц __values нет);
--   * ключ — короткий id из спецификации (pg_vexec, rep01, obs_q20_skip_sim); IRI узла строит отображение R2RML:
--     https://example.org/story-kg/id/habr-1097022/{id}; ссылки на узлы статьи — те же id;
--   * коды словарей хранятся без пространства имён: thesis, problem, database (а не kgc:claim/thesis);
--   * постоянные тройки (классы rdf:type, kgo:inDocument, источник цитат, правила вывода), обратные и симметричные
--     связи, имена выведенных узлов, собранные из колонок, — делает отображение R2RML, в таблицах их нет;
--   * колонка «Выведено (derived-…)» — свойство из выведенного фрейма; её тройки лежат в графе kgg:derived-…,
--     остальные — в графе статьи kgg:habr-1097022, если в комментарии не сказано иное.

BEGIN;
CREATE SCHEMA habr_1097022;
SET search_path = habr_1097022;

COMMENT ON SCHEMA habr_1097022 IS
'Story-KG, статья habr/1097022.md «Мой PostgreSQL быстрее твоего и почти догнал ClickHouse»: фреймы статьи и её '
'граф знаний (10 154 квада в 37 графах) в таблицах для людей. Таблица — фрейм, строка — узел графа, колонка — '
'свойство, список — массив в той же строке; таблиц __values нет. Ключи — короткие id из спецификации, IRI узла — '
'https://example.org/story-kg/id/habr-1097022/{id}; коды словарей kgc: — без пространства имён. Классы, постоянные '
'и обратные тройки строит отображение R2RML.';

CREATE FUNCTION iri(qname text) RETURNS text
LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
RETURN (SELECT p.ns FROM (VALUES
            ('schema', 'http://schema.org/'),
            ('kgo', 'https://example.org/story-kg/ontology#'),
            ('eso', 'http://www.newsreader-project.eu/domain-ontology#'),
            ('bbo', 'https://www.irit.fr/recherches/MELODI/ontologies/BBO#'),
            ('qb', 'http://purl.org/linked-data/cube#'),
            ('skos', 'http://www.w3.org/2004/02/skos/core#'),
            ('oa', 'http://www.w3.org/ns/oa#'),
            ('prov', 'http://www.w3.org/ns/prov#'),
            ('dcterms', 'http://purl.org/dc/terms/'),
            ('foaf', 'http://xmlns.com/foaf/0.1/'),
            ('sioc', 'http://rdfs.org/sioc/ns#'),
            ('vcard', 'http://www.w3.org/2006/vcard/ns#'),
            ('rdf', 'http://www.w3.org/1999/02/22-rdf-syntax-ns#')) AS p (prefix, ns)
        WHERE p.prefix = split_part(qname, ':', 1))
       || substr(qname, strpos(qname, ':') + 1);
COMMENT ON FUNCTION iri(text) IS
'IRI по qname: schema:Person → http://schema.org/Person. Колонки классов (types) и свойств (relations.predicate) '
'хранят qname, отображение R2RML пишет из них IRI этой функцией';

-- ============================================================== слой спецификации: граф kgg:habr-1097022

CREATE TABLE article (
    slug                      text PRIMARY KEY,
    title                     text NOT NULL,
    description               text,
    types                     text[] NOT NULL,
    post_type                 text,
    genres                    text[],
    tags                      text[],
    about                     text[],
    mentions                  text[],
    author                    text,
    published                 timestamp,
    language                  text,
    habr_id                   integer,
    url                       text,
    score                     integer,
    reading_count             integer,
    comments_count            integer,
    favorites_count           integer,
    votes_count               integer,
    votes_plus                integer,
    votes_minus               integer,
    publisher                 text,
    publisher_name            text,
    publisher_url             text,
    author_nick               text,
    author_score              integer,
    author_votes              integer,
    source_file               text,
    source_format             text,
    source_bytes              integer,
    source_chars              integer,
    source_sha256             text,
    source_date               timestamptz,
    spec_file                 text,
    mentions_method           text,
    narrative_person          text,
    narrative_person_basis    text,
    like_share                numeric,
    comments_per_1000_views   numeric,
    bookmarks_per_1000_views  numeric,
    style_key                 text,
    style_word_count          integer,
    style_sentence_count      integer,
    style_paragraph_count     integer,
    style_mean_sentence_length    numeric,
    style_median_sentence_length  numeric,
    style_mean_paragraph_length   numeric,
    style_type_token_ratio    numeric,
    style_hapax_share         numeric,
    style_function_word_share numeric,
    argmap_argument_count     integer,
    argmap_claim_count        integer,
    argmap_conflict_count     integer,
    argmap_contested_claim_count integer,
    argmap_evidence_share     numeric,
    argmap_depth              integer,
    argmap_main_claims        text[]
);
COMMENT ON TABLE article IS
'Фрейм 1 «Документ»: статья (узел work: schema:Article, BlogPosting, TechArticle), её исходный файл и его состояние, '
'счётчики Хабра, издатель, учётная запись автора на Хабре, описания графов статьи. Одна строка. Колонки style_…, '
'argmap_… и отклика — выведенные сводки по статье (derived-stylometry, derived-arguments, derived-ratings): узлы '
'style/{style_key}, argument-map и response с именами «Стиль текста: {slug}», «Карта аргументации ({slug})», '
'«Отклик на статью: {title}». Узлы стека техники (techstack), словаря понятий (terms) и словаря терминов '
'(glossary) отображение строит из названия и таблиц entities, concepts, relations, terms';
COMMENT ON COLUMN article.slug IS 'Имя статьи в Story-KG; пространство IRI её узлов https://example.org/story-kg/id/{slug}/, граф статьи kgg:{slug}';
COMMENT ON COLUMN article.title IS 'Заголовок. RDF: schema:name и schema:headline @ru';
COMMENT ON COLUMN article.description IS 'Аннотация. RDF: schema:description @ru';
COMMENT ON COLUMN article.types IS 'Классы статьи (qname). RDF: rdf:type';
COMMENT ON COLUMN article.post_type IS 'Тип публикации на Хабре (postType). RDF: schema:additionalType';
COMMENT ON COLUMN article.genres IS 'Жанры. RDF: schema:genre @ru, тройка на элемент';
COMMENT ON COLUMN article.tags IS 'Теги автора (user_tags). RDF: schema:keywords — дважды: строкой и строкой @ru';
COMMENT ON COLUMN article.about IS 'Главные предметы статьи: id сущностей и понятий. RDF: schema:about';
COMMENT ON COLUMN article.mentions IS 'Люди, упомянутые в статье. RDF: schema:mentions';
COMMENT ON COLUMN article.author IS 'Автор — id сущности. RDF: schema:author; второй schema:author — kge:habr-user/{author_nick}';
COMMENT ON COLUMN article.published IS 'Дата публикации. RDF: schema:datePublished; она же vcard:rev карточки автора';
COMMENT ON COLUMN article.language IS 'Язык текста. RDF: schema:inLanguage';
COMMENT ON COLUMN article.habr_id IS 'Номер статьи на Хабре. RDF: schema:identifier (строкой)';
COMMENT ON COLUMN article.url IS 'Адрес статьи. RDF: schema:sameAs';
COMMENT ON COLUMN article.score IS 'Рейтинг статьи (score). RDF: kgo:score';
COMMENT ON COLUMN article.reading_count IS 'Просмотры (readingCount): счётчик work#stat-readingCount, schema:ReadAction. RDF: schema:userInteractionCount';
COMMENT ON COLUMN article.comments_count IS 'Комментарии (commentsCount): счётчик schema:CommentAction';
COMMENT ON COLUMN article.favorites_count IS 'Закладки (favoritesCount): счётчик schema:BookmarkAction';
COMMENT ON COLUMN article.votes_count IS 'Голоса (votesCount): счётчик schema:VoteAction';
COMMENT ON COLUMN article.votes_plus IS 'Плюсы (votesCountPlus): счётчик schema:LikeAction';
COMMENT ON COLUMN article.votes_minus IS 'Минусы (votesCountMinus): счётчик schema:DislikeAction';
COMMENT ON COLUMN article.publisher IS 'Издатель — глобальный узел kge:{publisher} (schema:Organization, kgo:OnlineCommunity). RDF: schema:publisher; в графе _global — kgo:mentionedInGraph';
COMMENT ON COLUMN article.publisher_name IS 'Название издателя. RDF: schema:name узла издателя (строкой)';
COMMENT ON COLUMN article.publisher_url IS 'Сайт издателя. RDF: schema:url издателя и foaf:accountServiceHomepage учётной записи автора';
COMMENT ON COLUMN article.author_nick IS 'Ник автора на Хабре: узлы kge:habr-user/{ник} (schema:Person, schema:name, schema:alternateName) и kge:habr-account/{ник} (foaf:OnlineAccount, foaf:accountName, sioc:account_of)';
COMMENT ON COLUMN article.author_score IS 'Карма автора (authorScore). RDF: kgo:accountScore учётной записи на Хабре';
COMMENT ON COLUMN article.author_votes IS 'Голоса за карму автора (authorVotesCount). RDF: kgo:accountVotesCount';
COMMENT ON COLUMN article.source_file IS 'Исходный файл в корпусе: узел src:{файл} (schema:MediaObject) с schema:name и schema:identifier; статья ссылается на него schema:encoding, он на неё — schema:encodesCreativeWork';
COMMENT ON COLUMN article.source_format IS 'Формат файла. RDF: schema:encodingFormat';
COMMENT ON COLUMN article.source_bytes IS 'Размер файла. RDF: schema:contentSize «{N} bytes»';
COMMENT ON COLUMN article.source_chars IS 'Длина текста в символах. RDF: kgo:charCount';
COMMENT ON COLUMN article.source_sha256 IS 'SHA-256 файла. RDF: kgo:sha256 файла и его состояния src:{файл}#state-{12 знаков}';
COMMENT ON COLUMN article.source_date IS 'Время версии файла, к которой привязаны смещения цитат. RDF: oa:sourceDate состояния (oa:TimeState)';
COMMENT ON COLUMN article.spec_file IS 'Спецификация, из которой компилятор построил граф статьи. RDF: dcterms:source графа kgg:{slug} (граф по умолчанию, вместе с prov:wasDerivedFrom и prov:wasGeneratedBy)';
COMMENT ON COLUMN article.mentions_method IS 'Как построен индекс упоминаний. RDF: kgo:extractionMethod графа kgg:{slug}-mentions @ru (граф по умолчанию)';
COMMENT ON COLUMN article.narrative_person IS 'Выведено (derived-narrative): лицо повествования. RDF: kgo:narrativePersonType → kgc:person/{код}';
COMMENT ON COLUMN article.narrative_person_basis IS 'Выведено (derived-narrative): основание вывода. RDF: kgo:narrativePersonBasis';
COMMENT ON COLUMN article.like_share IS 'Выведено (derived-ratings): доля плюсов среди голосов. RDF: kgo:likeShare узла response; его счётчики (kgo:viewCount, kgo:likeCount…) — счётчики Хабра этой таблицы (reading_count, votes_plus…)';
COMMENT ON COLUMN article.comments_per_1000_views IS 'Выведено (derived-ratings): комментариев на 1000 просмотров. RDF: kgo:commentsPerThousandViews';
COMMENT ON COLUMN article.bookmarks_per_1000_views IS 'Выведено (derived-ratings): закладок на 1000 просмотров. RDF: kgo:bookmarksPerThousandViews';
COMMENT ON COLUMN article.style_key IS 'Выведено (derived-stylometry): ключ узла профиля стиля style/{ключ} (kgo:TextStyleProfile)';
COMMENT ON COLUMN article.style_word_count IS 'Выведено (derived-stylometry): слов. RDF: kgo:styleWordCount';
COMMENT ON COLUMN article.style_sentence_count IS 'Выведено (derived-stylometry): предложений. RDF: kgo:styleSentenceCount';
COMMENT ON COLUMN article.style_paragraph_count IS 'Выведено (derived-stylometry): абзацев. RDF: kgo:styleParagraphCount';
COMMENT ON COLUMN article.style_mean_sentence_length IS 'Выведено (derived-stylometry): средняя длина предложения в словах. RDF: kgo:meanSentenceLength';
COMMENT ON COLUMN article.style_median_sentence_length IS 'Выведено (derived-stylometry): медианная длина предложения. RDF: kgo:medianSentenceLength';
COMMENT ON COLUMN article.style_mean_paragraph_length IS 'Выведено (derived-stylometry): средняя длина абзаца. RDF: kgo:meanParagraphLength';
COMMENT ON COLUMN article.style_type_token_ratio IS 'Выведено (derived-stylometry): доля разных слов. RDF: kgo:typeTokenRatio';
COMMENT ON COLUMN article.style_hapax_share IS 'Выведено (derived-stylometry): доля слов, встреченных один раз. RDF: kgo:hapaxShare';
COMMENT ON COLUMN article.style_function_word_share IS 'Выведено (derived-stylometry): доля служебных слов. RDF: kgo:functionWordShare';
COMMENT ON COLUMN article.argmap_argument_count IS 'Выведено (derived-arguments): доводов в карте аргументации. RDF: kgo:argumentCount';
COMMENT ON COLUMN article.argmap_claim_count IS 'Выведено (derived-arguments): утверждений в карте. RDF: kgo:claimCount';
COMMENT ON COLUMN article.argmap_conflict_count IS 'Выведено (derived-arguments): возражений. RDF: kgo:conflictCount';
COMMENT ON COLUMN article.argmap_contested_claim_count IS 'Выведено (derived-arguments): оспоренных утверждений. RDF: kgo:contestedClaimCount';
COMMENT ON COLUMN article.argmap_evidence_share IS 'Выведено (derived-arguments): доля утверждений с опорой на наблюдения. RDF: kgo:evidenceShare';
COMMENT ON COLUMN article.argmap_depth IS 'Выведено (derived-arguments): глубина дерева доводов. RDF: kgo:maxDepth';
COMMENT ON COLUMN article.argmap_main_claims IS 'Выведено (derived-arguments): главные тезисы. RDF: kgo:mainClaim';

CREATE TABLE hubs (
    slug            text PRIMARY KEY,
    name            text NOT NULL,
    views_rank      integer,
    views_rank_key  text
);
COMMENT ON TABLE hubs IS
'Хабы Хабра, в которых опубликована статья: узлы kge:habr-hub/{slug} (skos:Concept схемы kge:habr-hubs). '
'Статья ссылается на них kgo:hub';
COMMENT ON COLUMN hubs.slug IS 'Код хаба в Story-KG (транслит названия)';
COMMENT ON COLUMN hubs.name IS 'Название хаба. RDF: skos:prefLabel @ru';
COMMENT ON COLUMN hubs.views_rank IS 'Выведено (derived-ratings): место статьи в рейтинге хаба по просмотрам. RDF: schema:position элемента списка kge:habr-hub/{slug}#by-views';
COMMENT ON COLUMN hubs.views_rank_key IS 'Выведено (derived-ratings): ключ элемента списка response#hub-{ключ} (schema:ListItem); отклик ссылается на него kgo:hubPosition';

CREATE TABLE sections (
    id                   text PRIMARY KEY,
    kind                 text NOT NULL,
    name                 text NOT NULL,
    level                integer,
    line                 integer,
    parent               text,
    start_pos            integer,
    end_pos              integer,
    mentions             text[],
    main_claim           text,
    main_claim_supports  integer,
    terms                text[]
);
COMMENT ON TABLE sections IS
'Фрейм 2 «Структура текста»: шапка (fm), вступление (body) и разделы s1…s5 — узлы sec/{id} с промежутком '
'текста sec/{id}#span (oa:SpecificResource и oa:TextPositionSelector sec/{id}#span-selector)';
COMMENT ON COLUMN sections.id IS 'Код раздела. RDF: kgo:sectionId; IRI — sec/{id}';
COMMENT ON COLUMN sections.kind IS 'Класс раздела: Section или FrontMatter (kgo:)';
COMMENT ON COLUMN sections.name IS 'Заголовок. RDF: schema:name @ru';
COMMENT ON COLUMN sections.level IS 'Уровень заголовка. RDF: kgo:level';
COMMENT ON COLUMN sections.line IS 'Строка начала в исходном файле. RDF: kgo:line';
COMMENT ON COLUMN sections.parent IS 'Объемлющий раздел; пусто — статья целиком (work). RDF: schema:isPartOf';
COMMENT ON COLUMN sections.start_pos IS 'Начало раздела в символах текста. RDF: oa:start (xsd:nonNegativeInteger)';
COMMENT ON COLUMN sections.end_pos IS 'Конец раздела в символах текста. RDF: oa:end';
COMMENT ON COLUMN sections.mentions IS 'Сущности и понятия, названные в разделе. RDF: schema:mentions, граф упоминаний kgg:habr-1097022-mentions';
COMMENT ON COLUMN sections.main_claim IS 'Выведено (derived-passages): главный тезис раздела. RDF: kgo:mainClaim';
COMMENT ON COLUMN sections.main_claim_supports IS 'Выведено (derived-passages): сколько доводов его поддерживает. RDF: kgo:mainClaimSupports';
COMMENT ON COLUMN sections.terms IS 'Выведено (derived-terminology): термины, упомянутые в разделе. RDF: schema:mentions term/{slug}';

CREATE TABLE evidence (
    key            text PRIMARY KEY,
    about          text NOT NULL,
    graph          text NOT NULL,
    motivation     text NOT NULL,
    first_mention  boolean NOT NULL DEFAULT false,
    comment        text,
    section        text,
    line           integer,
    quote          text NOT NULL,
    prefix         text,
    suffix         text,
    start_pos      integer NOT NULL,
    end_pos        integer NOT NULL
);
COMMENT ON TABLE evidence IS
'Фрейм 3 «Привязка к тексту» (W3C Web Annotation): цитата статьи, на которую опирается узел. Строка — аннотация '
'anno/{key} (oa:Annotation); её цель (oa:SpecificResource с oa:hasSource и oa:hasState) и селекторы цитаты '
'(oa:TextQuoteSelector) и позиции (oa:TextPositionSelector) — пустые узлы, их строит отображение. Здесь же '
'первые упоминания (граф упоминаний) и цитаты выведенных фреймов. Путь в графе от аннотации: oa:hasBody — узел; '
'oa:hasTarget → kgo:line, kgo:inSection; oa:hasTarget → oa:hasSelector → oa:exact, oa:prefix, oa:suffix '
'(селектор цитаты) и oa:start, oa:end (селектор позиции)';
COMMENT ON COLUMN evidence.key IS 'Ключ аннотации: 12 знаков SHA-1; first-… — первое упоминание, d-… — цитата выведенного фрейма. IRI — anno/{key}';
COMMENT ON COLUMN evidence.about IS 'Узел, который цитата подтверждает: id или путь (rel/…, theme/…, definition/…). RDF: oa:hasBody';
COMMENT ON COLUMN evidence.graph IS 'Граф аннотации: habr-1097022, habr-1097022-mentions или derived-…';
COMMENT ON COLUMN evidence.motivation IS 'Назначение цитаты: describing, classifying, identifying, linking. RDF: oa:motivatedBy → oa:{код}';
COMMENT ON COLUMN evidence.first_mention IS 'Первое упоминание узла в тексте. RDF: kgo:firstMention у узла about';
COMMENT ON COLUMN evidence.comment IS 'Пояснение к цитате. RDF: rdfs:comment @ru';
COMMENT ON COLUMN evidence.section IS 'Раздел цитаты. RDF: kgo:inSection цели аннотации (oa:hasTarget → kgo:inSection)';
COMMENT ON COLUMN evidence.line IS 'Строка исходного файла. RDF: kgo:line цели аннотации (oa:hasTarget → kgo:line)';
COMMENT ON COLUMN evidence.quote IS 'Цитата дословно. RDF: oa:exact селектора цитаты (oa:hasTarget → oa:hasSelector → oa:exact)';
COMMENT ON COLUMN evidence.prefix IS 'Текст перед цитатой. RDF: oa:prefix селектора цитаты (oa:hasTarget → oa:hasSelector → oa:prefix)';
COMMENT ON COLUMN evidence.suffix IS 'Текст после цитаты. RDF: oa:suffix селектора цитаты (oa:hasTarget → oa:hasSelector → oa:suffix)';
COMMENT ON COLUMN evidence.start_pos IS 'Начало цитаты в символах текста. RDF: oa:start селектора позиции (oa:hasTarget → oa:hasSelector → oa:start; xsd:nonNegativeInteger)';
COMMENT ON COLUMN evidence.end_pos IS 'Конец цитаты в символах текста. RDF: oa:end селектора позиции (oa:hasTarget → oa:hasSelector → oa:end)';

CREATE TABLE entities (
    id                   text PRIMARY KEY,
    types                text[] NOT NULL,
    name                 text NOT NULL,
    alt_names            text[],
    hidden_labels        text[],
    description          text,
    roles                text[],
    global               text,
    same_as              text,
    tech_role            text,
    discourse_position   integer,
    sensitivity          text,
    url                  text,
    code_repository      text,
    author               text,
    about                text[],
    contacts_sensitivity text,
    account_service      text,
    account_name         text,
    account_service_url  text,
    account_url          text,
    mention_count        integer,
    stack_role           text
);
COMMENT ON TABLE entities IS
'Фреймы 5, 6, 8 «Люди, организации, предметы»: раздел entities спецификации — люди, программы, библиотеки, '
'статьи, организации. Связи между ними — в таблице relations';
COMMENT ON COLUMN entities.id IS 'id из спецификации; IRI — https://example.org/story-kg/id/habr-1097022/{id}';
COMMENT ON COLUMN entities.types IS 'Классы (qname): schema:Person, schema:SoftwareApplication… RDF: rdf:type';
COMMENT ON COLUMN entities.name IS 'Имя. RDF: schema:name @ru';
COMMENT ON COLUMN entities.alt_names IS 'Другие названия. RDF: schema:alternateName @ru';
COMMENT ON COLUMN entities.hidden_labels IS 'Написания для поиска (постгрес, кликхаус). RDF: skos:hiddenLabel @ru';
COMMENT ON COLUMN entities.description IS 'Описание. RDF: schema:description @ru';
COMMENT ON COLUMN entities.roles IS 'Роль в тексте: author, narrator, protagonist, major. RDF: kgo:characterRole → kgc:role/{код}';
COMMENT ON COLUMN entities.global IS 'Глобальный узел Story-KG, общий для всех текстов. RDF: owl:sameAs kge:{global}; в графе _global — kge:{global} kgo:mentionedInGraph kgg:habr-1097022';
COMMENT ON COLUMN entities.same_as IS 'Другой внешний узел того же объекта. RDF: owl:sameAs kge:{same_as}';
COMMENT ON COLUMN entities.tech_role IS 'Роль в технике: database, framework_library… RDF: kgo:techRole → kgc:techrole/{код}';
COMMENT ON COLUMN entities.discourse_position IS 'Позиция в сюжете: смещение первого упоминания. RDF: kgo:discoursePosition';
COMMENT ON COLUMN entities.sensitivity IS 'Чувствительность сведений: personal. RDF: kgo:sensitivity → kgc:sensitivity/{код}';
COMMENT ON COLUMN entities.url IS 'Адрес. RDF: schema:url';
COMMENT ON COLUMN entities.code_repository IS 'Репозиторий исходного кода. RDF: schema:codeRepository';
COMMENT ON COLUMN entities.author IS 'Автор произведения или кода — id. RDF: schema:author';
COMMENT ON COLUMN entities.about IS 'О чём произведение — id. RDF: schema:about';
COMMENT ON COLUMN entities.contacts_sensitivity IS 'Есть карточка контактов {id}#vcard (vcard:Individual: vcard:fn — имя, vcard:rev — дата статьи); значение — её kgo:sensitivity. Персона ссылается на карточку kgo:contactCard';
COMMENT ON COLUMN entities.account_service IS 'Учётная запись {id}#account-{сервис}_{имя} (foaf:OnlineAccount, sioc:UserAccount): сервис. RDF: schema:description @ru; персона ссылается на запись foaf:account';
COMMENT ON COLUMN entities.account_name IS 'Имя учётной записи. RDF: foaf:accountName';
COMMENT ON COLUMN entities.account_service_url IS 'Сайт сервиса. RDF: foaf:accountServiceHomepage';
COMMENT ON COLUMN entities.account_url IS 'Адрес учётной записи. RDF: schema:url';
COMMENT ON COLUMN entities.mention_count IS 'Сколько раз названа в тексте. RDF: kgo:mentionCount, граф упоминаний';
COMMENT ON COLUMN entities.stack_role IS 'Выведено (derived-techstack): роль в стеке техники статьи. RDF: kgo:techRole; стек ссылается на узел kgo:stackComponent';

CREATE TABLE concepts (
    id                text PRIMARY KEY,
    name              text NOT NULL,
    alt_names         text[],
    kind              text,
    definition        text,
    description       text,
    global            text,
    broader           text[],
    narrower          text[],
    related           text[],
    counter_measures  text[],
    procedure         text,
    goal              text,
    arises_when       text,
    manifestation     text,
    mechanism         text,
    mention_count     integer,
    stack_role        text,
    extraction_basis  text,
    definition_key    text,
    problem_key       text
);
COMMENT ON TABLE concepts IS
'Фрейм 9 «Понятия»: раздел concepts спецификации — механизмы, методы, структуры данных, явления '
'(schema:DefinedTerm, skos:Concept) словаря понятий статьи terms (skos:inScheme, schema:inDefinedTermSet). '
'Отличия и части — в таблице relations, вклад методов в качества — в contributions';
COMMENT ON COLUMN concepts.id IS 'id из спецификации; IRI — https://example.org/story-kg/id/habr-1097022/{id}';
COMMENT ON COLUMN concepts.name IS 'Название. RDF: schema:name и skos:prefLabel @ru';
COMMENT ON COLUMN concepts.alt_names IS 'Другие названия. RDF: skos:altLabel @ru';
COMMENT ON COLUMN concepts.kind IS 'Вид понятия: mechanism, technique, component, datastructure, variant, phenomenon… RDF: kgo:conceptKind → kgc:conceptkind/{код}';
COMMENT ON COLUMN concepts.definition IS 'Определение. RDF: skos:definition и schema:description @ru';
COMMENT ON COLUMN concepts.description IS 'Пояснение. RDF: schema:description @ru';
COMMENT ON COLUMN concepts.global IS 'Глобальное понятие Story-KG. RDF: skos:exactMatch kge:{global}; в графе _global — kgo:mentionedInGraph';
COMMENT ON COLUMN concepts.broader IS 'Более общие понятия. RDF: skos:broader';
COMMENT ON COLUMN concepts.narrower IS 'Более частные понятия. RDF: skos:narrower';
COMMENT ON COLUMN concepts.related IS 'Связанные понятия. RDF: skos:related';
COMMENT ON COLUMN concepts.counter_measures IS 'Чем бороться с явлением. RDF: kgo:counterMeasure';
COMMENT ON COLUMN concepts.procedure IS 'Процедура метода — id процесса. RDF: kgo:hasProcedure';
COMMENT ON COLUMN concepts.goal IS 'Цель метода. RDF: kgo:methodGoal @ru';
COMMENT ON COLUMN concepts.arises_when IS 'Когда возникает явление. RDF: kgo:arisesWhen @ru';
COMMENT ON COLUMN concepts.manifestation IS 'Как проявляется явление. RDF: kgo:manifestation @ru';
COMMENT ON COLUMN concepts.mechanism IS 'Механизм явления. RDF: kgo:phenomenonMechanismText @ru';
COMMENT ON COLUMN concepts.mention_count IS 'Сколько раз названо в тексте. RDF: kgo:mentionCount, граф упоминаний';
COMMENT ON COLUMN concepts.stack_role IS 'Выведено (derived-techstack): роль в стеке техники статьи. RDF: kgo:techRole → kgc:techrole/{код}';
COMMENT ON COLUMN concepts.extraction_basis IS 'Выведено (derived-provenance): основание извлечения. RDF: kgo:extractionBasis → kgc:basis/{код}';
COMMENT ON COLUMN concepts.definition_key IS 'Выведено (derived-definitions): ключ узла definition/{ключ} (kgo:Definition: kgo:defines — понятие, kgo:definiendum — name, kgo:definiens — definition, kgo:definitionPattern «concept»)';
COMMENT ON COLUMN concepts.problem_key IS 'Выведено (derived-problems): ключ узла problem/{ключ} (kgo:Phenomenon: kgo:phenomenonConcept — понятие, schema:name — name)';

CREATE TABLE contributions (
    key          text PRIMARY KEY,
    concept      text NOT NULL,
    type         text NOT NULL,
    effect_kind  text NOT NULL,
    effect       text NOT NULL,
    quality      text
);
COMMENT ON TABLE contributions IS
'Вклад метода в качество (kgo:Contribution, узлы contribution/{key}): из поля benefits понятия. Понятие '
'ссылается на вклад kgo:benefit; schema:name — «{название понятия}: {effect}»';
COMMENT ON COLUMN contributions.key IS 'Ключ узла: 12 знаков SHA-1. IRI — contribution/{key}';
COMMENT ON COLUMN contributions.concept IS 'Метод — id понятия. RDF: kgo:contributionOf';
COMMENT ON COLUMN contributions.type IS 'help — помогает, hurt — мешает. RDF: kgo:contributionType → kgc:contribution/{код}';
COMMENT ON COLUMN contributions.effect_kind IS 'benefit или cost. RDF: kgo:effectKind → kgc:effectkind/{код}';
COMMENT ON COLUMN contributions.effect IS 'Что даёт метод. RDF: kgo:effectText @ru';
COMMENT ON COLUMN contributions.quality IS 'Атрибут качества ISO/IEC 25010: time_behaviour, resource_utilization… RDF: kgo:qualityAttribute → kgc:quality/{код}';

CREATE TABLE themes (
    slug  text PRIMARY KEY,
    name  text NOT NULL
);
COMMENT ON TABLE themes IS
'Темы статьи: узлы theme/{slug} (schema:DefinedTerm, skos:Concept) — хабы и темы из спецификации; статья '
'ссылается на них kgo:theme. Привязка к рубрикам тем Story-KG — в theme_links';
COMMENT ON COLUMN themes.slug IS 'Код темы (транслит названия). IRI — theme/{slug}';
COMMENT ON COLUMN themes.name IS 'Название. RDF: schema:name и skos:prefLabel @ru';

CREATE TABLE relations (
    key        text PRIMARY KEY,
    subject    text NOT NULL,
    predicate  text NOT NULL,
    object     text NOT NULL,
    label      text,
    feature    text,
    in_stack   boolean NOT NULL DEFAULT false
);
COMMENT ON TABLE relations IS
'Фрейм 11 «Отношения»: n-арный узел rel/{key} (kgo:Relationship, rdf:Statement) — кто, какое свойство, с кем, '
'подпись, отличие. Прямую тройку «subject predicate object» строит отображение; kgo:differsFrom и '
'kgo:integratesWith — в обе стороны';
COMMENT ON COLUMN relations.key IS 'Ключ узла: 12 знаков SHA-1. IRI — rel/{key}';
COMMENT ON COLUMN relations.subject IS 'Кто — id. RDF: rdf:subject';
COMMENT ON COLUMN relations.predicate IS 'Свойство (qname): kgo:usesTool, kgo:implements, kgo:integratesWith, kgo:differsFrom, schema:isPartOf, schema:isBasedOn. RDF: rdf:predicate';
COMMENT ON COLUMN relations.object IS 'С кем — id. RDF: rdf:object';
COMMENT ON COLUMN relations.label IS 'Подпись. RDF: kgo:relationLabel @ru';
COMMENT ON COLUMN relations.feature IS 'Чем отличаются (для kgo:differsFrom). RDF: kgo:distinguishingFeature @ru';
COMMENT ON COLUMN relations.in_stack IS 'Выведено (derived-techstack): отношение входит в стек техники статьи. RDF: kgo:stackRelation и prov:wasDerivedFrom узла techstack';

CREATE TABLE events (
    id                  text PRIMARY KEY,
    types               text[] NOT NULL,
    name                text NOT NULL,
    description         text,
    frame               text,
    agent               text,
    object              text,
    instrument          text,
    date_text           text,
    factuality          text,
    precedes            text[],
    causes              text[],
    caused_by           text,
    motivated_by        text,
    discourse_position  integer,
    creates             text,
    timeline_rank       integer,
    lifecycle_stage     text,
    fn_frame            text,
    fn_frame_choice     text,
    fn_frame_match      text,
    fn_frame_mapping    text,
    fn_roles            jsonb,
    dialog_act          text,
    speaker             text
);
COMMENT ON TABLE events IS
'Фреймы 13–14 «События»: раздел events спецификации — события и действия schema.org с классами ESO';
COMMENT ON COLUMN events.id IS 'id из спецификации';
COMMENT ON COLUMN events.types IS 'Классы (qname): schema:Event, schema:AssessAction, eso:Creating… RDF: rdf:type';
COMMENT ON COLUMN events.name IS 'Название. RDF: schema:name @ru';
COMMENT ON COLUMN events.description IS 'Описание. RDF: schema:description @ru';
COMMENT ON COLUMN events.frame IS 'Фрейм FrameNet из спецификации. RDF: kgo:frame → fn:{фрейм}';
COMMENT ON COLUMN events.agent IS 'Кто действует. RDF: schema:agent';
COMMENT ON COLUMN events.object IS 'Над чем. RDF: schema:object';
COMMENT ON COLUMN events.instrument IS 'Чем. RDF: schema:instrument';
COMMENT ON COLUMN events.date_text IS 'Дата словами из текста. RDF: kgo:dateText @ru';
COMMENT ON COLUMN events.factuality IS 'Фактичность: actual… RDF: kgo:factuality → kgc:factuality/{код}';
COMMENT ON COLUMN events.precedes IS 'Какие события следуют. RDF: kgo:precedes';
COMMENT ON COLUMN events.causes IS 'Причина каких событий. RDF: kgo:causes';
COMMENT ON COLUMN events.caused_by IS 'Следствие какого события. RDF: kgo:causedBy';
COMMENT ON COLUMN events.motivated_by IS 'Что побудило — id. RDF: kgo:motivatedBy';
COMMENT ON COLUMN events.discourse_position IS 'Позиция в сюжете: смещение первого упоминания. RDF: kgo:discoursePosition';
COMMENT ON COLUMN events.creates IS 'Что создано (ESO Creating). RDF: eso:creating-theme; ситуации до и после — узлы и графы kgg:situation/habr-1097022/{id}#pre|#post (eso:Situation, kgo:situationOf) с eso:exist false и true';
COMMENT ON COLUMN events.timeline_rank IS 'Выведено (derived-states): место на шкале времени. RDF: kgo:timelineRank';
COMMENT ON COLUMN events.lifecycle_stage IS 'Выведено (derived-creations): стадия жизненного цикла. RDF: kgo:lifecycleStage → kgc:creationstage/{код}';
COMMENT ON COLUMN events.fn_frame IS 'Выведено (derived-framenet): фрейм FrameNet по классу ESO. RDF: kgo:frame → fn:{фрейм}';
COMMENT ON COLUMN events.fn_frame_choice IS 'Выведено (derived-framenet): как выбран фрейм. RDF: kgo:frameChoice → kgc:framechoice/{код}';
COMMENT ON COLUMN events.fn_frame_match IS 'Выведено (derived-framenet): точность соответствия. RDF: kgo:frameMatch → kgc:framematch/{код}';
COMMENT ON COLUMN events.fn_frame_mapping IS 'Выведено (derived-framenet): соответствие ESO — FrameNet. RDF: kgo:frameMapping → kge:{…}';
COMMENT ON COLUMN events.fn_roles IS 'Выведено (derived-framenet): элементы фрейма {"{роль}": "{id}"}. RDF: fe:{роль} {id}';
COMMENT ON COLUMN events.dialog_act IS 'Выведено (derived-dialogue): событие — речевой акт (kgo:CommunicationEvent) с функцией. RDF: kgo:communicativeFunction → kgc:dialogact/{код}';
COMMENT ON COLUMN events.speaker IS 'Выведено (derived-dialogue): говорящий. RDF: kgo:speaker';

CREATE TABLE processes (
    id            text PRIMARY KEY,
    name          text NOT NULL,
    applies_to    text,
    precondition  text,
    result        text,
    process_kind  text
);
COMMENT ON TABLE processes IS
'Фрейм 21 «Процессы» (BBO): раздел processes спецификации — процесс (bbo:Process); шаги — process_steps, '
'переходы — process_flows; bbo:has_flowElements отображение берёт из них';
COMMENT ON COLUMN processes.id IS 'id из спецификации';
COMMENT ON COLUMN processes.name IS 'Название. RDF: bbo:name (строкой) и schema:name @ru';
COMMENT ON COLUMN processes.applies_to IS 'К кому применяется — id. RDF: kgo:appliesTo';
COMMENT ON COLUMN processes.precondition IS 'Предусловие. RDF: kgo:precondition @ru';
COMMENT ON COLUMN processes.result IS 'Результат. RDF: kgo:processResult @ru';
COMMENT ON COLUMN processes.process_kind IS 'Выведено (derived-origins): вид процесса. RDF: kgo:processKind → kgc:processkind/{код}';

CREATE TABLE process_steps (
    process      text NOT NULL,
    step         text NOT NULL,
    type         text NOT NULL,
    name         text NOT NULL,
    uses_tool    text[],
    stack_tools  text[],
    PRIMARY KEY (process, step)
);
COMMENT ON TABLE process_steps IS
'Шаги процесса BBO: узлы {process}.{step} (bbo:StartEvent, Task, ServiceTask, ExclusiveGateway, EndEvent) в '
'процессе (bbo:has_container). Соседей (bbo:has_incoming, has_outgoing, has_previousFlowNode, has_nextFlowNode) '
'отображение берёт из process_flows';
COMMENT ON COLUMN process_steps.process IS 'Процесс — id';
COMMENT ON COLUMN process_steps.step IS 'Код шага в процессе (s0, t1, g1, e1); IRI — {process}.{step}';
COMMENT ON COLUMN process_steps.type IS 'Класс шага: StartEvent, Task, ServiceTask, ExclusiveGateway, EndEvent (bbo:)';
COMMENT ON COLUMN process_steps.name IS 'Название. RDF: bbo:name (строкой) и schema:name @ru';
COMMENT ON COLUMN process_steps.uses_tool IS 'Чем выполняется шаг — id. RDF: kgo:usesTool';
COMMENT ON COLUMN process_steps.stack_tools IS 'Выведено (derived-techstack): компоненты стека на шаге. RDF: kgo:usesTool';

CREATE TABLE process_flows (
    process    text NOT NULL,
    n          integer NOT NULL,
    source     text NOT NULL,
    target     text NOT NULL,
    condition  text,
    PRIMARY KEY (process, n)
);
COMMENT ON TABLE process_flows IS
'Переходы между шагами: узлы {process}.flow{n} (bbo:SequenceFlow; с условием — bbo:ConditionalSequenceFlow и '
'условие {process}.flow{n}-cond, bbo:ConditionExpression)';
COMMENT ON COLUMN process_flows.process IS 'Процесс — id. RDF: bbo:has_container';
COMMENT ON COLUMN process_flows.n IS 'Номер перехода в процессе; IRI — {process}.flow{n}';
COMMENT ON COLUMN process_flows.source IS 'Откуда — код шага. RDF: bbo:has_sourceRef';
COMMENT ON COLUMN process_flows.target IS 'Куда — код шага. RDF: bbo:has_targetRef';
COMMENT ON COLUMN process_flows.condition IS 'Условие перехода из шлюза. RDF: rdfs:label @ru узла условия';

CREATE TABLE claims (
    id        text PRIMARY KEY,
    text      text NOT NULL,
    role      text NOT NULL,
    zone      text NOT NULL,
    author    text,
    supports  text[],
    attacks   text[],
    about     text[]
);
COMMENT ON TABLE claims IS
'Утверждения: раздел claims спецификации — тезисы, доводы, примеры, ограничения (schema:Claim). Выведенные '
'доводы и возражения — в arguments и conflicts';
COMMENT ON COLUMN claims.id IS 'id из спецификации';
COMMENT ON COLUMN claims.text IS 'Текст утверждения. RDF: schema:text @ru';
COMMENT ON COLUMN claims.role IS 'Роль в рассуждении: thesis, argument, example, counterexample, opinion, criticism, limitation… RDF: kgo:claimRole → kgc:claim/{код}';
COMMENT ON COLUMN claims.zone IS 'Риторическая зона: problem, method, result, discussion, limitation, conclusion. RDF: kgo:rhetoricalZone → kgc:rhetoricalzone/{код}';
COMMENT ON COLUMN claims.author IS 'Чьё утверждение, если не автора статьи — id. RDF: schema:author';
COMMENT ON COLUMN claims.supports IS 'Какие утверждения поддерживает. RDF: kgo:supports';
COMMENT ON COLUMN claims.attacks IS 'Какие утверждения опровергает. RDF: kgo:attacks';
COMMENT ON COLUMN claims.about IS 'О чём: id сущностей, понятий, наблюдений. RDF: schema:about';

CREATE TABLE quotations (
    id             text PRIMARY KEY,
    speaker        text NOT NULL,
    addressees     text[],
    speech_act     text,
    stance         text,
    stance_target  text,
    text           text NOT NULL,
    description    text,
    about          text[],
    dialogue       text,
    turn_index     integer,
    responds_to    text,
    answers        text
);
COMMENT ON TABLE quotations IS
'Фрейм 24 «Речь»: реплики спора автора со знакомым архитектором (schema:Quotation, часть статьи — schema:isPartOf)';
COMMENT ON COLUMN quotations.id IS 'id реплики: rep01…';
COMMENT ON COLUMN quotations.speaker IS 'Кто говорит — id. RDF: schema:creator и schema:spokenByCharacter';
COMMENT ON COLUMN quotations.addressees IS 'Кому — id. RDF: kgo:addressee';
COMMENT ON COLUMN quotations.speech_act IS 'Речевой акт: question, directive, assertive, expressive, commissive. RDF: kgo:speechAct → kgc:speechact/{код}';
COMMENT ON COLUMN quotations.stance IS 'Позиция говорящего: disagree, agree, irony. RDF: kgo:stance → kgc:stance/{код}';
COMMENT ON COLUMN quotations.stance_target IS 'К какой реплике позиция. RDF: kgo:stanceTarget';
COMMENT ON COLUMN quotations.text IS 'Реплика (дословный фрагмент). RDF: schema:text @ru';
COMMENT ON COLUMN quotations.description IS 'Роль реплики в споре. RDF: schema:description @ru';
COMMENT ON COLUMN quotations.about IS 'О чём реплика: id технического слоя. RDF: schema:about';
COMMENT ON COLUMN quotations.dialogue IS 'Выведено (derived-dialogue): диалог — ключ. RDF: kgo:inDialogue';
COMMENT ON COLUMN quotations.turn_index IS 'Выведено (derived-dialogue): номер хода в диалоге. RDF: kgo:turnIndex';
COMMENT ON COLUMN quotations.responds_to IS 'Выведено (derived-dialogue): на какую реплику отвечает. RDF: kgo:respondsTo';
COMMENT ON COLUMN quotations.answers IS 'Выведено (derived-dialogue): на какой вопрос отвечает. RDF: kgo:answers';

CREATE TABLE attitudes (
    id               text PRIMARY KEY,
    holder           text NOT NULL,
    type             text NOT NULL,
    target           text,
    target_text      text,
    name             text,
    description      text,
    affect_class     text,
    affect_kind      text,
    valence          text,
    outcome_key      text,
    outcome_event    text,
    outcome_status   text,
    outcome_verdict  text
);
COMMENT ON TABLE attitudes IS
'Установки (ментальные состояния): раздел attitudes спецификации — чья, какая, к чему (kgo:Attitude)';
COMMENT ON COLUMN attitudes.id IS 'id из спецификации';
COMMENT ON COLUMN attitudes.holder IS 'Чья установка — id. RDF: kgo:holder';
COMMENT ON COLUMN attitudes.type IS 'Вид: belief, trust… RDF: kgo:attitudeType → kgc:attitude/{код}';
COMMENT ON COLUMN attitudes.target IS 'К чему — узел. RDF: kgo:attitudeTarget';
COMMENT ON COLUMN attitudes.target_text IS 'К чему — словами. RDF: kgo:attitudeTarget @ru';
COMMENT ON COLUMN attitudes.name IS 'Название. RDF: schema:name @ru';
COMMENT ON COLUMN attitudes.description IS 'Описание. RDF: schema:description @ru';
COMMENT ON COLUMN attitudes.affect_class IS 'Выведено (derived-affect): CognitiveAttitude или AffectiveDisposition (kgo:). RDF: rdf:type';
COMMENT ON COLUMN attitudes.affect_kind IS 'Выведено (derived-affect): вид аффекта. RDF: kgo:affectKind → kgc:affectkind/{код}';
COMMENT ON COLUMN attitudes.valence IS 'Выведено (derived-emotions): знак. RDF: kgo:valence → kgc:valence/{код}';
COMMENT ON COLUMN attitudes.outcome_key IS 'Выведено (derived-outcomes): итог установки outcome/{ключ} (kgo:AttitudeOutcome): kgo:intention — установка, kgo:intentionKind «attitude:{type}», schema:name — description';
COMMENT ON COLUMN attitudes.outcome_event IS 'Выведено (derived-outcomes): событие-итог — id. RDF: kgo:outcomeEvent';
COMMENT ON COLUMN attitudes.outcome_status IS 'Выведено (derived-outcomes): статус. RDF: kgo:outcomeStatus → kgc:outcome/{код}';
COMMENT ON COLUMN attitudes.outcome_verdict IS 'Выведено (derived-outcomes): вердикт. RDF: kgo:outcomeVerdict → kgc:outcome/{код}';

CREATE TABLE narratives (
    id                   text PRIMARY KEY,
    name                 text NOT NULL,
    description          text,
    type                 text,
    factuality           text,
    told_by              text,
    characters           text[],
    moral                text,
    level                integer,
    span_start           integer,
    span_end             integer,
    inset_class          text,
    diegetic_level       integer,
    diegetic_level_kind  text,
    audience_kind        text,
    narrator_kind        text,
    narrator_basis       text,
    purpose              text
);
COMMENT ON TABLE narratives IS
'Вложенные рассказы: раздел narratives спецификации (kgo:EmbeddedNarrative) — здесь рамка статьи, спор автора '
'со знакомым архитектором. Колонки вставного рассказа — выведенный фрейм derived-insets';
COMMENT ON COLUMN narratives.id IS 'id из спецификации';
COMMENT ON COLUMN narratives.name IS 'Название. RDF: schema:name @ru';
COMMENT ON COLUMN narratives.description IS 'Описание. RDF: schema:description @ru';
COMMENT ON COLUMN narratives.type IS 'Вид рассказа: anecdote… RDF: kgo:narrativeType → kgc:narrative/{код}';
COMMENT ON COLUMN narratives.factuality IS 'Фактичность. RDF: kgo:factuality → kgc:factuality/{код}';
COMMENT ON COLUMN narratives.told_by IS 'Рассказчик — id. RDF: kgo:toldBy';
COMMENT ON COLUMN narratives.characters IS 'Персонажи — id. RDF: schema:character';
COMMENT ON COLUMN narratives.moral IS 'Мораль — id утверждения. RDF: kgo:moral';
COMMENT ON COLUMN narratives.level IS 'Уровень вложенности. RDF: kgo:narrativeLevel';
COMMENT ON COLUMN narratives.span_start IS 'Начало рассказа в символах текста. RDF: oa:start селектора промежутка kgo:textSpan';
COMMENT ON COLUMN narratives.span_end IS 'Конец рассказа в символах текста. RDF: oa:end';
COMMENT ON COLUMN narratives.inset_class IS 'Выведено (derived-insets): класс вставного рассказа: InsetAnecdote… RDF: rdf:type kgo:Inset и kgo:{класс}';
COMMENT ON COLUMN narratives.diegetic_level IS 'Выведено (derived-insets): степень по Женетту. RDF: kgo:diegeticLevel';
COMMENT ON COLUMN narratives.diegetic_level_kind IS 'Выведено (derived-insets): RDF: kgo:diegeticLevelKind → kgc:diegeticlevel/{код}';
COMMENT ON COLUMN narratives.audience_kind IS 'Выведено (derived-insets): кому рассказано. RDF: kgo:insetAudienceKind → kgc:insetaudience/{код}';
COMMENT ON COLUMN narratives.narrator_kind IS 'Выведено (derived-insets): кто рассказывает. RDF: kgo:insetNarratorKind → kgc:insetnarrator/{код}';
COMMENT ON COLUMN narratives.narrator_basis IS 'Выведено (derived-insets): как найден рассказчик. RDF: kgo:insetNarratorBasis → kgc:insetbasis/{код}';
COMMENT ON COLUMN narratives.purpose IS 'Выведено (derived-insets): зачем рассказ. RDF: kgo:insetPurpose → kgc:insetpurpose/{код}';

CREATE TABLE observations (
    id                  text PRIMARY KEY,
    variable            text NOT NULL,
    value               numeric,
    value_range         text,
    unit                text,
    condition           text,
    dataset             text,
    about               text[],
    unit_code           text,
    quantity_kind       text,
    base_unit           text,
    value_in_base_unit  numeric,
    min_value           numeric,
    max_value           numeric,
    min_in_base_unit    numeric,
    max_in_base_unit    numeric,
    carriers            text[],
    carrier_basis       text,
    observed_property   text,
    property_basis      text,
    count_noun          text,
    CHECK (value IS NOT NULL OR value_range IS NOT NULL)
);
COMMENT ON TABLE observations IS
'Наблюдения и измерения: раздел observations спецификации — числа статьи (schema:Observation, '
'schema:QuantitativeValue): что, сколько, в чём, при каких условиях. Выведенные колонки — единицы и величины '
'(derived-quantities)';
COMMENT ON COLUMN observations.id IS 'id из спецификации';
COMMENT ON COLUMN observations.variable IS 'Что измерено. RDF: schema:variableMeasured и schema:name @ru';
COMMENT ON COLUMN observations.value IS 'Число. RDF: schema:value — xsd:integer у целых, xsd:double у дробных';
COMMENT ON COLUMN observations.value_range IS 'Значение-диапазон как в тексте («51-86»). RDF: schema:value @ru';
COMMENT ON COLUMN observations.unit IS 'Единица как в тексте: мс, с, %, раз. RDF: schema:unitText @ru';
COMMENT ON COLUMN observations.condition IS 'Условия: система, планировщик, хранилище, запрос. RDF: kgo:conditionText @ru';
COMMENT ON COLUMN observations.dataset IS 'Набор измерений — id из поля dataset спецификации; карточка набора — в datasets (у набора из одного наблюдения её нет, поэтому внешнего ключа нет). RDF: qb:dataSet в графе статьи и в derived-experiments (там же rdf:type qb:Observation)';
COMMENT ON COLUMN observations.about IS 'О чём — id. RDF: schema:observationAbout';
COMMENT ON COLUMN observations.unit_code IS 'Выведено (derived-quantities): единица по словарю: millisecond, percent… RDF: kgo:unit → kgc:unit/{код}';
COMMENT ON COLUMN observations.quantity_kind IS 'Выведено (derived-quantities): род величины: time, ratio… RDF: kgo:quantityKind → kgc:quantitykind/{код}';
COMMENT ON COLUMN observations.base_unit IS 'Выведено (derived-quantities): базовая единица. RDF: kgo:baseUnit → kgc:unit/{код}';
COMMENT ON COLUMN observations.value_in_base_unit IS 'Выведено (derived-quantities): значение в базовой единице. RDF: kgo:valueInBaseUnit';
COMMENT ON COLUMN observations.min_value IS 'Выведено (derived-quantities): нижняя граница диапазона. RDF: schema:minValue';
COMMENT ON COLUMN observations.max_value IS 'Выведено (derived-quantities): верхняя граница диапазона. RDF: schema:maxValue';
COMMENT ON COLUMN observations.min_in_base_unit IS 'Выведено (derived-quantities): нижняя граница в базовой единице. RDF: kgo:minValueInBaseUnit';
COMMENT ON COLUMN observations.max_in_base_unit IS 'Выведено (derived-quantities): верхняя граница в базовой единице. RDF: kgo:maxValueInBaseUnit';
COMMENT ON COLUMN observations.carriers IS 'Выведено (derived-quantities): носители величины — id. RDF: kgo:carrier';
COMMENT ON COLUMN observations.carrier_basis IS 'Выведено (derived-quantities): по какому полю найдены носители. RDF: kgo:carrierBasis';
COMMENT ON COLUMN observations.observed_property IS 'Выведено (derived-quantities): измеряемое свойство — id. RDF: kgo:observedProperty';
COMMENT ON COLUMN observations.property_basis IS 'Выведено (derived-quantities): как найдено свойство. RDF: kgo:propertyBasis';
COMMENT ON COLUMN observations.count_noun IS 'Выведено (derived-quantities): что считается. RDF: kgo:countNoun @ru';

-- ============================================================== слой выведенных фреймов: графы kgg:derived-*

CREATE TABLE datasets (
    id                 text PRIMARY KEY,
    types              text[] NOT NULL,
    name               text NOT NULL,
    measure            text,
    condition          text,
    units              text[],
    series_kind        text,
    subjects           text[],
    section            text,
    observation_count  integer,
    best_observation   text,
    better_is          text
);
COMMENT ON TABLE datasets IS
'Выведенный фрейм «Эксперименты» (derived-experiments): наблюдения одной величины — набор измерений (qb:DataSet, '
'kgo:MeasurementSet; сравнение — kgo:Experiment, kgo:Benchmark). Узел {id}; наблюдения ссылаются на него '
'qb:dataSet, он на них — prov:wasDerivedFrom';
COMMENT ON COLUMN datasets.id IS 'id из поля dataset спецификации';
COMMENT ON COLUMN datasets.types IS 'Классы (qname). RDF: rdf:type';
COMMENT ON COLUMN datasets.name IS 'Название. RDF: schema:name @ru';
COMMENT ON COLUMN datasets.measure IS 'Измеряемая величина. RDF: kgo:measureLabel @ru';
COMMENT ON COLUMN datasets.condition IS 'Контекст набора. RDF: kgo:conditionText @ru';
COMMENT ON COLUMN datasets.units IS 'Единицы. RDF: schema:unitText';
COMMENT ON COLUMN datasets.series_kind IS 'Что меняется: comparison (объект), conditions (условие), timeline (дата). RDF: kgo:seriesKind → kgc:series/{код}';
COMMENT ON COLUMN datasets.subjects IS 'Что испытывается — id. RDF: kgo:subjectUnderTest';
COMMENT ON COLUMN datasets.section IS 'Раздел статьи. RDF: kgo:contextSection';
COMMENT ON COLUMN datasets.observation_count IS 'Наблюдений в наборе. RDF: kgo:observationCount';
COMMENT ON COLUMN datasets.best_observation IS 'Лучшее наблюдение — id. RDF: kgo:bestObservation';
COMMENT ON COLUMN datasets.better_is IS 'Что лучше: lower или higher. RDF: kgo:betterIs';

CREATE TABLE dialogues (
    key           text PRIMARY KEY,
    name          text NOT NULL,
    section       text,
    participants  text[],
    turn_count    integer
);
COMMENT ON TABLE dialogues IS
'Выведенный фрейм «Диалог» (derived-dialogue): подряд идущие реплики раздела с чередованием говорящих '
'(kgo:Dialogue, узлы dialogue/{key}); реплики ссылаются на диалог kgo:inDialogue, он на них — prov:wasDerivedFrom';
COMMENT ON COLUMN dialogues.key IS 'Ключ узла: 12 знаков SHA-1. IRI — dialogue/{key}';
COMMENT ON COLUMN dialogues.name IS 'Название. RDF: schema:name @ru';
COMMENT ON COLUMN dialogues.section IS 'Раздел. RDF: kgo:contextSection';
COMMENT ON COLUMN dialogues.participants IS 'Участники — id. RDF: kgo:dialogueParticipant';
COMMENT ON COLUMN dialogues.turn_count IS 'Ходов. RDF: kgo:turnCount';

CREATE TABLE arguments (
    key           text PRIMARY KEY,
    name          text NOT NULL,
    conclusion    text NOT NULL,
    premises      text[] NOT NULL,
    premise_role  text
);
COMMENT ON TABLE arguments IS
'Выведенный фрейм «Аргументы» (derived-arguments): довод — вывод и посылки (kgo:Argument, узлы argument/{key}, '
'часть карты аргументации статьи — schema:isPartOf argument-map)';
COMMENT ON COLUMN arguments.key IS 'Ключ узла: 12 знаков SHA-1. IRI — argument/{key}';
COMMENT ON COLUMN arguments.name IS 'Название. RDF: schema:name @ru';
COMMENT ON COLUMN arguments.conclusion IS 'Вывод — id утверждения. RDF: kgo:conclusion';
COMMENT ON COLUMN arguments.premises IS 'Посылки — id утверждений. RDF: kgo:premise';
COMMENT ON COLUMN arguments.premise_role IS 'Роль посылок. RDF: kgo:premiseRole → kgc:claim/{код}';

CREATE TABLE conflicts (
    key          text PRIMARY KEY,
    attacked     text NOT NULL,
    attacker     text NOT NULL,
    rebutted     boolean,
    verdict      text,
    name         text NOT NULL,
    review_name  text
);
COMMENT ON TABLE conflicts IS
'Выведенные фреймы «Аргументы» и «Достоверность» (derived-arguments, derived-credibility): возражение — '
'утверждение, опровергающее другое (kgo:Conflict, conflict/{key}), и оценка опровергнутого (schema:ClaimReview, '
'review/{key})';
COMMENT ON COLUMN conflicts.key IS 'Ключ обоих узлов: 12 знаков SHA-1';
COMMENT ON COLUMN conflicts.attacked IS 'Опровергаемое утверждение — id. RDF: kgo:conflictedClaim; у оценки — schema:itemReviewed';
COMMENT ON COLUMN conflicts.attacker IS 'Опровергающее утверждение — id. RDF: kgo:conflictingClaim; у оценки — kgo:reviewingClaim';
COMMENT ON COLUMN conflicts.rebutted IS 'Возражение отбито. RDF: kgo:attackRebutted';
COMMENT ON COLUMN conflicts.verdict IS 'Вердикт оценки: disputed… RDF: kgo:verdict → kgc:verdict/{код}, граф derived-credibility';
COMMENT ON COLUMN conflicts.name IS 'Название возражения. RDF: schema:name @ru';
COMMENT ON COLUMN conflicts.review_name IS 'Название оценки. RDF: schema:name @ru, граф derived-credibility';

CREATE TABLE style_keywords (
    key             text PRIMARY KEY,
    rank            integer NOT NULL,
    lemma           text NOT NULL,
    count           integer,
    log_likelihood  numeric
);
COMMENT ON TABLE style_keywords IS
'Выведенный фрейм «Стилометрия» (derived-stylometry): ключевые слова статьи по логарифму правдоподобия '
'(kgo:StyleKeyword, узлы style/{article.style_key}/kw/{key}); профиль стиля — колонки style_… в article';
COMMENT ON COLUMN style_keywords.key IS 'Ключ узла: 12 знаков SHA-1';
COMMENT ON COLUMN style_keywords.rank IS 'Место в списке. RDF: kgo:keywordRank';
COMMENT ON COLUMN style_keywords.lemma IS 'Слово (лемма). RDF: kgo:keywordLemma @ru';
COMMENT ON COLUMN style_keywords.count IS 'Сколько раз в тексте. RDF: kgo:keywordCount';
COMMENT ON COLUMN style_keywords.log_likelihood IS 'Логарифм правдоподобия. RDF: kgo:keywordLogLikelihood';

CREATE TABLE methods (
    key         text PRIMARY KEY,
    name        text NOT NULL,
    concept     text,
    procedure   text,
    kind        text,
    confidence  numeric,
    section     text
);
COMMENT ON TABLE methods IS
'Выведенный фрейм «Методы» (derived-methods, derived-contributions): карточка метода (kgo:Method, method/{key}) — '
'из понятия вида «метод» или из процесса без такого понятия; польза метода (kgo:benefit) — из contributions его '
'понятия';
COMMENT ON COLUMN methods.key IS 'Ключ узла: 12 знаков SHA-1. IRI — method/{key}';
COMMENT ON COLUMN methods.name IS 'Название. RDF: schema:name @ru';
COMMENT ON COLUMN methods.concept IS 'Понятие метода — id. RDF: kgo:methodConcept';
COMMENT ON COLUMN methods.procedure IS 'Процедура — id процесса. RDF: kgo:hasProcedure';
COMMENT ON COLUMN methods.kind IS 'Вид. RDF: kgo:methodKind → kgc:conceptkind/{код}';
COMMENT ON COLUMN methods.confidence IS 'Уверенность правила. RDF: kgo:confidence';
COMMENT ON COLUMN methods.section IS 'Раздел. RDF: kgo:contextSection';

CREATE TABLE passages (
    key      text PRIMARY KEY,
    section  text NOT NULL,
    mode     text NOT NULL,
    blocks   integer,
    chars    integer
);
COMMENT ON TABLE passages IS
'Выведенный фрейм «Фрагменты» (derived-passages): часть раздела с одним режимом изложения (kgo:Passage, '
'kgo:ModePassage; узлы passage/{key})';
COMMENT ON COLUMN passages.key IS 'Ключ узла: 12 знаков SHA-1. IRI — passage/{key}';
COMMENT ON COLUMN passages.section IS 'Раздел. RDF: kgo:passageSection и prov:wasDerivedFrom';
COMMENT ON COLUMN passages.mode IS 'Режим изложения. RDF: kgo:discourseMode → kgc:discoursemode/{код}';
COMMENT ON COLUMN passages.blocks IS 'Абзацев. RDF: kgo:passageBlocks';
COMMENT ON COLUMN passages.chars IS 'Символов. RDF: kgo:passageChars';

CREATE TABLE media (
    kind       text NOT NULL,
    key        text NOT NULL,
    types      text[] NOT NULL,
    name       text,
    url        text NOT NULL,
    link_kind  text,
    section    text,
    PRIMARY KEY (kind, key)
);
COMMENT ON TABLE media IS
'Выведенный фрейм «Ссылки и медиа» (derived-media): ссылки статьи (link/{key}: репозитории, статьи; '
'kgo:linkedFrom — статья) и картинки (image/{key}; schema:isPartOf — статья)';
COMMENT ON COLUMN media.kind IS 'link или image — первая часть IRI';
COMMENT ON COLUMN media.key IS 'Ключ узла: 12 знаков SHA-1';
COMMENT ON COLUMN media.types IS 'Классы (qname). RDF: rdf:type';
COMMENT ON COLUMN media.name IS 'Текст ссылки. RDF: schema:name @ru';
COMMENT ON COLUMN media.url IS 'Адрес. RDF: schema:url; у картинки — schema:contentUrl';
COMMENT ON COLUMN media.link_kind IS 'Вид ссылки: repository, article… RDF: kgo:linkKind → kgc:link/{код}';
COMMENT ON COLUMN media.section IS 'Раздел. RDF: kgo:contextSection';

CREATE TABLE code_listings (
    n           integer PRIMARY KEY,
    name        text NOT NULL,
    language    text,
    line_count  integer,
    section     text,
    process     text,
    step        text,
    step_basis  text,
    start_pos   integer,
    end_pos     integer
);
COMMENT ON TABLE code_listings IS
'Выведенный фрейм «Код» (derived-code): блоки кода статьи (schema:SoftwareSourceCode, узлы code/{n} с промежутком '
'текста code/{n}#span) и шаг процесса, который они показывают';
COMMENT ON COLUMN code_listings.n IS 'Номер блока кода в статье. IRI — code/{n}';
COMMENT ON COLUMN code_listings.name IS 'Название. RDF: schema:name @ru';
COMMENT ON COLUMN code_listings.language IS 'Язык. RDF: schema:programmingLanguage';
COMMENT ON COLUMN code_listings.line_count IS 'Строк. RDF: kgo:codeLineCount';
COMMENT ON COLUMN code_listings.section IS 'Раздел. RDF: schema:isPartOf';
COMMENT ON COLUMN code_listings.process IS 'Процесс шага — id';
COMMENT ON COLUMN code_listings.step IS 'Шаг, который показывает код. RDF: kgo:codeOfStep; у шага — kgo:stepCode';
COMMENT ON COLUMN code_listings.step_basis IS 'Как найден шаг. RDF: kgo:stepCodeBasis';
COMMENT ON COLUMN code_listings.start_pos IS 'Начало блока в символах текста. RDF: oa:start';
COMMENT ON COLUMN code_listings.end_pos IS 'Конец блока в символах текста. RDF: oa:end';

CREATE TABLE discourse_relations (
    key         text PRIMARY KEY,
    name        text NOT NULL,
    sense       text NOT NULL,
    connective  text,
    scope       text,
    section     text,
    arg1_claim  text,
    arg1_start  integer,
    arg1_end    integer,
    arg2_claim  text,
    arg2_start  integer,
    arg2_end    integer
);
COMMENT ON TABLE discourse_relations IS
'Выведенный фрейм «Связи дискурса» (derived-discourse): связка двух частей текста — причина, следствие '
'(kgo:DiscourseRelation и kgo:Discourse{Sense}, узлы discourse/{key})';
COMMENT ON COLUMN discourse_relations.key IS 'Ключ узла: 12 знаков SHA-1. IRI — discourse/{key}';
COMMENT ON COLUMN discourse_relations.name IS 'Название. RDF: schema:name @ru';
COMMENT ON COLUMN discourse_relations.sense IS 'Смысл связи: result, reason… RDF: kgo:discourseSense → kgc:discourserelation/{код}';
COMMENT ON COLUMN discourse_relations.connective IS 'Связка: поэтому, потому что… RDF: kgo:discourseConnective @ru';
COMMENT ON COLUMN discourse_relations.scope IS 'Внутри предложения или между ними. RDF: kgo:discourseScope → kgc:discoursescope/{код}';
COMMENT ON COLUMN discourse_relations.section IS 'Раздел. RDF: schema:isPartOf и prov:wasDerivedFrom';
COMMENT ON COLUMN discourse_relations.arg1_claim IS 'Утверждение первой части — id. RDF: kgo:discourseArg1Claim';
COMMENT ON COLUMN discourse_relations.arg1_start IS 'Начало первой части. RDF: kgo:discourseArg1Start';
COMMENT ON COLUMN discourse_relations.arg1_end IS 'Конец первой части. RDF: kgo:discourseArg1End';
COMMENT ON COLUMN discourse_relations.arg2_claim IS 'Утверждение второй части — id. RDF: kgo:discourseArg2Claim';
COMMENT ON COLUMN discourse_relations.arg2_start IS 'Начало второй части. RDF: kgo:discourseArg2Start';
COMMENT ON COLUMN discourse_relations.arg2_end IS 'Конец второй части. RDF: kgo:discourseArg2End';

CREATE TABLE idea_links (
    key     text PRIMARY KEY,
    name    text NOT NULL,
    object  text NOT NULL,
    person  text NOT NULL,
    kind    text NOT NULL,
    role    text,
    stance  text,
    year    integer,
    basis   text
);
COMMENT ON TABLE idea_links IS
'Выведенный фрейм «Идеи» (derived-ideas): кто автор идеи, произведения или кода (kgo:IdeaLink и kgo:Idea{Kind}, '
'узлы idea/{key}); объект получает prov:qualifiedAttribution и prov:wasAttributedTo';
COMMENT ON COLUMN idea_links.key IS 'Ключ узла: 12 знаков SHA-1. IRI — idea/{key}';
COMMENT ON COLUMN idea_links.name IS 'Название. RDF: schema:name @ru';
COMMENT ON COLUMN idea_links.object IS 'Идея, произведение, код — id. RDF: kgo:ideaObject и prov:wasDerivedFrom';
COMMENT ON COLUMN idea_links.person IS 'Чья — id. RDF: kgo:ideaPerson и prov:agent';
COMMENT ON COLUMN idea_links.kind IS 'Вид связи: origin… RDF: kgo:ideaKind → kgc:ideakind/{код}';
COMMENT ON COLUMN idea_links.role IS 'Роль человека: authored… RDF: kgo:ideaRole и prov:hadRole → kgc:idearole/{код}';
COMMENT ON COLUMN idea_links.stance IS 'Как текст говорит об идее: cites… RDF: kgo:ideaStance → kgc:ideastance/{код}';
COMMENT ON COLUMN idea_links.year IS 'Год. RDF: kgo:ideaYear (xsd:gYear)';
COMMENT ON COLUMN idea_links.basis IS 'Основание. RDF: kgo:ideaBasis → kgc:ideabasis/{код}';

CREATE TABLE theme_links (
    key      text PRIMARY KEY,
    name     text NOT NULL,
    subject  text NOT NULL,
    theme    text NOT NULL,
    matched  text,
    basis    text
);
COMMENT ON TABLE theme_links IS
'Выведенный фрейм «Темы» (derived-themes): привязка статьи, её тем и понятий к рубрикам тем Story-KG '
'(kgo:ThemeLink, kgo:ThemeLinkTopic; узлы themelink/{key}); субъект получает skos:broadMatch рубрики';
COMMENT ON COLUMN theme_links.key IS 'Ключ узла: 12 знаков SHA-1. IRI — themelink/{key}';
COMMENT ON COLUMN theme_links.name IS 'Название. RDF: schema:name @ru';
COMMENT ON COLUMN theme_links.subject IS 'Что привязано: work, theme/{slug} или id понятия. RDF: kgo:themeSubject и prov:wasDerivedFrom';
COMMENT ON COLUMN theme_links.theme IS 'Рубрика тем Story-KG: databases… RDF: kgo:themeValue → kgc:theme/{код}';
COMMENT ON COLUMN theme_links.matched IS 'По какому слову найдено. RDF: kgo:themeMatched @ru';
COMMENT ON COLUMN theme_links.basis IS 'Основание: name, keyword. RDF: kgo:themeBasis → kgc:themebasis/{код}';

CREATE TABLE copresence (
    key         text PRIMARY KEY,
    name        text NOT NULL,
    persons     text[] NOT NULL,
    talks       text[],
    talk_count  integer,
    kind        text,
    basis       text
);
COMMENT ON TABLE copresence IS
'Выведенный фрейм «Совместное присутствие» (derived-copresence): кто с кем встречается в тексте (kgo:CoPresence, '
'kgo:PersonCoPresence; узлы copresence/{key}); люди получают kgo:coPresentWith';
COMMENT ON COLUMN copresence.key IS 'Ключ узла: 12 знаков SHA-1. IRI — copresence/{key}';
COMMENT ON COLUMN copresence.name IS 'Название. RDF: schema:name @ru';
COMMENT ON COLUMN copresence.persons IS 'Кто — id. RDF: kgo:coPresent';
COMMENT ON COLUMN copresence.talks IS 'В каких репликах вместе — id. RDF: kgo:coPresentInTalk и prov:wasDerivedFrom';
COMMENT ON COLUMN copresence.talk_count IS 'Реплик. RDF: kgo:coPresentTalkCount';
COMMENT ON COLUMN copresence.kind IS 'Вид. RDF: kgo:coPresenceKind → kgc:copresencekind/{код}';
COMMENT ON COLUMN copresence.basis IS 'Основание: conversation… RDF: kgo:coPresenceBasis → kgc:copresencebasis/{код}';

CREATE TABLE state_spans (
    key               text PRIMARY KEY,
    name              text NOT NULL,
    entity            text NOT NULL,
    kind              text NOT NULL,
    span_index        integer,
    started_by        text,
    first_attested_by text,
    last_attested_by  text,
    from_rank         integer,
    to_rank           integer
);
COMMENT ON TABLE state_spans IS
'Выведенный фрейм «Состояния» (derived-states): промежуток сюжета, когда сущность существует или пребывает в '
'состоянии (kgo:StateSpan и kgo:ExistenceSpan; узлы state/{key})';
COMMENT ON COLUMN state_spans.key IS 'Ключ узла: 12 знаков SHA-1. IRI — state/{key}';
COMMENT ON COLUMN state_spans.name IS 'Название. RDF: schema:name @ru';
COMMENT ON COLUMN state_spans.entity IS 'Чьё состояние — id. RDF: kgo:stateOf';
COMMENT ON COLUMN state_spans.kind IS 'Вид: existence… RDF: kgo:spanKind → kgc:statekind/{код}';
COMMENT ON COLUMN state_spans.span_index IS 'Номер промежутка у сущности. RDF: kgo:spanIndex';
COMMENT ON COLUMN state_spans.started_by IS 'Событие начала — id. RDF: kgo:startedBy и prov:wasDerivedFrom';
COMMENT ON COLUMN state_spans.first_attested_by IS 'Первое событие, где состояние видно. RDF: kgo:firstAttestedBy';
COMMENT ON COLUMN state_spans.last_attested_by IS 'Последнее такое событие. RDF: kgo:lastAttestedBy';
COMMENT ON COLUMN state_spans.from_rank IS 'С какого места шкалы времени. RDF: kgo:fromRank';
COMMENT ON COLUMN state_spans.to_rank IS 'По какое место. RDF: kgo:toRank';

CREATE TABLE terms (
    slug           text PRIMARY KEY,
    name           text NOT NULL,
    denotes        text,
    mention_count  integer
);
COMMENT ON TABLE terms IS
'Выведенный фрейм «Терминология» (derived-terminology): термины словаря техники в тексте (schema:DefinedTerm, '
'узлы term/{slug}) словаря glossary статьи; первое упоминание — в evidence';
COMMENT ON COLUMN terms.slug IS 'Код термина. IRI — term/{slug}';
COMMENT ON COLUMN terms.name IS 'Термин. RDF: schema:name @ru';
COMMENT ON COLUMN terms.denotes IS 'Понятие словаря техники. RDF: kgt:denotes → kgc:tech/{код}';
COMMENT ON COLUMN terms.mention_count IS 'Сколько раз в тексте. RDF: kgo:mentionCount';

CREATE TABLE concept_links (
    key         text PRIMARY KEY,
    name        text NOT NULL,
    concept     text NOT NULL,
    global      text NOT NULL,
    kind        text NOT NULL,
    basis       text,
    cue         text,
    confidence  numeric,
    method      text
);
COMMENT ON TABLE concept_links IS
'Выведенный фрейм «Связи понятий» (derived-conceptlinks): понятие статьи и глобальное понятие — синонимы '
'(kgo:ConceptLink и kgo:ConceptLink{Kind}, rdf:Statement; узлы conceptlink/{key}); kgo:conceptSynonymOf — в обе '
'стороны';
COMMENT ON COLUMN concept_links.key IS 'Ключ узла: 12 знаков SHA-1. IRI — conceptlink/{key}';
COMMENT ON COLUMN concept_links.name IS 'Название. RDF: schema:name @ru';
COMMENT ON COLUMN concept_links.concept IS 'Понятие статьи — id. RDF: rdf:subject';
COMMENT ON COLUMN concept_links.global IS 'Глобальное понятие kge:{global}. RDF: rdf:object';
COMMENT ON COLUMN concept_links.kind IS 'Вид связи: synonym… RDF: kgo:conceptLinkKind → kgc:conceptlink/{код}';
COMMENT ON COLUMN concept_links.basis IS 'Основание. RDF: kgo:conceptLinkBasis';
COMMENT ON COLUMN concept_links.cue IS 'Подсказка правила. RDF: kgo:conceptLinkCue';
COMMENT ON COLUMN concept_links.confidence IS 'Уверенность. RDF: kgo:confidence';
COMMENT ON COLUMN concept_links.method IS 'Способ. RDF: kgo:extractionMethod';

-- ============================================================== связи (внешние ключи) там, где цель одна

ALTER TABLE article       ADD FOREIGN KEY (author)        REFERENCES entities (id);
ALTER TABLE sections      ADD FOREIGN KEY (parent)        REFERENCES sections (id);
ALTER TABLE sections      ADD FOREIGN KEY (main_claim)    REFERENCES claims (id);
ALTER TABLE evidence      ADD FOREIGN KEY (section)       REFERENCES sections (id);
ALTER TABLE entities      ADD FOREIGN KEY (author)        REFERENCES entities (id);
ALTER TABLE concepts      ADD FOREIGN KEY (procedure)     REFERENCES processes (id);
ALTER TABLE contributions ADD FOREIGN KEY (concept)       REFERENCES concepts (id);
ALTER TABLE events        ADD FOREIGN KEY (agent)         REFERENCES entities (id);
ALTER TABLE events        ADD FOREIGN KEY (speaker)       REFERENCES entities (id);
ALTER TABLE processes     ADD FOREIGN KEY (applies_to)    REFERENCES entities (id);
ALTER TABLE process_steps ADD FOREIGN KEY (process)       REFERENCES processes (id);
ALTER TABLE process_flows ADD FOREIGN KEY (process, source) REFERENCES process_steps (process, step);
ALTER TABLE process_flows ADD FOREIGN KEY (process, target) REFERENCES process_steps (process, step);
ALTER TABLE claims        ADD FOREIGN KEY (author)        REFERENCES entities (id);
ALTER TABLE quotations    ADD FOREIGN KEY (speaker)       REFERENCES entities (id);
ALTER TABLE quotations    ADD FOREIGN KEY (stance_target) REFERENCES quotations (id);
ALTER TABLE quotations    ADD FOREIGN KEY (responds_to)   REFERENCES quotations (id);
ALTER TABLE quotations    ADD FOREIGN KEY (answers)       REFERENCES quotations (id);
ALTER TABLE quotations    ADD FOREIGN KEY (dialogue)      REFERENCES dialogues (key);
ALTER TABLE attitudes     ADD FOREIGN KEY (holder)        REFERENCES entities (id);
ALTER TABLE attitudes     ADD FOREIGN KEY (outcome_event) REFERENCES events (id);
ALTER TABLE narratives    ADD FOREIGN KEY (told_by)       REFERENCES entities (id);
ALTER TABLE narratives    ADD FOREIGN KEY (moral)         REFERENCES claims (id);
ALTER TABLE datasets      ADD FOREIGN KEY (section)       REFERENCES sections (id);
ALTER TABLE datasets      ADD FOREIGN KEY (best_observation) REFERENCES observations (id);
ALTER TABLE dialogues     ADD FOREIGN KEY (section)       REFERENCES sections (id);
ALTER TABLE arguments     ADD FOREIGN KEY (conclusion)    REFERENCES claims (id);
ALTER TABLE conflicts     ADD FOREIGN KEY (attacked)      REFERENCES claims (id);
ALTER TABLE conflicts     ADD FOREIGN KEY (attacker)      REFERENCES claims (id);
ALTER TABLE methods       ADD FOREIGN KEY (concept)       REFERENCES concepts (id);
ALTER TABLE methods       ADD FOREIGN KEY (procedure)     REFERENCES processes (id);
ALTER TABLE methods       ADD FOREIGN KEY (section)       REFERENCES sections (id);
ALTER TABLE passages      ADD FOREIGN KEY (section)       REFERENCES sections (id);
ALTER TABLE media         ADD FOREIGN KEY (section)       REFERENCES sections (id);
ALTER TABLE code_listings ADD FOREIGN KEY (section)       REFERENCES sections (id);
ALTER TABLE code_listings ADD FOREIGN KEY (process, step) REFERENCES process_steps (process, step);
ALTER TABLE discourse_relations ADD FOREIGN KEY (section)    REFERENCES sections (id);
ALTER TABLE discourse_relations ADD FOREIGN KEY (arg1_claim) REFERENCES claims (id);
ALTER TABLE discourse_relations ADD FOREIGN KEY (arg2_claim) REFERENCES claims (id);
ALTER TABLE idea_links    ADD FOREIGN KEY (person)        REFERENCES entities (id);
ALTER TABLE state_spans   ADD FOREIGN KEY (entity)        REFERENCES entities (id);
ALTER TABLE state_spans   ADD FOREIGN KEY (started_by)    REFERENCES events (id);
ALTER TABLE concept_links ADD FOREIGN KEY (concept)       REFERENCES concepts (id);

COMMIT;

-- Story-KG: the rows of the article's frames (kg/scripts/article_tables.py data from source.nq)
BEGIN;
SET search_path = habr_1097022;

INSERT INTO entities (id, types, name, description, tech_role, discourse_position, mention_count) VALUES ('aoco', '{"schema:CreativeWork","schema:SoftwareApplication"}', 'AOCO', 'Колоночное хранилище из Greenplum; в порте работает только на пропатченном ядре', 'database', 4241, 1);
INSERT INTO entities (id, types, name, description, global, tech_role, discourse_position) VALUES ('apache_cloudberry', '{"schema:CreativeWork","schema:SoftwareApplication"}', 'Apache Cloudberry', 'СУБД, которую автор перенёс на PostgreSQL 19 в виде набора расширений; у порта есть и серия патчей ядра', 'apache_cloudberry', 'database', 1995);
INSERT INTO entities (id, types, name, description, roles, discourse_position, sensitivity) VALUES ('architect_friend', '{"schema:Person"}', 'Знакомый архитектор автора', 'Знакомый автора: по его словам, отличный архитектор, но «полнейший сноб»; у него в проде четыре разные СУБД. Собеседник автора в споре о PostgreSQL и ClickHouse', '{"major"}', 648, 'personal');
INSERT INTO entities (id, types, name, description, tech_role, discourse_position, mention_count) VALUES ('citus_columnar', '{"schema:CreativeWork","schema:SoftwareApplication"}', 'Citus columnar', 'Колоночное хранилище для PostgreSQL: внутри колоночное, но через tableAM API отдаёт слоты по одной строке', 'database', 4130, 1);
INSERT INTO entities (id, types, name, description, global, discourse_position) VALUES ('clickbench', '{"schema:CreativeWork"}', 'ClickBench', 'Аналитический бенчмарк; в статье — запросы Q10, Q20, Q23, Q28 к таблице из 105 колонок на 10 млн строк; по словам автора, писался под технологии ClickHouse', 'clickbench', 2763);
INSERT INTO entities (id, types, name, hidden_labels, description, global, tech_role, discourse_position, mention_count, stack_role) VALUES ('clickhouse', '{"schema:CreativeWork","schema:SoftwareApplication"}', 'ClickHouse', '{"кликхаус"}', 'Колоночная аналитическая СУБД: у друга автора в ней лежат данные OpenTelemetry и веб-аналитики; из неё автор взял движок MergeTree; эталон скорости на ClickBench', 'clickhouse', 'database', 766, 9, 'database');
INSERT INTO entities (id, types, name, description, tech_role, discourse_position, stack_role) VALUES ('dmbtree', '{"schema:CreativeWork","schema:SoftwareApplication"}', 'dmbtree', 'Форк индексного метода btree из PostgreSQL 19 внутри расширения iheap: помечает старую запись удалённой, поэтому новая запись появляется только в индексах с изменившимися ключами', 'framework_library', 10327, 'framework_library');
INSERT INTO entities (id, types, name, description, global, tech_role, discourse_position, mention_count) VALUES ('elasticsearch', '{"schema:CreativeWork","schema:SoftwareApplication"}', 'Elasticsearch', 'Поисковая СУБД; у друга автора — для полнотекстового поиска в приложении', 'elasticsearch', 'database', 830, 1);
INSERT INTO entities (id, types, name, description, global, tech_role, discourse_position, mention_count) VALUES ('gcc', '{"schema:CreativeWork","schema:SoftwareApplication"}', 'GCC', 'Компилятор, которым PGXS собирает расширения с -O2; его автовекторизация почти ничего не дала', 'gnu_compiler_collection', 'tool', 5026, 1);
INSERT INTO entities (id, types, name, description, global, discourse_position, mention_count) VALUES ('google', '{"schema:Corporation","schema:Organization"}', 'Google', 'Пример масштаба данных, при котором, по мнению автора, оправдана специализированная база', 'google', 11997, 1);
INSERT INTO entities (id, types, name, description, tech_role, discourse_position) VALUES ('gp_ao', '{"schema:CreativeWork","schema:SoftwareApplication"}', 'gp_ao', 'Хранилище порта Cloudberry на PostgreSQL 19, на шестнадцати сегментах которого ORCA с pg_vexec показывали лучший результат порта (в тексте не поясняется)', 'database', 4367);
INSERT INTO entities (id, types, name, hidden_labels, description, global, tech_role, discourse_position, mention_count) VALUES ('greenplum', '{"schema:CreativeWork","schema:SoftwareApplication"}', 'Greenplum', '{"гринплам"}', 'Массивно-параллельная СУБД на основе PostgreSQL; её стоимостный планировщик ORCA и хранилища PAX и AOCO упоминаются в статье', 'greenplum', 'database', 2134, 2);
INSERT INTO entities (id, types, name, description, tech_role, discourse_position, mention_count) VALUES ('hydra_columnar', '{"schema:CreativeWork","schema:SoftwareApplication"}', 'Hydra', 'Колоночное хранилище для PostgreSQL; как и Citus columnar, наружу через tableAM API отдаёт строки по одной', 'database', 4130, 1);
INSERT INTO entities (id, types, name, description, roles, same_as, discourse_position, contacts_sensitivity, account_service, account_name, account_service_url, account_url) VALUES ('igor_suhorukov', '{"schema:Person"}', 'igor_suhorukov', 'Автор статьи (ник на Хабре; настоящее имя в тексте не названо). Перенёс Apache Cloudberry на PostgreSQL 19 набором расширений, написал векторизованный исполнитель pg_vexec, расширения ch_table_engines (MergeTree в PostgreSQL) и iheap (обновление строк на месте); в споре со знакомым архитектором отстаивает одну СУБД вместо нескольких специализированных', '{"author","narrator","protagonist"}', 'habr-user/igor_suhorukov', 100, 'personal', 'GitHub', 'igor-suhorukov', 'https://github.com/', 'https://github.com/igor-suhorukov');
INSERT INTO entities (id, types, name, description, global, discourse_position, mention_count) VALUES ('large_hadron_collider', '{"schema:Product"}', 'Большой адронный коллайдер', 'Пример данных масштаба, при котором, по мнению автора, оправдана специализированная база', 'large_hadron_collider', 11963, 1);
INSERT INTO entities (id, types, name, description, tech_role, discourse_position) VALUES ('libchte_engine', '{"schema:CreativeWork","schema:SoftwareApplication"}', 'libchte_engine.so', 'Разделяемая библиотека, которая получается после статической линковки нужных сабмодулей ClickHouse с MergeTree для ch_table_engines', 'framework_library', 8039);
INSERT INTO entities (id, types, name, description, global, tech_role, discourse_position, mention_count) VALUES ('mongodb', '{"schema:CreativeWork","schema:SoftwareApplication"}', 'MongoDB', 'Документная СУБД в проде у друга автора, оставшаяся там по историческим причинам', 'mongodb', 'database', 887, 1);
INSERT INTO entities (id, types, name, description, global, tech_role, discourse_position, mention_count) VALUES ('opentelemetry', '{"schema:CreativeWork","schema:SoftwareApplication"}', 'OpenTelemetry', 'Стандарт и средства сбора телеметрии; данные OpenTelemetry друг автора хранит в ClickHouse', 'opentelemetry', 'protocol_format', 792, 1);
INSERT INTO entities (id, types, name, description, tech_role, discourse_position, mention_count) VALUES ('orca', '{"schema:CreativeWork","schema:SoftwareApplication"}', 'ORCA', 'Стоимостный планировщик (оптимизатор запросов) Greenplum, доставшийся автору вместе с портом Apache Cloudberry на PostgreSQL 19; оценивает векторные узлы pg_vexec своей моделью стоимости', 'framework_library', 2098, 5);
INSERT INTO entities (id, types, name, description, tech_role, discourse_position, mention_count) VALUES ('pax', '{"schema:CreativeWork","schema:SoftwareApplication"}', 'PAX', 'Колоночное хранилище из Greenplum; в порте работает только на пропатченном ядре', 'database', 4241, 1);
INSERT INTO entities (id, types, name, description, tech_role, discourse_position, mention_count) VALUES ('pgxs', '{"schema:CreativeWork","schema:SoftwareApplication"}', 'PGXS', 'Инфраструктура сборки расширений PostgreSQL; собирает с уровнем оптимизации -O2', 'tool', 5055, 1);
INSERT INTO entities (id, types, name, alt_names, hidden_labels, description, global, tech_role, discourse_position, mention_count) VALUES ('postgresql', '{"schema:CreativeWork","schema:SoftwareApplication"}', 'PostgreSQL', '{"PG19","PostgreSQL 19","PostgreSQL19"}', '{"постгрес"}', 'Реляционная СУБД. У друга автора — СУБД для OLTP; у автора — ванильный PostgreSQL 19 без патчей ядра, в который через штатные механизмы расширения встроены pg_vexec, ch_table_engines и iheap', 'postgresql', 'database', 745, 4);
INSERT INTO entities (id, types, name, description, global, discourse_position) VALUES ('tpc_ds', '{"schema:CreativeWork"}', 'TPC-DS', 'Бенчмарк аналитических запросов; в статье — сумма запросов и запрос Q2', 'tpc_ds', 8680);
INSERT INTO entities (id, types, name, description, global, discourse_position) VALUES ('tpc_h', '{"schema:CreativeWork"}', 'TPC-H', 'Бенчмарк аналитических запросов; в статье — сумма запросов при масштабе SF1', 'tpc_h', 8604);
INSERT INTO entities (id, types, name, description, tech_role, discourse_position) VALUES ('zheap', '{"schema:CreativeWork","schema:SoftwareApplication"}', 'zheap', 'Проект табличного хранилища PostgreSQL, идейно похожий на iheap; его много лет пытались довести до ядра, но забросили', 'database', 9483);
INSERT INTO entities (id, types, name, description, discourse_position, url, author, about, mention_count) VALUES ('art_cloudberry_pg19', '{"schema:Article","schema:CreativeWork"}', 'Apache Cloudberry на PostgreSQL 19', 'Прежняя статья автора на Хабре о переносе Apache Cloudberry на PostgreSQL 19', 1995, 'https://habr.com/ru/articles/1088264/', 'igor_suhorukov', '{"apache_cloudberry"}', 1);
INSERT INTO entities (id, types, name, description, discourse_position, url, author, about) VALUES ('art_pg_vexec', '{"schema:Article","schema:CreativeWork"}', 'pg_vexec', 'Прежняя статья автора на Хабре о векторизованном исполнителе pg_vexec', 2209, 'https://habr.com/ru/articles/1091738/', 'igor_suhorukov', '{"pg_vexec"}');
INSERT INTO entities (id, types, name, description, tech_role, discourse_position, code_repository, author, stack_role) VALUES ('ch_table_engines', '{"schema:CreativeWork","schema:SoftwareApplication","schema:SoftwareSourceCode"}', 'ch_table_engines', 'Расширение автора, встраивающее в PostgreSQL движки таблиц семейства MergeTree из ClickHouse табличным методом доступа; даёт хранилище, заточенное под анализ логов сервера', 'database', 7460, 'https://github.com/igor-suhorukov/pg_ch_table_engines', 'igor_suhorukov', 'database');
INSERT INTO entities (id, types, name, alt_names, hidden_labels, description, tech_role, discourse_position, code_repository, author, stack_role) VALUES ('iheap', '{"schema:CreativeWork","schema:SoftwareApplication","schema:SoftwareSourceCode"}', 'iheap (pg_inplace_update_am)', '{"pg_inplace_update_am"}', '{"iheap"}', 'Табличный метод доступа PostgreSQL 19 автора (расширение pg_inplace_update_am): перезаписывает строку на месте по тому же TID, старую версию хранит в undo log; сделан без патча ядра', 'database', 9278, 'https://github.com/igor-suhorukov/pg_inplace_update_am', 'igor_suhorukov', 'database');
INSERT INTO entities (id, types, name, hidden_labels, description, tech_role, discourse_position, code_repository, author) VALUES ('pg_vexec', '{"schema:CreativeWork","schema:SoftwareApplication","schema:SoftwareSourceCode"}', 'pg_vexec', '{"vexec"}', 'Векторизованный исполнитель запросов автора — расширение PostgreSQL без единого патча ядра: его узлы попадают в план штатными механизмами и обрабатывают батчи в колоночном виде ядрами-вычислителями', 'framework_library', 2259, 'https://github.com/igor-suhorukov/pg_vexec', 'igor_suhorukov');

INSERT INTO claims (id, text, role, zone, about) VALUES ('claim_bottleneck_reading', 'Векторизация в PostgreSQL упирается не в вычисления, а в считывание данных из heap', 'thesis', 'problem', '{"heap","vectorized_execution"}');
INSERT INTO claims (id, text, role, zone, supports, about) VALUES ('claim_citus_hydra_rows', 'Citus columnar и Hydra колоночные внутри, но через tableAM API отдают слоты по одной строке', 'example', 'problem', '{"claim_no_columnar_source"}', '{"citus_columnar","hydra_columnar","table_access_method"}');
INSERT INTO claims (id, text, role, zone, about) VALUES ('claim_clickbench_tailored', 'На ClickBench невозможно победить без технологий, под которые писался тест: форматов данных ClickHouse, фоновой сортировки и слияний', 'thesis', 'method', '{"background_merge","clickbench","mergetree"}');
INSERT INTO claims (id, text, role, zone, about) VALUES ('claim_custom_glue', 'Встроить MergeTree в PostgreSQL простой линковкой нельзя — понадобилась собственная прослойка', 'thesis', 'method', '{"ch_table_engines","libchte_engine","mergetree"}');
INSERT INTO claims (id, text, role, zone, attacks, about) VALUES ('claim_final_result', 'PostgreSQL 19 с расширениями автора выполняет ClickBench лишь в несколько раз медленнее ClickHouse на той же машине и при этом сохраняет реплики, pg_dump и MVCC PostgreSQL', 'counterexample', 'result', '{"claim_reliable_or_fast"}', '{"ch_table_engines","obs_final_ch","obs_final_pg","pg_vexec","postgresql"}');
INSERT INTO claims (id, text, role, zone, about) VALUES ('claim_first_version_biggest', 'Самое большое ускорение дала первоначальная работа pg_vexec с MergeTree, а дальнейший прогресс был медленным и кропотливым', 'thesis', 'result', '{"mergetree","obs_cb_mt_first","pg_vexec"}');
INSERT INTO claims (id, text, role, zone, author, supports, about) VALUES ('claim_friend_bloat', 'В начале эксплуатации системы друга bloat таблиц был проблемой: пришлось сокращать время транзакций и выносить аналитические запросы из PostgreSQL', 'example', 'problem', 'architect_friend', '{"claim_heap_update_pain"}', '{"bloat","postgresql"}');
INSERT INTO claims (id, text, role, zone, author, about) VALUES ('claim_heap_update_pain', 'Обновление данных в PostgreSQL при длительных транзакциях болезненно: каждый UPDATE создаёт новую версию строки, мёртвые кортежи копятся, автовакуум не успевает', 'opinion', 'problem', 'architect_friend', '{"autovacuum","bloat","heap"}');
INSERT INTO claims (id, text, role, zone, about) VALUES ('claim_iheap_compat', 'Поскольку undo хранится в экстентах основного слоя самой таблицы, WAL, восстановление после сбоя, реплики, бэкапы и логическая репликация работают для iheap как для любой таблицы', 'thesis', 'result', '{"iheap","undo_log"}');
INSERT INTO claims (id, text, role, zone, supports, about) VALUES ('claim_iheap_no_bloat', 'Длительная транзакция при частых обновлениях перестаёт быть большой проблемой: таблицы iheap не раздуваются, как heap', 'argument', 'conclusion', '{"claim_postgres_can_compete"}', '{"bloat","heap","iheap"}');
INSERT INTO claims (id, text, role, zone, about) VALUES ('claim_iheap_no_core_patch', 'Обновление на месте, идейно похожее на zheap, удалось сделать без патча ядра: в PostgreSQL 19 для этого хватает штатных механизмов — от собственного менеджера ресурсов до горизонтов видимости', 'thesis', 'result', '{"iheap","inplace_update","zheap"}');
INSERT INTO claims (id, text, role, zone, supports, about) VALUES ('claim_kernels_negligible', 'Профилирование показало, что вычисления в ядрах функций занимают ничтожную долю времени, а основное время уходит на разбор широких строк и копирование страниц', 'argument', 'result', '{"claim_bottleneck_reading"}', '{"obs_kernel_share","obs_page_copy_share","obs_wide_rows_share","oid_kernel"}');
INSERT INTO claims (id, text, role, zone, about) VALUES ('claim_mergetree_without_vexec', 'Без векторизованного исполнителя MergeTree в PostgreSQL проигрывает даже heap: колоночное хранилище отдаёт данные построчно через слот', 'thesis', 'result', '{"heap","mergetree","obs_tpcds_mt_std","obs_tpch_mt_std","pg_vexec"}');
INSERT INTO claims (id, text, role, zone, about) VALUES ('claim_need_columnar', 'Чтобы векторизация окупилась, нужен источник данных, отдающий колонки, — отсюда задача встроить в PostgreSQL движки семейства MergeTree и догнать ClickHouse на ClickBench', 'thesis', 'problem', '{"columnar_storage","mergetree","pg_vexec"}');
INSERT INTO claims (id, text, role, zone, supports, about) VALUES ('claim_no_columnar_source', 'На немодифицированном PostgreSQL 19 нет ни одного хранилища, которое отдавало бы векторизованному исполнителю данные поколоночно', 'argument', 'problem', '{"claim_need_columnar"}', '{"columnar_storage","pg_vexec","table_access_method"}');
INSERT INTO claims (id, text, role, zone, about) VALUES ('claim_not_all_steps', 'Не все шаги оптимизации вели к улучшениям', 'thesis', 'limitation', '{"proc_optimization_cycle"}');
INSERT INTO claims (id, text, role, zone, supports, about) VALUES ('claim_not_standalone', 'MergeTree отдельно не собирается: он тянет за собой интерпретатор, парсеры и функции ClickHouse, из сабмодулей которого понадобилась лишь малая часть', 'argument', 'method', '{"claim_custom_glue"}', '{"clickhouse","mergetree","obs_submodules"}');
INSERT INTO claims (id, text, role, zone, supports, about) VALUES ('claim_page_geometry', 'Батч широких строк размазан по множеству страниц, и heap поднимает эти страницы в память целиком, даже если запросу нужны лишь несколько колонок', 'argument', 'problem', '{"claim_bottleneck_reading"}', '{"batch","heap","obs_cols_needed","obs_pages_per_batch"}');
INSERT INTO claims (id, text, role, zone, supports, about) VALUES ('claim_pax_aoco_patched', 'PAX и AOCO из Greenplum работают только на пропатченном ядре порта, а не на ванильном PostgreSQL', 'example', 'problem', '{"claim_no_columnar_source"}', '{"aoco","apache_cloudberry","pax"}');
INSERT INTO claims (id, text, role, zone, about) VALUES ('claim_port_16_segments', 'Быстрый результат порта на сегментах gp_ao несопоставим с одним узлом и получен на форке ядра, от которого автор хотел уйти', 'thesis', 'limitation', '{"apache_cloudberry","gp_ao","obs_port_gp_ao"}');
INSERT INTO claims (id, text, role, zone, about) VALUES ('claim_postgres_can_compete', 'Старый PostgreSQL ещё может потягаться с современными базами данных в обычных проектах', 'thesis', 'conclusion', '{"postgresql"}');
INSERT INTO claims (id, text, role, zone, supports, about) VALUES ('claim_process_model', 'Готовый StorageMergeTree рассчитан на многопоточную модель одного серверного процесса, а PostgreSQL создаёт отдельный процесс на каждое соединение', 'argument', 'method', '{"claim_custom_glue"}', '{"mergetree","postgresql"}');
INSERT INTO claims (id, text, role, zone, author, about) VALUES ('claim_reliable_or_fast', 'Надёжность и скорость несовместимы: система бывает либо надёжной, либо быстрой', 'opinion', 'discussion', 'architect_friend', '{"clickhouse","postgresql"}');
INSERT INTO claims (id, text, role, zone, about) VALUES ('claim_row_locks_undo', 'Блокировки строк в iheap тоже хранятся undo-записями, поэтому не нужны ни MultiXact, ни заморозка', 'thesis', 'method', '{"freezing","iheap","multixact","undo_log"}');
INSERT INTO claims (id, text, role, zone, about) VALUES ('claim_sim_only', 'Ускорение от пропуска страниц получено лишь в симуляции, а не на работающем хранилище', 'thesis', 'limitation', '{"heap","obs_skip_speedup"}');
INSERT INTO claims (id, text, role, zone, supports, about) VALUES ('claim_skip_simulation', 'Симуляция пропуска ненужных страниц многократно ускоряла те же запросы ClickBench', 'argument', 'result', '{"claim_need_columnar"}', '{"heap","obs_q20_skip_sim","obs_skip_speedup"}');
INSERT INTO claims (id, text, role, zone, supports, about) VALUES ('claim_slowdown_cause', 'Таблица с LowCardinality, мелкими гранулами и без сжатия заняла больше места из-за отключённого сжатия, а замедлилась не из-за опций, а из-за недослитых частей после перезапуска стенда', 'example', 'result', '{"claim_not_all_steps"}', '{"data_part","granule","low_cardinality","obs_disk_lowcard","obs_parts35_time"}');
INSERT INTO claims (id, text, role, zone, supports, about) VALUES ('claim_specialized_complexity', 'Специализированная база — это сложности в разработке и поддержке, оправданные лишь при масштабе данных бигтеха', 'argument', 'conclusion', '{"claim_postgres_can_compete"}', '{"clickhouse","google","large_hadron_collider"}');
INSERT INTO claims (id, text, role, zone, supports, about) VALUES ('claim_tableam_row_api', 'Табличный API PostgreSQL отдаёт строки по одной через слот и не принимает список нужных колонок, а heap не даёт точки расширения, чтобы пропускать ненужные страницы', 'argument', 'problem', '{"claim_bottleneck_reading"}', '{"heap","table_access_method"}');
INSERT INTO claims (id, text, role, zone, supports, about) VALUES ('claim_use_case', 'PostgreSQL с расширениями подходит для огромной таблицы метрик с сотнями колонок рядом с транзакционными данными из разных систем и соединениями между таблицами — всё в единой транзакции', 'argument', 'conclusion', '{"claim_postgres_can_compete"}', '{"ch_table_engines","mergetree","postgresql"}');

INSERT INTO sections (id, kind, name, level, line, start_pos, end_pos) VALUES ('body', 'Section', 'текст статьи', 1, 32, 568, 12138);
INSERT INTO sections (id, kind, name, level, line, start_pos, end_pos) VALUES ('fm', 'FrontMatter', 'front matter', 1, 1, 0, 568);
INSERT INTO sections (id, kind, name, level, line, parent, start_pos, end_pos, mentions, terms) VALUES ('s1', 'Section', 'Векторизация уперлась в heap', 2, 48, 'body', 1681, 4656, '{"aoco","art_cloudberry_pg19","citus_columnar","clickhouse","greenplum","hydra_columnar","mergetree","orca","pax","postgresql","vec_hash_join","vec_sort"}', '{"hash_table"}');
INSERT INTO sections (id, kind, name, level, line, parent, start_pos, end_pos, mentions) VALUES ('s2', 'Section', 'Как уменьшал среднее время запроса от 715 до 49 миллисекунд', 2, 74, 'body', 4656, 7077, '{"gcc","low_cardinality","mergetree","pgxs","vec_hash_join","vec_sort"}');
INSERT INTO sections (id, kind, name, level, line, parent, start_pos, end_pos, mentions, main_claim, main_claim_supports) VALUES ('s3', 'Section', 'Мне бы очередной колоночный велосипед', 2, 92, 'body', 7077, 8878, '{"clickhouse","mergetree","orca"}', 'claim_custom_glue', 2);
INSERT INTO sections (id, kind, name, level, line, parent, start_pos, end_pos, mentions) VALUES ('s4', 'Section', 'UPDATE не раздувает таблицу', 2, 111, 'body', 8878, 10519, '{"multixact","postgresql"}');
INSERT INTO sections (id, kind, name, level, line, parent, start_pos, end_pos, mentions, main_claim, main_claim_supports) VALUES ('s5', 'Section', 'Мой PostgreSQL', 2, 128, 'body', 10519, 12138, '{"clickhouse","google","large_hadron_collider","mvcc","postgresql"}', 'claim_postgres_can_compete', 3);

INSERT INTO processes (id, name, result, process_kind) VALUES ('proc_attach_storage', 'Выбор хранилища таблицы через CREATE TABLE … USING', 'таблица работает на выбранном хранилище, а реплики, pg_dump и MVCC — как у обычного heap', 'instruction');
INSERT INTO processes (id, name, applies_to, result, process_kind) VALUES ('proc_iheap_update', 'Обновление строки в таблице iheap', 'iheap', 'таблица и индексы не раздуваются от обновлений', 'instruction');
INSERT INTO processes (id, name, applies_to, process_kind) VALUES ('proc_lazy_scan', 'Скан с дочитыванием колонок после первого условия', 'pg_vexec', 'instruction');
INSERT INTO processes (id, name, applies_to, precondition, process_kind) VALUES ('proc_optimization_cycle', 'Цикл оптимизации pg_vexec с MergeTree', 'igor_suhorukov', 'первая, ещё неоптимизированная версия MergeTree вместе с pg_vexec', 'course');

INSERT INTO process_steps (process, step, type, name) VALUES ('proc_attach_storage', 'e1', 'EndEvent', 'Таблица создана на выбранном хранилище');
INSERT INTO process_steps (process, step, type, name) VALUES ('proc_attach_storage', 'g1', 'ExclusiveGateway', 'Какая нагрузка на таблицу?');
INSERT INTO process_steps (process, step, type, name) VALUES ('proc_attach_storage', 's0', 'StartEvent', 'Нужна таблица под определённую нагрузку');
INSERT INTO process_steps (process, step, type, name, stack_tools) VALUES ('proc_attach_storage', 't1', 'Task', 'Подключить расширение хранилища (ch_table_engines или pg_inplace_update_am)', '{"ch_table_engines","iheap"}');
INSERT INTO process_steps (process, step, type, name) VALUES ('proc_attach_storage', 't2', 'Task', 'Выбрать хранилище mergetree');
INSERT INTO process_steps (process, step, type, name, stack_tools) VALUES ('proc_attach_storage', 't3', 'Task', 'Выбрать хранилище iheap', '{"iheap"}');
INSERT INTO process_steps (process, step, type, name) VALUES ('proc_attach_storage', 't4', 'Task', 'Создать таблицу стандартным синтаксисом CREATE TABLE … USING');
INSERT INTO process_steps (process, step, type, name) VALUES ('proc_iheap_update', 'e1', 'EndEvent', 'Строка обновлена без новой версии в таблице');
INSERT INTO process_steps (process, step, type, name, stack_tools) VALUES ('proc_iheap_update', 's0', 'StartEvent', 'UPDATE строки таблицы iheap', '{"iheap"}');
INSERT INTO process_steps (process, step, type, name) VALUES ('proc_iheap_update', 't1', 'ServiceTask', 'Перезаписать строку на месте по тому же TID');
INSERT INTO process_steps (process, step, type, name) VALUES ('proc_iheap_update', 't2', 'ServiceTask', 'Перенести старую версию строки в undo log в экстентах таблицы');
INSERT INTO process_steps (process, step, type, name, uses_tool) VALUES ('proc_iheap_update', 't3', 'ServiceTask', 'Пометить старую индексную запись удалённой и добавить новую только в индексы с изменившимися ключами', '{"dmbtree"}');
INSERT INTO process_steps (process, step, type, name) VALUES ('proc_iheap_update', 't4', 'ServiceTask', 'Читатель, чьему снимку нужна старая версия, собирает её из undo log');
INSERT INTO process_steps (process, step, type, name) VALUES ('proc_lazy_scan', 'e1', 'EndEvent', 'Батч обработан');
INSERT INTO process_steps (process, step, type, name) VALUES ('proc_lazy_scan', 'g1', 'ExclusiveGateway', 'Остались ли строки после первого условия?');
INSERT INTO process_steps (process, step, type, name) VALUES ('proc_lazy_scan', 's0', 'StartEvent', 'Скан обрабатывает очередной батч');
INSERT INTO process_steps (process, step, type, name) VALUES ('proc_lazy_scan', 't1', 'ServiceTask', 'Запросить у источника данных колонки первого условия');
INSERT INTO process_steps (process, step, type, name) VALUES ('proc_lazy_scan', 't2', 'ServiceTask', 'Применить первое условие к батчу');
INSERT INTO process_steps (process, step, type, name) VALUES ('proc_lazy_scan', 't3', 'ServiceTask', 'Дочитать остальные колонки для этого батча');
INSERT INTO process_steps (process, step, type, name) VALUES ('proc_lazy_scan', 't4', 'ServiceTask', 'Не читать остальные колонки батча');
INSERT INTO process_steps (process, step, type, name) VALUES ('proc_optimization_cycle', 'e1', 'EndEvent', 'Шаг оптимизации завершён');
INSERT INTO process_steps (process, step, type, name) VALUES ('proc_optimization_cycle', 'g1', 'ExclusiveGateway', 'Изменение ускорило запросы?');
INSERT INTO process_steps (process, step, type, name) VALUES ('proc_optimization_cycle', 's0', 'StartEvent', 'Есть рабочая версия и замер ClickBench');
INSERT INTO process_steps (process, step, type, name) VALUES ('proc_optimization_cycle', 't1', 'Task', 'Профилирование запросов');
INSERT INTO process_steps (process, step, type, name) VALUES ('proc_optimization_cycle', 't2', 'Task', 'Гипотеза об узком месте по профилю');
INSERT INTO process_steps (process, step, type, name) VALUES ('proc_optimization_cycle', 't3', 'Task', 'Прототипирование изменения');
INSERT INTO process_steps (process, step, type, name) VALUES ('proc_optimization_cycle', 't4', 'Task', 'Повторный замер');
INSERT INTO process_steps (process, step, type, name) VALUES ('proc_optimization_cycle', 't5', 'Task', 'Оставить изменение');
INSERT INTO process_steps (process, step, type, name) VALUES ('proc_optimization_cycle', 't6', 'Task', 'Откатить изменение');

INSERT INTO process_flows (process, n, source, target) VALUES ('proc_attach_storage', 1, 's0', 't1');
INSERT INTO process_flows (process, n, source, target) VALUES ('proc_attach_storage', 2, 't1', 'g1');
INSERT INTO process_flows (process, n, source, target, condition) VALUES ('proc_attach_storage', 3, 'g1', 't2', 'метрики и широкие таблицы');
INSERT INTO process_flows (process, n, source, target, condition) VALUES ('proc_attach_storage', 4, 'g1', 't3', 'горячие обновления');
INSERT INTO process_flows (process, n, source, target) VALUES ('proc_attach_storage', 5, 't2', 't4');
INSERT INTO process_flows (process, n, source, target) VALUES ('proc_attach_storage', 6, 't3', 't4');
INSERT INTO process_flows (process, n, source, target) VALUES ('proc_attach_storage', 7, 't4', 'e1');
INSERT INTO process_flows (process, n, source, target) VALUES ('proc_iheap_update', 1, 's0', 't1');
INSERT INTO process_flows (process, n, source, target) VALUES ('proc_iheap_update', 2, 't1', 't2');
INSERT INTO process_flows (process, n, source, target) VALUES ('proc_iheap_update', 3, 't2', 't3');
INSERT INTO process_flows (process, n, source, target) VALUES ('proc_iheap_update', 4, 't3', 't4');
INSERT INTO process_flows (process, n, source, target) VALUES ('proc_iheap_update', 5, 't4', 'e1');
INSERT INTO process_flows (process, n, source, target) VALUES ('proc_lazy_scan', 1, 's0', 't1');
INSERT INTO process_flows (process, n, source, target) VALUES ('proc_lazy_scan', 2, 't1', 't2');
INSERT INTO process_flows (process, n, source, target) VALUES ('proc_lazy_scan', 3, 't2', 'g1');
INSERT INTO process_flows (process, n, source, target, condition) VALUES ('proc_lazy_scan', 4, 'g1', 't3', 'остались');
INSERT INTO process_flows (process, n, source, target, condition) VALUES ('proc_lazy_scan', 5, 'g1', 't4', 'не остались');
INSERT INTO process_flows (process, n, source, target) VALUES ('proc_lazy_scan', 6, 't3', 'e1');
INSERT INTO process_flows (process, n, source, target) VALUES ('proc_lazy_scan', 7, 't4', 'e1');
INSERT INTO process_flows (process, n, source, target) VALUES ('proc_optimization_cycle', 1, 's0', 't1');
INSERT INTO process_flows (process, n, source, target) VALUES ('proc_optimization_cycle', 2, 't1', 't2');
INSERT INTO process_flows (process, n, source, target) VALUES ('proc_optimization_cycle', 3, 't2', 't3');
INSERT INTO process_flows (process, n, source, target) VALUES ('proc_optimization_cycle', 4, 't3', 't4');
INSERT INTO process_flows (process, n, source, target) VALUES ('proc_optimization_cycle', 5, 't4', 'g1');
INSERT INTO process_flows (process, n, source, target, condition) VALUES ('proc_optimization_cycle', 6, 'g1', 't5', 'ускорило');
INSERT INTO process_flows (process, n, source, target, condition) VALUES ('proc_optimization_cycle', 7, 'g1', 't6', 'не ускорило');
INSERT INTO process_flows (process, n, source, target) VALUES ('proc_optimization_cycle', 8, 't5', 'e1');
INSERT INTO process_flows (process, n, source, target) VALUES ('proc_optimization_cycle', 9, 't6', 'e1');

INSERT INTO concepts (id, name, kind, description, global) VALUES ('auto_vectorization', 'Автовекторизация компилятора', 'technique', 'Автовекторизация GCC на -O2, с которым собирает PGXS, почти ничего не дала pg_vexec: векторизовался ровно один цикл и ни одного сравнения', 'automatic_vectorization');
INSERT INTO concepts (id, name, kind, description) VALUES ('autovacuum', 'Автовакуум', 'mechanism', 'Фоновая очистка мёртвых кортежей в PostgreSQL; при длительных транзакциях с частыми UPDATE не справляется с их накоплением');
INSERT INTO concepts (id, name, alt_names, kind, description, related) VALUES ('background_merge', 'Фоновые слияния частей MergeTree', '{"фоновая сортировка и слияния"}', 'mechanism', 'Фоновая сортировка и слияния частей в хранилище — одна из технологий ClickHouse, без которых, по словам автора, на ClickBench не победить', '{"data_part"}');
INSERT INTO concepts (id, name, kind, definition, definition_key) VALUES ('batch', 'Батч', 'datastructure', 'Пакет строк в колоночном виде, который векторизованный исполнитель обрабатывает целиком; в pg_vexec — 1024 строки', 'c-c67ffcb63180');
INSERT INTO concepts (id, name, alt_names, kind, related, counter_measures, arises_when, manifestation, mechanism, problem_key) VALUES ('bloat', 'Bloat (раздувание таблиц и индексов)', '{"bloat"}', 'phenomenon', '{"autovacuum"}', '{"inplace_update"}', 'при обновлении данных во время длительных транзакций', 'автовакуум не успевает («пыхтит»)', 'каждый UPDATE создаёт новую версию строки, и мёртвые кортежи копятся', '673d7f155859');
INSERT INTO concepts (id, name, alt_names, kind, description, global) VALUES ('columnar_storage', 'Колоночное хранилище', '{"колоночное хранение"}', 'variant', 'Хранилище, которое должно отдавать данные поколоночно; для PostgreSQL таких хранилищ около десятка, но через tableAM API они отдают строки по одной, а без векторизованного исполнителя ведут себя как медленный heap', 'column_oriented_dbms');
INSERT INTO concepts (id, name, kind, definition, description, related, definition_key) VALUES ('cost_based_planner', 'Стоимостный планировщик', 'component', 'Планировщик запросов, выбирающий узлы плана по оценке их стоимости', 'В статье — ORCA и стандартный планировщик PostgreSQL: векторные узлы pg_vexec соревнуются в них с обычными узлами по стоимости', '{"vec_plan_node"}', 'c-c6e8650418c1');
INSERT INTO concepts (id, name, kind, description) VALUES ('data_part', 'Часть таблицы MergeTree', 'datastructure', 'Таблица MergeTree состоит из частей, которые объединяют фоновые слияния; если слияния не завершены, запросы читают больше частей и идут медленнее');
INSERT INTO concepts (id, name, kind, description, extraction_basis) VALUES ('freezing', 'Заморозка', 'mechanism', 'Обслуживающая операция PostgreSQL над версиями строк (подробности вне текста); в iheap не нужна, потому что блокировки строк хранятся undo-записями', 'external_knowledge');
INSERT INTO concepts (id, name, kind, description, global) VALUES ('geometric_mean', 'Среднее геометрическое времени запросов', 'metric', 'Сводная метрика, которой автор сравнивает прогоны ClickBench', 'geometric_mean');
INSERT INTO concepts (id, name, kind, description) VALUES ('granule', 'Гранула MergeTree', 'datastructure', 'Единица хранения данных MergeTree; таблица с мелкими гранулами, LowCardinality и без сжатия неожиданно оказалась медленнее');
INSERT INTO concepts (id, name, alt_names, kind, description, related) VALUES ('heap', 'heap (штатное хранилище таблиц PostgreSQL)', '{"heap"}', 'variant', 'Строки целиком лежат в страницах: чтобы достать несколько колонок, heap поднимает страницы в память целиком и не даёт пропускать ненужные страницы; каждый UPDATE создаёт новую версию строки', '{"columnar_storage","table_access_method"}');
INSERT INTO concepts (id, name, kind, definition, related, procedure, goal, definition_key) VALUES ('inplace_update', 'Обновление строки на месте по TID', 'technique', 'Табличный метод доступа перезаписывает строку на месте, по тому же TID, а её старую версию переносит в undo log, откуда её собирает только тот читатель, чьему снимку она нужна', '{"undo_log","visibility_snapshot"}', 'proc_iheap_update', 'чтобы UPDATE не раздувал таблицу', 'c-cab91028ff8f');
INSERT INTO concepts (id, name, alt_names, kind, definition, related, procedure, definition_key) VALUES ('lazy_column_read', 'Дочитывание колонок после первого условия', '{"ленивое дочитывание колонок при скане"}', 'technique', 'Скан сначала запрашивает у источника данных колонки первого условия, а остальные колонки дочитывает только для батчей, в которых после первого условия остались строки', '{"vec_plan_node"}', 'proc_lazy_scan', 'c-3e9629b64285');
INSERT INTO concepts (id, name, alt_names, kind, definition, description, mention_count, definition_key) VALUES ('low_cardinality', 'LowCardinality (словарное представление колонки)', '{"LowCardinality"}', 'datastructure', 'Представление колонки с небольшим числом различных значений индексами в словаре', 'В pg_vexec такие колонки приходят индексами словаря, а выражения считаются один раз на каждое значение словаря', 2, 'c-6398a1192260');
INSERT INTO concepts (id, name, alt_names, kind, definition, description, broader, related, mention_count, stack_role, definition_key) VALUES ('mergetree', 'MergeTree (движок таблиц ClickHouse)', '{"MergeTree","движки таблиц семейства MergeTree"}', 'component', 'Семейство движков таблиц ClickHouse с собственными форматами данных, фоновой сортировкой и слияниями частей в хранилище', 'По словам автора, испытан годами в пользовательской аналитике под реальной нагрузкой. Отдельно не собирается: часть СУБД ClickHouse, тянет интерпретатор, парсеры и функции; готовый StorageMergeTree рассчитан на многопоточную модель одного серверного процесса. В PostgreSQL без векторизованного исполнителя проигрывает даже heap', '{"columnar_storage"}', '{"background_merge","data_part","granule","low_cardinality"}', 9, 'database', 'c-e93659e4d2da');
INSERT INTO concepts (id, name, kind, description, mention_count, extraction_basis) VALUES ('multixact', 'MultiXact', 'mechanism', 'Механизм PostgreSQL, связанный с блокировками строк (подробности вне текста); в iheap не нужен, потому что блокировки строк — тоже undo-записи', 1, 'external_knowledge');
INSERT INTO concepts (id, name, alt_names, kind, description, global, mention_count) VALUES ('mvcc', 'MVCC (многоверсионное управление конкурентным доступом)', '{"MVCC"}', 'mechanism', 'В таблицах на хранилищах автора MVCC, реплики и pg_dump работают как у обычного heap, потому что ими по-прежнему занимается PostgreSQL', 'multiversion_concurrency_control', 1);
INSERT INTO concepts (id, name, alt_names, kind, definition, related, definition_key) VALUES ('oid_kernel', 'Ядро-вычислитель, привязанное к OID функции', '{"ядро функции"}', 'mechanism', 'Специализированная векторная реализация функции, выбираемая по OID функции; если такого ядра нет, выражение вычисляет штатный интерпретатор выражений PostgreSQL внутри узла', '{"vectorized_execution"}', 'c-cfae81df3cfb');
INSERT INTO concepts (id, name, kind, description) VALUES ('partitioned_shared_agg', 'Агрегация с разделами в общей памяти', 'technique', 'Вместе с собственным ядром регулярных выражений в векторизаторе сократила время запроса Q28 более чем в пять раз');
INSERT INTO concepts (id, name, kind, counter_measures, manifestation, mechanism, problem_key) VALUES ('regex_dfa_rebuild', 'Повторное построение DFA движком регулярных выражений PostgreSQL', 'phenomenon', '{"oid_kernel","partitioned_shared_agg"}', 'в запросе Q28 функция miss() съедала большую долю тактов', 'движок регулярных выражений PostgreSQL строит DFA заново при каждом вызове', 'b3008d832197');
INSERT INTO concepts (id, name, kind, definition, description, definition_key) VALUES ('simd_movemask', 'Ручная векторизация сравнений на SSE2 с movemask', 'technique', 'Переписывание сравнения строк батча на инструкциях SSE2 с movemask вместо расчёта на автовекторизацию компилятора', 'Код автор переписал с помощью нейросети', 'c-a7206cc4374e');
INSERT INTO concepts (id, name, alt_names, kind, definition, description, stack_role, definition_key) VALUES ('table_access_method', 'Табличный метод доступа (tableAM API)', '{"tableAM API","табличный API","табличный метод доступа"}', 'mechanism', 'Точка расширения PostgreSQL, через которую расширение подключает собственное хранилище таблицы', 'Отдаёт строки по одной через слот; scan_begin() не принимает список нужных запросу колонок, поэтому даже колоночные хранилища наружу отдают строки', 'database', 'c-67800c48aebe');
INSERT INTO concepts (id, name, alt_names, kind, definition, description, definition_key) VALUES ('undo_log', 'Undo log (журнал старых версий строк)', '{"undo"}', 'mechanism', 'Хранилище старых версий строк, перезаписанных на месте, из которого читатель собирает нужную его снимку версию', 'В iheap undo живёт в экстентах основного слоя самой таблицы; блокировки строк тоже записываются как undo-записи', 'c-300923d620f9');
INSERT INTO concepts (id, name, kind, description, broader, mention_count) VALUES ('vec_hash_join', 'VecHashJoin', 'component', 'Векторный узел соединения хешированием pg_vexec; пока в коде, решающем, может ли выражение бросить ошибку, не было ветки для T_TargetEntry, он читал строчного потомка по одной строке', '{"vec_plan_node"}', 2);
INSERT INTO concepts (id, name, alt_names, kind, definition, narrower, definition_key) VALUES ('vec_plan_node', 'Векторный узел плана pg_vexec', '{"VecAgg","VecHashJoin","VecScan","VecSort"}', 'component', 'Узел плана запроса pg_vexec, который попадает в план через штатные механизмы расширения СУБД и соревнуется с обычными узлами по стоимости', '{"vec_hash_join","vec_sort"}', 'c-007b8e894261');
INSERT INTO concepts (id, name, kind, description, broader, mention_count) VALUES ('vec_sort', 'VecSort', 'component', 'Векторный узел сортировки pg_vexec; до исправления в режиме auto планировщик не ставил его над узлом скана, а в режиме force его стоимость уходила в минус', '{"vec_plan_node"}', 3);
INSERT INTO concepts (id, name, alt_names, kind, definition, global, related, definition_key) VALUES ('vectorized_execution', 'Векторизованное исполнение запросов', '{"векторизация"}', 'technique', 'Исполнение запроса над батчами данных в колоночном виде вместо построчной обработки', 'vectorization_computer_science', '{"batch","columnar_storage"}', 'c-b024643789a7');
INSERT INTO concepts (id, name, kind, description, related) VALUES ('visibility_snapshot', 'Снимок видимости', 'mechanism', 'По своему снимку читатель определяет, нужна ли ему старая версия строки из undo log', '{"mvcc"}');

INSERT INTO contributions (key, concept, type, effect_kind, effect, quality) VALUES ('1402629605b6', 'lazy_column_read', 'help', 'benefit', 'уменьшило время выполнения запроса Q23 в один поток', 'time_behaviour');
INSERT INTO contributions (key, concept, type, effect_kind, effect, quality) VALUES ('6e735415ae0d', 'inplace_update', 'help', 'benefit', 'при частых обновлениях и длительных транзакциях таблицы не раздуваются, как в heap', 'resource_utilization');
INSERT INTO contributions (key, concept, type, effect_kind, effect, quality) VALUES ('bdbf96f3017f', 'simd_movemask', 'help', 'benefit', 'сравнение 1024 строк стало в несколько раз быстрее', 'time_behaviour');
INSERT INTO contributions (key, concept, type, effect_kind, effect, quality) VALUES ('c217ab943a63', 'partitioned_shared_agg', 'help', 'benefit', 'время выполнения Q28 более чем в пять раз меньше', 'time_behaviour');

INSERT INTO events (id, types, name, description, frame, agent, object, factuality, precedes, discourse_position, timeline_rank, lifecycle_stage) VALUES ('ev_cloudberry_port', '{"schema:Action","schema:Event","schema:UpdateAction"}', 'Перенос Apache Cloudberry на PostgreSQL 19 в виде набора расширений', 'Автор перенёс Apache Cloudberry на PostgreSQL 19 набором расширений (у порта есть и серия патчей ядра) и получил планировщик ORCA на PostgreSQL 19', 'Cause_change', 'igor_suhorukov', 'apache_cloudberry', 'actual', '{"ev_vexec_dev"}', 1979, 1, 'update');
INSERT INTO events (id, types, name, description, frame, agent, factuality, motivated_by, discourse_position, timeline_rank, dialog_act, speaker) VALUES ('ev_drop_bicycle', '{"schema:Action","schema:AllocateAction","schema:Event","schema:OrganizeAction","schema:RejectAction"}', 'Отказ от собственного колоночного хранилища («велосипеда»)', 'Автор начинал со своего колоночного хранилища, но быстро отказался от него в пользу испытанного MergeTree', 'Abandonment', 'igor_suhorukov', 'actual', 'att_author_trust_mergetree', 7119, 7, 'refuse', 'igor_suhorukov');
INSERT INTO events (id, types, name, description, frame, factuality, caused_by, discourse_position, timeline_rank) VALUES ('ev_false_slowdown', '{"schema:Event"}', 'Мнимое замедление таблицы с LowCardinality и мелкими гранулами', 'Таблица с LowCardinality, мелкими гранулами и без сжатия стала медленнее, но причина была не в опциях, а в недослитых частях', 'Change_position_on_a_scale', 'actual', 'ev_restart_before_merges', 6563, 6);
INSERT INTO events (id, types, name, description, frame, agent, object, instrument, factuality, discourse_position, timeline_rank) VALUES ('ev_first_clickbench', '{"schema:Action","schema:AssessAction","schema:Event"}', 'Первый замер pg_vexec на ClickBench', 'Векторизация на heap почти не ускорила запросы ClickBench; результат привёл автора к профилированию и к поиску колоночного источника данных', 'Operational_testing', 'igor_suhorukov', 'pg_vexec', 'clickbench', 'actual', 2763, 3);
INSERT INTO events (id, types, name, description, frame, agent, object, instrument, date_text, factuality, discourse_position, timeline_rank) VALUES ('ev_measure_oct5', '{"schema:Action","schema:AssessAction","schema:Event"}', 'Опорный замер ClickBench 5 октября: heap без векторизации', 'Замер heap без векторизации, с которым автор сравнил первую версию MergeTree с pg_vexec', 'Operational_testing', 'igor_suhorukov', 'heap', 'clickbench', '5 октября', 'actual', 4851, 4);
INSERT INTO events (id, types, name, description, frame, object, factuality, causes, discourse_position, timeline_rank) VALUES ('ev_restart_before_merges', '{"schema:Action","schema:Event"}', 'Перезапуск сервера стендом до окончания фоновых слияний', 'Тестовый стенд перезапускал сервер, не дождавшись конца слияний, и таблица осталась из 35 частей вместо трёх', 'Interrupt_process', 'background_merge', 'actual', '{"ev_false_slowdown"}', 6755, 5);
INSERT INTO events (id, types, name, description, agent, object, factuality, precedes, discourse_position, creates, timeline_rank, lifecycle_stage, fn_frame, fn_frame_choice, fn_frame_match, fn_frame_mapping, fn_roles) VALUES ('ev_vexec_dev', '{"eso:Creating","eso:DynamicEvent","eso:InternalChange","schema:Action","schema:CreateAction","schema:Event"}', 'Разработка векторизованного исполнителя pg_vexec', 'Поверх оптимизатора ORCA автор написал векторизованный исполнитель pg_vexec без единого патча ядра', 'igor_suhorukov', 'pg_vexec', 'actual', '{"ev_first_clickbench"}', 2169, 'pg_vexec', 2, 'creation', 'Creating', 'general', 'close', 'framenet/class/Creating', '{"Created_entity.creating": "pg_vexec", "Creator.creating": "igor_suhorukov"}');
INSERT INTO events (id, types, name, description, frame, object, factuality, discourse_position, timeline_rank) VALUES ('ev_zheap_abandoned', '{"schema:Event"}', 'Прекращение проекта zheap', 'Проект zheap много лет пытались довести до ядра PostgreSQL, но так и забросили', 'Activity_stop', 'zheap', 'actual', 9513, 8);

INSERT INTO dialogues (key, name, section, participants, turn_count) VALUES ('0fdfd068fa77', 'Диалог: Знакомый архитектор автора, igor_suhorukov', 's1', '{"architect_friend","igor_suhorukov"}', 6);
INSERT INTO dialogues (key, name, section, participants, turn_count) VALUES ('3fd1f5f5586a', 'Диалог: Знакомый архитектор автора, igor_suhorukov', 's4', '{"architect_friend","igor_suhorukov"}', 2);
INSERT INTO dialogues (key, name, section, participants, turn_count) VALUES ('7499dec2be50', 'Диалог: igor_suhorukov, Знакомый архитектор автора', 'body', '{"architect_friend","igor_suhorukov"}', 5);
INSERT INTO dialogues (key, name, section, participants, turn_count) VALUES ('8aed080c1eef', 'Диалог: Знакомый архитектор автора, igor_suhorukov', 's3', '{"architect_friend","igor_suhorukov"}', 2);
INSERT INTO dialogues (key, name, section, participants, turn_count) VALUES ('9a215ea52b74', 'Диалог: Знакомый архитектор автора, igor_suhorukov', 's5', '{"architect_friend","igor_suhorukov"}', 2);

INSERT INTO quotations (id, speaker, addressees, speech_act, text, description, about, dialogue, turn_index) VALUES ('rep01', 'igor_suhorukov', '{"architect_friend"}', 'assertive', 'Мне удалось вставить табличный движок MergeTree из ClickHouse в PostgreSQL табличным методом доступа', 'Автор сообщает другу, что встроил MergeTree в ванильный PostgreSQL с доступом из векторизованного исполнителя', '{"ch_table_engines","mergetree","pg_vexec","table_access_method"}', '7499dec2be50', 0);
INSERT INTO quotations (id, speaker, addressees, speech_act, text, description, about, dialogue, turn_index) VALUES ('rep06', 'architect_friend', '{"igor_suhorukov"}', 'question', 'Ты же недавно портировал Greenplum в расширение для постгреса, а потом написал векторный исполнитель поверх него. MergeTree-то тебе зачем?', 'Друг спрашивает, зачем автору MergeTree, если у него уже есть порт Greenplum и векторный исполнитель', '{"ev_cloudberry_port","mergetree","pg_vexec"}', '0fdfd068fa77', 0);
INSERT INTO quotations (id, speaker, addressees, speech_act, text, description, about, dialogue, turn_index) VALUES ('rep12', 'architect_friend', '{"igor_suhorukov"}', 'question', 'То есть ты просто слинковал ClickHouse с бэкэндом постгреса?', 'Друг спрашивает, не свелась ли работа к простой линковке ClickHouse с PostgreSQL', '{"ch_table_engines","clickhouse"}', '8aed080c1eef', 0);
INSERT INTO quotations (id, speaker, addressees, speech_act, text, description, about, dialogue, turn_index) VALUES ('rep14', 'architect_friend', '{"igor_suhorukov"}', 'directive', 'Ладно аналитика. Но признай что постгрес на обновлении данных при длительных транзакциях это боль.', 'Друг уступает в аналитике, но требует признать, что обновления при длительных транзакциях в PostgreSQL болезненны', '{"bloat","claim_friend_bloat","claim_heap_update_pain"}', '3fd1f5f5586a', 0);
INSERT INTO quotations (id, speaker, addressees, speech_act, text, description, about, dialogue, turn_index) VALUES ('rep16', 'architect_friend', '{"igor_suhorukov"}', 'question', 'Ну хорошо. И зачем все это если ClickHouse все равно быстрее работает?', 'Друг спрашивает, зачем всё это, если ClickHouse всё равно быстрее', '{"clickhouse","obs_final_ch"}', '9a215ea52b74', 0);
INSERT INTO quotations (id, speaker, addressees, speech_act, text, description, about, dialogue, turn_index, responds_to) VALUES ('rep02', 'architect_friend', '{"igor_suhorukov"}', 'directive', 'Зачем? Просто возьми ClickHouse и не мучайся.', 'Друг советует не мучиться и взять ClickHouse', '{"clickhouse"}', '7499dec2be50', 1, 'rep01');
INSERT INTO quotations (id, speaker, addressees, speech_act, text, description, about, dialogue, turn_index, responds_to, answers) VALUES ('rep07', 'igor_suhorukov', '{"architect_friend"}', 'assertive', 'Векторизация быстро молотит столбцы, но захлебывается в момент считывания данных.', 'Автор отвечает, что векторизация упирается в чтение данных', '{"claim_bottleneck_reading","vectorized_execution"}', '0fdfd068fa77', 1, 'rep06', 'rep06');
INSERT INTO quotations (id, speaker, addressees, speech_act, text, description, about, dialogue, turn_index, responds_to, answers) VALUES ('rep13', 'igor_suhorukov', '{"architect_friend"}', 'assertive', 'Не просто. MergeTree отдельно не собирается, он часть dbms ClickHouse и тянет за собой интерпретатор, парсеры и функции.', 'Автор возражает, что встроить MergeTree потребовало отдельной сборки и своей прослойки', '{"claim_custom_glue","libchte_engine","mergetree","obs_submodules"}', '8aed080c1eef', 1, 'rep12', 'rep12');
INSERT INTO quotations (id, speaker, addressees, speech_act, stance, text, description, about, dialogue, turn_index, responds_to) VALUES ('rep15', 'igor_suhorukov', '{"architect_friend"}', 'assertive', 'agree', 'Признаю! Поэтому я и сделал свой iheap', 'Автор соглашается с проблемой и называет своё решение — табличный метод доступа iheap с обновлением на месте', '{"iheap","inplace_update","undo_log"}', '3fd1f5f5586a', 1, 'rep14');
INSERT INTO quotations (id, speaker, addressees, speech_act, text, description, about, dialogue, turn_index, responds_to, answers) VALUES ('rep17', 'igor_suhorukov', '{"architect_friend"}', 'assertive', 'Затем что это отличная база данных для огромной таблицы метрик с сотнями колонок.', 'Автор отвечает итоговым доводом: одна PostgreSQL с расширениями закрывает и метрики, и транзакции без лишней сложности', '{"claim_specialized_complexity","claim_use_case"}', '9a215ea52b74', 1, 'rep16', 'rep16');
INSERT INTO quotations (id, speaker, addressees, speech_act, text, description, about, dialogue, turn_index, responds_to) VALUES ('rep03', 'igor_suhorukov', '{"architect_friend"}', 'assertive', 'Затем что мне нужны JOIN между множеством таблиц и согласованность данных в системе и одна привычная в разработке и поддержке платформа.', 'Автор объясняет, что ему нужны соединения таблиц, согласованность данных и одна привычная платформа', '{"claim_use_case","postgresql"}', '7499dec2be50', 2, 'rep02');
INSERT INTO quotations (id, speaker, addressees, speech_act, text, description, about, dialogue, turn_index, responds_to) VALUES ('rep08', 'architect_friend', '{"igor_suhorukov"}', 'question', '18%, серьезно? И ради этого стоило городить векторизацию?', 'Друг сомневается, стоило ли делать векторизацию ради ускорения на 18 %', '{"obs_cb_orca_heap_vexec","vectorized_execution"}', '0fdfd068fa77', 2, 'rep07');
INSERT INTO quotations (id, speaker, addressees, speech_act, stance, text, description, about, dialogue, turn_index, responds_to) VALUES ('rep04', 'architect_friend', '{"igor_suhorukov"}', 'assertive', 'disagree', 'Так не бывает. Либо надежно, либо быстро!', 'Друг возражает, что надёжность и скорость не совместить', '{"claim_reliable_or_fast"}', '7499dec2be50', 3, 'rep03');
INSERT INTO quotations (id, speaker, addressees, speech_act, text, description, about, dialogue, turn_index, responds_to, answers) VALUES ('rep09', 'igor_suhorukov', '{"architect_friend"}', 'assertive', 'Ну я запустил профилирование и понял что ядра функций занимали только 0-2% от общего времени исполнения запроса.', 'Автор отвечает результатами профилирования: время уходит не на вычисления, а на разбор строк и копирование страниц', '{"claim_kernels_negligible","obs_kernel_share","obs_page_copy_share","obs_wide_rows_share"}', '0fdfd068fa77', 3, 'rep08', 'rep08');
INSERT INTO quotations (id, speaker, addressees, speech_act, text, description, about, dialogue, turn_index, responds_to) VALUES ('rep05', 'igor_suhorukov', '{"architect_friend"}', 'assertive', 'А у меня получилось совместить лучшее из двух миров.', 'Автор отвечает, что ему удалось совместить надёжность PostgreSQL и скорость аналитической СУБД', '{"claim_final_result"}', '7499dec2be50', 4, 'rep04');
INSERT INTO quotations (id, speaker, addressees, speech_act, text, description, about, dialogue, turn_index, responds_to) VALUES ('rep10', 'architect_friend', '{"igor_suhorukov"}', 'directive', 'Так возьми колоночное хранилище. Их для PostgreSQL с десяток.', 'Друг советует взять одно из готовых колоночных хранилищ для PostgreSQL', '{"columnar_storage"}', '0fdfd068fa77', 4, 'rep09');
INSERT INTO quotations (id, speaker, addressees, speech_act, stance, stance_target, text, description, about, dialogue, turn_index, responds_to) VALUES ('rep11', 'igor_suhorukov', '{"architect_friend"}', 'assertive', 'irony', 'rep10', 'Ты конечно советчик Капитан Очевидность) На немодифицированном PostgreSQL19 у vexec не нашлось ни одного источника, который бы отдавал данные поколоночно.', 'Автор иронизирует над очевидным советом и объясняет, что ни одно колоночное хранилище на ванильном PostgreSQL не отдаёт данные поколоночно', '{"aoco","citus_columnar","claim_no_columnar_source","hydra_columnar","obs_port_gp_ao","pax"}', '0fdfd068fa77', 5, 'rep10');

INSERT INTO attitudes (id, holder, type, target, name, description, affect_class, affect_kind, valence, outcome_key, outcome_event, outcome_status, outcome_verdict) VALUES ('att_author_trust_mergetree', 'igor_suhorukov', 'trust', 'mergetree', 'Автор доверяет MergeTree как движку, испытанному годами под реальной нагрузкой, и поэтому отказался от своего колоночного хранилища', 'Автор доверяет MergeTree как движку, испытанному годами под реальной нагрузкой, и поэтому отказался от своего колоночного хранилища', 'AffectiveDisposition', 'disposition', 'positive', '8be1045faea5', 'ev_drop_bicycle', 'acted_upon', 'realized');
INSERT INTO attitudes (id, holder, type, target_text, name, description, affect_class, affect_kind) VALUES ('att_author_zoo', 'igor_suhorukov', 'belief', 'несколько СУБД с ETL и CDC между ними — излишняя сложность в поддержке и разработке', 'Автор оценивает зоопарк из нескольких СУБД, связанных ETL и CDC, как излишнюю сложность', 'Автор оценивает зоопарк из нескольких СУБД, связанных ETL и CDC, как излишнюю сложность', 'CognitiveAttitude', 'cognitive');
INSERT INTO attitudes (id, holder, type, target_text, name, description, affect_class, affect_kind) VALUES ('att_friend_architecture', 'architect_friend', 'belief', 'четыре разные СУБД с ETL и CDC между ними — продуманная архитектура', 'Друг считает свой стек из PostgreSQL, ClickHouse, Elasticsearch и MongoDB продуманной архитектурой', 'Друг считает свой стек из PostgreSQL, ClickHouse, Elasticsearch и MongoDB продуманной архитектурой', 'CognitiveAttitude', 'cognitive');

INSERT INTO narratives (id, name, description, type, factuality, told_by, characters, moral, level, span_start, span_end, inset_class, diegetic_level, diegetic_level_kind, audience_kind, narrator_kind, narrator_basis, purpose) VALUES ('narr_dispute', 'Спор автора со знакомым архитектором: PostgreSQL против ClickHouse', 'Рамка статьи: автор рассказывает знакомому архитектору о своих расширениях PostgreSQL, тот возражает и советует взять ClickHouse или колоночное хранилище; реплики спора перемежаются техническим рассказом', 'anecdote', 'actual', 'igor_suhorukov', '{"architect_friend","igor_suhorukov"}', 'claim_postgres_can_compete', 2, 648, 11059, 'InsetAnecdote', 1, 'intradiegetic', 'readers', 'author', 'named', 'thesis');

INSERT INTO observations (id, variable, value, unit, condition, dataset, about, unit_code, quantity_kind, base_unit, value_in_base_unit, observed_property, property_basis) VALUES ('obs_cb_heap_oct5', 'среднее геометрическое время запроса ClickBench', 715, 'мс', 'PostgreSQL 19, heap без векторизации, замер 5 октября', 'bench_clickbench_mergetree_first', '{"clickbench","heap"}', 'millisecond', 'time', 'second', 0.715, 'geometric_mean', 'variable');
INSERT INTO observations (id, variable, value, unit, condition, dataset, about, unit_code, quantity_kind, base_unit, value_in_base_unit, carriers, carrier_basis, observed_property, property_basis) VALUES ('obs_cb_mt_first', 'среднее геометрическое время запроса ClickBench', 148, 'мс', 'PostgreSQL 19, первая неоптимизированная версия MergeTree с pg_vexec', 'bench_clickbench_mergetree_first', '{"clickbench","mergetree","pg_vexec"}', 'millisecond', 'time', 'second', 0.148, '{"pg_vexec"}', 'about', 'geometric_mean', 'variable');
INSERT INTO observations (id, variable, value, unit, condition, dataset, about, unit_code, quantity_kind, base_unit, value_in_base_unit, carriers, carrier_basis, observed_property, property_basis) VALUES ('obs_cb_orca_heap_pg', 'среднее геометрическое время запроса ClickBench', 1647, 'мс', 'PostgreSQL 19, ORCA, heap, штатный исполнитель', 'bench_clickbench_vexec_heap', '{"clickbench","heap","orca"}', 'millisecond', 'time', 'second', 1.647, '{"orca"}', 'about', 'geometric_mean', 'variable');
INSERT INTO observations (id, variable, value, unit, condition, dataset, about, unit_code, quantity_kind, base_unit, value_in_base_unit, carriers, carrier_basis, observed_property, property_basis) VALUES ('obs_cb_orca_heap_vexec', 'среднее геометрическое время запроса ClickBench', 1349, 'мс', 'PostgreSQL 19, ORCA, heap, pg_vexec', 'bench_clickbench_vexec_heap', '{"clickbench","heap","orca","pg_vexec"}', 'millisecond', 'time', 'second', 1.349, '{"orca","pg_vexec"}', 'about', 'geometric_mean', 'variable');
INSERT INTO observations (id, variable, value, unit, condition, dataset, about, unit_code, quantity_kind) VALUES ('obs_cb_saving_16', 'экономия времени по всему ClickBench', 16, '%', 'собственное ядро регулярных выражений и агрегация с разделами в общей памяти', 'bench_q28_regex', '{"clickbench","oid_kernel","partitioned_shared_agg"}', 'percent', 'ratio');
INSERT INTO observations (id, variable, value, unit, condition, dataset, about, unit_code, quantity_kind, base_unit, value_in_base_unit, observed_property, property_basis) VALUES ('obs_cb_std_heap_pg', 'среднее геометрическое время запроса ClickBench', 625, 'мс', 'PostgreSQL 19, стандартный планировщик, heap, штатный исполнитель', 'bench_clickbench_vexec_heap', '{"clickbench","heap"}', 'millisecond', 'time', 'second', 0.625, 'geometric_mean', 'variable');
INSERT INTO observations (id, variable, value, unit, condition, dataset, about, unit_code, quantity_kind, base_unit, value_in_base_unit, carriers, carrier_basis, observed_property, property_basis) VALUES ('obs_cb_std_heap_vexec', 'среднее геометрическое время запроса ClickBench', 506, 'мс', 'PostgreSQL 19, стандартный планировщик, heap, pg_vexec', 'bench_clickbench_vexec_heap', '{"clickbench","heap","pg_vexec"}', 'millisecond', 'time', 'second', 0.506, '{"pg_vexec"}', 'about', 'geometric_mean', 'variable');
INSERT INTO observations (id, variable, value, unit, condition, dataset, about, unit_code, quantity_kind, base_unit, value_in_base_unit, carriers, carrier_basis) VALUES ('obs_cmp_autovec', 'время сравнения 1024 строк', 426, 'нс', 'код pg_vexec, автовекторизация GCC на -O2 (сборка PGXS)', 'bench_cmp_1024', '{"auto_vectorization","gcc"}', 'nanosecond', 'time', 'second', 0.00000042600000000000003, '{"gcc"}', 'about');
INSERT INTO observations (id, variable, value, unit, condition, dataset, about, unit_code, quantity_kind, base_unit, value_in_base_unit) VALUES ('obs_cmp_sse2', 'время сравнения 1024 строк', 82, 'нс', 'код pg_vexec, сравнение переписано на SSE2 с movemask', 'bench_cmp_1024', '{"simd_movemask"}', 'nanosecond', 'time', 'second', 0.000000082);
INSERT INTO observations (id, variable, value, unit, condition, dataset, about, unit_code, quantity_kind, count_noun) VALUES ('obs_cols_needed', 'число колонок, которые нужно достать запросу', 3, 'колонки', 'из 105 колонок таблицы теста ClickBench', 'heap_page_geometry', '{"clickbench","heap"}', 'item', 'count', 'колонки');
INSERT INTO observations (id, variable, value, unit, condition, dataset, about, unit_code, quantity_kind, base_unit, value_in_base_unit) VALUES ('obs_disk_lowcard', 'объём таблицы на диске', 11.8, 'ГБ', 'MergeTree с LowCardinality, мелкими гранулами и без сжатия', 'bench_lowcard_disk', '{"granule","low_cardinality","mergetree"}', 'gigabyte', 'datasize', 'byte', 11800000000);
INSERT INTO observations (id, variable, value, unit, condition, dataset, about, unit_code, quantity_kind, base_unit, value_in_base_unit) VALUES ('obs_disk_orig', 'объём таблицы на диске', 4.8, 'ГБ', 'исходная таблица MergeTree', 'bench_lowcard_disk', '{"mergetree"}', 'gigabyte', 'datasize', 'byte', 4800000000);
INSERT INTO observations (id, variable, value, unit, condition, dataset, about, unit_code, quantity_kind, base_unit, value_in_base_unit, carriers, carrier_basis, observed_property, property_basis) VALUES ('obs_final_ch', 'среднее геометрическое время запроса ClickBench', 16.8, 'мс', 'ClickHouse, те же данные (10 млн строк), та же машина', 'bench_final_laptop', '{"clickbench","clickhouse"}', 'millisecond', 'time', 'second', 0.016800000000000002, '{"clickhouse"}', 'about', 'geometric_mean', 'variable');
INSERT INTO observations (id, variable, value, unit, condition, dataset, about, unit_code, quantity_kind, base_unit, value_in_base_unit, carriers, carrier_basis, observed_property, property_basis) VALUES ('obs_final_pg', 'среднее геометрическое время запроса ClickBench', 49.9, 'мс', 'PostgreSQL 19 с расширениями автора, 10 млн строк, ноутбук автора', 'bench_final_laptop', '{"ch_table_engines","clickbench","pg_vexec","postgresql"}', 'millisecond', 'time', 'second', 0.0499, '{"ch_table_engines","pg_vexec","postgresql"}', 'about', 'geometric_mean', 'variable');
INSERT INTO observations (id, variable, value, unit, condition, dataset, about, unit_code, quantity_kind, carriers, carrier_basis) VALUES ('obs_hash_check_share', 'доля тактов на проверки значения в хеш-таблице', 5, '%', 'pg_vexec на heap, профилирование запросов ClickBench', 'prof_vexec_heap', '{"pg_vexec"}', 'percent', 'ratio', '{"pg_vexec"}', 'about');
INSERT INTO observations (id, variable, value_range, unit, condition, dataset, about, unit_code, quantity_kind, min_value, max_value, carriers, carrier_basis) VALUES ('obs_kernel_share', 'доля ядер функций в общем времени исполнения запроса', '0-2', '%', 'pg_vexec на heap, профилирование запросов ClickBench', 'prof_vexec_heap', '{"oid_kernel","pg_vexec"}', 'percent', 'ratio', 0, 2, '{"pg_vexec"}', 'about');
INSERT INTO observations (id, variable, value_range, unit, condition, dataset, about, unit_code, quantity_kind, min_value, max_value, carriers, carrier_basis) VALUES ('obs_page_copy_share', 'доля времени на копирование страниц', '26-47', '%', 'pg_vexec на heap, в зависимости от запроса', 'prof_vexec_heap', '{"heap","pg_vexec"}', 'percent', 'ratio', 26, 47, '{"pg_vexec"}', 'about');
INSERT INTO observations (id, variable, value, unit, condition, dataset, about, unit_code, quantity_kind, count_noun) VALUES ('obs_pages_per_batch', 'число страниц, по которым размазан батч', 180, 'страниц', 'heap, батч из 1024 строк, строка около 1,4 КБ, примерно', 'heap_page_geometry', '{"batch","heap"}', 'item', 'count', 'страниц');
INSERT INTO observations (id, variable, value, unit, condition, dataset, about, unit_code, quantity_kind, base_unit, value_in_base_unit) VALUES ('obs_parts35_time', 'время запросов ClickBench на исходной таблице', 106, 'мс', '35 частей: сервер перезапущен до конца слияний', 'bench_parts_35', '{"background_merge","data_part"}', 'millisecond', 'time', 'second', 0.106);
INSERT INTO observations (id, variable, value, unit, condition, dataset, about, unit_code, quantity_kind, base_unit, value_in_base_unit) VALUES ('obs_parts3_time', 'время запросов ClickBench на исходной таблице', 71, 'мс', 'слияния завершены (три части вместо 35)', 'bench_parts_35', '{"background_merge","data_part"}', 'millisecond', 'time', 'second', 0.07100000000000001);
INSERT INTO observations (id, variable, value, unit, condition, dataset, about, unit_code, quantity_kind, base_unit, value_in_base_unit, carriers, carrier_basis) VALUES ('obs_port_gp_ao', 'время выполнения запросов ClickBench', 105, 'мс', 'порт Cloudberry на PostgreSQL 19 (форк ядра), 16 сегментов gp_ao, ORCA + pg_vexec', 'bench_cloudberry_port', '{"apache_cloudberry","gp_ao","orca","pg_vexec"}', 'millisecond', 'time', 'second', 0.105, '{"apache_cloudberry","gp_ao","orca","pg_vexec"}', 'about');
INSERT INTO observations (id, variable, value, unit, condition, dataset, about, unit_code, quantity_kind, base_unit, value_in_base_unit) VALUES ('obs_q10_after', 'время запроса Q10 ClickBench', 85.6, 'мс', 'один поток, колонки приходят индексами словаря LowCardinality', 'bench_lowcard_q10', '{"clickbench","low_cardinality"}', 'millisecond', 'time', 'second', 0.0856);
INSERT INTO observations (id, variable, value, unit, condition, dataset, about, unit_code, quantity_kind, base_unit, value_in_base_unit) VALUES ('obs_q10_before', 'время запроса Q10 ClickBench', 148.2, 'мс', 'один поток, без словаря LowCardinality', 'bench_lowcard_q10', '{"clickbench","low_cardinality"}', 'millisecond', 'time', 'second', 0.1482);
INSERT INTO observations (id, variable, value, unit, condition, dataset, about, unit_code, quantity_kind, base_unit, value_in_base_unit) VALUES ('obs_q20_heap', 'время запроса Q20 ClickBench', 510, 'мс', 'heap без пропуска страниц', 'bench_skip_simulation', '{"clickbench","heap"}', 'millisecond', 'time', 'second', 0.51);
INSERT INTO observations (id, variable, value, unit, condition, dataset, about, unit_code, quantity_kind, base_unit, value_in_base_unit) VALUES ('obs_q20_skip_sim', 'время запроса Q20 ClickBench', 5.3, 'мс', 'симуляция пропуска ненужных страниц heap', 'bench_skip_simulation', '{"clickbench","heap"}', 'millisecond', 'time', 'second', 0.0053);
INSERT INTO observations (id, variable, value, unit, condition, dataset, about, unit_code, quantity_kind, base_unit, value_in_base_unit) VALUES ('obs_q23_after', 'время выполнения запроса Q23 ClickBench', 247, 'мс', 'один поток, с дочитыванием колонок после первого условия', 'bench_lazy_columns', '{"clickbench","lazy_column_read"}', 'millisecond', 'time', 'second', 0.247);
INSERT INTO observations (id, variable, value, unit, condition, dataset, about, unit_code, quantity_kind, base_unit, value_in_base_unit) VALUES ('obs_q23_before', 'время выполнения запроса Q23 ClickBench', 471, 'мс', 'один поток, без дочитывания колонок после первого условия', 'bench_lazy_columns', '{"clickbench","lazy_column_read"}', 'millisecond', 'time', 'second', 0.47100000000000003);
INSERT INTO observations (id, variable, value, unit, condition, dataset, about, unit_code, quantity_kind, base_unit, value_in_base_unit) VALUES ('obs_q28_after', 'время выполнения запроса Q28 ClickBench', 213, 'мс', 'собственное ядро в векторизаторе и агрегация с разделами в общей памяти', 'bench_q28_regex', '{"clickbench","oid_kernel","partitioned_shared_agg"}', 'millisecond', 'time', 'second', 0.213);
INSERT INTO observations (id, variable, value, unit, condition, dataset, about, unit_code, quantity_kind, base_unit, value_in_base_unit) VALUES ('obs_q28_before', 'время выполнения запроса Q28 ClickBench', 1090, 'мс', 'штатный движок регулярных выражений PostgreSQL', 'bench_q28_regex', '{"clickbench","regex_dfa_rebuild"}', 'millisecond', 'time', 'second', 1.09);
INSERT INTO observations (id, variable, value, unit, condition, dataset, about, unit_code, quantity_kind) VALUES ('obs_q28_miss_share', 'доля тактов функции miss() в запросе Q28', 36, '%', 'штатный движок регулярных выражений PostgreSQL', 'bench_q28_regex', '{"regex_dfa_rebuild"}', 'percent', 'ratio');
INSERT INTO observations (id, variable, value, unit, condition, dataset, about, unit_code, quantity_kind, base_unit, value_in_base_unit) VALUES ('obs_q2_after', 'время запроса TPC-DS Q2', 1246, 'мс', 'после фикса ветки T_TargetEntry в одну строку', 'bench_tpcds_q2_fix', '{"tpc_ds","vec_hash_join"}', 'millisecond', 'time', 'second', 1.246);
INSERT INTO observations (id, variable, value, unit, condition, dataset, about, unit_code, quantity_kind, count_noun) VALUES ('obs_q2_batches', 'число батчей из одной строки в запросе TPC-DS Q2', 2153556, 'батчей', 'VecHashJoin без ветки для T_TargetEntry', 'bench_tpcds_q2_fix', '{"tpc_ds","vec_hash_join"}', 'item', 'count', 'батчей');
INSERT INTO observations (id, variable, value, unit, condition, dataset, about, unit_code, quantity_kind, base_unit, value_in_base_unit) VALUES ('obs_q2_before', 'время запроса TPC-DS Q2', 3447, 'мс', 'до фикса ветки T_TargetEntry', 'bench_tpcds_q2_fix', '{"tpc_ds","vec_hash_join"}', 'millisecond', 'time', 'second', 3.447);
INSERT INTO observations (id, variable, value, unit, condition, dataset, about, unit_code, quantity_kind, carriers, carrier_basis) VALUES ('obs_ratio_ext', 'отставание от ClickHouse на ClickBench', 3, 'раза', 'PostgreSQL 19 с расширениями автора против ClickHouse, те же данные, та же машина', 'bench_final_laptop', '{"ch_table_engines","clickhouse","pg_vexec","postgresql"}', 'times', 'multiple', '{"ch_table_engines","clickhouse","pg_vexec","postgresql"}', 'about');
INSERT INTO observations (id, variable, value, unit, condition, dataset, about, unit_code, quantity_kind, carriers, carrier_basis) VALUES ('obs_ratio_vanilla', 'отставание от ClickHouse на ClickBench', 39, 'раз', 'ванильный PostgreSQL против ClickHouse', 'bench_final_laptop', '{"clickhouse","postgresql"}', 'times', 'multiple', '{"clickhouse","postgresql"}', 'about');
INSERT INTO observations (id, variable, value, unit, condition, dataset, about, unit_code, quantity_kind, base_unit, value_in_base_unit) VALUES ('obs_row_size', 'размер строки', 1.4, 'КБ', 'таблица теста ClickBench в heap, около', 'heap_page_geometry', '{"clickbench","heap"}', 'kilobyte', 'datasize', 'byte', 1400);
INSERT INTO observations (id, variable, value_range, unit, condition, dataset, about, unit_code, quantity_kind, min_value, max_value, count_noun) VALUES ('obs_rows_per_page', 'число строк на странице', '5-6', 'строк', 'heap, строка около 1,4 КБ', 'heap_page_geometry', '{"heap"}', 'item', 'count', 5, 6, 'строк');
INSERT INTO observations (id, variable, value_range, unit, condition, dataset, about, unit_code, quantity_kind, min_value, max_value) VALUES ('obs_skip_speedup', 'ускорение запросов ClickBench', '8-100', 'раз', 'симуляция пропуска ненужных страниц heap', 'bench_skip_simulation', '{"clickbench","heap"}', 'times', 'multiple', 8, 100);
INSERT INTO observations (id, variable, value_range, unit, condition, dataset, about, unit_code, quantity_kind, base_unit, min_value, max_value, min_in_base_unit, max_in_base_unit) VALUES ('obs_sort_after', 'время запроса SELECT * FROM hits ORDER BY CounterID LIMIT 10', '67-76', 'мс', 'после фикса VecSort', 'bench_vecsort_fix', '{"vec_sort"}', 'millisecond', 'time', 'second', 67, 76, 0.067, 0.076);
INSERT INTO observations (id, variable, value, unit, condition, dataset, about, unit_code, quantity_kind) VALUES ('obs_sort_before', 'время запроса SELECT * FROM hits ORDER BY CounterID LIMIT 10', 2.1, 'с', 'до фикса VecSort', 'bench_vecsort_fix', '{"vec_sort"}', 'second', 'time');
INSERT INTO observations (id, variable, value, unit, condition, about, unit_code, quantity_kind, carriers, carrier_basis, count_noun) VALUES ('obs_submodules', 'число сабмодулей ClickHouse, нужных для сборки MergeTree', 28, 'сабмодулей', 'из полутора сотен сабмодулей ClickHouse', '{"clickhouse","libchte_engine","mergetree"}', 'item', 'count', '{"clickhouse","libchte_engine"}', 'about', 'сабмодулей');
INSERT INTO observations (id, variable, value, unit, condition, dataset, about, unit_code, quantity_kind) VALUES ('obs_tpcds_heap_std', 'сумма времени запросов TPC-DS', 58.8, 'с', 'ORCA, heap, штатный исполнитель', 'bench_tpcds_orca', '{"heap","tpc_ds"}', 'second', 'time');
INSERT INTO observations (id, variable, value, unit, condition, dataset, about, unit_code, quantity_kind) VALUES ('obs_tpcds_mt_std', 'сумма времени запросов TPC-DS', 380.5, 'с', 'ORCA, MergeTree, штатный исполнитель', 'bench_tpcds_orca', '{"mergetree","tpc_ds"}', 'second', 'time');
INSERT INTO observations (id, variable, value, unit, condition, dataset, about, unit_code, quantity_kind, carriers, carrier_basis) VALUES ('obs_tpcds_mt_vexec', 'сумма времени запросов TPC-DS', 48.6, 'с', 'ORCA, MergeTree, pg_vexec', 'bench_tpcds_orca', '{"mergetree","pg_vexec","tpc_ds"}', 'second', 'time', '{"pg_vexec"}', 'about');
INSERT INTO observations (id, variable, value, unit, condition, dataset, about, unit_code, quantity_kind) VALUES ('obs_tpch_heap_std', 'сумма времени запросов TPC-H SF1', 17.2, 'с', 'ORCA, heap, штатный исполнитель', 'bench_tpch_sf1_orca', '{"heap","tpc_h"}', 'second', 'time');
INSERT INTO observations (id, variable, value, unit, condition, dataset, about, unit_code, quantity_kind) VALUES ('obs_tpch_mt_std', 'сумма времени запросов TPC-H SF1', 61.8, 'с', 'ORCA, MergeTree, штатный исполнитель', 'bench_tpch_sf1_orca', '{"mergetree","tpc_h"}', 'second', 'time');
INSERT INTO observations (id, variable, value, unit, condition, dataset, about, unit_code, quantity_kind, carriers, carrier_basis) VALUES ('obs_tpch_mt_vexec', 'сумма времени запросов TPC-H SF1', 6.9, 'с', 'ORCA, MergeTree, pg_vexec', 'bench_tpch_sf1_orca', '{"mergetree","pg_vexec","tpc_h"}', 'second', 'time', '{"pg_vexec"}', 'about');
INSERT INTO observations (id, variable, value, condition, dataset, about) VALUES ('obs_vecsort_cost', 'оценка стоимости VecSort', -46403, 'режим force, до фикса', 'bench_vecsort_fix', '{"vec_sort"}');
INSERT INTO observations (id, variable, value_range, unit, condition, dataset, about, unit_code, quantity_kind, min_value, max_value, carriers, carrier_basis) VALUES ('obs_wide_rows_share', 'доля тактов GROUP BY на разбор широких строк', '51-86', '%', 'pg_vexec на heap, в зависимости от запроса', 'prof_vexec_heap', '{"heap","pg_vexec"}', 'percent', 'ratio', 51, 86, '{"pg_vexec"}', 'about');

INSERT INTO datasets (id, types, name, measure, condition, units, series_kind, subjects, section, observation_count, best_observation, better_is) VALUES ('bench_clickbench_mergetree_first', '{"kgo:Benchmark","kgo:Experiment","kgo:MeasurementSet","qb:DataSet"}', 'среднее геометрическое время запроса clickbench: heap (штатное хранилище таблиц PostgreSQL), MergeTree (движок таблиц ClickHouse)', 'среднее геометрическое время запроса clickbench', 'Как уменьшал среднее время запроса от 715 до 49 миллисекунд', '{"мс"}', 'comparison', '{"heap","mergetree"}', 's2', 2, 'obs_cb_mt_first', 'lower');
INSERT INTO datasets (id, types, name, measure, condition, units, series_kind, subjects, section, observation_count, best_observation, better_is) VALUES ('bench_clickbench_vexec_heap', '{"kgo:Benchmark","kgo:Experiment","kgo:MeasurementSet","qb:DataSet"}', 'среднее геометрическое время запроса clickbench: heap (штатное хранилище таблиц PostgreSQL), ORCA, pg_vexec', 'среднее геометрическое время запроса clickbench', 'Векторизация уперлась в heap', '{"мс"}', 'comparison', '{"heap","orca","pg_vexec"}', 's1', 4, 'obs_cb_std_heap_vexec', 'lower');
INSERT INTO datasets (id, types, name, measure, condition, units, series_kind, subjects, section, observation_count) VALUES ('bench_cmp_1024', '{"kgo:MeasurementSet","qb:DataSet"}', 'время сравнения 1024 строк: Автовекторизация компилятора, Ручная векторизация сравнений на SSE2 с movemask', 'время сравнения 1024 строк', 'Как уменьшал среднее время запроса от 715 до 49 миллисекунд', '{"нс"}', 'comparison', '{"auto_vectorization","simd_movemask"}', 's2', 2);
INSERT INTO datasets (id, types, name, measure, condition, units, series_kind, subjects, section, observation_count) VALUES ('bench_final_laptop', '{"kgo:Benchmark","kgo:Experiment","kgo:MeasurementSet","qb:DataSet"}', 'среднее геометрическое время запроса ClickBench: ClickHouse, PostgreSQL', 'среднее геометрическое время запроса ClickBench', 'Мой PostgreSQL', '{"мс","раз","раза"}', 'comparison', '{"clickhouse","postgresql"}', 's5', 4);
INSERT INTO datasets (id, types, name, measure, condition, units, series_kind, subjects, section, observation_count, best_observation, better_is) VALUES ('bench_lazy_columns', '{"kgo:Benchmark","kgo:Experiment","kgo:MeasurementSet","qb:DataSet"}', 'время выполнения запроса q23 clickbench: один поток, без дочитывания колонок после первого условия, один поток, с дочитыванием колонок после первого условия', 'время выполнения запроса q23 clickbench', 'Как уменьшал среднее время запроса от 715 до 49 миллисекунд', '{"мс"}', 'conditions', '{"lazy_column_read"}', 's2', 2, 'obs_q23_after', 'lower');
INSERT INTO datasets (id, types, name, measure, condition, units, series_kind, subjects, section, observation_count) VALUES ('bench_lowcard_disk', '{"kgo:MeasurementSet","qb:DataSet"}', 'объем таблицы на диске: MergeTree с LowCardinality, мелкими гранулами и без сжатия, исходная таблица MergeTree', 'объем таблицы на диске', 'Как уменьшал среднее время запроса от 715 до 49 миллисекунд', '{"гб"}', 'conditions', '{"mergetree"}', 's2', 2);
INSERT INTO datasets (id, types, name, measure, condition, units, series_kind, subjects, section, observation_count, best_observation, better_is) VALUES ('bench_lowcard_q10', '{"kgo:Benchmark","kgo:Experiment","kgo:MeasurementSet","qb:DataSet"}', 'время запроса q10 clickbench: один поток, без словаря LowCardinality, один поток, колонки приходят индексами словаря LowCardinality', 'время запроса q10 clickbench', 'Как уменьшал среднее время запроса от 715 до 49 миллисекунд', '{"мс"}', 'conditions', '{"low_cardinality"}', 's2', 2, 'obs_q10_after', 'lower');
INSERT INTO datasets (id, types, name, measure, condition, units, series_kind, subjects, section, observation_count, best_observation, better_is) VALUES ('bench_parts_35', '{"kgo:Benchmark","kgo:Experiment","kgo:MeasurementSet","qb:DataSet"}', 'время запросов clickbench на исходной таблице: 35 частей: сервер перезапущен до конца слияний, слияния завершены (три части вместо 35)', 'время запросов clickbench на исходной таблице', 'Как уменьшал среднее время запроса от 715 до 49 миллисекунд', '{"мс"}', 'conditions', '{"data_part"}', 's2', 2, 'obs_parts3_time', 'lower');
INSERT INTO datasets (id, types, name, measure, condition, units, series_kind, subjects, section, observation_count) VALUES ('bench_q28_regex', '{"kgo:Benchmark","kgo:Experiment","kgo:MeasurementSet","qb:DataSet"}', 'экономия времени по всему ClickBench: Ядро-вычислитель, привязанное к OID функции, Повторное построение DFA движком регулярных выражений PostgreSQL', 'экономия времени по всему ClickBench', 'Как уменьшал среднее время запроса от 715 до 49 миллисекунд', '{"%","мс"}', 'comparison', '{"oid_kernel","regex_dfa_rebuild"}', 's2', 4);
INSERT INTO datasets (id, types, name, measure, condition, units, series_kind, subjects, section, observation_count) VALUES ('bench_skip_simulation', '{"kgo:Benchmark","kgo:Experiment","kgo:MeasurementSet","qb:DataSet"}', 'время запроса Q20 ClickBench: heap без пропуска страниц, симуляция пропуска ненужных страниц heap', 'время запроса Q20 ClickBench', 'Векторизация уперлась в heap', '{"мс","раз"}', 'conditions', '{"heap"}', 's1', 3);
INSERT INTO datasets (id, types, name, measure, condition, units, series_kind, subjects, section, observation_count, best_observation, better_is) VALUES ('bench_tpcds_orca', '{"kgo:Benchmark","kgo:Experiment","kgo:MeasurementSet","qb:DataSet"}', 'сумма времени запросов tpc-ds: heap (штатное хранилище таблиц PostgreSQL), MergeTree (движок таблиц ClickHouse)', 'сумма времени запросов tpc-ds', 'Мне бы очередной колоночный велосипед', '{"с"}', 'comparison', '{"heap","mergetree"}', 's3', 3, 'obs_tpcds_mt_vexec', 'lower');
INSERT INTO datasets (id, types, name, measure, condition, units, series_kind, subjects, section, observation_count) VALUES ('bench_tpcds_q2_fix', '{"kgo:Benchmark","kgo:Experiment","kgo:MeasurementSet","qb:DataSet"}', 'время запроса TPC-DS Q2: VecHashJoin без ветки для T_TargetEntry, до фикса ветки T_TargetEntry, после фикса ветки T_TargetEntry в одну строку', 'время запроса TPC-DS Q2', 'Как уменьшал среднее время запроса от 715 до 49 миллисекунд', '{"батчей","мс"}', 'conditions', '{"vec_hash_join"}', 's2', 3);
INSERT INTO datasets (id, types, name, measure, condition, units, series_kind, subjects, section, observation_count, best_observation, better_is) VALUES ('bench_tpch_sf1_orca', '{"kgo:Benchmark","kgo:Experiment","kgo:MeasurementSet","qb:DataSet"}', 'сумма времени запросов tpc-h sf1: heap (штатное хранилище таблиц PostgreSQL), MergeTree (движок таблиц ClickHouse)', 'сумма времени запросов tpc-h sf1', 'Мне бы очередной колоночный велосипед', '{"с"}', 'comparison', '{"heap","mergetree"}', 's3', 3, 'obs_tpch_mt_vexec', 'lower');
INSERT INTO datasets (id, types, name, measure, condition, units, series_kind, subjects, section, observation_count) VALUES ('bench_vecsort_fix', '{"kgo:Benchmark","kgo:Experiment","kgo:MeasurementSet","qb:DataSet"}', 'время запроса SELECT * FROM hits ORDER BY CounterID LIMIT 10: до фикса VecSort, после фикса VecSort, режим force, до фикса', 'время запроса SELECT * FROM hits ORDER BY CounterID LIMIT 10', 'Как уменьшал среднее время запроса от 715 до 49 миллисекунд', '{"мс","с"}', 'conditions', '{"vec_sort"}', 's2', 3);
INSERT INTO datasets (id, types, name, measure, condition, units, series_kind, subjects, section, observation_count) VALUES ('heap_page_geometry', '{"kgo:Benchmark","kgo:Experiment","kgo:MeasurementSet","qb:DataSet"}', 'число колонок, которые нужно достать запросу: heap, батч из 1024 строк, строка около 1,4 КБ, примерно, heap, строка около 1,4 КБ, из 105 колонок таблицы теста ClickBench, таблица теста ClickBench в heap, около', 'число колонок, которые нужно достать запросу', 'Векторизация уперлась в heap', '{"кб","колонки","страниц","строк"}', 'conditions', '{"heap"}', 's1', 4);
INSERT INTO datasets (id, types, name, measure, condition, units, series_kind, subjects, section, observation_count) VALUES ('prof_vexec_heap', '{"kgo:Benchmark","kgo:Experiment","kgo:MeasurementSet","qb:DataSet"}', 'доля: heap (штатное хранилище таблиц PostgreSQL), Ядро-вычислитель, привязанное к OID функции, pg_vexec', 'доля', 'Векторизация уперлась в heap', '{"%"}', 'comparison', '{"heap","oid_kernel","pg_vexec"}', 's1', 4);

INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('02836345e3d8', 'rep11', 'habr-1097022', 'describing', false, 's1', 70, 'Ты конечно советчик Капитан Очевидность) На немодифицированном PostgreSQL19 у vexec не нашлось ни одного источника, который бы отдавал данные поколоночно.', 'х для PostgreSQL с десяток.

-- ', ' Citus columnar и Hydra внутри к', 3975, 4129);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('0394c5737834', 'obs_q28_before', 'habr-1097022', 'describing', false, 's2', 88, 'сделали время выполнения для Q28 более чем в пять раз меньше - с 1090 до 213мс', 'ация с разделами в общей памяти ', '. А по всему ClickBench сэкономи', 6400, 6478);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('03ca9e3b9521', 'greenplum', 'habr-1097022', 'identifying', false, 's1', 54, 'стоимостный планировщик Greenplum', 'достался ORCA на PostgreSQL19 - ', '. Сверху оптимизатора запросов р', 2134, 2167);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('04b17c33da56', 'proc_iheap_update.t4', 'habr-1097022', 'describing', false, 's4', 115, 'собирает ее оттуда только тот читатель, чьему снимку она нужна', 'рая версия уходит в undo log, и ', '.

Идейно похоже на проект zheap', 9418, 9480);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('04c93eaeb123', 'rep02', 'habr-1097022', 'describing', false, 'body', 40, 'Зачем? Просто возьми ClickHouse и не мучайся.', 'нного исполнителя запросов.

-- ', '

-- Затем что мне нужны JOIN ме', 1390, 1435);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('053205c8203c', 'ev_drop_bicycle', 'habr-1097022', 'describing', false, 's3', 94, 'Я так и начинал со своего велосипеда, но быстро выбросил его на металлолом.', 'очередной колоночный велосипед

', ' MergeTree испытан годами в поль', 7119, 7194);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('06802d2f39ad', 'obs_q20_skip_sim', 'habr-1097022', 'describing', false, 's1', 66, 'Q20 с 510 до 5.3мс', 'запросы ClickBench в 8-100 раз (', '). Но это была лишь симуляция.

', 3856, 3874);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('071f16a39400', 'obs_tpcds_heap_std', 'habr-1097022', 'describing', false, 's3', 109, 'TPC-DS 380.5с против 58.8с', 'у heap со штатным исполнителем, ', '. С pg_vexec те же запросы на Me', 8680, 8706);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('077e310911c3', 'obs_submodules', 'habr-1097022', 'describing', false, 's3', 107, 'Из полутора сотен сабмодулей понадобилось лишь 28.', 'терпретатор, парсеры и функции. ', ' На выходе после статической лин', 7988, 8038);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('07aaf044b845', 'claim_no_columnar_source', 'habr-1097022', 'describing', false, 's1', 70, 'у vexec не нашлось ни одного источника, который бы отдавал данные поколоночно', 'немодифицированном PostgreSQL19 ', '. Citus columnar и Hydra внутри ', 4051, 4128);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('07dc0e20ca83', 'theme/bazy_dannykh', 'habr-1097022', 'classifying', false, 'fm', 19, '"Базы данных"', 'stgreSQL"
  - "Open source"
  - ', '
  - "Big Data"
  - "Программиро', 359, 372);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('080adb91f8c6', 'proc_iheap_update.t1', 'habr-1097022', 'describing', false, 's4', 115, 'перезаписывает строку на месте, по тому же TID', 'д доступа PostgreSQL 19 который ', '. Ее старая версия уходит в undo', 9332, 9378);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('08af8c71d472', 'libchte_engine', 'habr-1097022', 'identifying', false, 's3', 107, 'На выходе после статической линковки получается libchte_engine.so.', 'абмодулей понадобилось лишь 28. ', ' Взять готовый StorageMergeTree ', 8039, 8105);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('099599eb4f00', 'obs_q10_before', 'habr-1097022', 'describing', false, 's2', 86, 'Q10 в один поток 85.6мс вместо 148.2.', 'раз на каждое значение словаря. ', '

Движок регулярных выражений Po', 6163, 6200);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('0a05a2f1d5d3', 'pg_vexec', 'habr-1097022', 'identifying', false, 's1', 54, 'векторизованный исполнитель без единого патча ядра', '/habr.com/ru/articles/1091738/) ', '.

Его узлы VecScan, VecHashJoin', 2259, 2309);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('0a5520b5efb0', 'rel/6279b87a98f1', 'habr-1097022', 'linking', false, 's4', 115, 'iheap - табличный метод доступа PostgreSQL 19', 'ризнаю! Поэтому я и сделал свой ', ' который перезаписывает строку н', 9278, 9323);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('0d79068145b3', 'claim_skip_simulation', 'habr-1097022', 'describing', false, 's1', 66, 'Симуляция такого пропуска ускоряла те же запросы ClickBench в 8-100 раз', 'такой точки расширения не дает. ', ' (Q20 с 510 до 5.3мс). Но это бы', 3783, 3854);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('0e46b3a70c8b', 'obs_kernel_share', 'habr-1097022', 'describing', false, 's1', 62, 'ядра функций занимали только 0-2% от общего времени исполнения запроса', 'стил профилирование и понял что ', '. В зависимости от запроса разбо', 3128, 3198);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('0e7243084e39', 'obs_q28_after', 'habr-1097022', 'describing', false, 's2', 88, 'сделали время выполнения для Q28 более чем в пять раз меньше - с 1090 до 213мс', 'ация с разделами в общей памяти ', '. А по всему ClickBench сэкономи', 6400, 6478);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('0e7a03348265', 'ev_first_clickbench', 'habr-1097022', 'describing', false, 's1', 58, 'Первый замер на ClickBench меня не порадовал, векторизация не сильно помогла в ускорении.', 'й постгреса прямо внутри узла.

', ' На стандартном планировщике на ', 2763, 2852);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('0ee9fd77035d', 'claim_process_model', 'habr-1097022', 'describing', false, 's3', 107, 'а постгрес на каждое соединение создает отдельный процесс', 'e directory is already running" ', '. Поэтому понадобилась своя синя', 8330, 8387);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('105d534ebe86', 'art_cloudberry_pg19', 'habr-1097022', 'identifying', false, 's1', 54, '[Apache Cloudberry на PostgreSQL 19](https://habr.com/ru/articles/1088264/)', ' этого началась когда я перенес ', ' в виде набора расширений и мне ', 1995, 2070);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('1118efbd6171', 'claim_iheap_compat', 'habr-1097022', 'describing', false, 's4', 126, 'логическая репликация работают как у любой таблицы', 'е после сбоя, реплики, бэкапы и ', '. Блокировки строк - тоже undo-з', 10126, 10176);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('12b713a07687', 'ev_false_slowdown', 'habr-1097022', 'describing', false, 's2', 90, 'замедление оказалось вовсе не в опциях', 'сто съело отключенное сжатие, а ', ': стенд перезапускал сервер до к', 6715, 6753);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('12da691c6f7b', 'claim_pax_aoco_patched', 'habr-1097022', 'describing', false, 's1', 70, 'кроме расширений у порта есть и серия патчей ядра', 'патченном ядре порта постгреса: ', '. Порт конечно на 16 сегментах g', 4316, 4365);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('12ee20ab5e3d', 'rep01', 'habr-1097022', 'describing', false, 'body', 38, 'Мне удалось вставить табличный движок MergeTree из ClickHouse в PostgreSQL табличным методом доступа', ' занимался последнее время.

-- ', ', на ванильное ядро СУБД без фор', 1191, 1291);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('140d3fc34dfa', 'obs_ratio_ext', 'habr-1097022', 'describing', false, 's5', 134, 'всего в 3 раза медленнее чем на ClickHouse с теми же данными на той же машине', 'росы ClickBench на 10 млн строк ', ': 49.9мс против 16.8мс по средне', 11151, 11228);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('158524a7e7f1', 'clickbench', 'habr-1097022', 'identifying', false, 's1', 58, 'Первый замер на ClickBench меня не порадовал', 'й постгреса прямо внутри узла.

', ', векторизация не сильно помогла', 2763, 2807);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('17dabe8b2d46', 'rep13', 'habr-1097022', 'describing', false, 's3', 107, 'Не просто. MergeTree отдельно не собирается, он часть dbms ClickHouse и тянет за собой интерпретатор, парсеры и функции.', 'House с бэкэндом постгреса?

-- ', ' Из полутора сотен сабмодулей по', 7867, 7987);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('1882876c3480', 'rel/af96f21a57e4', 'habr-1097022', 'linking', false, 's1', 56, 'ORCA оценивает векторные узлы своей моделью стоимости.', 'с обычными узлами по стоимости. ', ' Внутри исполнитель обрабатывает', 2470, 2524);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('1969ba188e97', 'vec_hash_join', 'habr-1097022', 'classifying', false, 's2', 80, 'В итоге VecHashJoin читал строчного потомка по одной строке', 'е было ветки для T_TargetEntry. ', ' и TPC-DS Q2 из-за этого собирал', 5357, 5416);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('196f14be8799', 'claim_slowdown_cause', 'habr-1097022', 'describing', false, 's2', 90, 'Место съело отключенное сжатие, а замедление оказалось вовсе не в опциях', 'а 11.8ГБ на диске вместо 4.8ГБ. ', ': стенд перезапускал сервер до к', 6681, 6753);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('1a8426732885', 'low_cardinality', 'habr-1097022', 'classifying', false, 's2', 86, 'а выражения считаются один раз на каждое значение словаря', 'ексов в словаре LowCardinality, ', '. Q10 в один поток 85.6мс вместо', 6104, 6161);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('1b4e0613da83', 'theme/vektorizovannoe_ispolnenie_zaprosov_v_postgresql', 'habr-1097022', 'classifying', false, 's1', 54, 'векторизованный исполнитель без единого патча ядра', '/habr.com/ru/articles/1091738/) ', '.

Его узлы VecScan, VecHashJoin', 2259, 2309);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('1b9ab11b6d2d', 'orca', 'habr-1097022', 'identifying', false, 's1', 54, 'мне достался ORCA на PostgreSQL19 - стоимостный планировщик Greenplum', '64/) в виде набора расширений и ', '. Сверху оптимизатора запросов р', 2098, 2167);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('1efcc96be0b2', 'obs_cb_mt_first', 'habr-1097022', 'describing', false, 's2', 76, 'Первая же, еще неоптимизированная версия MergeTree вместе с pg_vexec сразу снизила среднее геометрическое время выполнения запроса', 'проса от 715 до 49 миллисекунд

', ' с 715мс у heap без векторизации', 4720, 4850);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('1efe743fc591', 'work', 'habr-1097022', 'describing', false, 'fm', 2, 'title: "Мой PostgreSQL быстрее твоего и почти догнал ClickHouse"', '---
', '
published: 2026-10-21T06:00:36
', 4, 68);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('1f0ada65dac8', 'rel/77dafbc24f44', 'habr-1097022', 'linking', false, 's4', 126, 'в расширении живет dmbtree форк btree из PG19', 'и не трогало остальные индексы, ', ', который умеет помечать старую ', 10327, 10372);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('218b9667cad8', 'rel/dc1055132d00', 'habr-1097022', 'linking', false, 'body', 32, 'PostgreSQL для OLTP, в ClickHouse у него лежат данные OpenTelemetry и веб аналитики', 'роде четыре разных базы данных. ', ', Elasticsearch для полнотекстов', 745, 828);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('232b2d27dff9', 'proc_lazy_scan.t4', 'habr-1097022', 'describing', false, 's2', 84, 'а остальные дочитывает только для батчей, где после первого условия остались строки', 'данных колонки первого условия, ', '. В запросе Q23 в один поток это', 5829, 5912);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('23f8f457cc81', 'proc_optimization_cycle.t2', 'habr-1097022', 'describing', false, 's2', 88, 'а в Q28 его функция miss() съедала 36% тактов', 'т DFA заново при каждом вызове, ', '. Собственное ядро в векторизато', 6278, 6323);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('24b8f21a3233', 'att_author_trust_mergetree', 'habr-1097022', 'describing', false, 's3', 94, 'MergeTree испытан годами в пользовательской аналитике под реальной нагрузкой и запросами бизнеса.', 'тро выбросил его на металлолом. ', ' Ну и конечно же в ClickBench не', 7195, 7292);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('25efa995f1ae', 'theme/postgresql', 'habr-1097022', 'classifying', false, 'fm', 17, '"PostgreSQL"', 'otesCountMinus: 0
hub_tags:
  - ', '
  - "Open source"
  - "Базы дан', 324, 336);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('2612f67af997', 'mergetree', 'habr-1097022', 'classifying', false, 's3', 94, 'форматов данных ClickHouse, фоновой сортировки и слияний в хранилище', ' под которые этот тест писался: ', '.

Теперь в постгресе можно запу', 7389, 7457);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('29a776b07348', 'auto_vectorization', 'habr-1097022', 'classifying', false, 's2', 78, 'векторизовался ровно один цикл и ни одного сравнения', 'ает PGXS, почти ничего не дала: ', '. После переписывания с помощью ', 5102, 5154);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('29c944b0f247', 'claim_not_all_steps', 'habr-1097022', 'describing', false, 's2', 90, 'Если честно, не все шаги вели к улучшениям.', 'ему ClickBench сэкономили 16%.

', ' Таблица с LowCardinality, мелки', 6519, 6562);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('2a7d9abb1f89', 'work', 'habr-1097022', 'describing', false, 's5', 136, 'Старичок PostgreSQL еще может потягаться с современными базами данных в проектах из обычной жизни!', 'дронного коллайдера или Google. ', '
', 12039, 12137);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('2b35c342ff50', 'obs_final_pg', 'habr-1097022', 'describing', false, 's5', 134, '49.9мс против 16.8мс по среднему геометрическому', 'ми же данными на той же машине: ', '. Ванильный постгрес при запуска', 11230, 11278);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('2e6ac8a55159', 'rel/3ae6d8357cee', 'habr-1097022', 'linking', false, 's3', 96, 'Теперь в постгресе можно запустить ch_table_engines и получить хранилище', 'тировки и слияний в хранилище.

', ', заточенное под анализ логов се', 7460, 7532);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('2eb941601951', 'obs_cmp_sse2', 'habr-1097022', 'describing', false, 's2', 78, 'сравнение 1024 строк уже занимало 82нс вместо 426', 'щью нейронки на SSE2 с movemask ', '.

В коде, который решает, может', 5214, 5263);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('2fa0d6303eac', 'vec_hash_join', 'habr-1097022', 'classifying', false, 's2', 80, 'В коде, который решает, может ли выражение бросить ошибку не было ветки для T_TargetEntry.', ' уже занимало 82нс вместо 426.

', ' В итоге VecHashJoin читал строч', 5266, 5356);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('2fcf3951599e', 'claim_not_standalone', 'habr-1097022', 'describing', false, 's3', 107, 'тянет за собой интерпретатор, парсеры и функции', 'тся, он часть dbms ClickHouse и ', '. Из полутора сотен сабмодулей п', 7939, 7986);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('308b520593af', 'claim_final_result', 'habr-1097022', 'describing', false, 's5', 134, 'запускать запросы ClickBench на 10 млн строк всего в 3 раза медленнее чем на ClickHouse с теми же данными на той же машине', 'а своем ноутбуке в PostgreSQL19 ', ': 49.9мс против 16.8мс по средне', 11106, 11228);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('30adce98cccb', 'obs_q23_before', 'habr-1097022', 'describing', false, 's2', 84, 'В запросе Q23 в один поток это уменьшило время выполнения с 471 до 247мс.', 'ервого условия остались строки. ', '

Колонки с небольшим числом раз', 5914, 5987);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('313db12ffec8', 'rel/f159dc55029f', 'habr-1097022', 'linking', false, 's3', 96, 'Теперь в постгресе можно запустить ch_table_engines', 'тировки и слияний в хранилище.

', ' и получить хранилище, заточенно', 7460, 7511);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('31cc2eed5c8e', 'claim_first_version_biggest', 'habr-1097022', 'describing', false, 's2', 90, 'Самое большое ускорение для pg_vexec было при первоначальной работе с MergeTree', ' частях давала 106мс против 71. ', ', а дальше прогресс был медленны', 6898, 6977);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('3270988d9d6d', 'background_merge', 'habr-1097022', 'classifying', false, 's2', 90, 'стенд перезапускал сервер до конца слияний', 'ие оказалось вовсе не в опциях: ', ', и запросы читали 35 частей вме', 6755, 6797);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('33ea478d127e', 'proc_iheap_update.t2', 'habr-1097022', 'describing', false, 's4', 115, 'Ее старая версия уходит в undo log', 'троку на месте, по тому же TID. ', ', и собирает ее оттуда только то', 9380, 9414);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('342dd7364ab3', 'obs_parts35_time', 'habr-1097022', 'describing', false, 's2', 90, 'Даже исходная таблица на 35 частях давала 106мс против 71.', 'ы читали 35 частей вместо трех. ', ' Самое большое ускорение для pg_', 6839, 6897);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('34a9d9d03807', 'batch', 'habr-1097022', 'classifying', false, 's1', 56, 'Внутри исполнитель обрабатывает батчи данных по 1024 строки в колоночном виде', 'е узлы своей моделью стоимости. ', ' ядрами-вычислителями, привязанн', 2525, 2602);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('3667aa757a53', 'claim_specialized_complexity', 'habr-1097022', 'describing', false, 's5', 136, 'Специализированная база это сложности в разработке и поддержке, если масштаб данных не телеметрия Большого адронного коллайдера или Google.', 'режнему занимается PostgreSQL.

', ' Старичок PostgreSQL еще может п', 11899, 12038);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('3671b815b538', 'tpc_ds', 'habr-1097022', 'identifying', false, 's3', 109, 'TPC-DS 380.5с против 58.8с', 'у heap со штатным исполнителем, ', '. С pg_vexec те же запросы на Me', 8680, 8706);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('38b36c59b872', 'proc_optimization_cycle.t1', 'habr-1097022', 'describing', false, 's2', 76, 'началась обычная программистская жизнь: профилирование, гипотезы', ' 5 октября до 148мс. После чего ', ', прототипирование и откат измен', 4923, 4987);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('3ba98be0d6ad', 'obs_final_ch', 'habr-1097022', 'describing', false, 's5', 134, '49.9мс против 16.8мс по среднему геометрическому', 'ми же данными на той же машине: ', '. Ванильный постгрес при запуска', 11230, 11278);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('3ed9831ec3de', 'rep03', 'habr-1097022', 'describing', false, 'body', 42, 'Затем что мне нужны JOIN между множеством таблиц и согласованность данных в системе и одна привычная в разработке и поддержке платформа.', 'ми ClickHouse и не мучайся.

-- ', '

-- Так не бывает. Либо надежно', 1440, 1576);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('42b99154cd18', 'rel/8efd249f92ae', 'habr-1097022', 'linking', false, 's4', 117, 'Мне же удалось сделать подобное без патча ядра.', 'ти до ядра, но так и забросили. ', ' В PostgreSQL 19 для реализации ', 9577, 9624);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('4426954253f1', 'citus_columnar', 'habr-1097022', 'identifying', false, 's1', 70, 'Citus columnar и Hydra внутри колоночные', ' бы отдавал данные поколоночно. ', ', а наружу через tableAM API отд', 4130, 4170);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('45245d1b5799', 'partitioned_shared_agg', 'habr-1097022', 'classifying', false, 's2', 88, 'Собственное ядро в векторизаторе плюс агрегация с разделами в общей памяти', 'кция miss() съедала 36% тактов. ', ' сделали время выполнения для Q2', 6325, 6399);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('458ffe036e91', 'vectorized_execution', 'habr-1097022', 'classifying', false, 's1', 56, 'Внутри исполнитель обрабатывает батчи данных по 1024 строки в колоночном виде', 'е узлы своей моделью стоимости. ', ' ядрами-вычислителями, привязанн', 2525, 2602);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('461c31d6771b', 'claim_mergetree_without_vexec', 'habr-1097022', 'describing', false, 's3', 109, 'Без векторизованного исполнителя MergeTree проигрывал даже heap', 'ном исполнителе постгреса мало. ', ': под ORCA сумма запросов TPC-H ', 8530, 8593);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('466aa22085ac', 'obs_cmp_autovec', 'habr-1097022', 'describing', false, 's2', 78, 'сравнение 1024 строк уже занимало 82нс вместо 426', 'щью нейронки на SSE2 с movemask ', '.

В коде, который решает, может', 5214, 5263);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('47a76dab9023', 'postgresql', 'habr-1097022', 'identifying', false, 's4', 117, 'В PostgreSQL 19 для реализации хватает штатных механизмов СУБД', 'делать подобное без патча ядра. ', ', от собственного менеджера ресу', 9625, 9687);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('4a2630b61734', 'proc_optimization_cycle.t3', 'habr-1097022', 'describing', false, 's2', 78, 'После переписывания с помощью нейронки на SSE2 с movemask', 'дин цикл и ни одного сравнения. ', ' сравнение 1024 строк уже занима', 5156, 5213);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('4a822d8418bf', 'proc_optimization_cycle.t6', 'habr-1097022', 'describing', false, 's2', 90, 'не все шаги вели к улучшениям', 'h сэкономили 16%.

Если честно, ', '. Таблица с LowCardinality, мелк', 6532, 6561);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('4bd2fbf6cee5', 'regex_dfa_rebuild', 'habr-1097022', 'classifying', false, 's2', 88, 'а в Q28 его функция miss() съедала 36% тактов', 'т DFA заново при каждом вызове, ', '. Собственное ядро в векторизато', 6278, 6323);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('4c4051889c42', 'claim_not_standalone', 'habr-1097022', 'describing', false, 's3', 107, 'Из полутора сотен сабмодулей понадобилось лишь 28.', 'терпретатор, парсеры и функции. ', ' На выходе после статической лин', 7988, 8038);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('4cd1e0f4a600', 'heap', 'habr-1097022', 'classifying', false, 's1', 66, 'Пропустить ненужные страницы тоже нечем: heap такой точки расширения не дает.', 'ок нужных для запроса колонок.

', ' Симуляция такого пропуска ускор', 3705, 3782);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('4e15078bbc76', 'low_cardinality', 'habr-1097022', 'classifying', false, 's2', 86, 'Колонки с небольшим числом различных значений теперь приходят в pg_vexec в виде индексов в словаре LowCardinality', 'емя выполнения с 471 до 247мс.

', ', а выражения считаются один раз', 5989, 6102);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('4f56df5d635f', 'rep09', 'habr-1097022', 'describing', false, 's1', 62, 'Ну я запустил профилирование и понял что ядра функций занимали только 0-2% от общего времени исполнения запроса.', 'оило городить векторизацию?

-- ', ' В зависимости от запроса разбор', 3087, 3199);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('4f5fe652f9ab', 'heap', 'habr-1097022', 'classifying', false, 's1', 64, 'heap честно поднимает страницы в память целиком', 'колонки из 105 в таблице теста, ', '. Табличный API постгреса отдает', 3528, 3575);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('4fded83bc67f', 'google', 'habr-1097022', 'identifying', false, 's5', 136, 'Большого адронного коллайдера или Google', 'ли масштаб данных не телеметрия ', '. Старичок PostgreSQL еще может ', 11997, 12037);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('4ff38bcf24fc', 'obs_tpcds_mt_std', 'habr-1097022', 'describing', false, 's3', 109, 'TPC-DS 380.5с против 58.8с', 'у heap со штатным исполнителем, ', '. С pg_vexec те же запросы на Me', 8680, 8706);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('50f00830ce66', 'rep14', 'habr-1097022', 'describing', false, 's4', 113, 'Ладно аналитика. Но признай что постгрес на обновлении данных при длительных транзакциях это боль.', 'UPDATE не раздувает таблицу

-- ', ' Каждый UPDATE новая версия стро', 8913, 9011);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('51e51772a71f', 'ev_cloudberry_port', 'habr-1097022', 'describing', false, 's1', 54, 'когда я перенес [Apache Cloudberry на PostgreSQL 19](https://habr.com/ru/articles/1088264/) в виде набора расширений', 'ых.

Предыстория этого началась ', ' и мне достался ORCA на PostgreS', 1979, 2095);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('52312694a8d8', 'ev_restart_before_merges', 'habr-1097022', 'describing', false, 's2', 90, 'стенд перезапускал сервер до конца слияний, и запросы читали 35 частей вместо трех', 'ие оказалось вовсе не в опциях: ', '. Даже исходная таблица на 35 ча', 6755, 6837);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('53ef2c8cf1fd', 'obs_ratio_vanilla', 'habr-1097022', 'describing', false, 's5', 134, 'Ванильный постгрес при запусках был в 39 раз медленнее кликхауса.', 'мс по среднему геометрическому. ', ' Получился свой набор расширений', 11280, 11345);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('54b9a5b9005a', 'proc_iheap_update', 'habr-1097022', 'describing', false, 's4', 115, 'iheap - табличный метод доступа PostgreSQL 19 который перезаписывает строку на месте', 'ризнаю! Поэтому я и сделал свой ', ', по тому же TID. Ее старая верс', 9278, 9362);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('56121a062037', 'obs_q2_before', 'habr-1097022', 'describing', false, 's2', 80, 'Фикс в одну строку дал 1246мс вместо исходных 3447.', '2153556 батчей из одной строки. ', '

В режиме auto планировщик не с', 5481, 5532);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('56843b56b3be', 'proc_optimization_cycle.t4', 'habr-1097022', 'describing', false, 's2', 80, 'Фикс в одну строку дал 1246мс вместо исходных 3447.', '2153556 батчей из одной строки. ', '

В режиме auto планировщик не с', 5481, 5532);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('56ede26d2514', 'claim_row_locks_undo', 'habr-1097022', 'describing', false, 's4', 126, 'Блокировки строк - тоже undo-записи, так что нет ни MultiXact ни заморозки.', 'я работают как у любой таблицы. ', ' А чтобы обновление индексирован', 10178, 10253);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('59f2bdb138d0', 'postgresql', 'habr-1097022', 'identifying', false, 'body', 32, 'PostgreSQL для OLTP', 'роде четыре разных базы данных. ', ', в ClickHouse у него лежат данн', 745, 764);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('5ac2d98e3c10', 'columnar_storage', 'habr-1097022', 'classifying', false, 's1', 68, 'Их для PostgreSQL с десяток.', 'ак возьми колоночное хранилище. ', '

-- Ты конечно советчик Капитан', 3942, 3970);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('5e302a9605ec', 'contribution/6e735415ae0d', 'habr-1097022', 'describing', false, 's5', 132, 'в iheap таблицы так не раздуваются, как в heap', 'роблема при частых обновлениях: ', '. Если у тебя не бигтех зачем те', 10940, 10986);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('5efe1e8adcde', 'art_pg_vexec', 'habr-1097022', 'identifying', false, 's1', 54, '[pg_vexec](https://habr.com/ru/articles/1091738/)', 'птимизатора запросов разработал ', ' векторизованный исполнитель без', 2209, 2258);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('5fc38d61c1ee', 'claim_iheap_no_core_patch', 'habr-1097022', 'describing', false, 's4', 117, 'Мне же удалось сделать подобное без патча ядра.', 'ти до ядра, но так и забросили. ', ' В PostgreSQL 19 для реализации ', 9577, 9624);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('6038b0635358', 'obs_vecsort_cost', 'habr-1097022', 'describing', false, 's2', 82, 'в режиме force стоимость VecSort проваливалась в минус: -46403!', 'авил VecSort над узлом скана, а ', ' После фикса `SELECT * FROM hits', 5597, 5660);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('60f692075a12', 'proc_optimization_cycle', 'habr-1097022', 'describing', false, 's2', 76, 'После чего началась обычная программистская жизнь: профилирование, гипотезы, прототипирование и откат изменений.', 'ии в замере 5 октября до 148мс. ', '

Автовекторизация GCC на -O2, с', 4912, 5024);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('637477f5ad1e', 'elasticsearch', 'habr-1097022', 'identifying', false, 'body', 32, 'Elasticsearch для полнотекстового поиска в приложении', ' OpenTelemetry и веб аналитики, ', ', а MongoDB - "так исторически с', 830, 883);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('656289ab46bb', 'theme/odna_subd_protiv_zooparka_spetsializirovannykh_baz', 'habr-1097022', 'classifying', false, 's5', 136, 'Специализированная база это сложности в разработке и поддержке', 'режнему занимается PostgreSQL.

', ', если масштаб данных не телемет', 11899, 11961);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('66646c50a01b', 'obs_tpch_heap_std', 'habr-1097022', 'describing', false, 's3', 109, 'под ORCA сумма запросов TPC-H SF1 61.8с против 17.2с у heap со штатным исполнителем', 'MergeTree проигрывал даже heap: ', ', TPC-DS 380.5с против 58.8с. С ', 8595, 8678);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('66ce642d872e', 'apache_cloudberry', 'habr-1097022', 'identifying', false, 's1', 54, '[Apache Cloudberry на PostgreSQL 19](https://habr.com/ru/articles/1088264/)', ' этого началась когда я перенес ', ' в виде набора расширений и мне ', 1995, 2070);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('68a0a4851283', 'rel/de6351f0a632', 'habr-1097022', 'linking', false, 's3', 107, 'MergeTree отдельно не собирается, он часть dbms ClickHouse', 'эндом постгреса?

-- Не просто. ', ' и тянет за собой интерпретатор,', 7878, 7936);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('6971eee785db', 'obs_hash_check_share', 'habr-1097022', 'describing', false, 's1', 62, 'проверки значения в хеш-таблице 5%', ' съедал 51-86% тактов GROUP BY, ', '. Еще 26-47% уходило на копирова', 3277, 3311);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('6c1ef234ceac', 'obs_port_gp_ao', 'habr-1097022', 'describing', false, 's1', 70, 'Порт конечно на 16 сегментах gp_ao с ORCA + vexec выжимал 105мс', 'порта есть и серия патчей ядра. ', ' но это шестнадцать сегментов пр', 4367, 4430);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('6cc41efb1d82', 'proc_iheap_update.t3', 'habr-1097022', 'describing', false, 's4', 126, 'новая запись появляется только в индексах, чьи ключи изменились, а не во всех индексах таблицы', 'мечать старую запись удаленной: ', '.

## Мой PostgreSQL

-- Ну хоро', 10422, 10516);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('6d7488206f14', 'rel/3ae6d8357cee', 'habr-1097022', 'linking', false, 'body', 38, 'вставить табличный движок MergeTree из ClickHouse в PostgreSQL табличным методом доступа', 'оследнее время.

-- Мне удалось ', ', на ванильное ядро СУБД без фор', 1203, 1291);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('6dc13b580fd6', 'architect_friend', 'habr-1097022', 'identifying', false, 'body', 32, 'Мой знакомый - отличный архитектор, но полнейший сноб.', '03f0359c4b82e370af263b9439c.png)', ' У него в проде четыре разных ба', 648, 702);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('6ecb374e21b3', 'obs_wide_rows_share', 'habr-1097022', 'describing', false, 's1', 62, 'В зависимости от запроса разбор широких строк съедал 51-86% тактов GROUP BY', 'его времени исполнения запроса. ', ', проверки значения в хеш-таблиц', 3200, 3275);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('6ff9dd8e4f2e', 'theme/open_source', 'habr-1097022', 'classifying', false, 'fm', 18, '"Open source"', '
hub_tags:
  - "PostgreSQL"
  - ', '
  - "Базы данных"
  - "Big Data', 341, 354);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('721b725028c4', 'obs_parts3_time', 'habr-1097022', 'describing', false, 's2', 90, 'Даже исходная таблица на 35 частях давала 106мс против 71.', 'ы читали 35 частей вместо трех. ', ' Самое большое ускорение для pg_', 6839, 6897);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('733171551995', 'igor_suhorukov#vcard', 'habr-1097022', 'identifying', false, 's5', 134, '[pg_vexec](https://github.com/igor-suhorukov/pg_vexec)', 'набор расширений для PostgreSQL ', ', [ch_table_engines](https://git', 11393, 11447);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('7518224037e9', 'mongodb', 'habr-1097022', 'identifying', false, 'body', 32, 'MongoDB - "так исторически сложилось"', 'кстового поиска в приложении, а ', '.

Между всем этим ETL, CDC вмес', 887, 924);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('7606ced68a38', 'att_author_zoo', 'habr-1097022', 'describing', false, 'body', 34, 'а для меня излишняя сложностью в поддержке и разработке', 'то все продуманная архитектура, ', '.

Недавно рассказал ему чем я з', 1074, 1129);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('76ea1a4befcd', 'opentelemetry', 'habr-1097022', 'identifying', false, 'body', 32, 'данные OpenTelemetry и веб аналитики', 'OLTP, в ClickHouse у него лежат ', ', Elasticsearch для полнотекстов', 792, 828);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('7762183390a8', 'rel/74e54dfd6491', 'habr-1097022', 'linking', false, 'body', 32, 'PostgreSQL для OLTP, в ClickHouse у него лежат данные OpenTelemetry и веб аналитики', 'роде четыре разных базы данных. ', ', Elasticsearch для полнотекстов', 745, 828);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('78e10a0524ee', 'cost_based_planner', 'habr-1097022', 'classifying', false, 's1', 56, 'соревнуются с обычными узлами по стоимости', 'ные механизмы расширения СУБД и ', '. ORCA оценивает векторные узлы ', 2426, 2468);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('78ebf4d3e752', 'claim_bottleneck_reading', 'habr-1097022', 'describing', false, 's1', 52, 'захлебывается в момент считывания данных', 'ация быстро молотит столбцы, но ', '.

Предыстория этого началась ко', 1909, 1949);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('79ae34cef7e7', 'rep12', 'habr-1097022', 'describing', false, 's3', 105, 'То есть ты просто слинковал ClickHouse с бэкэндом постгреса?', 'D'', storage = ''pages'');
```

-- ', '

-- Не просто. MergeTree отдель', 7802, 7862);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('7b620faf607d', 'rep07', 'habr-1097022', 'describing', false, 's1', 52, 'Векторизация быстро молотит столбцы, но захлебывается в момент считывания данных.', 'о. MergeTree-то тебе зачем?

-- ', '

Предыстория этого началась ког', 1869, 1950);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('7c16df9318ff', 'obs_row_size', 'habr-1097022', 'describing', false, 's1', 64, 'Если строка весит около 1.4КБ, на страницу помещается 5-6 строк', 'ходило на копирование страниц.

', ' и батч из 1024 строк размазан п', 3357, 3420);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('7f249b9fa5ca', 'claim_clickbench_tailored', 'habr-1097022', 'describing', false, 's3', 94, 'в ClickBench невозможно победить без технологий, под которые этот тест писался', 'росами бизнеса. Ну и конечно же ', ': форматов данных ClickHouse, фо', 7309, 7387);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('80c12ff3217f', 'mergetree', 'habr-1097022', 'classifying', false, 's3', 94, 'MergeTree испытан годами в пользовательской аналитике под реальной нагрузкой и запросами бизнеса.', 'тро выбросил его на металлолом. ', ' Ну и конечно же в ClickBench не', 7195, 7292);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('810fe5d73e7f', 'pgxs', 'habr-1097022', 'identifying', false, 's2', 78, 'с которым собирает PGXS', '.

Автовекторизация GCC на -O2, ', ', почти ничего не дала: векториз', 5055, 5078);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('8118cd0b723b', 'obs_q23_after', 'habr-1097022', 'describing', false, 's2', 84, 'В запросе Q23 в один поток это уменьшило время выполнения с 471 до 247мс.', 'ервого условия остались строки. ', '

Колонки с небольшим числом раз', 5914, 5987);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('837b41c7128c', 'vec_plan_node', 'habr-1097022', 'classifying', false, 's1', 56, 'Его узлы VecScan, VecHashJoin, VecAgg и VecSort попадают в план запроса через штатные механизмы расширения СУБД', 'нитель без единого патча ядра.

', ' и соревнуются с обычными узлами', 2312, 2423);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('863d16e9b00f', 'bloat', 'habr-1097022', 'classifying', false, 's4', 113, 'Каждый UPDATE новая версия строки, мертвые кортежи копятся и автовакуум пыхтит.', 'лительных транзакциях это боль. ', ' Для нас в начале эксплуатации с', 9012, 9091);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('885a0fb0987b', 'igor_suhorukov', 'habr-1097022', 'identifying', false, 'body', 36, 'Недавно рассказал ему чем я занимался последнее время.', 'стью в поддержке и разработке.

', '

-- Мне удалось вставить таблич', 1132, 1186);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('8a2715563cc6', 'geometric_mean', 'habr-1097022', 'classifying', false, 's5', 134, '49.9мс против 16.8мс по среднему геометрическому', 'ми же данными на той же машине: ', '. Ванильный постгрес при запуска', 11230, 11278);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('8a8915971166', 'obs_cb_orca_heap_pg', 'habr-1097022', 'describing', false, 's1', 58, 'а на ORCA на 18% с 1647 -\> 1349мс', 'а всего на 19% с 625 -\> 506мс, ', '.

-- 18%, серьезно? И ради этог', 2985, 3019);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('8b1c8ec5156e', 'claim_heap_update_pain', 'habr-1097022', 'describing', false, 's4', 113, 'Каждый UPDATE новая версия строки, мертвые кортежи копятся и автовакуум пыхтит.', 'лительных транзакциях это боль. ', ' Для нас в начале эксплуатации с', 9012, 9091);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('8b53ae64b911', 'oid_kernel', 'habr-1097022', 'classifying', false, 's1', 56, 'ядрами-вычислителями, привязанными к OID функции', 'о 1024 строки в колоночном виде ', '. Если специального ядра нет, вы', 2603, 2651);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('8bd23d86f8d3', 'theme/big_data', 'habr-1097022', 'classifying', false, 'fm', 20, '"Big Data"', 'n source"
  - "Базы данных"
  - ', '
  - "Программирование"
user_tag', 377, 387);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('8beaf3a86208', 'claim_friend_bloat', 'habr-1097022', 'describing', false, 's4', 113, 'Пришлось сокращать время транзакций и выносить аналитические запросы из постгреса.', 'емы bloat таблиц был проблемой. ', '

-- Признаю! Поэтому я и сделал', 9158, 9240);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('8c00a8321c55', 'claim_port_16_segments', 'habr-1097022', 'describing', false, 's1', 70, 'это шестнадцать сегментов против одного узла и все же форк ядра СУБД от которого хотелось уйти', 'с ORCA + vexec выжимал 105мс но ', '.

Так в моем плане появилась за', 4434, 4528);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('8d1679534374', 'proc_attach_storage.t3', 'habr-1097022', 'describing', false, 's5', 134, 'iheap для горячих обновлений без bloat таблиц и индексов', 'ee для метрик и широких таблиц, ', '. Реплики, pg_dump и MVCC работа', 11736, 11792);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('8d1ecde711a9', 'obs_cb_orca_heap_vexec', 'habr-1097022', 'describing', false, 's1', 58, 'а на ORCA на 18% с 1647 -\> 1349мс', 'а всего на 19% с 625 -\> 506мс, ', '.

-- 18%, серьезно? И ради этог', 2985, 3019);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('8e43961c90a9', 'obs_cb_std_heap_vexec', 'habr-1097022', 'describing', false, 's1', 58, 'На стандартном планировщике на heap pg_vexec уменьшил среднее геометрическое время выполнения запроса всего на 19% с 625 -\> 506мс', ' не сильно помогла в ускорении. ', ', а на ORCA на 18% с 1647 -\> 13', 2853, 2983);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('904b8108f73b', 'aoco', 'habr-1097022', 'identifying', false, 's1', 70, 'PAX и AOCO из гринплама живут только на пропатченном ядре порта постгреса', 'же самые слоты по одной строке. ', ': кроме расширений у порта есть ', 4241, 4314);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('91db8d3ba854', 'auto_vectorization', 'habr-1097022', 'classifying', false, 's2', 78, 'Автовекторизация GCC на -O2, с которым собирает PGXS, почти ничего не дала', 'типирование и откат изменений.

', ': векторизовался ровно один цикл', 5026, 5100);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('9224789fa609', 'ch_table_engines', 'habr-1097022', 'identifying', false, 's5', 134, '[ch_table_engines](https://github.com/igor-suhorukov/pg_ch_table_engines)', 'b.com/igor-suhorukov/pg_vexec), ', ' и [iheap](https://github.com/ig', 11449, 11522);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('9239cc30c2f1', 'proc_lazy_scan.t1', 'habr-1097022', 'describing', false, 's2', 84, 'Скан сначала просит у источника данных колонки первого условия', 'с вместо исходных 2.1 секунды.

', ', а остальные дочитывает только ', 5765, 5827);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('928a2934006b', 'claim_kernels_negligible', 'habr-1097022', 'describing', false, 's1', 62, 'В зависимости от запроса разбор широких строк съедал 51-86% тактов GROUP BY', 'его времени исполнения запроса. ', ', проверки значения в хеш-таблиц', 3200, 3275);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('952256e7937f', 'mvcc', 'habr-1097022', 'classifying', false, 's5', 134, 'Реплики, pg_dump и MVCC работают как у обычного heap, потому что ими по-прежнему занимается PostgreSQL.', 'ий без bloat таблиц и индексов. ', '

Специализированная база это сл', 11794, 11897);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('972295fe4e87', 'claim_custom_glue', 'habr-1097022', 'describing', false, 's3', 107, 'Поэтому понадобилась своя синяя изолента, чтобы примотать его к PostgreSQL.', 'ение создает отдельный процесс. ', '

Но толка от MergeTree в станда', 8389, 8464);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('97371d2371aa', 'obs_cb_heap_oct5', 'habr-1097022', 'describing', false, 's2', 76, 'с 715мс у heap без векторизации в замере 5 октября до 148мс', 'ческое время выполнения запроса ', '. После чего началась обычная пр', 4851, 4910);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('97832cacbc7b', 'proc_attach_storage.t1', 'habr-1097022', 'describing', false, 's3', 96, 'Теперь в постгресе можно запустить ch_table_engines', 'тировки и слияний в хранилище.

', ' и получить хранилище, заточенно', 7460, 7511);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('98c59fbeec88', 'claim_first_version_biggest', 'habr-1097022', 'describing', false, 's2', 90, 'а дальше прогресс был медленным и кропотливым', 'воначальной работе с MergeTree, ', ', с множеством развилок куда идт', 6979, 7024);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('98ce0d85e2c2', 'claim_iheap_no_bloat', 'habr-1097022', 'describing', false, 's5', 132, 'в iheap таблицы так не раздуваются, как в heap', 'роблема при частых обновлениях: ', '. Если у тебя не бигтех зачем те', 10940, 10986);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('98f34aff0a7a', 'rep06', 'habr-1097022', 'describing', false, 's1', 50, 'Ты же недавно портировал Greenplum в расширение для постгреса, а потом написал векторный исполнитель поверх него. MergeTree-то тебе зачем?', 'ия уперлась в heap

-- Подожди. ', '

-- Векторизация быстро молотит', 1726, 1864);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('9a34a1d132d6', 'claim_page_geometry', 'habr-1097022', 'describing', false, 's1', 64, 'heap честно поднимает страницы в память целиком', 'колонки из 105 в таблице теста, ', '. Табличный API постгреса отдает', 3528, 3575);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('9b3dff3c4e4a', 'bloat', 'habr-1097022', 'classifying', false, 's5', 134, 'для горячих обновлений без bloat таблиц и индексов', ' метрик и широких таблиц, iheap ', '. Реплики, pg_dump и MVCC работа', 11742, 11792);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('9b5f78f3e549', 'ch_table_engines', 'habr-1097022', 'identifying', false, 's3', 96, 'Теперь в постгресе можно запустить ch_table_engines и получить хранилище, заточенное под анализ логов сервера', 'тировки и слияний в хранилище.

', ':

``` sql
-- postgresql.conf: s', 7460, 7569);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('9bdf07d64b3b', 'claim_tableam_row_api', 'habr-1097022', 'describing', false, 's1', 64, 'Табличный API постгреса отдает строки по одной через слот, а scan_begin() даже не принимает список нужных для запроса колонок.', 'мает страницы в память целиком. ', '

Пропустить ненужные страницы т', 3577, 3703);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('9e7210367282', 'obs_q20_heap', 'habr-1097022', 'describing', false, 's1', 66, 'Q20 с 510 до 5.3мс', 'запросы ClickBench в 8-100 раз (', '). Но это была лишь симуляция.

', 3856, 3874);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('9f199893f3d4', 'rel/c8adba16917b', 'habr-1097022', 'linking', false, 'body', 32, 'Elasticsearch для полнотекстового поиска в приложении', ' OpenTelemetry и веб аналитики, ', ', а MongoDB - "так исторически с', 830, 883);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('a1f97bcb4c0e', 'ev_false_slowdown', 'habr-1097022', 'describing', false, 's2', 90, 'Таблица с LowCardinality, мелкими гранулами и без сжатия вдруг стала медленнее', ' не все шаги вели к улучшениям. ', ' и заняла 11.8ГБ на диске вместо', 6563, 6641);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('a26a626f2ee1', 'claim_tableam_row_api', 'habr-1097022', 'describing', false, 's1', 66, 'Пропустить ненужные страницы тоже нечем: heap такой точки расширения не дает.', 'ок нужных для запроса колонок.

', ' Симуляция такого пропуска ускор', 3705, 3782);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('a2a7795b1138', 'proc_optimization_cycle.t5', 'habr-1097022', 'describing', false, 's2', 88, 'А по всему ClickBench сэкономили 16%.', 'ь раз меньше - с 1090 до 213мс. ', '

Если честно, не все шаги вели ', 6480, 6517);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('a3ea2e30dc18', 'rel/84b79083df6b', 'habr-1097022', 'linking', false, 's2', 78, 'После переписывания с помощью нейронки на SSE2 с movemask', 'дин цикл и ни одного сравнения. ', ' сравнение 1024 строк уже занима', 5156, 5213);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('a4084ec37d06', 'obs_sort_before', 'habr-1097022', 'describing', false, 's2', 82, 'идет 67-76мс вместо исходных 2.1 секунды', 'ts ORDER BY CounterID LIMIT 10` ', '.

Скан сначала просит у источни', 5722, 5762);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('a443285d6a2e', 'obs_cb_saving_16', 'habr-1097022', 'describing', false, 's2', 88, 'А по всему ClickBench сэкономили 16%.', 'ь раз меньше - с 1090 до 213мс. ', '

Если честно, не все шаги вели ', 6480, 6517);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('a5a618b9a23a', 'architect_friend', 'habr-1097022', 'identifying', false, 'body', 32, 'У него в проде четыре разных базы данных.', ' архитектор, но полнейший сноб. ', ' PostgreSQL для OLTP, в ClickHou', 703, 744);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('a7dfb836f1da', 'theme/programmirovanie', 'habr-1097022', 'classifying', false, 'fm', 21, '"Программирование"', 'Базы данных"
  - "Big Data"
  - ', '
user_tags:
  - "tableAM"
  - "c', 392, 410);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('a8d8e419fe7e', 'columnar_storage', 'habr-1097022', 'classifying', false, 's3', 109, 'Без этой детали получалось колоночное хранилище, которое отдает данные построчно через слот, как медленный heap.', ' на MergeTree шли 6.9с и 48.6с. ', '

## UPDATE не раздувает таблицу', 8764, 8876);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('a961be18b7e6', 'rep16', 'habr-1097022', 'describing', false, 's5', 130, 'Ну хорошо. И зачем все это если ClickHouse все равно быстрее работает?', 'таблицы.

## Мой PostgreSQL

-- ', '

-- Затем что это отличная база', 10541, 10611);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('ab03d6e451d2', 'claim_process_model', 'habr-1097022', 'describing', false, 's3', 107, 'Взять готовый StorageMergeTree тоже нельзя с его многопоточной моделью одного серверного процесса.', 'и получается libchte_engine.so. ', ' При попытке доступа второго про', 8106, 8204);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('ab24f63c556b', 'inplace_update', 'habr-1097022', 'classifying', false, 's4', 115, 'который перезаписывает строку на месте, по тому же TID', 'ный метод доступа PostgreSQL 19 ', '. Ее старая версия уходит в undo', 9324, 9378);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('aba0ec07aec8', 'narr_dispute', 'habr-1097022', 'describing', false, 'body', 34, 'Для него это все продуманная архитектура', ' именно результаты не сходятся. ', ', а для меня излишняя сложностью', 1032, 1072);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('ac13be3d33ff', 'claim_iheap_no_bloat', 'habr-1097022', 'describing', false, 's5', 132, 'И длительная транзакция теперь не такая большая проблема при частых обновлениях', 'ostgreSQL, в единой транзакции. ', ': в iheap таблицы так не раздува', 10859, 10938);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('ac5466be0a5a', 'simd_movemask', 'habr-1097022', 'classifying', false, 's2', 78, 'После переписывания с помощью нейронки на SSE2 с movemask сравнение 1024 строк уже занимало 82нс вместо 426.', 'дин цикл и ни одного сравнения. ', '

В коде, который решает, может ', 5156, 5264);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('acef92ca00d9', 'undo_log', 'habr-1097022', 'classifying', false, 's4', 115, 'Ее старая версия уходит в undo log', 'троку на месте, по тому же TID. ', ', и собирает ее оттуда только то', 9380, 9414);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('ad9dad5ce272', 'ev_measure_oct5', 'habr-1097022', 'describing', false, 's2', 76, 'с 715мс у heap без векторизации в замере 5 октября до 148мс', 'ческое время выполнения запроса ', '. После чего началась обычная пр', 4851, 4910);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('adf9b8ce3677', 'claim_sim_only', 'habr-1097022', 'describing', false, 's1', 66, 'Но это была лишь симуляция.', '8-100 раз (Q20 с 510 до 5.3мс). ', '

-- Так возьми колоночное храни', 3877, 3904);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('ae53ce08a37e', 'rep10', 'habr-1097022', 'describing', false, 's1', 68, 'Так возьми колоночное хранилище. Их для PostgreSQL с десяток.', 'Но это была лишь симуляция.

-- ', '

-- Ты конечно советчик Капитан', 3909, 3970);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('ae719e43e98b', 'proc_attach_storage.t4', 'habr-1097022', 'describing', false, 's5', 134, 'Хранилище в базе просто выбирается стандартным синтаксисом `CREATE TABLE ... USING`', 'ate_am) и ни одного патча ядра. ', ' mergetree для метрик и широких ', 11613, 11696);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('aee57c2c0a19', 'large_hadron_collider', 'habr-1097022', 'identifying', false, 's5', 136, 'если масштаб данных не телеметрия Большого адронного коллайдера или Google', 'ности в разработке и поддержке, ', '. Старичок PostgreSQL еще может ', 11963, 12037);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('af4d3687092f', 'background_merge', 'habr-1097022', 'classifying', false, 's3', 94, 'фоновой сортировки и слияний в хранилище', 'ся: форматов данных ClickHouse, ', '.

Теперь в постгресе можно запу', 7417, 7457);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('b04b2958b21f', 'autovacuum', 'habr-1097022', 'classifying', false, 's4', 113, 'мертвые кортежи копятся и автовакуум пыхтит', 'дый UPDATE новая версия строки, ', '. Для нас в начале эксплуатации ', 9047, 9090);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('b09e80aa983e', 'proc_lazy_scan.t3', 'habr-1097022', 'describing', false, 's2', 84, 'а остальные дочитывает только для батчей', 'данных колонки первого условия, ', ', где после первого условия оста', 5829, 5869);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('b2613dd9d866', 'igor_suhorukov', 'habr-1097022', 'identifying', false, 'fm', 4, 'author: "igor_suhorukov"', '
published: 2026-10-21T06:00:36
', '
id: 1097022
postType: article
a', 100, 124);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('b417363fffbd', 'proc_iheap_update.t2', 'habr-1097022', 'describing', false, 's4', 126, 'Undo живет в экстентах основного слоя самой таблицы', ' -- перевести существующую
```

', ', поэтому WAL, восстановление по', 10015, 10066);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('b53454f2d943', 'obs_q2_after', 'habr-1097022', 'describing', false, 's2', 80, 'Фикс в одну строку дал 1246мс вместо исходных 3447.', '2153556 батчей из одной строки. ', '

В режиме auto планировщик не с', 5481, 5532);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('b57782244fbb', 'proc_attach_storage.e1', 'habr-1097022', 'describing', false, 's5', 134, 'Реплики, pg_dump и MVCC работают как у обычного heap', 'ий без bloat таблиц и индексов. ', ', потому что ими по-прежнему зан', 11794, 11846);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('b6dc6e65033c', 'rep17', 'habr-1097022', 'describing', false, 's5', 132, 'Затем что это отличная база данных для огромной таблицы метрик с сотнями колонок.', 'все равно быстрее работает?

-- ', ' А если в базе еще должны быть т', 10616, 10697);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('b6e7658abc64', 'rel/8c5d45efdc19', 'habr-1097022', 'linking', false, 'body', 32, 'У него в проде четыре разных базы данных.', ' архитектор, но полнейший сноб. ', ' PostgreSQL для OLTP, в ClickHou', 703, 744);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('b703454e6239', 'vec_sort', 'habr-1097022', 'classifying', false, 's2', 82, 'В режиме auto планировщик не ставил VecSort над узлом скана', 'л 1246мс вместо исходных 3447.

', ', а в режиме force стоимость Vec', 5534, 5593);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('b992bc4f6dfa', 'claim_iheap_compat', 'habr-1097022', 'describing', false, 's4', 126, 'Undo живет в экстентах основного слоя самой таблицы', ' -- перевести существующую
```

', ', поэтому WAL, восстановление по', 10015, 10066);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('ba16307227f2', 'proc_attach_storage.t2', 'habr-1097022', 'describing', false, 's5', 134, 'mergetree для метрик и широких таблиц', 'ксисом `CREATE TABLE ... USING` ', ', iheap для горячих обновлений б', 11697, 11734);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('ba65ec77cfdc', 'table_access_method', 'habr-1097022', 'classifying', false, 's1', 70, 'а наружу через tableAM API отдают те же самые слоты по одной строке', 'mnar и Hydra внутри колоночные, ', '. PAX и AOCO из гринплама живут ', 4172, 4239);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('ba767e16912a', 'proc_attach_storage', 'habr-1097022', 'describing', false, 's5', 134, 'Хранилище в базе просто выбирается стандартным синтаксисом', 'ate_am) и ни одного патча ядра. ', ' `CREATE TABLE ... USING` merget', 11613, 11671);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('bad620fb8021', 'claim_pax_aoco_patched', 'habr-1097022', 'describing', false, 's1', 70, 'PAX и AOCO из гринплама живут только на пропатченном ядре порта постгреса', 'же самые слоты по одной строке. ', ': кроме расширений у порта есть ', 4241, 4314);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('bb385f20b927', 'obs_q2_batches', 'habr-1097022', 'describing', false, 's2', 80, 'TPC-DS Q2 из-за этого собирал 2153556 батчей из одной строки', 'чного потомка по одной строке и ', '. Фикс в одну строку дал 1246мс ', 5419, 5479);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('bd9c3e71d215', 'rel/74e54dfd6491', 'habr-1097022', 'linking', false, 'body', 32, 'Elasticsearch для полнотекстового поиска в приложении', ' OpenTelemetry и веб аналитики, ', ', а MongoDB - "так исторически с', 830, 883);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('be961a1093bc', 'lazy_column_read', 'habr-1097022', 'classifying', false, 's2', 84, 'Скан сначала просит у источника данных колонки первого условия, а остальные дочитывает только для батчей', 'с вместо исходных 2.1 секунды.

', ', где после первого условия оста', 5765, 5869);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('bed27d82ab1b', 'rep08', 'habr-1097022', 'describing', false, 's1', 60, '18%, серьезно? И ради этого стоило городить векторизацию?', 'A на 18% с 1647 -\> 1349мс.

-- ', '

-- Ну я запустил профилировани', 3025, 3082);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('bed483e32318', 'proc_lazy_scan.t2', 'habr-1097022', 'describing', false, 's2', 84, 'где после первого условия остались строки', 'е дочитывает только для батчей, ', '. В запросе Q23 в один поток это', 5871, 5912);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('beeefa3616a5', 'obs_tpcds_mt_vexec', 'habr-1097022', 'describing', false, 's3', 109, 'С pg_vexec те же запросы на MergeTree шли 6.9с и 48.6с.', 'ем, TPC-DS 380.5с против 58.8с. ', ' Без этой детали получалось коло', 8708, 8763);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('c0312e96af6e', 'rel/4ae41ac5de1d', 'habr-1097022', 'linking', false, 's4', 113, 'Каждый UPDATE новая версия строки, мертвые кортежи копятся', 'лительных транзакциях это боль. ', ' и автовакуум пыхтит. Для нас в ', 9012, 9070);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('c0734a45c7ef', 'contribution/1402629605b6', 'habr-1097022', 'describing', false, 's2', 84, 'В запросе Q23 в один поток это уменьшило время выполнения с 471 до 247мс.', 'ервого условия остались строки. ', '

Колонки с небольшим числом раз', 5914, 5987);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('c12dbc53caec', 'att_friend_architecture', 'habr-1097022', 'describing', false, 'body', 34, 'Для него это все продуманная архитектура', ' именно результаты не сходятся. ', ', а для меня излишняя сложностью', 1032, 1072);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('c1523dc81f25', 'obs_q10_after', 'habr-1097022', 'describing', false, 's2', 86, 'Q10 в один поток 85.6мс вместо 148.2.', 'раз на каждое значение словаря. ', '

Движок регулярных выражений Po', 6163, 6200);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('c2791d4aedff', 'claim_final_result', 'habr-1097022', 'describing', false, 's5', 134, 'Реплики, pg_dump и MVCC работают как у обычного heap', 'ий без bloat таблиц и индексов. ', ', потому что ими по-прежнему зан', 11794, 11846);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('c2e0c0c8e035', 'work', 'habr-1097022', 'describing', false, 'fm', 3, 'published: 2026-10-21T06:00:36', 'оего и почти догнал ClickHouse"
', '
author: "igor_suhorukov"
id: 10', 69, 99);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('c39d449c21a2', 'proc_lazy_scan', 'habr-1097022', 'describing', false, 's2', 84, 'Скан сначала просит у источника данных колонки первого условия, а остальные дочитывает только для батчей', 'с вместо исходных 2.1 секунды.

', ', где после первого условия оста', 5765, 5869);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('c4961458be56', 'rel/8c5d45efdc19', 'habr-1097022', 'linking', false, 'body', 32, 'а MongoDB - "так исторически сложилось"', 'текстового поиска в приложении, ', '.

Между всем этим ETL, CDC вмес', 885, 924);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('c521bd6ca408', 'regex_dfa_rebuild', 'habr-1097022', 'classifying', false, 's2', 88, 'Движок регулярных выражений PostgreSQL строит DFA заново при каждом вызове', 'дин поток 85.6мс вместо 148.2.

', ', а в Q28 его функция miss() съе', 6202, 6276);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('c534d7ce7aa5', 'gp_ao', 'habr-1097022', 'identifying', false, 's1', 70, 'Порт конечно на 16 сегментах gp_ao с ORCA + vexec выжимал 105мс', 'порта есть и серия патчей ядра. ', ' но это шестнадцать сегментов пр', 4367, 4430);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('c672a078e40f', 'freezing', 'habr-1097022', 'classifying', false, 's4', 126, 'Блокировки строк - тоже undo-записи, так что нет ни MultiXact ни заморозки.', 'я работают как у любой таблицы. ', ' А чтобы обновление индексирован', 10178, 10253);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('c6a324fb36f5', 'obs_q28_miss_share', 'habr-1097022', 'describing', false, 's2', 88, 'а в Q28 его функция miss() съедала 36% тактов', 'т DFA заново при каждом вызове, ', '. Собственное ядро в векторизато', 6278, 6323);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('c7d55187f39e', 'contribution/bdbf96f3017f', 'habr-1097022', 'describing', false, 's2', 78, 'сравнение 1024 строк уже занимало 82нс вместо 426', 'щью нейронки на SSE2 с movemask ', '.

В коде, который решает, может', 5214, 5263);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('cc1c6a28c268', 'obs_pages_per_batch', 'habr-1097022', 'describing', false, 's1', 64, 'батч из 1024 строк размазан примерно по 180 страницам', 'страницу помещается 5-6 строк и ', '. Чтобы достать три колонки из 1', 3423, 3476);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('cc5cbfa3d933', 'obs_tpch_mt_std', 'habr-1097022', 'describing', false, 's3', 109, 'под ORCA сумма запросов TPC-H SF1 61.8с против 17.2с у heap со штатным исполнителем', 'MergeTree проигрывал даже heap: ', ', TPC-DS 380.5с против 58.8с. С ', 8595, 8678);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('cc8a82146a29', 'rep15', 'habr-1097022', 'describing', false, 's4', 115, 'Признаю! Поэтому я и сделал свой iheap', 'еские запросы из постгреса.

-- ', ' - табличный метод доступа Postg', 9245, 9283);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('cd29002e7c47', 'obs_cb_std_heap_pg', 'habr-1097022', 'describing', false, 's1', 58, 'На стандартном планировщике на heap pg_vexec уменьшил среднее геометрическое время выполнения запроса всего на 19% с 625 -\> 506мс', ' не сильно помогла в ускорении. ', ', а на ORCA на 18% с 1647 -\> 13', 2853, 2983);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('cd6227ead77d', 'rel/dc1055132d00', 'habr-1097022', 'linking', false, 'body', 32, 'Elasticsearch для полнотекстового поиска в приложении', ' OpenTelemetry и веб аналитики, ', ', а MongoDB - "так исторически с', 830, 883);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('ceb53f5060ed', 'obs_sort_after', 'habr-1097022', 'describing', false, 's2', 82, 'идет 67-76мс вместо исходных 2.1 секунды', 'ts ORDER BY CounterID LIMIT 10` ', '.

Скан сначала просит у источни', 5722, 5762);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('cfe1f05dfa71', 'hydra_columnar', 'habr-1097022', 'identifying', false, 's1', 70, 'Citus columnar и Hydra внутри колоночные', ' бы отдавал данные поколоночно. ', ', а наружу через tableAM API отд', 4130, 4170);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('d-0159f4d0f47b', 'link/caad0b666630', 'derived-media', 'linking', false, 's5', 134, 'iheap', 'horukov/pg_ch_table_engines) и [', '](https://github.com/igor-suhoru', 11526, 11531);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('d-06e92b806143', 'link/aa1193282db2', 'derived-media', 'linking', false, 's5', 134, 'pg_vexec', 'абор расширений для PostgreSQL [', '](https://github.com/igor-suhoru', 11394, 11402);
INSERT INTO evidence (key, about, graph, motivation, first_mention, comment, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('d-080851679487', 'definition/c-c67ffcb63180', 'derived-definitions', 'describing', false, 'цитата понятия; формулировка определения — из спецификации', 's1', 56, 'Внутри исполнитель обрабатывает батчи данных по 1024 строки в колоночном виде', 'е узлы своей моделью стоимости. ', ' ядрами-вычислителями, привязанн', 2525, 2602);
INSERT INTO evidence (key, about, graph, motivation, first_mention, comment, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('d-08b3fee3c364', 'code/2', 'derived-code', 'identifying', false, 'начало блока кода', 's4', 119, '``` sql
-- postgresql.conf: shared_preload_libraries = ''pg_inplace_update_am''
CREATE EXTENSION pg_inplace_update_am;
CRE', 'урсов до горизонтов видимости.

', 'ATE TABLE accounts (id int PRIMA', 9750, 9870);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('d-0e9fe97c36a1', 'term/hash_table', 'derived-terminology', 'identifying', true, 's1', 62, 'хеш-таблице', 'в GROUP BY, проверки значения в ', ' 5%. Еще 26-47% уходило на копир', 3297, 3308);
INSERT INTO evidence (key, about, graph, motivation, first_mention, comment, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('d-1535beaa8f98', 'definition/c-6398a1192260', 'derived-definitions', 'describing', false, 'цитата понятия; формулировка определения — из спецификации', 's2', 86, 'Колонки с небольшим числом различных значений теперь приходят в pg_vexec в виде индексов в словаре LowCardinality', 'емя выполнения с 471 до 247мс.

', ', а выражения считаются один раз', 5989, 6102);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('d-2ac7df93177a', 'idea/0eed6def06e7', 'derived-ideas', 'describing', false, 's1', 54, '[pg_vexec](https://habr.com/ru/articles/1091738/)', 'птимизатора запросов разработал ', ' векторизованный исполнитель без', 2209, 2258);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('d-4a1161191b58', 'link/be1471385550', 'derived-media', 'linking', false, 's5', 134, 'ch_table_engines', '.com/igor-suhorukov/pg_vexec), [', '](https://github.com/igor-suhoru', 11450, 11466);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('d-4c8d83811171', 'link/bc3a870cf498', 'derived-media', 'linking', false, 's1', 54, 'pg_vexec', 'тимизатора запросов разработал [', '](https://habr.com/ru/articles/1', 2210, 2218);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('d-595b059ad85c', 'idea/ff5544b26ac0', 'derived-ideas', 'describing', false, 's3', 96, 'Теперь в постгресе можно запустить ch_table_engines и получить хранилище, заточенное под анализ логов сервера', 'тировки и слияний в хранилище.

', ':

``` sql
-- postgresql.conf: s', 7460, 7569);
INSERT INTO evidence (key, about, graph, motivation, first_mention, comment, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('d-614c3964d780', 'code/1', 'derived-code', 'identifying', false, 'начало блока кода', 's3', 98, '``` sql
-- postgresql.conf: shared_preload_libraries = ''ch_table_engines''
CREATE EXTENSION ch_table_engines;
CREATE TABL', 'нное под анализ логов сервера:

', 'E hits (...) USING mergetree
   ', 7572, 7692);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('d-762fcda2bbda', 'idea/dee1de855fad', 'derived-ideas', 'describing', false, 's1', 54, 'векторизованный исполнитель без единого патча ядра', '/habr.com/ru/articles/1091738/) ', '.

Его узлы VecScan, VecHashJoin', 2259, 2309);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('d-76e3be50ed21', 'discourse/d04b3fb5a64e', 'derived-discourse', 'describing', false, 's3', 107, 'При попытке доступа второго процесса в свой каталог получаешь "Another server instance in same directory is already running" а постгрес на каждое соединение создает отдельный процесс. Поэтому понадобилась своя синяя изолента, чтобы примотать его к PostgreSQL', 'лью одного серверного процесса. ', '.

Но толка от MergeTree в станд', 8205, 8463);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('d-7f8cbe348189', 'discourse/6d443dc696b5', 'derived-discourse', 'describing', false, 's4', 126, 'Undo живет в экстентах основного слоя самой таблицы, поэтому WAL, восстановление после сбоя, реплики, бэкапы и логическая репликация работают как у любой таблицы', ' -- перевести существующую
```

', '. Блокировки строк - тоже undo-з', 10015, 10176);
INSERT INTO evidence (key, about, graph, motivation, first_mention, comment, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('d-8d450d775302', 'definition/c-cab91028ff8f', 'derived-definitions', 'describing', false, 'цитата понятия; формулировка определения — из спецификации', 's4', 115, 'который перезаписывает строку на месте, по тому же TID', 'ный метод доступа PostgreSQL 19 ', '. Ее старая версия уходит в undo', 9324, 9378);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('d-9cdf3daa7ab3', 'discourse/dac800829dee', 'derived-discourse', 'describing', false, 's5', 134, 'Реплики, pg_dump и MVCC работают как у обычного heap, потому что ими по-прежнему занимается PostgreSQL', 'ий без bloat таблиц и индексов. ', '.

Специализированная база это с', 11794, 11896);
INSERT INTO evidence (key, about, graph, motivation, first_mention, comment, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('d-a5040ef36038', 'definition/c-e93659e4d2da', 'derived-definitions', 'describing', false, 'цитата понятия; формулировка определения — из спецификации', 's3', 94, 'MergeTree испытан годами в пользовательской аналитике под реальной нагрузкой и запросами бизнеса.', 'тро выбросил его на металлолом. ', ' Ну и конечно же в ClickBench не', 7195, 7292);
INSERT INTO evidence (key, about, graph, motivation, first_mention, comment, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('d-a5aebdba145c', 'definition/c-b024643789a7', 'derived-definitions', 'describing', false, 'цитата понятия; формулировка определения — из спецификации', 's1', 56, 'Внутри исполнитель обрабатывает батчи данных по 1024 строки в колоночном виде', 'е узлы своей моделью стоимости. ', ' ядрами-вычислителями, привязанн', 2525, 2602);
INSERT INTO evidence (key, about, graph, motivation, first_mention, comment, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('d-adb67ed4340d', 'definition/c-300923d620f9', 'derived-definitions', 'describing', false, 'цитата понятия; формулировка определения — из спецификации', 's4', 115, 'Ее старая версия уходит в undo log', 'троку на месте, по тому же TID. ', ', и собирает ее оттуда только то', 9380, 9414);
INSERT INTO evidence (key, about, graph, motivation, first_mention, comment, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('d-b6f7f10d1531', 'definition/c-67800c48aebe', 'derived-definitions', 'describing', false, 'цитата понятия; формулировка определения — из спецификации', 's1', 64, 'Табличный API постгреса отдает строки по одной через слот', 'мает страницы в память целиком. ', ', а scan_begin() даже не принима', 3577, 3634);
INSERT INTO evidence (key, about, graph, motivation, first_mention, comment, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('d-c4a3b99db2f9', 'definition/c-3e9629b64285', 'derived-definitions', 'describing', false, 'цитата понятия; формулировка определения — из спецификации', 's2', 84, 'Скан сначала просит у источника данных колонки первого условия, а остальные дочитывает только для батчей', 'с вместо исходных 2.1 секунды.

', ', где после первого условия оста', 5765, 5869);
INSERT INTO evidence (key, about, graph, motivation, first_mention, comment, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('d-cd3068aa968f', 'definition/c-007b8e894261', 'derived-definitions', 'describing', false, 'цитата понятия; формулировка определения — из спецификации', 's1', 56, 'Его узлы VecScan, VecHashJoin, VecAgg и VecSort попадают в план запроса через штатные механизмы расширения СУБД', 'нитель без единого патча ядра.

', ' и соревнуются с обычными узлами', 2312, 2423);
INSERT INTO evidence (key, about, graph, motivation, first_mention, comment, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('d-d332891f2e54', 'definition/c-a7206cc4374e', 'derived-definitions', 'describing', false, 'цитата понятия; формулировка определения — из спецификации', 's2', 78, 'После переписывания с помощью нейронки на SSE2 с movemask сравнение 1024 строк уже занимало 82нс вместо 426.', 'дин цикл и ни одного сравнения. ', '

В коде, который решает, может ', 5156, 5264);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('d-e50ecb76f620', 'link/d4ecc8cec7bf', 'derived-media', 'linking', false, 's1', 54, 'Apache Cloudberry на PostgreSQL 19', 'этого началась когда я перенес [', '](https://habr.com/ru/articles/1', 1996, 2030);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('d-ebbd94e7a860', 'idea/762a53f1f463', 'derived-ideas', 'describing', false, 's4', 115, 'iheap - табличный метод доступа PostgreSQL 19 который перезаписывает строку на месте, по тому же TID', 'ризнаю! Поэтому я и сделал свой ', '. Ее старая версия уходит в undo', 9278, 9378);
INSERT INTO evidence (key, about, graph, motivation, first_mention, comment, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('d-f390ff0d2ef9', 'definition/c-c6e8650418c1', 'derived-definitions', 'describing', false, 'цитата понятия; формулировка определения — из спецификации', 's1', 54, 'стоимостный планировщик Greenplum', 'достался ORCA на PostgreSQL19 - ', '. Сверху оптимизатора запросов р', 2134, 2167);
INSERT INTO evidence (key, about, graph, motivation, first_mention, comment, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('d-f636d3e270d2', 'definition/c-cfae81df3cfb', 'derived-definitions', 'describing', false, 'цитата понятия; формулировка определения — из спецификации', 's1', 56, 'ядрами-вычислителями, привязанными к OID функции', 'о 1024 строки в колоночном виде ', '. Если специального ядра нет, вы', 2603, 2651);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('d-f937c678fcf5', 'idea/bb881327bfcb', 'derived-ideas', 'describing', false, 's1', 54, '[Apache Cloudberry на PostgreSQL 19](https://habr.com/ru/articles/1088264/)', ' этого началась когда я перенес ', ' в виде набора расширений и мне ', 1995, 2070);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('d-fa2e73ff2550', 'image/82074d3df1cb', 'derived-media', 'identifying', false, 'body', 32, '![](https://habrastorage.org/extt/18/c0/40/18c0403f0359c4b82e370af263b9439c.png)', 'method"
  - "vectorization"
---
', 'Мой знакомый - отличный архитект', 568, 648);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('d08a0d777ebe', 'iheap', 'habr-1097022', 'identifying', false, 's5', 134, '[iheap](https://github.com/igor-suhorukov/pg_inplace_update_am)', 'uhorukov/pg_ch_table_engines) и ', ' и ни одного патча ядра. Хранили', 11525, 11588);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('d141f9f916bc', 'obs_tpch_mt_vexec', 'habr-1097022', 'describing', false, 's3', 109, 'С pg_vexec те же запросы на MergeTree шли 6.9с и 48.6с.', 'ем, TPC-DS 380.5с против 58.8с. ', ' Без этой детали получалось коло', 8708, 8763);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('d3c7ebad5c1b', 'claim_specialized_complexity', 'habr-1097022', 'describing', false, 's5', 132, 'Если у тебя не бигтех зачем тебе городить сложности в поддержке систем?', 'так не раздуваются, как в heap. ', '

Мне удалось на своем ноутбуке ', 10988, 11059);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('d4620d2c7809', 'claim_reliable_or_fast', 'habr-1097022', 'describing', false, 'body', 44, 'Либо надежно, либо быстро!', 'е платформа.

-- Так не бывает. ', '

-- А у меня получилось совмест', 1596, 1622);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('d53b60a88459', 'rep05', 'habr-1097022', 'describing', false, 'body', 46, 'А у меня получилось совместить лучшее из двух миров.', ' Либо надежно, либо быстро!

-- ', '

## Векторизация уперлась в hea', 1627, 1679);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('d5acbe6d88f0', 'data_part', 'habr-1097022', 'classifying', false, 's2', 90, 'запросы читали 35 частей вместо трех', 'скал сервер до конца слияний, и ', '. Даже исходная таблица на 35 ча', 6801, 6837);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('d5bbc7f382b0', 'granule', 'habr-1097022', 'classifying', false, 's2', 90, 'Таблица с LowCardinality, мелкими гранулами и без сжатия вдруг стала медленнее', ' не все шаги вели к улучшениям. ', ' и заняла 11.8ГБ на диске вместо', 6563, 6641);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('d5fa8199bf23', 'theme/obnovlenie_strok_na_meste_bez_bloat', 'habr-1097022', 'classifying', false, 's5', 132, 'в iheap таблицы так не раздуваются, как в heap', 'роблема при частых обновлениях: ', '. Если у тебя не бигтех зачем те', 10940, 10986);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('d89b7e775b2c', 'claim_iheap_no_core_patch', 'habr-1097022', 'describing', false, 's4', 117, 'от собственного менеджера ресурсов до горизонтов видимости', 'ватает штатных механизмов СУБД, ', '.

``` sql
-- postgresql.conf: s', 9689, 9747);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('d8f8a65d0792', 'gcc', 'habr-1097022', 'identifying', false, 's2', 78, 'Автовекторизация GCC на -O2, с которым собирает PGXS, почти ничего не дала', 'типирование и откат изменений.

', ': векторизовался ровно один цикл', 5026, 5100);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('d905806b7f7d', 'pg_vexec', 'habr-1097022', 'identifying', false, 's5', 134, '[pg_vexec](https://github.com/igor-suhorukov/pg_vexec)', 'набор расширений для PostgreSQL ', ', [ch_table_engines](https://git', 11393, 11447);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('d994c3fe7fe9', 'claim_need_columnar', 'habr-1097022', 'describing', false, 's1', 72, 'Так в моем плане появилась задача затащить движки таблиц семейства MergeTree и попытаться догнать ClickHouse на ClickBench.', 'УБД от которого хотелось уйти.

', '

## Как уменьшал среднее время ', 4531, 4654);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('db4d45c9169f', 'claim_mergetree_without_vexec', 'habr-1097022', 'describing', false, 's3', 109, 'Но толка от MergeTree в стандартном исполнителе постгреса мало.', 'бы примотать его к PostgreSQL.

', ' Без векторизованного исполнител', 8466, 8529);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('dc4f472f5310', 'iheap', 'habr-1097022', 'identifying', false, 's4', 115, 'iheap - табличный метод доступа PostgreSQL 19 который перезаписывает строку на месте, по тому же TID', 'ризнаю! Поэтому я и сделал свой ', '. Ее старая версия уходит в undo', 9278, 9378);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('de13c130f8f8', 'contribution/c217ab943a63', 'habr-1097022', 'describing', false, 's2', 88, 'сделали время выполнения для Q28 более чем в пять раз меньше', 'ация с разделами в общей памяти ', ' - с 1090 до 213мс. А по всему C', 6400, 6460);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('dea00991baa7', 'ev_zheap_abandoned', 'habr-1097022', 'describing', false, 's4', 117, 'который много лет пытались довести до ядра, но так и забросили', '

Идейно похоже на проект zheap ', '. Мне же удалось сделать подобно', 9513, 9575);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('dfaaa4d0b61b', 'obs_disk_orig', 'habr-1097022', 'describing', false, 's2', 90, 'заняла 11.8ГБ на диске вместо 4.8ГБ', ' сжатия вдруг стала медленнее и ', '. Место съело отключенное сжатие', 6644, 6679);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('dfffe47d8917', 'claim_citus_hydra_rows', 'habr-1097022', 'describing', false, 's1', 70, 'Citus columnar и Hydra внутри колоночные, а наружу через tableAM API отдают те же самые слоты по одной строке.', ' бы отдавал данные поколоночно. ', ' PAX и AOCO из гринплама живут т', 4130, 4240);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('e2f78dc0fc7d', 'clickhouse', 'habr-1097022', 'identifying', false, 'body', 32, 'в ClickHouse у него лежат данные OpenTelemetry и веб аналитики', 'зы данных. PostgreSQL для OLTP, ', ', Elasticsearch для полнотекстов', 766, 828);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('e3293016f043', 'obs_rows_per_page', 'habr-1097022', 'describing', false, 's1', 64, 'Если строка весит около 1.4КБ, на страницу помещается 5-6 строк', 'ходило на копирование страниц.

', ' и батч из 1024 строк размазан п', 3357, 3420);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('e38fbf94866d', 'theme/kolonochnoe_khranilishche_mergetree_vnutri_postgresql', 'habr-1097022', 'classifying', false, 'body', 38, 'Мне удалось вставить табличный движок MergeTree из ClickHouse в PostgreSQL табличным методом доступа', ' занимался последнее время.

-- ', ', на ванильное ядро СУБД без фор', 1191, 1291);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('e722bd6d5cc0', 'rep04', 'habr-1097022', 'describing', false, 'body', 44, 'Так не бывает. Либо надежно, либо быстро!', 'отке и поддержке платформа.

-- ', '

-- А у меня получилось совмест', 1581, 1622);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('e86129ba2042', 'claim_use_case', 'habr-1097022', 'describing', false, 's5', 132, 'А если в базе еще должны быть транзакционные данные из разных систем и десятки соединений между таблицами.', 'блицы метрик с сотнями колонок. ', ' Все можно получать в PostgreSQL', 10698, 10804);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('e86c30fe6eb8', 'ev_vexec_dev', 'habr-1097022', 'describing', false, 's1', 54, 'Сверху оптимизатора запросов разработал [pg_vexec](https://habr.com/ru/articles/1091738/) векторизованный исполнитель без единого патча ядра', 'имостный планировщик Greenplum. ', '.

Его узлы VecScan, VecHashJoin', 2169, 2309);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('e8f970e7b04e', 'rel/721023002e6c', 'habr-1097022', 'linking', false, 'body', 38, 'с доступом к нему из векторизованного исполнителя запросов', 'а ванильное ядро СУБД без форка ', '.

-- Зачем? Просто возьми Click', 1326, 1384);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('e9a31e3e0363', 'claim_use_case', 'habr-1097022', 'describing', false, 's5', 132, 'Все можно получать в PostgreSQL, в единой транзакции.', 'тки соединений между таблицами. ', ' И длительная транзакция теперь ', 10805, 10858);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('e9e6a886ff26', 'rel/f159dc55029f', 'habr-1097022', 'linking', false, 's1', 72, 'Так в моем плане появилась задача затащить движки таблиц семейства MergeTree', 'УБД от которого хотелось уйти.

', ' и попытаться догнать ClickHouse', 4531, 4607);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('ea26e5e8d197', 'claim_friend_bloat', 'habr-1097022', 'describing', false, 's4', 113, 'Для нас в начале эксплуатации системы bloat таблиц был проблемой.', 'жи копятся и автовакуум пыхтит. ', ' Пришлось сокращать время транза', 9092, 9157);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('ea827d6f72db', 'claim_kernels_negligible', 'habr-1097022', 'describing', false, 's1', 62, 'Еще 26-47% уходило на копирование страниц.', 'ерки значения в хеш-таблице 5%. ', '

Если строка весит около 1.4КБ,', 3313, 3355);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('ec6b171ac985', 'multixact', 'habr-1097022', 'classifying', false, 's4', 126, 'Блокировки строк - тоже undo-записи, так что нет ни MultiXact ни заморозки.', 'я работают как у любой таблицы. ', ' А чтобы обновление индексирован', 10178, 10253);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('ec9faa930f38', 'orca', 'habr-1097022', 'identifying', false, 's1', 56, 'ORCA оценивает векторные узлы своей моделью стоимости.', 'с обычными узлами по стоимости. ', ' Внутри исполнитель обрабатывает', 2470, 2524);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('ed2ad09d0101', 'visibility_snapshot', 'habr-1097022', 'classifying', false, 's4', 115, 'собирает ее оттуда только тот читатель, чьему снимку она нужна', 'рая версия уходит в undo log, и ', '.

Идейно похоже на проект zheap', 9418, 9480);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('edc6d38e8575', 'proc_optimization_cycle.t6', 'habr-1097022', 'describing', false, 's2', 76, 'прототипирование и откат изменений', 'изнь: профилирование, гипотезы, ', '.

Автовекторизация GCC на -O2, ', 4989, 5023);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('ee1cc5e4bd75', 'narr_dispute', 'habr-1097022', 'describing', false, 'body', 36, 'Недавно рассказал ему чем я занимался последнее время.', 'стью в поддержке и разработке.

', '

-- Мне удалось вставить таблич', 1132, 1186);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('ee231298ea88', 'oid_kernel', 'habr-1097022', 'classifying', false, 's1', 56, 'Если специального ядра нет, выражение вычисляет штатный интерпретатор выражений постгреса прямо внутри узла.', 'ми, привязанными к OID функции. ', '

Первый замер на ClickBench мен', 2653, 2761);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('eeada6898963', 'obs_cols_needed', 'habr-1097022', 'describing', false, 's1', 64, 'Чтобы достать три колонки из 105 в таблице теста', 'азан примерно по 180 страницам. ', ', heap честно поднимает страницы', 3478, 3526);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('f251ea46a5f7', 'obs_page_copy_share', 'habr-1097022', 'describing', false, 's1', 62, 'Еще 26-47% уходило на копирование страниц.', 'ерки значения в хеш-таблице 5%. ', '

Если строка весит около 1.4КБ,', 3313, 3355);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('f2bb0f21bf47', 'rel/c8adba16917b', 'habr-1097022', 'linking', false, 'body', 32, 'PostgreSQL для OLTP, в ClickHouse у него лежат данные OpenTelemetry и веб аналитики', 'роде четыре разных базы данных. ', ', Elasticsearch для полнотекстов', 745, 828);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('f53140bedb2c', 'tpc_h', 'habr-1097022', 'identifying', false, 's3', 109, 'сумма запросов TPC-H SF1 61.8с против 17.2с у heap со штатным исполнителем', ' проигрывал даже heap: под ORCA ', ', TPC-DS 380.5с против 58.8с. С ', 8604, 8678);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('f53bfb38cb53', 'obs_disk_lowcard', 'habr-1097022', 'describing', false, 's2', 90, 'заняла 11.8ГБ на диске вместо 4.8ГБ', ' сжатия вдруг стала медленнее и ', '. Место съело отключенное сжатие', 6644, 6679);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('f678398778b0', 'pax', 'habr-1097022', 'identifying', false, 's1', 70, 'PAX и AOCO из гринплама живут только на пропатченном ядре порта постгреса', 'же самые слоты по одной строке. ', ': кроме расширений у порта есть ', 4241, 4314);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('f948ca407da6', 'zheap', 'habr-1097022', 'identifying', false, 's4', 117, 'Идейно похоже на проект zheap который много лет пытались довести до ядра, но так и забросили.', 'атель, чьему снимку она нужна.

', ' Мне же удалось сделать подобное', 9483, 9576);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('fb0b03f39640', 'cost_based_planner', 'habr-1097022', 'classifying', false, 's1', 54, 'стоимостный планировщик Greenplum', 'достался ORCA на PostgreSQL19 - ', '. Сверху оптимизатора запросов р', 2134, 2167);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('fc1a0f7eeba4', 'obs_skip_speedup', 'habr-1097022', 'describing', false, 's1', 66, 'Симуляция такого пропуска ускоряла те же запросы ClickBench в 8-100 раз', 'такой точки расширения не дает. ', ' (Q20 с 510 до 5.3мс). Но это бы', 3783, 3854);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('fd08b9ea29ca', 'undo_log', 'habr-1097022', 'classifying', false, 's4', 126, 'Undo живет в экстентах основного слоя самой таблицы', ' -- перевести существующую
```

', ', поэтому WAL, восстановление по', 10015, 10066);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('fdfa74fc7abf', 'dmbtree', 'habr-1097022', 'identifying', false, 's4', 126, 'в расширении живет dmbtree форк btree из PG19, который умеет помечать старую запись удаленной', 'и не трогало остальные индексы, ', ': новая запись появляется только', 10327, 10420);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('fea29e57a84b', 'table_access_method', 'habr-1097022', 'classifying', false, 's1', 64, 'Табличный API постгреса отдает строки по одной через слот', 'мает страницы в память целиком. ', ', а scan_begin() даже не принима', 3577, 3634);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('ff1815be4e7d', 'rel/721023002e6c', 'habr-1097022', 'linking', false, 's2', 76, 'Первая же, еще неоптимизированная версия MergeTree вместе с pg_vexec', 'проса от 715 до 49 миллисекунд

', ' сразу снизила среднее геометрич', 4720, 4788);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, line, quote, prefix, suffix, start_pos, end_pos) VALUES ('ff9382ea751a', 'claim_postgres_can_compete', 'habr-1097022', 'describing', false, 's5', 136, 'Старичок PostgreSQL еще может потягаться с современными базами данных в проектах из обычной жизни!', 'дронного коллайдера или Google. ', '
', 12039, 12137);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, quote, prefix, suffix, start_pos, end_pos) VALUES ('first-0234b5929d29', 'pgxs', 'habr-1097022-mentions', 'identifying', true, 's2', 'PGXS', ' GCC на -O2, с которым собирает ', ', почти ничего не дала: векториз', 5074, 5078);
INSERT INTO evidence (key, about, graph, motivation, first_mention, quote, prefix, suffix, start_pos, end_pos) VALUES ('first-191908d8c51a', 'clickhouse', 'habr-1097022-mentions', 'identifying', true, 'ClickHouse', ' данных. PostgreSQL для OLTP, в ', ' у него лежат данные OpenTelemet', 768, 778);
INSERT INTO evidence (key, about, graph, motivation, first_mention, quote, prefix, suffix, start_pos, end_pos) VALUES ('first-446cc9cba522', 'mongodb', 'habr-1097022-mentions', 'identifying', true, 'MongoDB', 'кстового поиска в приложении, а ', ' - "так исторически сложилось".
', 887, 894);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, quote, prefix, suffix, start_pos, end_pos) VALUES ('first-4dc3532359da', 'vec_sort', 'habr-1097022-mentions', 'identifying', true, 's1', 'VecSort', ' VecScan, VecHashJoin, VecAgg и ', ' попадают в план запроса через ш', 2352, 2359);
INSERT INTO evidence (key, about, graph, motivation, first_mention, quote, prefix, suffix, start_pos, end_pos) VALUES ('first-550840126d55', 'elasticsearch', 'habr-1097022-mentions', 'identifying', true, 'Elasticsearch', ' OpenTelemetry и веб аналитики, ', ' для полнотекстового поиска в пр', 830, 843);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, quote, prefix, suffix, start_pos, end_pos) VALUES ('first-5f405959d8f9', 'vec_hash_join', 'habr-1097022-mentions', 'identifying', true, 's1', 'VecHashJoin', ' патча ядра.

Его узлы VecScan, ', ', VecAgg и VecSort попадают в пл', 2330, 2341);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, quote, prefix, suffix, start_pos, end_pos) VALUES ('first-6d0227975502', 'mvcc', 'habr-1097022-mentions', 'identifying', true, 's5', 'MVCC', ' и индексов. Реплики, pg_dump и ', ' работают как у обычного heap, п', 11813, 11817);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, quote, prefix, suffix, start_pos, end_pos) VALUES ('first-7167d17013f7', 'google', 'habr-1097022-mentions', 'identifying', true, 's5', 'Google', 'льшого адронного коллайдера или ', '. Старичок PostgreSQL еще может ', 12031, 12037);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, quote, prefix, suffix, start_pos, end_pos) VALUES ('first-73090fcb0065', 'greenplum', 'habr-1097022-mentions', 'identifying', true, 's1', 'Greenplum', 'дожди. Ты же недавно портировал ', ' в расширение для постгреса, а п', 1751, 1760);
INSERT INTO evidence (key, about, graph, motivation, first_mention, quote, prefix, suffix, start_pos, end_pos) VALUES ('first-7e798f1b3a1f', 'mergetree', 'habr-1097022-mentions', 'identifying', true, 'MergeTree', 'алось вставить табличный движок ', ' из ClickHouse в PostgreSQL табл', 1229, 1238);
INSERT INTO evidence (key, about, graph, motivation, first_mention, quote, prefix, suffix, start_pos, end_pos) VALUES ('first-7fadf15deb9a', 'opentelemetry', 'habr-1097022-mentions', 'identifying', true, 'OpenTelemetry', ' ClickHouse у него лежат данные ', ' и веб аналитики, Elasticsearch ', 799, 812);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, quote, prefix, suffix, start_pos, end_pos) VALUES ('first-7fe5449325bf', 'gcc', 'habr-1097022-mentions', 'identifying', true, 's2', 'GCC', 'ат изменений.

Автовекторизация ', ' на -O2, с которым собирает PGXS', 5043, 5046);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, quote, prefix, suffix, start_pos, end_pos) VALUES ('first-8242dcbe54a0', 'orca', 'habr-1097022-mentions', 'identifying', true, 's1', 'ORCA', 'абора расширений и мне достался ', ' на PostgreSQL19 - стоимостный п', 2111, 2115);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, quote, prefix, suffix, start_pos, end_pos) VALUES ('first-8a6c0c7ffd09', 'hydra_columnar', 'habr-1097022-mentions', 'identifying', true, 's1', 'Hydra', 'е поколоночно. Citus columnar и ', ' внутри колоночные, а наружу чер', 4147, 4152);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, quote, prefix, suffix, start_pos, end_pos) VALUES ('first-99152c1c42b3', 'citus_columnar', 'habr-1097022-mentions', 'identifying', true, 's1', 'Citus columnar', ' бы отдавал данные поколоночно. ', ' и Hydra внутри колоночные, а на', 4130, 4144);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, quote, prefix, suffix, start_pos, end_pos) VALUES ('first-a14918c9c38d', 'art_cloudberry_pg19', 'habr-1097022-mentions', 'identifying', true, 's1', 'Apache Cloudberry на PostgreSQL', 'этого началась когда я перенес [', ' 19](https://habr.com/ru/article', 1996, 2027);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, quote, prefix, suffix, start_pos, end_pos) VALUES ('first-a3cd48c4c96f', 'pax', 'habr-1097022-mentions', 'identifying', true, 's1', 'PAX', 'же самые слоты по одной строке. ', ' и AOCO из гринплама живут тольк', 4241, 4244);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, quote, prefix, suffix, start_pos, end_pos) VALUES ('first-a7d0c577c75d', 'aoco', 'habr-1097022-mentions', 'identifying', true, 's1', 'AOCO', 'ые слоты по одной строке. PAX и ', ' из гринплама живут только на пр', 4247, 4251);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, quote, prefix, suffix, start_pos, end_pos) VALUES ('first-b5c5bfd48c84', 'low_cardinality', 'habr-1097022-mentions', 'identifying', true, 's2', 'LowCardinality', 'vexec в виде индексов в словаре ', ', а выражения считаются один раз', 6088, 6102);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, quote, prefix, suffix, start_pos, end_pos) VALUES ('first-bd3cf5c6e4a6', 'large_hadron_collider', 'habr-1097022-mentions', 'identifying', true, 's5', 'Большого адронного коллайдера', 'ли масштаб данных не телеметрия ', ' или Google. Старичок PostgreSQL', 11997, 12026);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, quote, prefix, suffix, start_pos, end_pos) VALUES ('first-dd06b9ea43d8', 'postgresql', 'habr-1097022-mentions', 'identifying', true, 's1', 'PostgreSQL', 'сширений и мне достался ORCA на ', '19 - стоимостный планировщик Gre', 2119, 2129);
INSERT INTO evidence (key, about, graph, motivation, first_mention, section, quote, prefix, suffix, start_pos, end_pos) VALUES ('first-eeab59765b46', 'multixact', 'habr-1097022-mentions', 'identifying', true, 's4', 'MultiXact', 'оже undo-записи, так что нет ни ', ' ни заморозки. А чтобы обновлени', 10230, 10239);

INSERT INTO themes (slug, name) VALUES ('bazy_dannykh', 'Базы данных');
INSERT INTO themes (slug, name) VALUES ('big_data', 'Big Data');
INSERT INTO themes (slug, name) VALUES ('kolonochnoe_khranilishche_mergetree_vnutri_postgresql', 'колоночное хранилище MergeTree внутри PostgreSQL');
INSERT INTO themes (slug, name) VALUES ('obnovlenie_strok_na_meste_bez_bloat', 'обновление строк на месте без bloat');
INSERT INTO themes (slug, name) VALUES ('odna_subd_protiv_zooparka_spetsializirovannykh_baz', 'одна СУБД против зоопарка специализированных баз');
INSERT INTO themes (slug, name) VALUES ('open_source', 'Open source');
INSERT INTO themes (slug, name) VALUES ('postgresql', 'PostgreSQL');
INSERT INTO themes (slug, name) VALUES ('programmirovanie', 'Программирование');
INSERT INTO themes (slug, name) VALUES ('vektorizovannoe_ispolnenie_zaprosov_v_postgresql', 'векторизованное исполнение запросов в PostgreSQL');

INSERT INTO hubs (slug, name, views_rank, views_rank_key) VALUES ('bazy_dannykh', 'Базы данных', 2, '112588ef67b0');
INSERT INTO hubs (slug, name) VALUES ('big_data', 'Big Data');
INSERT INTO hubs (slug, name, views_rank, views_rank_key) VALUES ('open_source', 'Open source', 4, '3cbe2c706a5f');
INSERT INTO hubs (slug, name, views_rank, views_rank_key) VALUES ('postgresql', 'PostgreSQL', 2, '17b0fd8c6175');
INSERT INTO hubs (slug, name, views_rank, views_rank_key) VALUES ('programmirovanie', 'Программирование', 15, '98794077329e');

INSERT INTO relations (key, subject, predicate, object, label, in_stack) VALUES ('3ae6d8357cee', 'ch_table_engines', 'kgo:implements', 'table_access_method', 'MergeTree подключён к PostgreSQL табличным методом доступа', false);
INSERT INTO relations (key, subject, predicate, object, feature, in_stack) VALUES ('4ae41ac5de1d', 'inplace_update', 'kgo:differsFrom', 'heap', 'heap на каждый UPDATE создаёт новую версию строки, и мёртвые кортежи копятся; iheap перезаписывает строку на месте', false);
INSERT INTO relations (key, subject, predicate, object, label, in_stack) VALUES ('6279b87a98f1', 'iheap', 'kgo:implements', 'table_access_method', 'iheap — табличный метод доступа PostgreSQL 19', false);
INSERT INTO relations (key, subject, predicate, object, label, in_stack) VALUES ('721023002e6c', 'pg_vexec', 'kgo:integratesWith', 'ch_table_engines', 'векторизованный исполнитель читает данные из MergeTree', false);
INSERT INTO relations (key, subject, predicate, object, label, in_stack) VALUES ('74e54dfd6491', 'architect_friend', 'kgo:usesTool', 'postgresql', 'в проде у друга: PostgreSQL для OLTP, ClickHouse для данных OpenTelemetry и веб-аналитики, Elasticsearch для полнотекстового поиска', false);
INSERT INTO relations (key, subject, predicate, object, label, in_stack) VALUES ('77dafbc24f44', 'dmbtree', 'schema:isPartOf', 'iheap', 'dmbtree живёт в расширении iheap', true);
INSERT INTO relations (key, subject, predicate, object, feature, in_stack) VALUES ('84b79083df6b', 'simd_movemask', 'kgo:differsFrom', 'auto_vectorization', 'сравнения векторизованы вручную на SSE2 с movemask, тогда как автовекторизация GCC не векторизовала ни одного сравнения', false);
INSERT INTO relations (key, subject, predicate, object, label, in_stack) VALUES ('8c5d45efdc19', 'architect_friend', 'kgo:usesTool', 'mongodb', 'MongoDB в проде у друга — «так исторически сложилось»', false);
INSERT INTO relations (key, subject, predicate, object, feature, in_stack) VALUES ('8efd249f92ae', 'inplace_update', 'kgo:differsFrom', 'zheap', 'zheap много лет пытались довести до ядра и забросили, а iheap сделан без патча ядра штатными механизмами PostgreSQL 19', false);
INSERT INTO relations (key, subject, predicate, object, label, in_stack) VALUES ('af96f21a57e4', 'pg_vexec', 'kgo:integratesWith', 'orca', 'векторные узлы pg_vexec оцениваются моделью стоимости ORCA', false);
INSERT INTO relations (key, subject, predicate, object, label, in_stack) VALUES ('c8adba16917b', 'architect_friend', 'kgo:usesTool', 'clickhouse', 'в проде у друга: PostgreSQL для OLTP, ClickHouse для данных OpenTelemetry и веб-аналитики, Elasticsearch для полнотекстового поиска', false);
INSERT INTO relations (key, subject, predicate, object, label, in_stack) VALUES ('dc1055132d00', 'architect_friend', 'kgo:usesTool', 'elasticsearch', 'в проде у друга: PostgreSQL для OLTP, ClickHouse для данных OpenTelemetry и веб-аналитики, Elasticsearch для полнотекстового поиска', false);
INSERT INTO relations (key, subject, predicate, object, label, in_stack) VALUES ('de6351f0a632', 'mergetree', 'schema:isPartOf', 'clickhouse', 'MergeTree — часть СУБД ClickHouse и отдельно не собирается', true);
INSERT INTO relations (key, subject, predicate, object, label, in_stack) VALUES ('f159dc55029f', 'ch_table_engines', 'schema:isBasedOn', 'mergetree', 'расширение построено на движках таблиц семейства MergeTree', true);

INSERT INTO article (slug, title, description, types, post_type, genres, tags, about, mentions, author, published, language, habr_id, url, score, reading_count, comments_count, favorites_count, votes_count, votes_plus, votes_minus, publisher, publisher_name, publisher_url, author_nick, author_score, author_votes, source_file, source_format, source_bytes, source_chars, source_sha256, source_date, spec_file, mentions_method, narrative_person, narrative_person_basis, like_share, comments_per_1000_views, bookmarks_per_1000_views, style_key, style_word_count, style_sentence_count, style_paragraph_count, style_mean_sentence_length, style_median_sentence_length, style_mean_paragraph_length, style_type_token_ratio, style_hapax_share, style_function_word_share, argmap_argument_count, argmap_claim_count, argmap_conflict_count, argmap_contested_claim_count, argmap_evidence_share, argmap_depth, argmap_main_claims) VALUES ('habr-1097022', 'Мой PostgreSQL быстрее твоего и почти догнал ClickHouse', 'Автор в споре со знакомым архитектором, у которого в проде четыре разные СУБД, рассказывает, как без единого патча ядра встроил в PostgreSQL 19 табличный движок MergeTree из ClickHouse (ch_table_engines), подключил к нему свой векторизованный исполнитель pg_vexec и сделал табличный метод доступа iheap с обновлением строк на месте. Векторизация на heap дала лишь 18–19 %: узким местом оказалось чтение строк, а не вычисления; с MergeTree и серией оптимизаций среднее геометрическое время ClickBench снизилось с 715 до 49,9 мс — всего в 3 раза медленнее ClickHouse на той же машине. Вывод автора: для проектов не масштаба бигтеха одна СУБД PostgreSQL с расширениями проще зоопарка специализированных баз.', '{"schema:Article","schema:BlogPosting","schema:CreativeWork","schema:SocialMediaPosting","schema:TechArticle"}', 'article', '{"диалог-полемика","исследование производительности","личный опыт","обзор разработки"}', '{"clickbench","clickhouse","mergetree","pg_vexec","postgresql","table-access-method","tableAM","vectorization"}', '{"ch_table_engines","iheap","mergetree","pg_vexec","postgresql"}', '{"architect_friend","igor_suhorukov"}', 'igor_suhorukov', '2026-10-21T06:00:36', 'ru', 1097022, 'https://habr.com/ru/articles/1097022/', 10, 4234, 9, 31, 8, 8, 0, 'habr', 'Хабр', 'https://habr.com/', 'igor_suhorukov', 179, 331, 'habr/1097022.md', 'text/markdown', 19690, 12138, '61c608f8417e8b389ddd9a265a0fa01d9c07bdf71cb3df9831d0252e2cbc4ac5', '2026-10-26T17:24:45+00:00', 'extract/habr-1097022.yaml', 'поиск по именам и псевдонимам с лемматизацией (pymorphy3), без разрешения кореференции', 'third', 'местоимений 1-го лица вне реплик: 7.4 на 1000 слов', 1, 2.13, 7.32, '70e146e0e426', 1511, 106, 41, 14.25, 13.5, 36.9, 0.58, 0.64, 0.315, 7, 22, 1, 1, 0.286, 2, '{"claim_bottleneck_reading","claim_custom_glue","claim_heap_update_pain","claim_need_columnar","claim_not_all_steps","claim_postgres_can_compete"}');

INSERT INTO arguments (key, name, conclusion, premises, premise_role) VALUES ('527b119cfc87', 'Довод: Чтобы векторизация окупилась, нужен источник данных, отдающий колонки, — отсюда задача вс…', 'claim_need_columnar', '{"claim_no_columnar_source","claim_skip_simulation"}', 'argument');
INSERT INTO arguments (key, name, conclusion, premises, premise_role) VALUES ('58d2901f90f1', 'Довод: Векторизация в PostgreSQL упирается не в вычисления, а в считывание данных из heap', 'claim_bottleneck_reading', '{"claim_kernels_negligible","claim_page_geometry","claim_tableam_row_api"}', 'argument');
INSERT INTO arguments (key, name, conclusion, premises, premise_role) VALUES ('5a11f2593c14', 'Довод: На немодифицированном PostgreSQL 19 нет ни одного хранилища, которое отдавало бы векториз…', 'claim_no_columnar_source', '{"claim_citus_hydra_rows","claim_pax_aoco_patched"}', 'example');
INSERT INTO arguments (key, name, conclusion, premises, premise_role) VALUES ('6373e9b81a12', 'Довод: Обновление данных в PostgreSQL при длительных транзакциях болезненно: каждый UPDATE созда…', 'claim_heap_update_pain', '{"claim_friend_bloat"}', 'example');
INSERT INTO arguments (key, name, conclusion, premises, premise_role) VALUES ('8d1c37d19e64', 'Довод: Не все шаги оптимизации вели к улучшениям', 'claim_not_all_steps', '{"claim_slowdown_cause"}', 'example');
INSERT INTO arguments (key, name, conclusion, premises, premise_role) VALUES ('9e02cd634ec8', 'Довод: Старый PostgreSQL ещё может потягаться с современными базами данных в обычных проектах', 'claim_postgres_can_compete', '{"claim_iheap_no_bloat","claim_specialized_complexity","claim_use_case"}', 'argument');
INSERT INTO arguments (key, name, conclusion, premises, premise_role) VALUES ('a1fae6e8ca57', 'Довод: Встроить MergeTree в PostgreSQL простой линковкой нельзя — понадобилась собственная просл…', 'claim_custom_glue', '{"claim_not_standalone","claim_process_model"}', 'argument');

INSERT INTO conflicts (key, attacked, attacker, rebutted, verdict, name, review_name) VALUES ('026f9e57a99c', 'claim_reliable_or_fast', 'claim_final_result', false, 'disputed', 'Возражение: PostgreSQL 19 с расширениями автора выполняет ClickBench лишь в несколько раз медленнее C…', 'Возражение: Надёжность и скорость несовместимы: система бывает либо надёжной, либо быстрой');

INSERT INTO style_keywords (key, rank, lemma, count, log_likelihood) VALUES ('bbb0e8e8cd72', 1, 'мс', 14, 156.9);
INSERT INTO style_keywords (key, rank, lemma, count, log_likelihood) VALUES ('0a2652e476fb', 2, 'строка', 16, 117.7);
INSERT INTO style_keywords (key, rank, lemma, count, log_likelihood) VALUES ('8efa40a7737a', 3, 'запрос', 16, 104.1);
INSERT INTO style_keywords (key, rank, lemma, count, log_likelihood) VALUES ('8372e8aecb2d', 4, 'таблица', 14, 91.3);
INSERT INTO style_keywords (key, rank, lemma, count, log_likelihood) VALUES ('d88906f5095f', 5, 'постгреса', 7, 88.6);
INSERT INTO style_keywords (key, rank, lemma, count, log_likelihood) VALUES ('754a3c2ae757', 6, 'исполнитель', 7, 59.7);
INSERT INTO style_keywords (key, rank, lemma, count, log_likelihood) VALUES ('8abfa65d6e90', 7, 'ядро', 11, 57.6);
INSERT INTO style_keywords (key, rank, lemma, count, log_likelihood) VALUES ('315ef2733b10', 8, 'колонка', 6, 53.9);
INSERT INTO style_keywords (key, rank, lemma, count, log_likelihood) VALUES ('36aca81dccf8', 9, 'расширение', 7, 48.6);
INSERT INTO style_keywords (key, rank, lemma, count, log_likelihood) VALUES ('57c111d76a4e', 10, 'данные', 11, 47.9);
INSERT INTO style_keywords (key, rank, lemma, count, log_likelihood) VALUES ('345f75ef4226', 11, 'индекс', 5, 40.1);
INSERT INTO style_keywords (key, rank, lemma, count, log_likelihood) VALUES ('27ad1382080d', 12, 'медленный', 5, 35.7);
INSERT INTO style_keywords (key, rank, lemma, count, log_likelihood) VALUES ('7ac17dcbbf7f', 13, 'хранилище', 5, 35.3);
INSERT INTO style_keywords (key, rank, lemma, count, log_likelihood) VALUES ('386d3eabc62b', 14, 'узел', 6, 33.3);
INSERT INTO style_keywords (key, rank, lemma, count, log_likelihood) VALUES ('80327de6144f', 15, 'база', 6, 29.5);

INSERT INTO methods (key, name, concept, procedure, kind, confidence, section) VALUES ('3e9629b64285', 'Дочитывание колонок после первого условия', 'lazy_column_read', 'proc_lazy_scan', 'technique', 0.9, 'body');
INSERT INTO methods (key, name, concept, kind, confidence, section) VALUES ('748e863ad9a5', 'Автовекторизация компилятора', 'auto_vectorization', 'technique', 0.9, 'body');
INSERT INTO methods (key, name, procedure, kind, confidence, section) VALUES ('a2a5595aa345', 'Выбор хранилища таблицы через CREATE TABLE … USING', 'proc_attach_storage', 'method', 0.6, 'body');
INSERT INTO methods (key, name, concept, kind, confidence, section) VALUES ('a7206cc4374e', 'Ручная векторизация сравнений на SSE2 с movemask', 'simd_movemask', 'technique', 0.9, 'body');
INSERT INTO methods (key, name, concept, kind, confidence, section) VALUES ('b024643789a7', 'Векторизованное исполнение запросов', 'vectorized_execution', 'technique', 0.9, 'body');
INSERT INTO methods (key, name, concept, kind, confidence, section) VALUES ('c59933269aaf', 'Агрегация с разделами в общей памяти', 'partitioned_shared_agg', 'technique', 0.9, 'body');
INSERT INTO methods (key, name, concept, procedure, kind, confidence, section) VALUES ('cab91028ff8f', 'Обновление строки на месте по TID', 'inplace_update', 'proc_iheap_update', 'technique', 0.9, 'body');

INSERT INTO passages (key, section, mode, blocks, chars) VALUES ('215edfdf7e2f', 's1', 'unmarked', 12, 2918);
INSERT INTO passages (key, section, mode, blocks, chars) VALUES ('4ef562180fb8', 's4', 'code', 1, 263);
INSERT INTO passages (key, section, mode, blocks, chars) VALUES ('584a801d8a77', 's4', 'unmarked', 4, 1336);
INSERT INTO passages (key, section, mode, blocks, chars) VALUES ('7272c8ab06f4', 's2', 'unmarked', 8, 2341);
INSERT INTO passages (key, section, mode, blocks, chars) VALUES ('9a40d0681191', 's3', 'code', 1, 225);
INSERT INTO passages (key, section, mode, blocks, chars) VALUES ('d691b0ae06d0', 's5', 'unmarked', 4, 1593);
INSERT INTO passages (key, section, mode, blocks, chars) VALUES ('da45dcdcaf53', 'body', 'unmarked', 7, 740);
INSERT INTO passages (key, section, mode, blocks, chars) VALUES ('e638be4be5f9', 's3', 'unmarked', 5, 1522);

INSERT INTO media (kind, key, types, url, section) VALUES ('image', '82074d3df1cb', '{"schema:CreativeWork","schema:ImageObject","schema:MediaObject"}', 'https://habrastorage.org/extt/18/c0/40/18c0403f0359c4b82e370af263b9439c.png', 'body');
INSERT INTO media (kind, key, types, name, url, link_kind) VALUES ('link', 'aa1193282db2', '{"schema:CreativeWork","schema:SoftwareSourceCode"}', 'pg_vexec', 'https://github.com/igor-suhorukov/pg_vexec', 'repository');
INSERT INTO media (kind, key, types, name, url, link_kind) VALUES ('link', 'bc3a870cf498', '{"schema:Article","schema:BlogPosting","schema:CreativeWork","schema:SocialMediaPosting"}', 'pg_vexec', 'https://habr.com/ru/articles/1091738/', 'habr_article');
INSERT INTO media (kind, key, types, name, url, link_kind) VALUES ('link', 'be1471385550', '{"schema:CreativeWork","schema:SoftwareSourceCode"}', 'ch_table_engines', 'https://github.com/igor-suhorukov/pg_ch_table_engines', 'repository');
INSERT INTO media (kind, key, types, name, url, link_kind) VALUES ('link', 'caad0b666630', '{"schema:CreativeWork","schema:SoftwareSourceCode"}', 'iheap', 'https://github.com/igor-suhorukov/pg_inplace_update_am', 'repository');
INSERT INTO media (kind, key, types, name, url, link_kind) VALUES ('link', 'd4ecc8cec7bf', '{"schema:Article","schema:BlogPosting","schema:CreativeWork","schema:SocialMediaPosting"}', 'Apache Cloudberry на PostgreSQL 19', 'https://habr.com/ru/articles/1088264/', 'habr_article');

INSERT INTO code_listings (n, name, language, line_count, section, process, step, step_basis, start_pos, end_pos) VALUES (1, 'Код 1 (sql)', 'sql', 4, 's3', 'proc_attach_storage', 't1', 'follows', 7572, 7797);
INSERT INTO code_listings (n, name, language, line_count, section, start_pos, end_pos) VALUES (2, 'Код 2 (sql)', 'sql', 4, 's4', 9750, 10013);

INSERT INTO discourse_relations (key, name, sense, connective, scope, section, arg1_claim, arg1_start, arg1_end, arg2_start, arg2_end) VALUES ('6d443dc696b5', 'Следствие: поэтому', 'result', 'поэтому', 'inner', 's4', 'claim_iheap_compat', 10015, 10066, 10068, 10176);
INSERT INTO discourse_relations (key, name, sense, connective, scope, section, arg1_start, arg1_end, arg2_claim, arg2_start, arg2_end) VALUES ('d04b3fb5a64e', 'Следствие: поэтому', 'result', 'поэтому', 'outer', 's3', 8205, 8387, 'claim_custom_glue', 8389, 8463);
INSERT INTO discourse_relations (key, name, sense, connective, scope, section, arg1_claim, arg1_start, arg1_end, arg2_start, arg2_end) VALUES ('dac800829dee', 'Причина: потому что', 'reason', 'потому что', 'inner', 's5', 'claim_final_result', 11794, 11846, 11848, 11896);

INSERT INTO idea_links (key, name, object, person, kind, role, stance, basis) VALUES ('0eed6def06e7', 'igor_suhorukov: автор произведения — pg_vexec', 'art_pg_vexec', 'igor_suhorukov', 'origin', 'authored', 'cites', 'work');
INSERT INTO idea_links (key, name, object, person, kind, role, year, basis) VALUES ('1f57a1ddbf60', 'igor_suhorukov: автор произведения — Мой PostgreSQL быстрее твоего и почти догнал ClickHouse', 'work', 'igor_suhorukov', 'origin', 'authored', 2026, 'work');
INSERT INTO idea_links (key, name, object, person, kind, role, stance, basis) VALUES ('762a53f1f463', 'igor_suhorukov: автор произведения — iheap (pg_inplace_update_am)', 'iheap', 'igor_suhorukov', 'origin', 'authored', 'cites', 'work');
INSERT INTO idea_links (key, name, object, person, kind, role, stance, basis) VALUES ('bb881327bfcb', 'igor_suhorukov: автор произведения — Apache Cloudberry на PostgreSQL 19', 'art_cloudberry_pg19', 'igor_suhorukov', 'origin', 'authored', 'cites', 'work');
INSERT INTO idea_links (key, name, object, person, kind, role, stance, basis) VALUES ('dee1de855fad', 'igor_suhorukov: автор произведения — pg_vexec', 'pg_vexec', 'igor_suhorukov', 'origin', 'authored', 'cites', 'work');
INSERT INTO idea_links (key, name, object, person, kind, role, stance, basis) VALUES ('ff5544b26ac0', 'igor_suhorukov: автор произведения — ch_table_engines', 'ch_table_engines', 'igor_suhorukov', 'origin', 'authored', 'cites', 'work');

INSERT INTO theme_links (key, name, subject, theme, matched, basis) VALUES ('1d39564a1933', 'Тема «базы данных и хранение данных»: Мой PostgreSQL быстрее твоего и почти догнал ClickHouse', 'work', 'databases', 'postgresql', 'keyword');
INSERT INTO theme_links (key, name, subject, theme, matched, basis) VALUES ('297b36b8dfaa', 'Тема «программирование и разработка»: Автовекторизация компилятора', 'auto_vectorization', 'programming', 'компилятора', 'name');
INSERT INTO theme_links (key, name, subject, theme, matched, basis) VALUES ('343fc96d9c9b', 'Тема «программирование и разработка»: Программирование', 'theme/programmirovanie', 'programming', 'программирование', 'name');
INSERT INTO theme_links (key, name, subject, theme, matched, basis) VALUES ('37642d7bffd6', 'Тема «базы данных и хранение данных»: Повторное построение DFA движком регулярных выражений PostgreSQL', 'regex_dfa_rebuild', 'databases', 'postgresql', 'name');
INSERT INTO theme_links (key, name, subject, theme, matched, basis) VALUES ('3a8321e8bc58', 'Тема «базы данных и хранение данных»: одна СУБД против зоопарка специализированных баз', 'theme/odna_subd_protiv_zooparka_spetsializirovannykh_baz', 'databases', 'субд', 'name');
INSERT INTO theme_links (key, name, subject, theme, matched, basis) VALUES ('3c716bf032f5', 'Тема «базы данных и хранение данных»: heap (штатное хранилище таблиц PostgreSQL)', 'heap', 'databases', 'postgresql', 'name');
INSERT INTO theme_links (key, name, subject, theme, matched, basis) VALUES ('51ea51bba56d', 'Тема «базы данных и хранение данных»: PostgreSQL', 'theme/postgresql', 'databases', 'postgresql', 'name');
INSERT INTO theme_links (key, name, subject, theme, matched, basis) VALUES ('6dad7b86d334', 'Тема «базы данных и хранение данных»: Базы данных', 'theme/bazy_dannykh', 'databases', 'базы данных', 'name');
INSERT INTO theme_links (key, name, subject, theme, matched, basis) VALUES ('76bfc7dcf04e', 'Тема «операционные системы и процессы»: Стоимостный планировщик', 'cost_based_planner', 'os_systems', 'планировщик', 'name');
INSERT INTO theme_links (key, name, subject, theme, matched, basis) VALUES ('889157a59808', 'Тема «базы данных и хранение данных»: векторизованное исполнение запросов в PostgreSQL', 'theme/vektorizovannoe_ispolnenie_zaprosov_v_postgresql', 'databases', 'postgresql', 'name');
INSERT INTO theme_links (key, name, subject, theme, matched, basis) VALUES ('f4c8a195b75f', 'Тема «базы данных и хранение данных»: колоночное хранилище MergeTree внутри PostgreSQL', 'theme/kolonochnoe_khranilishche_mergetree_vnutri_postgresql', 'databases', 'postgresql', 'name');

INSERT INTO copresence (key, name, persons, talks, talk_count, kind, basis) VALUES ('e515c8ce154a', 'Вместе: Знакомый архитектор автора и igor_suhorukov', '{"architect_friend","igor_suhorukov"}', '{"rep01","rep02","rep03","rep04","rep05","rep06","rep07","rep08","rep09","rep10","rep11","rep12","rep13","rep14","rep15","rep16","rep17"}', 17, 'persons', 'conversation');

INSERT INTO state_spans (key, name, entity, kind, span_index, started_by, first_attested_by, last_attested_by, from_rank, to_rank) VALUES ('c411dd9ed9dc', 'Существование: pg_vexec', 'pg_vexec', 'existence', 1, 'ev_vexec_dev', 'ev_vexec_dev', 'ev_vexec_dev', 2, 2);

INSERT INTO terms (slug, name, denotes, mention_count) VALUES ('hash_table', 'хеш-таблица', 'hash_table', 1);

INSERT INTO concept_links (key, name, concept, global, kind, basis, cue, confidence, method) VALUES ('7ba4b5cd1e7d', 'синоним: Автовекторизация компилятора ↔ Векторизация', 'auto_vectorization', 'automatic_vectorization', 'synonym', 'match', 'Автовекторизация компилятора = Векторизация', 0.85, 'rule');

COMMIT;

-- ============================================================== отображение R2RML таблиц в граф знаний
SELECT kb.add_mapping('habr_1097022', $ttl$# Story-KG, статья habr/1097022.md «Мой PostgreSQL быстрее твоего и почти догнал ClickHouse»: отображение R2RML
# таблиц схемы habr_1097022 (schema.sql) в граф знаний статьи — те же квады, что в хранилище Story-KG (source.nq).
#
#   SELECT kb.add_mapping('habr_1097022', pg_read_file('.../mapping.ttl'));
#
# Карта — таблица в одном графе: свойства статьи (граф kgg:habr-1097022), граф упоминаний, выведенные фреймы
# (kgg:derived-*), граф _global, граф по умолчанию (описания графов). Узлы статьи — шаблоны и колонки относительно
# @base: «{id}» — https://example.org/story-kg/id/habr-1097022/<id>. Списки разворачивает unnest() в rr:sqlQuery;
# классы, постоянные свойства, обратные и симметричные связи, имена из колонок пишет само отображение.

@base <https://example.org/story-kg/id/habr-1097022/> .
@prefix rr: <http://www.w3.org/ns/r2rml#> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
@prefix owl: <http://www.w3.org/2002/07/owl#> .
@prefix schema: <http://schema.org/> .
@prefix kgo: <https://example.org/story-kg/ontology#> .
@prefix kgt: <https://example.org/story-kg/ontology/tech#> .
@prefix kgg: <https://example.org/story-kg/graph/> .
@prefix kge: <https://example.org/story-kg/id/global/> .
@prefix kgc: <https://example.org/story-kg/concept/> .
@prefix oa: <http://www.w3.org/ns/oa#> .
@prefix skos: <http://www.w3.org/2004/02/skos/core#> .
@prefix prov: <http://www.w3.org/ns/prov#> .
@prefix dcterms: <http://purl.org/dc/terms/> .
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
@prefix sioc: <http://rdfs.org/sioc/ns#> .
@prefix vcard: <http://www.w3.org/2006/vcard/ns#> .
@prefix bbo: <https://www.irit.fr/recherches/MELODI/ontologies/BBO#> .
@prefix eso: <http://www.newsreader-project.eu/domain-ontology#> .
@prefix qb: <http://purl.org/linked-data/cube#> .


# =================================================================== статья (article), граф статьи

<#article> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT a.*, a.habr_id::text AS identifier,
               'https://example.org/story-kg/src/' || a.source_file AS src
        FROM habr_1097022.article a""" ] ;
    rr:subjectMap [ rr:constant <work> ; rr:graph kgg:habr-1097022 ] ;
    rr:predicateObjectMap
        [ rr:predicate schema:name , schema:headline ; rr:objectMap [ rr:column "title" ; rr:language "ru" ] ] ,
        [ rr:predicate schema:description ; rr:objectMap [ rr:column "description" ; rr:language "ru" ] ] ,
        [ rr:predicate schema:additionalType ; rr:objectMap [ rr:column "post_type" ] ] ,
        [ rr:predicate schema:author ; rr:objectMap [ rr:column "author" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate schema:author ;
          rr:objectMap [ rr:template "https://example.org/story-kg/id/global/habr-user/{author_nick}" ] ] ,
        [ rr:predicate schema:datePublished ; rr:objectMap [ rr:column "published" ] ] ,
        [ rr:predicate schema:inLanguage ; rr:objectMap [ rr:column "language" ] ] ,
        [ rr:predicate schema:identifier ; rr:objectMap [ rr:column "identifier" ] ] ,
        [ rr:predicate schema:sameAs ; rr:objectMap [ rr:column "url" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate kgo:score ; rr:objectMap [ rr:column "score" ] ] ,
        [ rr:predicate schema:publisher ;
          rr:objectMap [ rr:template "https://example.org/story-kg/id/global/{publisher}" ] ] ,
        [ rr:predicate schema:encoding ; rr:objectMap [ rr:column "src" ; rr:termType rr:IRI ] ] .

<#article-types> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT habr_1097022.iri(t) AS class FROM habr_1097022.article, unnest(types) t""" ] ;
    rr:subjectMap [ rr:constant <work> ; rr:graph kgg:habr-1097022 ] ;
    rr:predicateObjectMap [ rr:predicate rdf:type ; rr:objectMap [ rr:column "class" ; rr:termType rr:IRI ] ] .

<#article-genres> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT v FROM habr_1097022.article, unnest(genres) v" ] ;
    rr:subjectMap [ rr:constant <work> ; rr:graph kgg:habr-1097022 ] ;
    rr:predicateObjectMap [ rr:predicate schema:genre ; rr:objectMap [ rr:column "v" ; rr:language "ru" ] ] .

# теги автора — строкой и строкой @ru, как их пишет компилятор
<#article-tags> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT v FROM habr_1097022.article, unnest(tags) v" ] ;
    rr:subjectMap [ rr:constant <work> ; rr:graph kgg:habr-1097022 ] ;
    rr:predicateObjectMap
        [ rr:predicate schema:keywords ; rr:objectMap [ rr:column "v" ] ] ,
        [ rr:predicate schema:keywords ; rr:objectMap [ rr:column "v" ; rr:language "ru" ] ] .

<#article-about> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT v FROM habr_1097022.article, unnest(about) v" ] ;
    rr:subjectMap [ rr:constant <work> ; rr:graph kgg:habr-1097022 ] ;
    rr:predicateObjectMap [ rr:predicate schema:about ; rr:objectMap [ rr:column "v" ; rr:termType rr:IRI ] ] .

<#article-mentions> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT v FROM habr_1097022.article, unnest(mentions) v" ] ;
    rr:subjectMap [ rr:constant <work> ; rr:graph kgg:habr-1097022 ] ;
    rr:predicateObjectMap [ rr:predicate schema:mentions ; rr:objectMap [ rr:column "v" ; rr:termType rr:IRI ] ] .

# счётчики Хабра: узел work#stat-<ключ шапки> на колонку
<#article-counters> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT c.key, c.action, c.n
        FROM habr_1097022.article a,
             LATERAL (VALUES ('readingCount', 'ReadAction', a.reading_count),
                             ('commentsCount', 'CommentAction', a.comments_count),
                             ('favoritesCount', 'BookmarkAction', a.favorites_count),
                             ('votesCount', 'VoteAction', a.votes_count),
                             ('votesCountPlus', 'LikeAction', a.votes_plus),
                             ('votesCountMinus', 'DislikeAction', a.votes_minus)) AS c (key, action, n)
        WHERE c.n IS NOT NULL""" ] ;
    rr:subjectMap [ rr:template "work#stat-{key}" ; rr:graph kgg:habr-1097022 ;
                    rr:class schema:InteractionCounter , schema:Intangible , schema:StructuredValue ] ;
    rr:predicateObjectMap
        [ rr:predicate schema:interactionType ; rr:objectMap [ rr:template "http://schema.org/{action}" ] ] ,
        [ rr:predicate schema:userInteractionCount ; rr:objectMap [ rr:column "n" ] ] .

<#article-counter-links> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT c.key
        FROM habr_1097022.article a,
             LATERAL (VALUES ('readingCount', a.reading_count), ('commentsCount', a.comments_count),
                             ('favoritesCount', a.favorites_count), ('votesCount', a.votes_count),
                             ('votesCountPlus', a.votes_plus), ('votesCountMinus', a.votes_minus)) AS c (key, n)
        WHERE c.n IS NOT NULL""" ] ;
    rr:subjectMap [ rr:constant <work> ; rr:graph kgg:habr-1097022 ] ;
    rr:predicateObjectMap [ rr:predicate schema:interactionStatistic ; rr:objectMap [ rr:template "work#stat-{key}" ] ] .

# исходный файл и его версия
<#source-file> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT a.source_file, a.source_format, a.source_chars, a.source_sha256,
               a.source_bytes || ' bytes' AS size,
               'https://example.org/story-kg/src/' || a.source_file AS src
        FROM habr_1097022.article a""" ] ;
    rr:subjectMap [ rr:column "src" ; rr:graph kgg:habr-1097022 ;
                    rr:class dcterms:BibliographicResource , schema:CreativeWork , schema:MediaObject ] ;
    rr:predicateObjectMap
        [ rr:predicate schema:name , schema:identifier ; rr:objectMap [ rr:column "source_file" ] ] ,
        [ rr:predicate schema:encodingFormat ; rr:objectMap [ rr:column "source_format" ] ] ,
        [ rr:predicate schema:contentSize ; rr:objectMap [ rr:column "size" ] ] ,
        [ rr:predicate kgo:charCount ; rr:objectMap [ rr:column "source_chars" ] ] ,
        [ rr:predicate kgo:sha256 ; rr:objectMap [ rr:column "source_sha256" ] ] ,
        [ rr:predicate schema:encodesCreativeWork ; rr:object <work> ] .

<#source-state> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT a.source_sha256,
               'https://example.org/story-kg/src/' || a.source_file || '#state-' || left(a.source_sha256, 12) AS state,
               to_char(a.source_date AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS') || '+00:00' AS date
        FROM habr_1097022.article a""" ] ;
    rr:subjectMap [ rr:column "state" ; rr:graph kgg:habr-1097022 ; rr:class oa:TimeState ] ;
    rr:predicateObjectMap
        [ rr:predicate kgo:sha256 ; rr:objectMap [ rr:column "source_sha256" ] ] ,
        [ rr:predicate oa:sourceDate ; rr:objectMap [ rr:column "date" ; rr:datatype xsd:dateTime ] ] .

# издатель, автор и его учётная запись на Хабре — глобальные узлы, описанные в графе статьи
<#publisher> a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "habr_1097022.article" ] ;
    rr:subjectMap [ rr:template "https://example.org/story-kg/id/global/{publisher}" ; rr:graph kgg:habr-1097022 ;
                    rr:class schema:Organization , kgo:OnlineCommunity ] ;
    rr:predicateObjectMap
        [ rr:predicate schema:name ; rr:objectMap [ rr:column "publisher_name" ] ] ,
        [ rr:predicate schema:url ; rr:objectMap [ rr:column "publisher_url" ; rr:termType rr:IRI ] ] .

<#habr-user> a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "habr_1097022.article" ] ;
    rr:subjectMap [ rr:template "https://example.org/story-kg/id/global/habr-user/{author_nick}" ;
                    rr:graph kgg:habr-1097022 ; rr:class schema:Person ] ;
    rr:predicateObjectMap
        [ rr:predicate schema:name , schema:alternateName ; rr:objectMap [ rr:column "author_nick" ] ] ,
        [ rr:predicate foaf:account ;
          rr:objectMap [ rr:template "https://example.org/story-kg/id/global/habr-account/{author_nick}" ] ] .

<#habr-account> a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "habr_1097022.article" ] ;
    rr:subjectMap [ rr:template "https://example.org/story-kg/id/global/habr-account/{author_nick}" ;
                    rr:graph kgg:habr-1097022 ; rr:class foaf:OnlineAccount , sioc:UserAccount ] ;
    rr:predicateObjectMap
        [ rr:predicate foaf:accountName ; rr:objectMap [ rr:column "author_nick" ] ] ,
        [ rr:predicate foaf:accountServiceHomepage ; rr:objectMap [ rr:column "publisher_url" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate kgo:accountScore ; rr:objectMap [ rr:column "author_score" ] ] ,
        [ rr:predicate kgo:accountVotesCount ; rr:objectMap [ rr:column "author_votes" ] ] ,
        [ rr:predicate kgo:sensitivity ; rr:object kgc:sensitivity\/personal ] ,
        [ rr:predicate sioc:account_of ;
          rr:objectMap [ rr:template "https://example.org/story-kg/id/global/habr-user/{author_nick}" ] ] .

# словарь понятий статьи (раздел concepts спецификации)
<#concept-scheme> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT 'Понятия: ' || source_file AS name FROM habr_1097022.article" ] ;
    rr:subjectMap [ rr:constant <terms> ; rr:graph kgg:habr-1097022 ;
                    rr:class schema:CreativeWork , schema:DefinedTermSet , skos:ConceptScheme ] ;
    rr:predicateObjectMap [ rr:predicate schema:name ; rr:objectMap [ rr:column "name" ; rr:language "ru" ] ] .

# описания графов статьи — в графе по умолчанию
<#graph-article> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT spec_file, 'https://example.org/story-kg/src/' || source_file AS src FROM habr_1097022.article""" ] ;
    rr:subjectMap [ rr:constant kgg:habr-1097022 ; rr:class prov:Entity ] ;
    rr:predicateObjectMap
        [ rr:predicate dcterms:source ; rr:objectMap [ rr:column "spec_file" ] ] ,
        [ rr:predicate prov:wasDerivedFrom ; rr:objectMap [ rr:column "src" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate prov:wasGeneratedBy ; rr:object <https://example.org/story-kg/id/run/kgc> ] .

<#graph-mentions> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT mentions_method, 'https://example.org/story-kg/src/' || source_file AS src FROM habr_1097022.article""" ] ;
    rr:subjectMap [ rr:constant kgg:habr-1097022-mentions ] ;
    rr:predicateObjectMap
        [ rr:predicate kgo:extractionMethod ; rr:objectMap [ rr:column "mentions_method" ; rr:language "ru" ] ] ,
        [ rr:predicate prov:wasDerivedFrom ; rr:objectMap [ rr:column "src" ; rr:termType rr:IRI ] ] .

# ------------------------------------------------------------------- выведенные сводки статьи

<#article-narrative> a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "habr_1097022.article" ] ;
    rr:subjectMap [ rr:constant <work> ; rr:graph kgg:derived-narrative ] ;
    rr:predicateObjectMap
        [ rr:predicate kgo:narrativePersonType ;
          rr:objectMap [ rr:template "https://example.org/story-kg/concept/person/{narrative_person}" ] ] ,
        [ rr:predicate kgo:narrativePersonBasis ; rr:objectMap [ rr:column "narrative_person_basis" ] ] .

# отклик на статью (derived-ratings): счётчики — те же колонки, что счётчики Хабра
<#response> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT a.*, 'Отклик на статью: ' || a.title AS name
        FROM habr_1097022.article a WHERE a.like_share IS NOT NULL""" ] ;
    rr:subjectMap [ rr:constant <response> ; rr:graph kgg:derived-ratings ; rr:class kgo:ArticleResponse ] ;
    rr:predicateObjectMap
        [ rr:predicate schema:name ; rr:objectMap [ rr:column "name" ; rr:language "ru" ] ] ,
        [ rr:predicate kgo:viewCount ; rr:objectMap [ rr:column "reading_count" ] ] ,
        [ rr:predicate kgo:commentCount ; rr:objectMap [ rr:column "comments_count" ] ] ,
        [ rr:predicate kgo:bookmarkCount ; rr:objectMap [ rr:column "favorites_count" ] ] ,
        [ rr:predicate kgo:voteCount ; rr:objectMap [ rr:column "votes_count" ] ] ,
        [ rr:predicate kgo:likeCount ; rr:objectMap [ rr:column "votes_plus" ] ] ,
        [ rr:predicate kgo:dislikeCount ; rr:objectMap [ rr:column "votes_minus" ] ] ,
        [ rr:predicate kgo:likeShare ; rr:objectMap [ rr:column "like_share" ] ] ,
        [ rr:predicate kgo:commentsPerThousandViews ; rr:objectMap [ rr:column "comments_per_1000_views" ] ] ,
        [ rr:predicate kgo:bookmarksPerThousandViews ; rr:objectMap [ rr:column "bookmarks_per_1000_views" ] ] ,
        [ rr:predicate kgo:responseOf , kgo:inDocument , prov:wasDerivedFrom ; rr:object <work> ] ,
        [ rr:predicate kgo:derivationRule ; rr:object "отклик на статью — её счётчики schema:InteractionCounter (просмотры, комментарии, закладки, голоса за и против, все голоса) одним узлом; комментариев и закладок на тысячу просмотров; доля голосов «за» среди голосов за и против; место статьи среди статей графа в каждом её хабе — по просмотрам (хаб, где у графа одна статья, мест не даёт)"@ru ] .

# профиль стиля (derived-stylometry)
<#style> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT a.*, 'Стиль текста: ' || a.slug AS name
        FROM habr_1097022.article a WHERE a.style_key IS NOT NULL""" ] ;
    rr:subjectMap [ rr:template "style/{style_key}" ; rr:graph kgg:derived-stylometry ;
                    rr:class kgo:StyleProfile , kgo:TextStyleProfile ] ;
    rr:predicateObjectMap
        [ rr:predicate schema:name ; rr:objectMap [ rr:column "name" ; rr:language "ru" ] ] ,
        [ rr:predicate kgo:styleWordCount ; rr:objectMap [ rr:column "style_word_count" ] ] ,
        [ rr:predicate kgo:styleSentenceCount ; rr:objectMap [ rr:column "style_sentence_count" ] ] ,
        [ rr:predicate kgo:styleParagraphCount ; rr:objectMap [ rr:column "style_paragraph_count" ] ] ,
        [ rr:predicate kgo:meanSentenceLength ; rr:objectMap [ rr:column "style_mean_sentence_length" ] ] ,
        [ rr:predicate kgo:medianSentenceLength ; rr:objectMap [ rr:column "style_median_sentence_length" ] ] ,
        [ rr:predicate kgo:meanParagraphLength ; rr:objectMap [ rr:column "style_mean_paragraph_length" ] ] ,
        [ rr:predicate kgo:typeTokenRatio ; rr:objectMap [ rr:column "style_type_token_ratio" ] ] ,
        [ rr:predicate kgo:hapaxShare ; rr:objectMap [ rr:column "style_hapax_share" ] ] ,
        [ rr:predicate kgo:functionWordShare ; rr:objectMap [ rr:column "style_function_word_share" ] ] ,
        [ rr:predicate kgo:styleOf , kgo:inDocument ; rr:object <work> ] ,
        [ rr:predicate kgo:derivationRule ; rr:object "профиль стиля текста по самому тексту: слова, предложения (razdel) и абзацы без заголовков и таблиц; средняя и медианная длина предложения в словах; средняя длина абзаца; богатство словаря — скользящее отношение лемм к словам в окне 500 слов (MATTR, Covington, McFall 2010) и доля лемм, встретившихся один раз; доля служебных слов (предлоги, союзы, частицы, местоимения; первое чтение pymorphy3); доля слов речи — в романе и прозе (речь вырезана так же, как во фрейме 101); ключевые слова — леммы знаменательных слов против остального корпуса без учебников (логарифм отношения правдоподобия G², Dunning 1993; не реже 5 раз и чаще, чем в фоне)"@ru ] .

# карта аргументации (derived-arguments)
<#argument-map> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT a.*, 'Карта аргументации (' || a.slug || ')' AS name
        FROM habr_1097022.article a WHERE a.argmap_argument_count IS NOT NULL""" ] ;
    rr:subjectMap [ rr:constant <argument-map> ; rr:graph kgg:derived-arguments ; rr:class kgo:ArgumentMap ] ;
    rr:predicateObjectMap
        [ rr:predicate schema:name ; rr:objectMap [ rr:column "name" ; rr:language "ru" ] ] ,
        [ rr:predicate kgo:argumentCount ; rr:objectMap [ rr:column "argmap_argument_count" ] ] ,
        [ rr:predicate kgo:claimCount ; rr:objectMap [ rr:column "argmap_claim_count" ] ] ,
        [ rr:predicate kgo:conflictCount ; rr:objectMap [ rr:column "argmap_conflict_count" ] ] ,
        [ rr:predicate kgo:contestedClaimCount ; rr:objectMap [ rr:column "argmap_contested_claim_count" ] ] ,
        [ rr:predicate kgo:evidenceShare ; rr:objectMap [ rr:column "argmap_evidence_share" ] ] ,
        [ rr:predicate kgo:maxDepth ; rr:objectMap [ rr:column "argmap_depth" ] ] ,
        [ rr:predicate schema:isBasedOn , kgo:inDocument ; rr:object <work> ] ,
        [ rr:predicate kgo:derivationRule ; rr:object "главные тезисы — выводы, которые сами не служат посылкой и не возражают; глубина — самая длинная цепочка «посылка → вывод»; доля доказательных посылок — примеры, статистика и контрпримеры среди всех посылок" ] .

<#argument-map-claims> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT v FROM habr_1097022.article, unnest(argmap_main_claims) v" ] ;
    rr:subjectMap [ rr:constant <argument-map> ; rr:graph kgg:derived-arguments ] ;
    rr:predicateObjectMap [ rr:predicate kgo:mainClaim ; rr:objectMap [ rr:column "v" ; rr:termType rr:IRI ] ] .

# стек техники (derived-techstack): компоненты — строки entities и concepts с stack_role, отношения — in_stack
<#techstack> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT 'Технологический стек: ' || a.title AS name FROM habr_1097022.article a
        WHERE EXISTS (SELECT FROM habr_1097022.relations WHERE in_stack)
           OR EXISTS (SELECT FROM habr_1097022.entities WHERE stack_role IS NOT NULL)
           OR EXISTS (SELECT FROM habr_1097022.concepts WHERE stack_role IS NOT NULL)""" ] ;
    rr:subjectMap [ rr:constant <techstack> ; rr:graph kgg:derived-techstack ; rr:class kgo:TechStack ] ;
    rr:predicateObjectMap
        [ rr:predicate schema:name ; rr:objectMap [ rr:column "name" ; rr:language "ru" ] ] ,
        [ rr:predicate kgo:stackOf , kgo:inDocument ; rr:object <work> ] ,
        [ rr:predicate kgo:derivationRule ; rr:object "компоненты — технологии, связанные в статье отношениями зависимости, реализации, платформы, происхождения, совместимости, версии" ] .

<#techstack-components> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT id FROM habr_1097022.entities WHERE stack_role IS NOT NULL
        UNION SELECT id FROM habr_1097022.concepts WHERE stack_role IS NOT NULL""" ] ;
    rr:subjectMap [ rr:constant <techstack> ; rr:graph kgg:derived-techstack ] ;
    rr:predicateObjectMap [ rr:predicate kgo:stackComponent ; rr:objectMap [ rr:column "id" ; rr:termType rr:IRI ] ] .

<#techstack-relations> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT key FROM habr_1097022.relations WHERE in_stack" ] ;
    rr:subjectMap [ rr:constant <techstack> ; rr:graph kgg:derived-techstack ] ;
    rr:predicateObjectMap [ rr:predicate kgo:stackRelation , prov:wasDerivedFrom ; rr:objectMap [ rr:template "rel/{key}" ] ] .

# словарь терминов (derived-terminology), когда терминология нашла термины
<#glossary> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT 'Термины и аббревиатуры статьи «' || a.title || '» (восстановлены правилами)' AS name
        FROM habr_1097022.article a WHERE EXISTS (SELECT FROM habr_1097022.terms)""" ] ;
    rr:subjectMap [ rr:constant <glossary> ; rr:graph kgg:derived-terminology ;
                    rr:class schema:CreativeWork , schema:DefinedTermSet ] ;
    rr:predicateObjectMap
        [ rr:predicate schema:name ; rr:objectMap [ rr:column "name" ; rr:language "ru" ] ] ,
        [ rr:predicate schema:isBasedOn , kgo:inDocument ; rr:object <work> ] .


# =================================================================== хабы (hubs)

<#hubs> a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "habr_1097022.hubs" ] ;
    rr:subjectMap [ rr:template "https://example.org/story-kg/id/global/habr-hub/{slug}" ; rr:graph kgg:habr-1097022 ;
                    rr:class skos:Concept ] ;
    rr:predicateObjectMap
        [ rr:predicate skos:prefLabel ; rr:objectMap [ rr:column "name" ; rr:language "ru" ] ] ,
        [ rr:predicate skos:inScheme ; rr:object kge:habr-hubs ] .

<#article-hubs> a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "habr_1097022.hubs" ] ;
    rr:subjectMap [ rr:constant <work> ; rr:graph kgg:habr-1097022 ] ;
    rr:predicateObjectMap
        [ rr:predicate kgo:hub ; rr:objectMap [ rr:template "https://example.org/story-kg/id/global/habr-hub/{slug}" ] ] .

# место статьи в рейтинге хаба по просмотрам (derived-ratings)
<#hub-rank> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT * FROM habr_1097022.hubs WHERE views_rank_key IS NOT NULL" ] ;
    rr:subjectMap [ rr:template "response#hub-{views_rank_key}" ; rr:graph kgg:derived-ratings ;
                    rr:class schema:ListItem , schema:Intangible ] ;
    rr:predicateObjectMap
        [ rr:predicate schema:position ; rr:objectMap [ rr:column "views_rank" ] ] ,
        [ rr:predicate schema:item , kgo:inDocument ; rr:object <work> ] .

<#hub-rank-list> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT * FROM habr_1097022.hubs WHERE views_rank_key IS NOT NULL" ] ;
    rr:subjectMap [ rr:template "https://example.org/story-kg/id/global/habr-hub/{slug}#by-views" ;
                    rr:graph kgg:derived-ratings ] ;
    rr:predicateObjectMap
        [ rr:predicate schema:itemListElement ; rr:objectMap [ rr:template "response#hub-{views_rank_key}" ] ] ,
        [ rr:predicate prov:wasDerivedFrom ; rr:object <work> ] .

<#response-hubs> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT * FROM habr_1097022.hubs WHERE views_rank_key IS NOT NULL" ] ;
    rr:subjectMap [ rr:constant <response> ; rr:graph kgg:derived-ratings ] ;
    rr:predicateObjectMap
        [ rr:predicate kgo:hubPosition ; rr:objectMap [ rr:template "response#hub-{views_rank_key}" ] ] .


# =================================================================== темы (themes)

<#themes> a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "habr_1097022.themes" ] ;
    rr:subjectMap [ rr:template "theme/{slug}" ; rr:graph kgg:habr-1097022 ;
                    rr:class schema:DefinedTerm , schema:Intangible , skos:Concept ] ;
    rr:predicateObjectMap
        [ rr:predicate schema:name , skos:prefLabel ; rr:objectMap [ rr:column "name" ; rr:language "ru" ] ] .

<#article-themes> a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "habr_1097022.themes" ] ;
    rr:subjectMap [ rr:constant <work> ; rr:graph kgg:habr-1097022 ] ;
    rr:predicateObjectMap [ rr:predicate kgo:theme ; rr:objectMap [ rr:template "theme/{slug}" ] ] .


# =================================================================== разделы (sections)

<#sections> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT s.*, coalesce('sec/' || s.parent, 'work') AS part_of FROM habr_1097022.sections s""" ] ;
    rr:subjectMap [ rr:template "sec/{id}" ; rr:graph kgg:habr-1097022 ] ;
    rr:predicateObjectMap
        [ rr:predicate rdf:type ; rr:objectMap [ rr:template "https://example.org/story-kg/ontology#{kind}" ] ] ,
        [ rr:predicate kgo:sectionId ; rr:objectMap [ rr:column "id" ] ] ,
        [ rr:predicate schema:name ; rr:objectMap [ rr:column "name" ; rr:language "ru" ] ] ,
        [ rr:predicate kgo:level ; rr:objectMap [ rr:column "level" ] ] ,
        [ rr:predicate kgo:line ; rr:objectMap [ rr:column "line" ] ] ,
        [ rr:predicate schema:isPartOf ; rr:objectMap [ rr:column "part_of" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate kgo:textSpan ; rr:objectMap [ rr:template "sec/{id}#span" ] ] .

<#section-spans> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT s.id,
               'https://example.org/story-kg/src/' || a.source_file AS src,
               'https://example.org/story-kg/src/' || a.source_file || '#state-' || left(a.source_sha256, 12) AS state
        FROM habr_1097022.sections s CROSS JOIN habr_1097022.article a""" ] ;
    rr:subjectMap [ rr:template "sec/{id}#span" ; rr:graph kgg:habr-1097022 ; rr:class oa:SpecificResource ] ;
    rr:predicateObjectMap
        [ rr:predicate oa:hasSelector ; rr:objectMap [ rr:template "sec/{id}#span-selector" ] ] ,
        [ rr:predicate oa:hasSource ; rr:objectMap [ rr:column "src" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate oa:hasState ; rr:objectMap [ rr:column "state" ; rr:termType rr:IRI ] ] .

<#section-selectors> a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "habr_1097022.sections" ] ;
    rr:subjectMap [ rr:template "sec/{id}#span-selector" ; rr:graph kgg:habr-1097022 ;
                    rr:class oa:TextPositionSelector ] ;
    rr:predicateObjectMap
        [ rr:predicate oa:start ; rr:objectMap [ rr:column "start_pos" ; rr:datatype xsd:nonNegativeInteger ] ] ,
        [ rr:predicate oa:end ; rr:objectMap [ rr:column "end_pos" ; rr:datatype xsd:nonNegativeInteger ] ] .

<#section-mentions> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT id, v FROM habr_1097022.sections, unnest(mentions) v" ] ;
    rr:subjectMap [ rr:template "sec/{id}" ; rr:graph kgg:habr-1097022-mentions ] ;
    rr:predicateObjectMap [ rr:predicate schema:mentions ; rr:objectMap [ rr:column "v" ; rr:termType rr:IRI ] ] .

<#section-passages> a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "habr_1097022.sections" ] ;
    rr:subjectMap [ rr:template "sec/{id}" ; rr:graph kgg:derived-passages ] ;
    rr:predicateObjectMap
        [ rr:predicate kgo:mainClaim ; rr:objectMap [ rr:column "main_claim" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate kgo:mainClaimSupports ; rr:objectMap [ rr:column "main_claim_supports" ] ] .

<#section-terms> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT id, v FROM habr_1097022.sections, unnest(terms) v" ] ;
    rr:subjectMap [ rr:template "sec/{id}" ; rr:graph kgg:derived-terminology ] ;
    rr:predicateObjectMap [ rr:predicate schema:mentions ; rr:objectMap [ rr:template "term/{v}" ] ] .


# =================================================================== цитаты-доказательства (evidence)
# аннотация anno/<key> в своём графе; цель и два селектора — пустые узлы <key>-t, <key>-q, <key>-p

<#evidence> a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "habr_1097022.evidence" ] ;
    rr:subjectMap [ rr:template "anno/{key}" ; rr:class oa:Annotation ;
                    rr:graphMap [ rr:template "https://example.org/story-kg/graph/{graph}" ] ] ;
    rr:predicateObjectMap
        [ rr:predicate oa:hasBody ; rr:objectMap [ rr:column "about" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate oa:hasTarget ; rr:objectMap [ rr:template "{key}-t" ; rr:termType rr:BlankNode ] ] ,
        [ rr:predicate oa:motivatedBy ; rr:objectMap [ rr:template "http://www.w3.org/ns/oa#{motivation}" ] ] ,
        [ rr:predicate rdfs:comment ; rr:objectMap [ rr:column "comment" ; rr:language "ru" ] ] .

<#evidence-targets> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT e.key, e.graph, e.section, e.line,
               'https://example.org/story-kg/src/' || a.source_file AS src,
               CASE WHEN e.graph <> 'habr-1097022-mentions'
                    THEN 'https://example.org/story-kg/src/' || a.source_file || '#state-' || left(a.source_sha256, 12)
               END AS state
        FROM habr_1097022.evidence e CROSS JOIN habr_1097022.article a""" ] ;
    rr:subjectMap [ rr:template "{key}-t" ; rr:termType rr:BlankNode ; rr:class oa:SpecificResource ;
                    rr:graphMap [ rr:template "https://example.org/story-kg/graph/{graph}" ] ] ;
    rr:predicateObjectMap
        [ rr:predicate oa:hasSource ; rr:objectMap [ rr:column "src" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate oa:hasState ; rr:objectMap [ rr:column "state" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate kgo:inSection ; rr:objectMap [ rr:template "sec/{section}" ] ] ,
        [ rr:predicate kgo:line ; rr:objectMap [ rr:column "line" ] ] ,
        [ rr:predicate oa:hasSelector ; rr:objectMap [ rr:template "{key}-q" ; rr:termType rr:BlankNode ] ] ,
        [ rr:predicate oa:hasSelector ; rr:objectMap [ rr:template "{key}-p" ; rr:termType rr:BlankNode ] ] .

<#evidence-quotes> a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "habr_1097022.evidence" ] ;
    rr:subjectMap [ rr:template "{key}-q" ; rr:termType rr:BlankNode ; rr:class oa:TextQuoteSelector ;
                    rr:graphMap [ rr:template "https://example.org/story-kg/graph/{graph}" ] ] ;
    rr:predicateObjectMap
        [ rr:predicate oa:exact ; rr:objectMap [ rr:column "quote" ] ] ,
        [ rr:predicate oa:prefix ; rr:objectMap [ rr:column "prefix" ] ] ,
        [ rr:predicate oa:suffix ; rr:objectMap [ rr:column "suffix" ] ] .

<#evidence-positions> a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "habr_1097022.evidence" ] ;
    rr:subjectMap [ rr:template "{key}-p" ; rr:termType rr:BlankNode ; rr:class oa:TextPositionSelector ;
                    rr:graphMap [ rr:template "https://example.org/story-kg/graph/{graph}" ] ] ;
    rr:predicateObjectMap
        [ rr:predicate oa:start ; rr:objectMap [ rr:column "start_pos" ; rr:datatype xsd:nonNegativeInteger ] ] ,
        [ rr:predicate oa:end ; rr:objectMap [ rr:column "end_pos" ; rr:datatype xsd:nonNegativeInteger ] ] .

<#first-mentions> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT key, about, graph FROM habr_1097022.evidence WHERE first_mention" ] ;
    rr:subjectMap [ rr:column "about" ; rr:graphMap [ rr:template "https://example.org/story-kg/graph/{graph}" ] ] ;
    rr:predicateObjectMap [ rr:predicate kgo:firstMention ; rr:objectMap [ rr:template "anno/{key}" ] ] .


# =================================================================== сущности (entities)

<#entities> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT e.*,
               'https://example.org/story-kg/id/global/' || e.global AS global_iri,
               'https://example.org/story-kg/id/global/' || e.same_as AS same_as_iri,
               CASE WHEN e.contacts_sensitivity IS NOT NULL THEN e.id || '#vcard' END AS card,
               e.id || '#account-'
                   || regexp_replace(lower(e.account_service || '_' || e.account_name), '[^a-z0-9]+', '_', 'g') AS account
        FROM habr_1097022.entities e""" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:habr-1097022 ] ;
    rr:predicateObjectMap
        [ rr:predicate schema:name ; rr:objectMap [ rr:column "name" ; rr:language "ru" ] ] ,
        [ rr:predicate schema:description ; rr:objectMap [ rr:column "description" ; rr:language "ru" ] ] ,
        [ rr:predicate owl:sameAs ; rr:objectMap [ rr:column "global_iri" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate owl:sameAs ; rr:objectMap [ rr:column "same_as_iri" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate kgo:techRole ;
          rr:objectMap [ rr:template "https://example.org/story-kg/concept/techrole/{tech_role}" ] ] ,
        [ rr:predicate kgo:discoursePosition ; rr:objectMap [ rr:column "discourse_position" ] ] ,
        [ rr:predicate kgo:sensitivity ;
          rr:objectMap [ rr:template "https://example.org/story-kg/concept/sensitivity/{sensitivity}" ] ] ,
        [ rr:predicate schema:url ; rr:objectMap [ rr:column "url" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate schema:codeRepository ; rr:objectMap [ rr:column "code_repository" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate schema:author ; rr:objectMap [ rr:column "author" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate kgo:contactCard ; rr:objectMap [ rr:column "card" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate foaf:account ; rr:objectMap [ rr:column "account" ; rr:termType rr:IRI ] ] .

<#entity-types> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT id, habr_1097022.iri(t) AS class FROM habr_1097022.entities, unnest(types) t""" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:habr-1097022 ] ;
    rr:predicateObjectMap [ rr:predicate rdf:type ; rr:objectMap [ rr:column "class" ; rr:termType rr:IRI ] ] .

<#entity-alt-names> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT id, v FROM habr_1097022.entities, unnest(alt_names) v" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:habr-1097022 ] ;
    rr:predicateObjectMap [ rr:predicate schema:alternateName ; rr:objectMap [ rr:column "v" ; rr:language "ru" ] ] .

<#entity-hidden-labels> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT id, v FROM habr_1097022.entities, unnest(hidden_labels) v" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:habr-1097022 ] ;
    rr:predicateObjectMap [ rr:predicate skos:hiddenLabel ; rr:objectMap [ rr:column "v" ; rr:language "ru" ] ] .

<#entity-roles> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT id, v FROM habr_1097022.entities, unnest(roles) v" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:habr-1097022 ] ;
    rr:predicateObjectMap
        [ rr:predicate kgo:characterRole ; rr:objectMap [ rr:template "https://example.org/story-kg/concept/role/{v}" ] ] .

<#entity-about> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT id, v FROM habr_1097022.entities, unnest(about) v" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:habr-1097022 ] ;
    rr:predicateObjectMap [ rr:predicate schema:about ; rr:objectMap [ rr:column "v" ; rr:termType rr:IRI ] ] .

<#entity-cards> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT e.id, e.name, e.contacts_sensitivity, a.published
        FROM habr_1097022.entities e CROSS JOIN habr_1097022.article a
        WHERE e.contacts_sensitivity IS NOT NULL""" ] ;
    rr:subjectMap [ rr:template "{id}#vcard" ; rr:graph kgg:habr-1097022 ; rr:class vcard:Individual ] ;
    rr:predicateObjectMap
        [ rr:predicate vcard:fn ; rr:objectMap [ rr:column "name" ; rr:language "ru" ] ] ,
        [ rr:predicate vcard:rev ; rr:objectMap [ rr:column "published" ] ] ,
        [ rr:predicate kgo:sensitivity ;
          rr:objectMap [ rr:template "https://example.org/story-kg/concept/sensitivity/{contacts_sensitivity}" ] ] .

<#entity-accounts> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT e.*,
               e.id || '#account-'
                   || regexp_replace(lower(e.account_service || '_' || e.account_name), '[^a-z0-9]+', '_', 'g') AS account
        FROM habr_1097022.entities e WHERE e.account_name IS NOT NULL""" ] ;
    rr:subjectMap [ rr:column "account" ; rr:graph kgg:habr-1097022 ; rr:class foaf:OnlineAccount , sioc:UserAccount ] ;
    rr:predicateObjectMap
        [ rr:predicate schema:description ; rr:objectMap [ rr:column "account_service" ; rr:language "ru" ] ] ,
        [ rr:predicate foaf:accountName ; rr:objectMap [ rr:column "account_name" ] ] ,
        [ rr:predicate foaf:accountServiceHomepage ; rr:objectMap [ rr:column "account_service_url" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate schema:url ; rr:objectMap [ rr:column "account_url" ; rr:termType rr:IRI ] ] .

<#entity-mentions> a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "habr_1097022.entities" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:habr-1097022-mentions ] ;
    rr:predicateObjectMap [ rr:predicate kgo:mentionCount ; rr:objectMap [ rr:column "mention_count" ] ] .

<#entity-stack> a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "habr_1097022.entities" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:derived-techstack ] ;
    rr:predicateObjectMap
        [ rr:predicate kgo:techRole ;
          rr:objectMap [ rr:template "https://example.org/story-kg/concept/techrole/{stack_role}" ] ] .


# =================================================================== понятия (concepts)

<#concepts> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT c.*, 'https://example.org/story-kg/id/global/' || c.global AS global_iri
        FROM habr_1097022.concepts c""" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:habr-1097022 ;
                    rr:class schema:DefinedTerm , schema:Intangible , skos:Concept ] ;
    rr:predicateObjectMap
        [ rr:predicate schema:name , skos:prefLabel ; rr:objectMap [ rr:column "name" ; rr:language "ru" ] ] ,
        [ rr:predicate kgo:conceptKind ;
          rr:objectMap [ rr:template "https://example.org/story-kg/concept/conceptkind/{kind}" ] ] ,
        [ rr:predicate skos:definition , schema:description ; rr:objectMap [ rr:column "definition" ; rr:language "ru" ] ] ,
        [ rr:predicate schema:description ; rr:objectMap [ rr:column "description" ; rr:language "ru" ] ] ,
        [ rr:predicate skos:exactMatch ; rr:objectMap [ rr:column "global_iri" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate kgo:hasProcedure ; rr:objectMap [ rr:column "procedure" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate kgo:methodGoal ; rr:objectMap [ rr:column "goal" ; rr:language "ru" ] ] ,
        [ rr:predicate kgo:arisesWhen ; rr:objectMap [ rr:column "arises_when" ; rr:language "ru" ] ] ,
        [ rr:predicate kgo:manifestation ; rr:objectMap [ rr:column "manifestation" ; rr:language "ru" ] ] ,
        [ rr:predicate kgo:phenomenonMechanismText ; rr:objectMap [ rr:column "mechanism" ; rr:language "ru" ] ] ,
        [ rr:predicate skos:inScheme , schema:inDefinedTermSet ; rr:object <terms> ] .

<#concept-alt-names> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT id, v FROM habr_1097022.concepts, unnest(alt_names) v" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:habr-1097022 ] ;
    rr:predicateObjectMap [ rr:predicate skos:altLabel ; rr:objectMap [ rr:column "v" ; rr:language "ru" ] ] .

<#concept-broader> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT id, v FROM habr_1097022.concepts, unnest(broader) v" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:habr-1097022 ] ;
    rr:predicateObjectMap [ rr:predicate skos:broader ; rr:objectMap [ rr:column "v" ; rr:termType rr:IRI ] ] .

<#concept-narrower> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT id, v FROM habr_1097022.concepts, unnest(narrower) v" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:habr-1097022 ] ;
    rr:predicateObjectMap [ rr:predicate skos:narrower ; rr:objectMap [ rr:column "v" ; rr:termType rr:IRI ] ] .

<#concept-related> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT id, v FROM habr_1097022.concepts, unnest(related) v" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:habr-1097022 ] ;
    rr:predicateObjectMap [ rr:predicate skos:related ; rr:objectMap [ rr:column "v" ; rr:termType rr:IRI ] ] .

<#concept-counter-measures> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT id, v FROM habr_1097022.concepts, unnest(counter_measures) v" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:habr-1097022 ] ;
    rr:predicateObjectMap [ rr:predicate kgo:counterMeasure ; rr:objectMap [ rr:column "v" ; rr:termType rr:IRI ] ] .

<#concept-mentions> a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "habr_1097022.concepts" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:habr-1097022-mentions ] ;
    rr:predicateObjectMap [ rr:predicate kgo:mentionCount ; rr:objectMap [ rr:column "mention_count" ] ] .

<#concept-stack> a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "habr_1097022.concepts" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:derived-techstack ] ;
    rr:predicateObjectMap
        [ rr:predicate kgo:techRole ;
          rr:objectMap [ rr:template "https://example.org/story-kg/concept/techrole/{stack_role}" ] ] .

<#concept-provenance> a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "habr_1097022.concepts" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:derived-provenance ] ;
    rr:predicateObjectMap
        [ rr:predicate kgo:extractionBasis ;
          rr:objectMap [ rr:template "https://example.org/story-kg/concept/basis/{extraction_basis}" ] ] .

# определение понятия (derived-definitions): имя — «название — определение», определение сокращено до 80 знаков,
# как short() в derive_frames5.py
<#definitions> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT c.id, c.name, c.definition, c.definition_key,
               c.name || ' — ' || CASE WHEN length(d.text) <= 80 THEN d.text ELSE rtrim(left(d.text, 79)) || '…' END
                   AS label
        FROM habr_1097022.concepts c,
             LATERAL (SELECT btrim(regexp_replace(c.definition, '\\s+', ' ', 'g')) AS text) d
        WHERE c.definition_key IS NOT NULL""" ] ;
    rr:subjectMap [ rr:template "definition/{definition_key}" ; rr:graph kgg:derived-definitions ; rr:class kgo:Definition ] ;
    rr:predicateObjectMap
        [ rr:predicate schema:name ; rr:objectMap [ rr:column "label" ; rr:language "ru" ] ] ,
        [ rr:predicate kgo:defines , prov:wasDerivedFrom ; rr:objectMap [ rr:template "{id}" ] ] ,
        [ rr:predicate kgo:definiendum ; rr:objectMap [ rr:column "name" ; rr:language "ru" ] ] ,
        [ rr:predicate kgo:definiens ; rr:objectMap [ rr:column "definition" ; rr:language "ru" ] ] ,
        [ rr:predicate kgo:definitionPattern ; rr:object "concept" ] ,
        [ rr:predicate kgo:inDocument ; rr:object <work> ] .

# явление-проблема (derived-problems)
<#problems> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT id, name, problem_key FROM habr_1097022.concepts WHERE problem_key IS NOT NULL" ] ;
    rr:subjectMap [ rr:template "problem/{problem_key}" ; rr:graph kgg:derived-problems ; rr:class kgo:Phenomenon ] ;
    rr:predicateObjectMap
        [ rr:predicate schema:name ; rr:objectMap [ rr:column "name" ; rr:language "ru" ] ] ,
        [ rr:predicate kgo:phenomenonConcept , prov:wasDerivedFrom ; rr:objectMap [ rr:template "{id}" ] ] ,
        [ rr:predicate kgo:inDocument ; rr:object <work> ] ,
        [ rr:predicate kgo:derivationRule ; rr:object "карточка понятия вида «явление» или «антипаттерн»: два типа — kgo:Phenomenon и подкласс вида; вида правило не назвало: понятие технического текста или понятие, против которого найдено средство"@ru ] .


# =================================================================== вклад методов (contributions)

<#contributions> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT c.*, k.name || ': ' || c.effect AS name
        FROM habr_1097022.contributions c JOIN habr_1097022.concepts k ON k.id = c.concept""" ] ;
    rr:subjectMap [ rr:template "contribution/{key}" ; rr:graph kgg:habr-1097022 ; rr:class kgo:Contribution ] ;
    rr:predicateObjectMap
        [ rr:predicate schema:name ; rr:objectMap [ rr:column "name" ; rr:language "ru" ] ] ,
        [ rr:predicate kgo:contributionOf ; rr:objectMap [ rr:column "concept" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate kgo:contributionType ;
          rr:objectMap [ rr:template "https://example.org/story-kg/concept/contribution/{type}" ] ] ,
        [ rr:predicate kgo:effectKind ;
          rr:objectMap [ rr:template "https://example.org/story-kg/concept/effectkind/{effect_kind}" ] ] ,
        [ rr:predicate kgo:effectText ; rr:objectMap [ rr:column "effect" ; rr:language "ru" ] ] ,
        [ rr:predicate kgo:qualityAttribute ;
          rr:objectMap [ rr:template "https://example.org/story-kg/concept/quality/{quality}" ] ] .

<#concept-benefits> a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "habr_1097022.contributions" ] ;
    rr:subjectMap [ rr:column "concept" ; rr:graph kgg:habr-1097022 ] ;
    rr:predicateObjectMap [ rr:predicate kgo:benefit ; rr:objectMap [ rr:template "contribution/{key}" ] ] .


# =================================================================== отношения (relations)

<#relations> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT r.*, habr_1097022.iri(r.predicate) AS predicate_iri FROM habr_1097022.relations r""" ] ;
    rr:subjectMap [ rr:template "rel/{key}" ; rr:graph kgg:habr-1097022 ; rr:class kgo:Relationship , rdf:Statement ] ;
    rr:predicateObjectMap
        [ rr:predicate rdf:subject ; rr:objectMap [ rr:column "subject" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate rdf:predicate ; rr:objectMap [ rr:column "predicate_iri" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate rdf:object ; rr:objectMap [ rr:column "object" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate kgo:relationLabel ; rr:objectMap [ rr:column "label" ; rr:language "ru" ] ] ,
        [ rr:predicate kgo:distinguishingFeature ; rr:objectMap [ rr:column "feature" ; rr:language "ru" ] ] .

# прямая тройка отношения; kgo:differsFrom и kgo:integratesWith — в обе стороны
<#relation-triples> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT subject AS s, habr_1097022.iri(predicate) AS p, object AS o FROM habr_1097022.relations
        UNION
        SELECT object, habr_1097022.iri(predicate), subject FROM habr_1097022.relations
        WHERE predicate IN ('kgo:differsFrom', 'kgo:integratesWith')""" ] ;
    rr:subjectMap [ rr:column "s" ; rr:graph kgg:habr-1097022 ] ;
    rr:predicateObjectMap
        [ rr:predicateMap [ rr:column "p" ] ; rr:objectMap [ rr:column "o" ; rr:termType rr:IRI ] ] .


# =================================================================== события (events)

<#events> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT e.*,
               'https://example.org/story-kg/graph/situation/habr-1097022/' || e.id || '#pre' AS pre,
               'https://example.org/story-kg/graph/situation/habr-1097022/' || e.id || '#post' AS post
        FROM habr_1097022.events e""" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:habr-1097022 ] ;
    rr:predicateObjectMap
        [ rr:predicate schema:name ; rr:objectMap [ rr:column "name" ; rr:language "ru" ] ] ,
        [ rr:predicate schema:description ; rr:objectMap [ rr:column "description" ; rr:language "ru" ] ] ,
        [ rr:predicate kgo:frame ;
          rr:objectMap [ rr:template "https://w3id.org/framester/framenet/abox/frame/{frame}" ] ] ,
        [ rr:predicate schema:agent ; rr:objectMap [ rr:column "agent" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate schema:object ; rr:objectMap [ rr:column "object" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate schema:instrument ; rr:objectMap [ rr:column "instrument" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate kgo:dateText ; rr:objectMap [ rr:column "date_text" ; rr:language "ru" ] ] ,
        [ rr:predicate kgo:factuality ;
          rr:objectMap [ rr:template "https://example.org/story-kg/concept/factuality/{factuality}" ] ] ,
        [ rr:predicate kgo:causedBy ; rr:objectMap [ rr:column "caused_by" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate kgo:motivatedBy ; rr:objectMap [ rr:column "motivated_by" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate kgo:discoursePosition ; rr:objectMap [ rr:column "discourse_position" ] ] ,
        [ rr:predicate eso:creating-theme ; rr:objectMap [ rr:column "creates" ; rr:termType rr:IRI ] ] .

<#event-types> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT id, habr_1097022.iri(t) AS class FROM habr_1097022.events, unnest(types) t""" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:habr-1097022 ] ;
    rr:predicateObjectMap [ rr:predicate rdf:type ; rr:objectMap [ rr:column "class" ; rr:termType rr:IRI ] ] .

<#event-precedes> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT id, v FROM habr_1097022.events, unnest(precedes) v" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:habr-1097022 ] ;
    rr:predicateObjectMap [ rr:predicate kgo:precedes ; rr:objectMap [ rr:column "v" ; rr:termType rr:IRI ] ] .

<#event-causes> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT id, v FROM habr_1097022.events, unnest(causes) v" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:habr-1097022 ] ;
    rr:predicateObjectMap [ rr:predicate kgo:causes ; rr:objectMap [ rr:column "v" ; rr:termType rr:IRI ] ] .

# ситуации ESO до и после создания: узлы в графе статьи, состояния — в графах самих ситуаций
<#situations> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT e.id, e.creates, s.phase, s.exists,
               'https://example.org/story-kg/graph/situation/habr-1097022/' || e.id || '#' || s.phase AS situation
        FROM habr_1097022.events e, (VALUES ('pre', false), ('post', true)) AS s (phase, exists)
        WHERE e.creates IS NOT NULL""" ] ;
    rr:subjectMap [ rr:column "situation" ; rr:graph kgg:habr-1097022 ; rr:class eso:Situation ] ;
    rr:predicateObjectMap [ rr:predicate kgo:situationOf ; rr:objectMap [ rr:template "{id}" ] ] .

<#event-situations> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT e.id,
               'https://example.org/story-kg/graph/situation/habr-1097022/' || e.id || '#pre' AS pre,
               'https://example.org/story-kg/graph/situation/habr-1097022/' || e.id || '#post' AS post
        FROM habr_1097022.events e WHERE e.creates IS NOT NULL""" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:habr-1097022 ] ;
    rr:predicateObjectMap
        [ rr:predicate eso:hasPreSituation ; rr:objectMap [ rr:column "pre" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate eso:hasPostSituation ; rr:objectMap [ rr:column "post" ; rr:termType rr:IRI ] ] .

<#situation-states> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT e.creates, s.exists,
               'https://example.org/story-kg/graph/situation/habr-1097022/' || e.id || '#' || s.phase AS situation
        FROM habr_1097022.events e, (VALUES ('pre', false), ('post', true)) AS s (phase, exists)
        WHERE e.creates IS NOT NULL""" ] ;
    rr:subjectMap [ rr:column "creates" ; rr:graphMap [ rr:column "situation" ] ] ;
    rr:predicateObjectMap [ rr:predicate eso:exist ; rr:objectMap [ rr:column "exists" ] ] .

<#event-states> a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "habr_1097022.events" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:derived-states ] ;
    rr:predicateObjectMap [ rr:predicate kgo:timelineRank ; rr:objectMap [ rr:column "timeline_rank" ] ] .

<#event-creations> a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "habr_1097022.events" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:derived-creations ] ;
    rr:predicateObjectMap
        [ rr:predicate kgo:lifecycleStage ;
          rr:objectMap [ rr:template "https://example.org/story-kg/concept/creationstage/{lifecycle_stage}" ] ] .

<#event-framenet> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT e.*, 'https://example.org/story-kg/id/global/' || e.fn_frame_mapping AS mapping
        FROM habr_1097022.events e""" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:derived-framenet ] ;
    rr:predicateObjectMap
        [ rr:predicate kgo:frame ;
          rr:objectMap [ rr:template "https://w3id.org/framester/framenet/abox/frame/{fn_frame}" ] ] ,
        [ rr:predicate kgo:frameChoice ;
          rr:objectMap [ rr:template "https://example.org/story-kg/concept/framechoice/{fn_frame_choice}" ] ] ,
        [ rr:predicate kgo:frameMatch ;
          rr:objectMap [ rr:template "https://example.org/story-kg/concept/framematch/{fn_frame_match}" ] ] ,
        [ rr:predicate kgo:frameMapping ; rr:objectMap [ rr:column "mapping" ; rr:termType rr:IRI ] ] .

# элементы фрейма FrameNet: роль — свойство fe:<роль>
<#event-frame-roles> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT e.id, r.key AS role, r.value AS filler FROM habr_1097022.events e, jsonb_each_text(e.fn_roles) r""" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:derived-framenet ] ;
    rr:predicateObjectMap
        [ rr:predicateMap [ rr:template "https://w3id.org/framester/framenet/abox/fe/{role}" ] ;
          rr:objectMap [ rr:column "filler" ; rr:termType rr:IRI ] ] .

<#event-dialogue> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT * FROM habr_1097022.events WHERE dialog_act IS NOT NULL" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:derived-dialogue ; rr:class kgo:CommunicationEvent ] ;
    rr:predicateObjectMap
        [ rr:predicate kgo:communicativeFunction ;
          rr:objectMap [ rr:template "https://example.org/story-kg/concept/dialogact/{dialog_act}" ] ] ,
        [ rr:predicate kgo:speaker ; rr:objectMap [ rr:column "speaker" ; rr:termType rr:IRI ] ] .


# =================================================================== процессы BBO (processes, process_steps, process_flows)

<#processes> a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "habr_1097022.processes" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:habr-1097022 ; rr:class bbo:Process ] ;
    rr:predicateObjectMap
        [ rr:predicate bbo:name ; rr:objectMap [ rr:column "name" ] ] ,
        [ rr:predicate schema:name ; rr:objectMap [ rr:column "name" ; rr:language "ru" ] ] ,
        [ rr:predicate kgo:appliesTo ; rr:objectMap [ rr:column "applies_to" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate kgo:precondition ; rr:objectMap [ rr:column "precondition" ; rr:language "ru" ] ] ,
        [ rr:predicate kgo:processResult ; rr:objectMap [ rr:column "result" ; rr:language "ru" ] ] .

<#process-elements> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT process, process || '.' || step AS element FROM habr_1097022.process_steps
        UNION ALL
        SELECT process, process || '.flow' || n FROM habr_1097022.process_flows""" ] ;
    rr:subjectMap [ rr:template "{process}" ; rr:graph kgg:habr-1097022 ] ;
    rr:predicateObjectMap
        [ rr:predicate bbo:has_flowElements ; rr:objectMap [ rr:column "element" ; rr:termType rr:IRI ] ] .

<#process-kinds> a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "habr_1097022.processes" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:derived-origins ] ;
    rr:predicateObjectMap
        [ rr:predicate kgo:processKind ;
          rr:objectMap [ rr:template "https://example.org/story-kg/concept/processkind/{process_kind}" ] ] .

<#steps> a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "habr_1097022.process_steps" ] ;
    rr:subjectMap [ rr:template "{process}.{step}" ; rr:graph kgg:habr-1097022 ] ;
    rr:predicateObjectMap
        [ rr:predicate rdf:type ;
          rr:objectMap [ rr:template "https://www.irit.fr/recherches/MELODI/ontologies/BBO#{type}" ] ] ,
        [ rr:predicate bbo:name ; rr:objectMap [ rr:column "name" ] ] ,
        [ rr:predicate schema:name ; rr:objectMap [ rr:column "name" ; rr:language "ru" ] ] ,
        [ rr:predicate bbo:has_container ; rr:objectMap [ rr:template "{process}" ] ] .

<#step-tools> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT process, step, v FROM habr_1097022.process_steps, unnest(uses_tool) v" ] ;
    rr:subjectMap [ rr:template "{process}.{step}" ; rr:graph kgg:habr-1097022 ] ;
    rr:predicateObjectMap [ rr:predicate kgo:usesTool ; rr:objectMap [ rr:column "v" ; rr:termType rr:IRI ] ] .

<#step-stack-tools> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT process, step, v FROM habr_1097022.process_steps, unnest(stack_tools) v" ] ;
    rr:subjectMap [ rr:template "{process}.{step}" ; rr:graph kgg:derived-techstack ] ;
    rr:predicateObjectMap [ rr:predicate kgo:usesTool ; rr:objectMap [ rr:column "v" ; rr:termType rr:IRI ] ] .

# соседи шага — из переходов
<#step-outgoing> a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "habr_1097022.process_flows" ] ;
    rr:subjectMap [ rr:template "{process}.{source}" ; rr:graph kgg:habr-1097022 ] ;
    rr:predicateObjectMap
        [ rr:predicate bbo:has_outgoing ; rr:objectMap [ rr:template "{process}.flow{n}" ] ] ,
        [ rr:predicate bbo:has_nextFlowNode ; rr:objectMap [ rr:template "{process}.{target}" ] ] .

<#step-incoming> a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "habr_1097022.process_flows" ] ;
    rr:subjectMap [ rr:template "{process}.{target}" ; rr:graph kgg:habr-1097022 ] ;
    rr:predicateObjectMap
        [ rr:predicate bbo:has_incoming ; rr:objectMap [ rr:template "{process}.flow{n}" ] ] ,
        [ rr:predicate bbo:has_previousFlowNode ; rr:objectMap [ rr:template "{process}.{source}" ] ] .

<#flows> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT f.*,
               CASE WHEN f.condition IS NULL THEN 'SequenceFlow' ELSE 'ConditionalSequenceFlow' END AS class,
               CASE WHEN f.condition IS NOT NULL THEN f.process || '.flow' || f.n || '-cond' END AS condition_node
        FROM habr_1097022.process_flows f""" ] ;
    rr:subjectMap [ rr:template "{process}.flow{n}" ; rr:graph kgg:habr-1097022 ] ;
    rr:predicateObjectMap
        [ rr:predicate rdf:type ;
          rr:objectMap [ rr:template "https://www.irit.fr/recherches/MELODI/ontologies/BBO#{class}" ] ] ,
        [ rr:predicate bbo:has_container ; rr:objectMap [ rr:template "{process}" ] ] ,
        [ rr:predicate bbo:has_sourceRef ; rr:objectMap [ rr:template "{process}.{source}" ] ] ,
        [ rr:predicate bbo:has_targetRef ; rr:objectMap [ rr:template "{process}.{target}" ] ] ,
        [ rr:predicate bbo:has_conditionExpression ; rr:objectMap [ rr:column "condition_node" ; rr:termType rr:IRI ] ] .

<#flow-conditions> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT * FROM habr_1097022.process_flows WHERE condition IS NOT NULL" ] ;
    rr:subjectMap [ rr:template "{process}.flow{n}-cond" ; rr:graph kgg:habr-1097022 ; rr:class bbo:ConditionExpression ] ;
    rr:predicateObjectMap [ rr:predicate rdfs:label ; rr:objectMap [ rr:column "condition" ; rr:language "ru" ] ] .


# =================================================================== утверждения (claims)

<#claims> a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "habr_1097022.claims" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:habr-1097022 ; rr:class schema:Claim , schema:CreativeWork ] ;
    rr:predicateObjectMap
        [ rr:predicate schema:text ; rr:objectMap [ rr:column "text" ; rr:language "ru" ] ] ,
        [ rr:predicate kgo:claimRole ; rr:objectMap [ rr:template "https://example.org/story-kg/concept/claim/{role}" ] ] ,
        [ rr:predicate kgo:rhetoricalZone ;
          rr:objectMap [ rr:template "https://example.org/story-kg/concept/rhetoricalzone/{zone}" ] ] ,
        [ rr:predicate schema:author ; rr:objectMap [ rr:column "author" ; rr:termType rr:IRI ] ] .

<#claim-supports> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT id, v FROM habr_1097022.claims, unnest(supports) v" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:habr-1097022 ] ;
    rr:predicateObjectMap [ rr:predicate kgo:supports ; rr:objectMap [ rr:column "v" ; rr:termType rr:IRI ] ] .

<#claim-attacks> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT id, v FROM habr_1097022.claims, unnest(attacks) v" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:habr-1097022 ] ;
    rr:predicateObjectMap [ rr:predicate kgo:attacks ; rr:objectMap [ rr:column "v" ; rr:termType rr:IRI ] ] .

<#claim-about> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT id, v FROM habr_1097022.claims, unnest(about) v" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:habr-1097022 ] ;
    rr:predicateObjectMap [ rr:predicate schema:about ; rr:objectMap [ rr:column "v" ; rr:termType rr:IRI ] ] .


# =================================================================== реплики и диалоги (quotations, dialogues)

<#quotations> a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "habr_1097022.quotations" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:habr-1097022 ; rr:class schema:Quotation , schema:CreativeWork ] ;
    rr:predicateObjectMap
        [ rr:predicate schema:creator , schema:spokenByCharacter ; rr:objectMap [ rr:column "speaker" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate kgo:speechAct ;
          rr:objectMap [ rr:template "https://example.org/story-kg/concept/speechact/{speech_act}" ] ] ,
        [ rr:predicate kgo:stance ; rr:objectMap [ rr:template "https://example.org/story-kg/concept/stance/{stance}" ] ] ,
        [ rr:predicate kgo:stanceTarget ; rr:objectMap [ rr:column "stance_target" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate schema:text ; rr:objectMap [ rr:column "text" ; rr:language "ru" ] ] ,
        [ rr:predicate schema:description ; rr:objectMap [ rr:column "description" ; rr:language "ru" ] ] ,
        [ rr:predicate schema:isPartOf ; rr:object <work> ] .

<#quotation-addressees> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT id, v FROM habr_1097022.quotations, unnest(addressees) v" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:habr-1097022 ] ;
    rr:predicateObjectMap [ rr:predicate kgo:addressee ; rr:objectMap [ rr:column "v" ; rr:termType rr:IRI ] ] .

<#quotation-about> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT id, v FROM habr_1097022.quotations, unnest(about) v" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:habr-1097022 ] ;
    rr:predicateObjectMap [ rr:predicate schema:about ; rr:objectMap [ rr:column "v" ; rr:termType rr:IRI ] ] .

<#quotation-turns> a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "habr_1097022.quotations" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:derived-dialogue ] ;
    rr:predicateObjectMap
        [ rr:predicate kgo:inDialogue ; rr:objectMap [ rr:template "dialogue/{dialogue}" ] ] ,
        [ rr:predicate kgo:turnIndex ; rr:objectMap [ rr:column "turn_index" ] ] ,
        [ rr:predicate kgo:respondsTo ; rr:objectMap [ rr:column "responds_to" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate kgo:answers ; rr:objectMap [ rr:column "answers" ; rr:termType rr:IRI ] ] .

<#dialogues> a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "habr_1097022.dialogues" ] ;
    rr:subjectMap [ rr:template "dialogue/{key}" ; rr:graph kgg:derived-dialogue ; rr:class kgo:Dialogue ] ;
    rr:predicateObjectMap
        [ rr:predicate schema:name ; rr:objectMap [ rr:column "name" ; rr:language "ru" ] ] ,
        [ rr:predicate kgo:contextSection ; rr:objectMap [ rr:template "sec/{section}" ] ] ,
        [ rr:predicate kgo:turnCount ; rr:objectMap [ rr:column "turn_count" ] ] ,
        [ rr:predicate kgo:inDocument ; rr:object <work> ] ,
        [ rr:predicate kgo:derivationRule ; rr:object "подряд идущие реплики одного раздела (разрыв ≤ 3000 знаков, в стихотворном тексте — не больше 5 стихов), говорящий или адресат которых уже участвует в разговоре; не меньше двух говорящих; реплика отвечает на предыдущую (kgo:respondsTo), если её адресат — автор предыдущей или её автор — адресат предыдущей и она начинается не дальше 5 стихов или 1500 знаков от конца предыдущей; дальше — взаимная пара одной главы (A к B, затем B к A) не дальше 10 стихов или ответ адресата словами реплики (два общих слова) не дальше 20 стихов" ] .

<#dialogue-participants> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT key, v FROM habr_1097022.dialogues, unnest(participants) v" ] ;
    rr:subjectMap [ rr:template "dialogue/{key}" ; rr:graph kgg:derived-dialogue ] ;
    rr:predicateObjectMap [ rr:predicate kgo:dialogueParticipant ; rr:objectMap [ rr:column "v" ; rr:termType rr:IRI ] ] .

<#dialogue-turns> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT id, dialogue FROM habr_1097022.quotations WHERE dialogue IS NOT NULL" ] ;
    rr:subjectMap [ rr:template "dialogue/{dialogue}" ; rr:graph kgg:derived-dialogue ] ;
    rr:predicateObjectMap [ rr:predicate prov:wasDerivedFrom ; rr:objectMap [ rr:template "{id}" ] ] .


# =================================================================== установки (attitudes)

<#attitudes> a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "habr_1097022.attitudes" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:habr-1097022 ; rr:class kgo:Attitude ] ;
    rr:predicateObjectMap
        [ rr:predicate kgo:holder ; rr:objectMap [ rr:column "holder" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate kgo:attitudeType ; rr:objectMap [ rr:template "https://example.org/story-kg/concept/attitude/{type}" ] ] ,
        [ rr:predicate kgo:attitudeTarget ; rr:objectMap [ rr:column "target" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate kgo:attitudeTarget ; rr:objectMap [ rr:column "target_text" ; rr:language "ru" ] ] ,
        [ rr:predicate schema:name ; rr:objectMap [ rr:column "name" ; rr:language "ru" ] ] ,
        [ rr:predicate schema:description ; rr:objectMap [ rr:column "description" ; rr:language "ru" ] ] .

<#attitude-affect> a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "habr_1097022.attitudes" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:derived-affect ] ;
    rr:predicateObjectMap
        [ rr:predicate rdf:type ; rr:objectMap [ rr:template "https://example.org/story-kg/ontology#{affect_class}" ] ] ,
        [ rr:predicate kgo:affectKind ;
          rr:objectMap [ rr:template "https://example.org/story-kg/concept/affectkind/{affect_kind}" ] ] .

<#attitude-emotions> a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "habr_1097022.attitudes" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:derived-emotions ] ;
    rr:predicateObjectMap
        [ rr:predicate kgo:valence ; rr:objectMap [ rr:template "https://example.org/story-kg/concept/valence/{valence}" ] ] .

# итог установки (derived-outcomes): имя — описание установки
<#outcomes> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT a.*, 'attitude:' || a.type AS intention_kind
        FROM habr_1097022.attitudes a WHERE a.outcome_key IS NOT NULL""" ] ;
    rr:subjectMap [ rr:template "outcome/{outcome_key}" ; rr:graph kgg:derived-outcomes ;
                    rr:class kgo:AttitudeOutcome , kgo:Outcome ] ;
    rr:predicateObjectMap
        [ rr:predicate schema:name ; rr:objectMap [ rr:column "description" ; rr:language "ru" ] ] ,
        [ rr:predicate kgo:intention , prov:wasDerivedFrom ; rr:objectMap [ rr:template "{id}" ] ] ,
        [ rr:predicate kgo:intentionKind ; rr:objectMap [ rr:column "intention_kind" ] ] ,
        [ rr:predicate kgo:outcomeEvent , prov:wasDerivedFrom ; rr:objectMap [ rr:column "outcome_event" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate kgo:outcomeStatus ;
          rr:objectMap [ rr:template "https://example.org/story-kg/concept/outcome/{outcome_status}" ] ] ,
        [ rr:predicate kgo:outcomeVerdict ;
          rr:objectMap [ rr:template "https://example.org/story-kg/concept/outcome/{outcome_verdict}" ] ] ,
        [ rr:predicate kgo:inDocument ; rr:object <work> ] ,
        [ rr:predicate kgo:derivationRule ; rr:object "установка → события с kgo:motivatedBy (статус по их фактуальности) + их следствия kgo:causes" ] .


# =================================================================== вложенные рассказы (narratives)

<#narratives> a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "habr_1097022.narratives" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:habr-1097022 ; rr:class kgo:EmbeddedNarrative , schema:CreativeWork ] ;
    rr:predicateObjectMap
        [ rr:predicate schema:name ; rr:objectMap [ rr:column "name" ; rr:language "ru" ] ] ,
        [ rr:predicate schema:description ; rr:objectMap [ rr:column "description" ; rr:language "ru" ] ] ,
        [ rr:predicate kgo:narrativeType ; rr:objectMap [ rr:template "https://example.org/story-kg/concept/narrative/{type}" ] ] ,
        [ rr:predicate kgo:factuality ;
          rr:objectMap [ rr:template "https://example.org/story-kg/concept/factuality/{factuality}" ] ] ,
        [ rr:predicate kgo:toldBy ; rr:objectMap [ rr:column "told_by" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate kgo:moral ; rr:objectMap [ rr:column "moral" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate kgo:narrativeLevel ; rr:objectMap [ rr:column "level" ] ] ,
        [ rr:predicate schema:isPartOf ; rr:object <work> ] ,
        [ rr:predicate kgo:textSpan ; rr:objectMap [ rr:template "{id}-span" ; rr:termType rr:BlankNode ] ] .

<#narrative-characters> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT id, v FROM habr_1097022.narratives, unnest(characters) v" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:habr-1097022 ] ;
    rr:predicateObjectMap [ rr:predicate schema:character ; rr:objectMap [ rr:column "v" ; rr:termType rr:IRI ] ] .

<#narrative-spans> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT n.id, 'https://example.org/story-kg/src/' || a.source_file AS src
        FROM habr_1097022.narratives n CROSS JOIN habr_1097022.article a""" ] ;
    rr:subjectMap [ rr:template "{id}-span" ; rr:termType rr:BlankNode ; rr:graph kgg:habr-1097022 ;
                    rr:class oa:SpecificResource ] ;
    rr:predicateObjectMap
        [ rr:predicate oa:hasSource ; rr:objectMap [ rr:column "src" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate oa:hasSelector ; rr:objectMap [ rr:template "{id}-span-p" ; rr:termType rr:BlankNode ] ] .

<#narrative-span-selectors> a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "habr_1097022.narratives" ] ;
    rr:subjectMap [ rr:template "{id}-span-p" ; rr:termType rr:BlankNode ; rr:graph kgg:habr-1097022 ;
                    rr:class oa:TextPositionSelector ] ;
    rr:predicateObjectMap
        [ rr:predicate oa:start ; rr:objectMap [ rr:column "span_start" ; rr:datatype xsd:nonNegativeInteger ] ] ,
        [ rr:predicate oa:end ; rr:objectMap [ rr:column "span_end" ; rr:datatype xsd:nonNegativeInteger ] ] .

# вставной рассказ (derived-insets)
<#insets> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT * FROM habr_1097022.narratives WHERE inset_class IS NOT NULL" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:derived-insets ; rr:class kgo:Inset ] ;
    rr:predicateObjectMap
        [ rr:predicate rdf:type ; rr:objectMap [ rr:template "https://example.org/story-kg/ontology#{inset_class}" ] ] ,
        [ rr:predicate kgo:diegeticLevel ; rr:objectMap [ rr:column "diegetic_level" ] ] ,
        [ rr:predicate kgo:diegeticLevelKind ;
          rr:objectMap [ rr:template "https://example.org/story-kg/concept/diegeticlevel/{diegetic_level_kind}" ] ] ,
        [ rr:predicate kgo:insetAudienceKind ;
          rr:objectMap [ rr:template "https://example.org/story-kg/concept/insetaudience/{audience_kind}" ] ] ,
        [ rr:predicate kgo:insetNarratorKind ;
          rr:objectMap [ rr:template "https://example.org/story-kg/concept/insetnarrator/{narrator_kind}" ] ] ,
        [ rr:predicate kgo:insetNarratorBasis ;
          rr:objectMap [ rr:template "https://example.org/story-kg/concept/insetbasis/{narrator_basis}" ] ] ,
        [ rr:predicate kgo:insetPurpose ;
          rr:objectMap [ rr:template "https://example.org/story-kg/concept/insetpurpose/{purpose}" ] ] ,
        [ rr:predicate prov:wasDerivedFrom ; rr:objectMap [ rr:column "moral" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate prov:wasDerivedFrom ; rr:objectMap [ rr:column "told_by" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate prov:wasDerivedFrom ; rr:object <work> ] ,
        [ rr:predicate kgo:derivationRule ; rr:object "вставной рассказ спецификации (kgo:EmbeddedNarrative с привязкой): степень по Женетту — 1, если рассказчик не назван или он голос текста (автор книги, рассказчик произведения, лирический субъект, узел «Автор статьи …», голос из реестра); 2, если рассказчик — персонаж либо названное лицо, чей рассказ приводит автор; на единицу больше степени объемлющего рассказа, если рассказчик — персонаж объемлющего (по двум привязкам объемлющего и по schema:character). Адресат — kgo:toldTo; у рассказа голоса текста, если адресат не назван, — читатель произведения. Назначение — по классу узла kgo:moral. Событие рассказывания (рассказы персонажей и названных лиц) — событие-речь, письмо или исполнение с рассказчиком, перекрывающее место рассказа"@ru ] .


# =================================================================== наблюдения (observations)

<#observations> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT o.*,
               CASE WHEN o.value = trunc(o.value) THEN o.value::bigint END AS whole,
               CASE WHEN o.value <> trunc(o.value) THEN o.value::float8 END AS fraction
        FROM habr_1097022.observations o""" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:habr-1097022 ;
                    rr:class schema:Observation , schema:QuantitativeValue , schema:StructuredValue , schema:Intangible ] ;
    rr:predicateObjectMap
        [ rr:predicate schema:name , schema:variableMeasured ; rr:objectMap [ rr:column "variable" ; rr:language "ru" ] ] ,
        [ rr:predicate schema:value ; rr:objectMap [ rr:column "whole" ] ] ,
        [ rr:predicate schema:value ; rr:objectMap [ rr:column "fraction" ] ] ,
        [ rr:predicate schema:value ; rr:objectMap [ rr:column "value_range" ; rr:language "ru" ] ] ,
        [ rr:predicate schema:unitText ; rr:objectMap [ rr:column "unit" ; rr:language "ru" ] ] ,
        [ rr:predicate kgo:conditionText ; rr:objectMap [ rr:column "condition" ; rr:language "ru" ] ] ,
        [ rr:predicate qb:dataSet ; rr:objectMap [ rr:column "dataset" ; rr:termType rr:IRI ] ] .

<#observation-about> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT id, v FROM habr_1097022.observations, unnest(about) v" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:habr-1097022 ] ;
    rr:predicateObjectMap [ rr:predicate schema:observationAbout ; rr:objectMap [ rr:column "v" ; rr:termType rr:IRI ] ] .

# наблюдение набора измерений (derived-experiments) — когда у набора есть карточка
<#observation-datasets> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT o.id, o.dataset FROM habr_1097022.observations o JOIN habr_1097022.datasets d ON d.id = o.dataset""" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:derived-experiments ; rr:class qb:Observation ] ;
    rr:predicateObjectMap [ rr:predicate qb:dataSet ; rr:objectMap [ rr:column "dataset" ; rr:termType rr:IRI ] ] .

<#observation-quantities> a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "habr_1097022.observations" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:derived-quantities ] ;
    rr:predicateObjectMap
        [ rr:predicate kgo:unit ; rr:objectMap [ rr:template "https://example.org/story-kg/concept/unit/{unit_code}" ] ] ,
        [ rr:predicate kgo:quantityKind ;
          rr:objectMap [ rr:template "https://example.org/story-kg/concept/quantitykind/{quantity_kind}" ] ] ,
        [ rr:predicate kgo:baseUnit ; rr:objectMap [ rr:template "https://example.org/story-kg/concept/unit/{base_unit}" ] ] ,
        [ rr:predicate kgo:valueInBaseUnit ; rr:objectMap [ rr:column "value_in_base_unit" ] ] ,
        [ rr:predicate schema:minValue ; rr:objectMap [ rr:column "min_value" ] ] ,
        [ rr:predicate schema:maxValue ; rr:objectMap [ rr:column "max_value" ] ] ,
        [ rr:predicate kgo:minValueInBaseUnit ; rr:objectMap [ rr:column "min_in_base_unit" ] ] ,
        [ rr:predicate kgo:maxValueInBaseUnit ; rr:objectMap [ rr:column "max_in_base_unit" ] ] ,
        [ rr:predicate kgo:carrierBasis ; rr:objectMap [ rr:column "carrier_basis" ] ] ,
        [ rr:predicate kgo:observedProperty ; rr:objectMap [ rr:column "observed_property" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate kgo:propertyBasis ; rr:objectMap [ rr:column "property_basis" ] ] ,
        [ rr:predicate kgo:countNoun ; rr:objectMap [ rr:column "count_noun" ; rr:language "ru" ] ] .

<#observation-carriers> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT id, v FROM habr_1097022.observations, unnest(carriers) v" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:derived-quantities ] ;
    rr:predicateObjectMap [ rr:predicate kgo:carrier ; rr:objectMap [ rr:column "v" ; rr:termType rr:IRI ] ] .


# =================================================================== наборы измерений (datasets, derived-experiments)

<#datasets> a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "habr_1097022.datasets" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:derived-experiments ] ;
    rr:predicateObjectMap
        [ rr:predicate schema:name ; rr:objectMap [ rr:column "name" ; rr:language "ru" ] ] ,
        [ rr:predicate kgo:measureLabel ; rr:objectMap [ rr:column "measure" ; rr:language "ru" ] ] ,
        [ rr:predicate kgo:conditionText ; rr:objectMap [ rr:column "condition" ; rr:language "ru" ] ] ,
        [ rr:predicate kgo:seriesKind ; rr:objectMap [ rr:template "https://example.org/story-kg/concept/series/{series_kind}" ] ] ,
        [ rr:predicate kgo:contextSection ; rr:objectMap [ rr:template "sec/{section}" ] ] ,
        [ rr:predicate kgo:observationCount ; rr:objectMap [ rr:column "observation_count" ] ] ,
        [ rr:predicate kgo:bestObservation ; rr:objectMap [ rr:column "best_observation" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate kgo:betterIs ; rr:objectMap [ rr:column "better_is" ] ] ,
        [ rr:predicate kgo:inDocument ; rr:object <work> ] ,
        [ rr:predicate kgo:derivationRule ; rr:object "наблюдения одной статьи с одной измеряемой величиной (часть названия до двоеточия, без имени объекта, пояснений в скобках и чисел) → набор данных; вид — по тому, что меняется: объект (сравнение), дата (ряд), условие (хвост после двоеточия или число в названии)" ] .

<#dataset-types> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT id, habr_1097022.iri(t) AS class FROM habr_1097022.datasets, unnest(types) t""" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:derived-experiments ] ;
    rr:predicateObjectMap [ rr:predicate rdf:type ; rr:objectMap [ rr:column "class" ; rr:termType rr:IRI ] ] .

<#dataset-units> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT id, v FROM habr_1097022.datasets, unnest(units) v" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:derived-experiments ] ;
    rr:predicateObjectMap [ rr:predicate schema:unitText ; rr:objectMap [ rr:column "v" ] ] .

<#dataset-subjects> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT id, v FROM habr_1097022.datasets, unnest(subjects) v" ] ;
    rr:subjectMap [ rr:template "{id}" ; rr:graph kgg:derived-experiments ] ;
    rr:predicateObjectMap [ rr:predicate kgo:subjectUnderTest ; rr:objectMap [ rr:column "v" ; rr:termType rr:IRI ] ] .

<#dataset-sources> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT o.id, o.dataset FROM habr_1097022.observations o JOIN habr_1097022.datasets d ON d.id = o.dataset""" ] ;
    rr:subjectMap [ rr:template "{dataset}" ; rr:graph kgg:derived-experiments ] ;
    rr:predicateObjectMap [ rr:predicate prov:wasDerivedFrom ; rr:objectMap [ rr:template "{id}" ] ] .


# =================================================================== доводы и возражения (arguments, conflicts)

<#arguments> a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "habr_1097022.arguments" ] ;
    rr:subjectMap [ rr:template "argument/{key}" ; rr:graph kgg:derived-arguments ; rr:class kgo:Argument ] ;
    rr:predicateObjectMap
        [ rr:predicate schema:name ; rr:objectMap [ rr:column "name" ; rr:language "ru" ] ] ,
        [ rr:predicate kgo:conclusion , prov:wasDerivedFrom ; rr:objectMap [ rr:column "conclusion" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate kgo:premiseRole ;
          rr:objectMap [ rr:template "https://example.org/story-kg/concept/claim/{premise_role}" ] ] ,
        [ rr:predicate schema:isPartOf ; rr:object <argument-map> ] ,
        [ rr:predicate kgo:inDocument ; rr:object <work> ] ,
        [ rr:predicate kgo:derivationRule ; rr:object "посылки, связанные kgo:supports с одним выводом, — один довод (RA-узел AIF); роли посылок — из kgo:claimRole" ] .

<#argument-premises> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT key, v FROM habr_1097022.arguments, unnest(premises) v" ] ;
    rr:subjectMap [ rr:template "argument/{key}" ; rr:graph kgg:derived-arguments ] ;
    rr:predicateObjectMap
        [ rr:predicate kgo:premise , prov:wasDerivedFrom ; rr:objectMap [ rr:column "v" ; rr:termType rr:IRI ] ] .

<#conflicts> a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "habr_1097022.conflicts" ] ;
    rr:subjectMap [ rr:template "conflict/{key}" ; rr:graph kgg:derived-arguments ; rr:class kgo:Conflict ] ;
    rr:predicateObjectMap
        [ rr:predicate schema:name ; rr:objectMap [ rr:column "name" ; rr:language "ru" ] ] ,
        [ rr:predicate kgo:conflictedClaim , prov:wasDerivedFrom ; rr:objectMap [ rr:column "attacked" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate kgo:conflictingClaim , prov:wasDerivedFrom ; rr:objectMap [ rr:column "attacker" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate kgo:attackRebutted ; rr:objectMap [ rr:column "rebutted" ] ] ,
        [ rr:predicate schema:isPartOf ; rr:object <argument-map> ] ,
        [ rr:predicate kgo:inDocument ; rr:object <work> ] ,
        [ rr:predicate kgo:derivationRule ; rr:object "утверждение, связанное kgo:attacks с другим, — конфликт (CA-узел AIF); возражение опровергнуто, если на него самого есть kgo:attacks" ] .

# оценка опровергнутого утверждения (derived-credibility)
<#claim-reviews> a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "habr_1097022.conflicts" ] ;
    rr:subjectMap [ rr:template "review/{key}" ; rr:graph kgg:derived-credibility ;
                    rr:class schema:ClaimReview , schema:Review , schema:CreativeWork ] ;
    rr:predicateObjectMap
        [ rr:predicate schema:name ; rr:objectMap [ rr:column "review_name" ; rr:language "ru" ] ] ,
        [ rr:predicate schema:itemReviewed , prov:wasDerivedFrom ; rr:objectMap [ rr:column "attacked" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate kgo:reviewingClaim , prov:wasDerivedFrom ; rr:objectMap [ rr:column "attacker" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate kgo:verdict ; rr:objectMap [ rr:template "https://example.org/story-kg/concept/verdict/{verdict}" ] ] ,
        [ rr:predicate kgo:inDocument ; rr:object <work> ] ,
        [ rr:predicate kgo:derivationRule ; rr:object "утверждение A атакует утверждение B (kgo:attacks) → обзор B; «опровергнуто», если A содержит маркер опровержения («миф», «не подтвердилось», «ошибочно»…)" ] .


# =================================================================== ключевые слова стиля (style_keywords)

<#style-keywords> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT a.style_key, k.* FROM habr_1097022.style_keywords k CROSS JOIN habr_1097022.article a""" ] ;
    rr:subjectMap [ rr:template "style/{style_key}/kw/{key}" ; rr:graph kgg:derived-stylometry ; rr:class kgo:StyleKeyword ] ;
    rr:predicateObjectMap
        [ rr:predicate kgo:keywordRank ; rr:objectMap [ rr:column "rank" ] ] ,
        [ rr:predicate kgo:keywordLemma ; rr:objectMap [ rr:column "lemma" ; rr:language "ru" ] ] ,
        [ rr:predicate kgo:keywordCount ; rr:objectMap [ rr:column "count" ] ] ,
        [ rr:predicate kgo:keywordLogLikelihood ; rr:objectMap [ rr:column "log_likelihood" ] ] ,
        [ rr:predicate kgo:inDocument ; rr:object <work> ] .

<#style-keyword-links> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT a.style_key, k.key FROM habr_1097022.style_keywords k CROSS JOIN habr_1097022.article a""" ] ;
    rr:subjectMap [ rr:template "style/{style_key}" ; rr:graph kgg:derived-stylometry ] ;
    rr:predicateObjectMap [ rr:predicate kgo:styleKeyword ; rr:objectMap [ rr:template "style/{style_key}/kw/{key}" ] ] .


# =================================================================== методы (methods, derived-methods и derived-contributions)

<#methods> a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "habr_1097022.methods" ] ;
    rr:subjectMap [ rr:template "method/{key}" ; rr:graph kgg:derived-methods ; rr:class kgo:Method ] ;
    rr:predicateObjectMap
        [ rr:predicate schema:name ; rr:objectMap [ rr:column "name" ; rr:language "ru" ] ] ,
        [ rr:predicate kgo:methodConcept , prov:wasDerivedFrom ; rr:objectMap [ rr:column "concept" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate kgo:hasProcedure , prov:wasDerivedFrom ; rr:objectMap [ rr:column "procedure" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate kgo:methodKind ; rr:objectMap [ rr:template "https://example.org/story-kg/concept/conceptkind/{kind}" ] ] ,
        [ rr:predicate kgo:confidence ; rr:objectMap [ rr:column "confidence" ] ] ,
        [ rr:predicate kgo:contextSection ; rr:objectMap [ rr:template "sec/{section}" ] ] ,
        [ rr:predicate kgo:inDocument ; rr:object <work> ] .

# правило — по тому, из чего карточка: из понятия или из процесса
<#method-rules-concept> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT key FROM habr_1097022.methods WHERE concept IS NOT NULL" ] ;
    rr:subjectMap [ rr:template "method/{key}" ; rr:graph kgg:derived-methods ] ;
    rr:predicateObjectMap [ rr:predicate kgo:derivationRule ; rr:object "понятие вида «метод» (concepts.kind) → карточка; процедура — kgo:hasProcedure понятия, иначе процесс той же темы, название которого называет метод; советы и нормы — о понятии или называющие его (в его теме; вне темы — короткий совет до 14 слов, если в названии два содержательных слова или аббревиатура); практики — с этими советами в решении; рассказы — с моралью-понятием или его советом; примеры — kgo:knownUse понятия и утверждения-примеры о нём или в поддержку его советов; задания — упражнения и «Задачи» темы, называющие его (остальные — методу, по которому названа тема); цель — «чтобы…», «для…», «с целью…» его коротких советов; связи понятий — skos:broader, kgo:alternativeTo"@ru ] .

<#method-rules-process> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT key FROM habr_1097022.methods WHERE concept IS NULL" ] ;
    rr:subjectMap [ rr:template "method/{key}" ; rr:graph kgg:derived-methods ] ;
    rr:predicateObjectMap [ rr:predicate kgo:derivationRule ; rr:object "процесс BBO текста с видами понятий, который ни одно понятие не называет процедурой или примером, — методика, если это инструкция: не меньше половины шагов открывает инфинитив или повелительное наклонение либо название говорит о шагах, методе, порядке; обмен сообщениями, разбор одной задачи и ход явления (природный процесс, механизм, стадии развития) методикой не считаются"@ru ] .

<#method-benefits> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT m.key, c.key AS contribution
        FROM habr_1097022.methods m JOIN habr_1097022.contributions c ON c.concept = m.concept""" ] ;
    rr:subjectMap [ rr:template "method/{key}" ; rr:graph kgg:derived-contributions ] ;
    rr:predicateObjectMap
        [ rr:predicate kgo:benefit ; rr:objectMap [ rr:template "contribution/{contribution}" ] ] ,
        [ rr:predicate kgo:inDocument ; rr:object <work> ] .


# =================================================================== фрагменты (passages, derived-passages)

<#passages> a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "habr_1097022.passages" ] ;
    rr:subjectMap [ rr:template "passage/{key}" ; rr:graph kgg:derived-passages ; rr:class kgo:Passage , kgo:ModePassage ] ;
    rr:predicateObjectMap
        [ rr:predicate kgo:passageSection , prov:wasDerivedFrom ; rr:objectMap [ rr:template "sec/{section}" ] ] ,
        [ rr:predicate kgo:discourseMode ;
          rr:objectMap [ rr:template "https://example.org/story-kg/concept/discoursemode/{mode}" ] ] ,
        [ rr:predicate kgo:passageBlocks ; rr:objectMap [ rr:column "blocks" ] ] ,
        [ rr:predicate kgo:passageChars ; rr:objectMap [ rr:column "chars" ] ] ,
        [ rr:predicate kgo:inDocument ; rr:object <work> ] ,
        [ rr:predicate kgo:derivationRule ; rr:object "число блоков (абзацев, стихов) главы или раздела с этим режимом: код, таблица, список, стихи — по строению блока; прямая речь — реплики фрейма 100 покрывают не меньше половины блока; в романе повествование, описание и рассуждение — по глаголам абзаца; остальное — без признака"@ru ] .


# =================================================================== ссылки и медиа (media, derived-media)

<#media> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT m.*,
               CASE WHEN m.kind = 'link' THEN m.url END AS link_url,
               CASE WHEN m.kind = 'image' THEN m.url END AS image_url,
               CASE WHEN m.kind = 'link' THEN 'work' END AS linked_from,
               CASE WHEN m.kind = 'image' THEN 'work' END AS part_of
        FROM habr_1097022.media m""" ] ;
    rr:subjectMap [ rr:template "{kind}/{key}" ; rr:graph kgg:derived-media ] ;
    rr:predicateObjectMap
        [ rr:predicate schema:name ; rr:objectMap [ rr:column "name" ; rr:language "ru" ] ] ,
        [ rr:predicate schema:url ; rr:objectMap [ rr:column "link_url" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate schema:contentUrl ; rr:objectMap [ rr:column "image_url" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate kgo:linkKind ; rr:objectMap [ rr:template "https://example.org/story-kg/concept/link/{link_kind}" ] ] ,
        [ rr:predicate kgo:contextSection ; rr:objectMap [ rr:template "sec/{section}" ] ] ,
        [ rr:predicate kgo:linkedFrom ; rr:objectMap [ rr:column "linked_from" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate schema:isPartOf ; rr:objectMap [ rr:column "part_of" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate kgo:inDocument ; rr:object <work> ] .

<#media-types> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT kind, key, habr_1097022.iri(t) AS class FROM habr_1097022.media, unnest(types) t""" ] ;
    rr:subjectMap [ rr:template "{kind}/{key}" ; rr:graph kgg:derived-media ] ;
    rr:predicateObjectMap [ rr:predicate rdf:type ; rr:objectMap [ rr:column "class" ; rr:termType rr:IRI ] ] .


# =================================================================== блоки кода (code_listings, derived-code)

<#code> a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "habr_1097022.code_listings" ] ;
    rr:subjectMap [ rr:template "code/{n}" ; rr:graph kgg:derived-code ; rr:class schema:SoftwareSourceCode , schema:CreativeWork ] ;
    rr:predicateObjectMap
        [ rr:predicate schema:name ; rr:objectMap [ rr:column "name" ; rr:language "ru" ] ] ,
        [ rr:predicate schema:programmingLanguage ; rr:objectMap [ rr:column "language" ] ] ,
        [ rr:predicate kgo:codeLineCount ; rr:objectMap [ rr:column "line_count" ] ] ,
        [ rr:predicate schema:isPartOf ; rr:objectMap [ rr:template "sec/{section}" ] ] ,
        [ rr:predicate kgo:codeOfStep ; rr:objectMap [ rr:template "{process}.{step}" ] ] ,
        [ rr:predicate kgo:stepCodeBasis ; rr:objectMap [ rr:column "step_basis" ] ] ,
        [ rr:predicate kgo:textSpan ; rr:objectMap [ rr:template "code/{n}#span" ] ] ,
        [ rr:predicate kgo:inDocument ; rr:object <work> ] .

<#code-steps> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT * FROM habr_1097022.code_listings WHERE step IS NOT NULL" ] ;
    rr:subjectMap [ rr:template "{process}.{step}" ; rr:graph kgg:derived-code ] ;
    rr:predicateObjectMap [ rr:predicate kgo:stepCode ; rr:objectMap [ rr:template "code/{n}" ] ] .

<#code-spans> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT c.n,
               'https://example.org/story-kg/src/' || a.source_file AS src,
               'https://example.org/story-kg/src/' || a.source_file || '#state-' || left(a.source_sha256, 12) AS state
        FROM habr_1097022.code_listings c CROSS JOIN habr_1097022.article a""" ] ;
    rr:subjectMap [ rr:template "code/{n}#span" ; rr:graph kgg:derived-code ; rr:class oa:SpecificResource ] ;
    rr:predicateObjectMap
        [ rr:predicate oa:hasSelector ; rr:objectMap [ rr:template "code/{n}#span-selector" ] ] ,
        [ rr:predicate oa:hasSource ; rr:objectMap [ rr:column "src" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate oa:hasState ; rr:objectMap [ rr:column "state" ; rr:termType rr:IRI ] ] .

<#code-selectors> a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "habr_1097022.code_listings" ] ;
    rr:subjectMap [ rr:template "code/{n}#span-selector" ; rr:graph kgg:derived-code ; rr:class oa:TextPositionSelector ] ;
    rr:predicateObjectMap
        [ rr:predicate oa:start ; rr:objectMap [ rr:column "start_pos" ; rr:datatype xsd:nonNegativeInteger ] ] ,
        [ rr:predicate oa:end ; rr:objectMap [ rr:column "end_pos" ; rr:datatype xsd:nonNegativeInteger ] ] .


# =================================================================== связи дискурса (discourse_relations, derived-discourse)

<#discourse> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT d.*, 'Discourse' || initcap(d.sense) AS class FROM habr_1097022.discourse_relations d""" ] ;
    rr:subjectMap [ rr:template "discourse/{key}" ; rr:graph kgg:derived-discourse ; rr:class kgo:DiscourseRelation ] ;
    rr:predicateObjectMap
        [ rr:predicate rdf:type ; rr:objectMap [ rr:template "https://example.org/story-kg/ontology#{class}" ] ] ,
        [ rr:predicate schema:name ; rr:objectMap [ rr:column "name" ; rr:language "ru" ] ] ,
        [ rr:predicate kgo:discourseSense ;
          rr:objectMap [ rr:template "https://example.org/story-kg/concept/discourserelation/{sense}" ] ] ,
        [ rr:predicate kgo:discourseConnective ; rr:objectMap [ rr:column "connective" ; rr:language "ru" ] ] ,
        [ rr:predicate kgo:discourseScope ;
          rr:objectMap [ rr:template "https://example.org/story-kg/concept/discoursescope/{scope}" ] ] ,
        [ rr:predicate schema:isPartOf , prov:wasDerivedFrom ; rr:objectMap [ rr:template "sec/{section}" ] ] ,
        [ rr:predicate kgo:discourseArg1Claim , prov:wasDerivedFrom ; rr:objectMap [ rr:column "arg1_claim" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate kgo:discourseArg2Claim , prov:wasDerivedFrom ; rr:objectMap [ rr:column "arg2_claim" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate kgo:discourseArg1Start ; rr:objectMap [ rr:column "arg1_start" ] ] ,
        [ rr:predicate kgo:discourseArg1End ; rr:objectMap [ rr:column "arg1_end" ] ] ,
        [ rr:predicate kgo:discourseArg2Start ; rr:objectMap [ rr:column "arg2_start" ] ] ,
        [ rr:predicate kgo:discourseArg2End ; rr:objectMap [ rr:column "arg2_end" ] ] ,
        [ rr:predicate kgo:inDocument ; rr:object <work> ] ,
        [ rr:predicate kgo:derivationRule ; rr:object "явная связка реестра ontology/discourse.yaml в прозе текста; аргумент 2 — часть предложения, в которую входит связка, аргумент 1 — главная часть, предыдущая часть или предыдущее предложение; границы частей — «;», «:», тире, запятые перед сочинительными словами"@ru ] .


# =================================================================== авторство идей (idea_links, derived-ideas)

<#ideas> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT i.*, 'Idea' || initcap(i.kind) AS class FROM habr_1097022.idea_links i""" ] ;
    rr:subjectMap [ rr:template "idea/{key}" ; rr:graph kgg:derived-ideas ; rr:class kgo:IdeaLink ] ;
    rr:predicateObjectMap
        [ rr:predicate rdf:type ; rr:objectMap [ rr:template "https://example.org/story-kg/ontology#{class}" ] ] ,
        [ rr:predicate schema:name ; rr:objectMap [ rr:column "name" ; rr:language "ru" ] ] ,
        [ rr:predicate kgo:ideaObject , prov:wasDerivedFrom ; rr:objectMap [ rr:column "object" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate kgo:ideaPerson , prov:agent ; rr:objectMap [ rr:column "person" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate kgo:ideaKind ; rr:objectMap [ rr:template "https://example.org/story-kg/concept/ideakind/{kind}" ] ] ,
        [ rr:predicate kgo:ideaRole , prov:hadRole ;
          rr:objectMap [ rr:template "https://example.org/story-kg/concept/idearole/{role}" ] ] ,
        [ rr:predicate kgo:ideaStance ;
          rr:objectMap [ rr:template "https://example.org/story-kg/concept/ideastance/{stance}" ] ] ,
        [ rr:predicate kgo:ideaYear ; rr:objectMap [ rr:column "year" ; rr:datatype xsd:gYear ] ] ,
        [ rr:predicate kgo:ideaBasis ; rr:objectMap [ rr:template "https://example.org/story-kg/concept/ideabasis/{basis}" ] ] ,
        [ rr:predicate kgo:inDocument ; rr:object <work> ] ,
        [ rr:predicate kgo:derivationRule ; rr:object "произведение называет автора, переводчика, редактора или издателя (schema:author, translator, editor, publisher); у произведения с двумя авторами и больше — соавторы; год — год издания"@ru ] .

<#idea-attributions> a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "habr_1097022.idea_links" ] ;
    rr:subjectMap [ rr:column "object" ; rr:graph kgg:derived-ideas ] ;
    rr:predicateObjectMap
        [ rr:predicate prov:qualifiedAttribution ; rr:objectMap [ rr:template "idea/{key}" ] ] ,
        [ rr:predicate prov:wasAttributedTo ; rr:objectMap [ rr:column "person" ; rr:termType rr:IRI ] ] .


# =================================================================== привязка к рубрикам тем (theme_links, derived-themes)

<#theme-links> a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "habr_1097022.theme_links" ] ;
    rr:subjectMap [ rr:template "themelink/{key}" ; rr:graph kgg:derived-themes ; rr:class kgo:ThemeLink , kgo:ThemeLinkTopic ] ;
    rr:predicateObjectMap
        [ rr:predicate schema:name ; rr:objectMap [ rr:column "name" ; rr:language "ru" ] ] ,
        [ rr:predicate kgo:themeSubject , prov:wasDerivedFrom ; rr:objectMap [ rr:column "subject" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate kgo:themeValue ; rr:objectMap [ rr:template "https://example.org/story-kg/concept/theme/{theme}" ] ] ,
        [ rr:predicate kgo:themeMatched ; rr:objectMap [ rr:column "matched" ; rr:language "ru" ] ] ,
        [ rr:predicate kgo:themeBasis ; rr:objectMap [ rr:template "https://example.org/story-kg/concept/themebasis/{basis}" ] ] ,
        [ rr:predicate kgo:inDocument ; rr:object <work> ] ,
        [ rr:predicate kgo:derivationRule ; rr:object "запись реестра ontology/themes.yaml ставится по леммам (pymorphy3) названия узла и действия нормы, названий носителя и адресата нормы, названия и псевдонимов понятия, названия темы произведения или хаба, текста пословицы, а рассказу с моралью — по морали и названию; действие нормы вида action — kgo:regulatedAction, остальное — skos:broadMatch; из записи и её более узкой записи остаётся узкая; не больше четырёх записей на узел"@ru ] .

<#broad-themes> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT DISTINCT subject, theme FROM habr_1097022.theme_links" ] ;
    rr:subjectMap [ rr:column "subject" ; rr:graph kgg:derived-themes ] ;
    rr:predicateObjectMap
        [ rr:predicate skos:broadMatch ; rr:objectMap [ rr:template "https://example.org/story-kg/concept/theme/{theme}" ] ] .


# =================================================================== совместное присутствие (copresence, derived-copresence)

<#copresence> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT c.*, CASE c.kind WHEN 'persons' THEN 'PersonCoPresence' END AS class FROM habr_1097022.copresence c""" ] ;
    rr:subjectMap [ rr:template "copresence/{key}" ; rr:graph kgg:derived-copresence ; rr:class kgo:CoPresence ] ;
    rr:predicateObjectMap
        [ rr:predicate rdf:type ; rr:objectMap [ rr:template "https://example.org/story-kg/ontology#{class}" ] ] ,
        [ rr:predicate schema:name ; rr:objectMap [ rr:column "name" ; rr:language "ru" ] ] ,
        [ rr:predicate kgo:coPresentTalkCount ; rr:objectMap [ rr:column "talk_count" ] ] ,
        [ rr:predicate kgo:coPresenceKind ;
          rr:objectMap [ rr:template "https://example.org/story-kg/concept/copresencekind/{kind}" ] ] ,
        [ rr:predicate kgo:coPresenceBasis ;
          rr:objectMap [ rr:template "https://example.org/story-kg/concept/copresencebasis/{basis}" ] ] ,
        [ rr:predicate kgo:inDocument ; rr:object <work> ] ,
        [ rr:predicate kgo:derivationRule ; rr:object "реплика (schema:Quotation спецификаций или kgo:Utterance фрейма 100 — абзац романа с тире, говорящий по ремарке или по чередованию, адресат по ремарке, по ответу или по обращению) называет говорящего и адресата (kgo:addressee): двое говорили друг с другом; реплика фрейма 100 — только если каждый из двоих говорит другому хотя бы одну реплику. Не считаются мысли (kgo:ThoughtUtterance), обращения стихов и песен (лирический субъект, рассказчик, адресат), послания Нового Завета, реплики сна и других событий, которых не было, юридические формулы и изречения мудреца, и молитва: человек обращается к божеству. Число — реплики пары в обе стороны"@ru ] .

<#copresence-persons> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT key, v FROM habr_1097022.copresence, unnest(persons) v" ] ;
    rr:subjectMap [ rr:template "copresence/{key}" ; rr:graph kgg:derived-copresence ] ;
    rr:predicateObjectMap [ rr:predicate kgo:coPresent ; rr:objectMap [ rr:column "v" ; rr:termType rr:IRI ] ] .

<#copresence-talks> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery "SELECT key, v FROM habr_1097022.copresence, unnest(talks) v" ] ;
    rr:subjectMap [ rr:template "copresence/{key}" ; rr:graph kgg:derived-copresence ] ;
    rr:predicateObjectMap
        [ rr:predicate kgo:coPresentInTalk , prov:wasDerivedFrom ; rr:objectMap [ rr:column "v" ; rr:termType rr:IRI ] ] .

<#copresent-with> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT DISTINCT x, y FROM habr_1097022.copresence c, unnest(c.persons) x, unnest(c.persons) y WHERE x <> y""" ] ;
    rr:subjectMap [ rr:column "x" ; rr:graph kgg:derived-copresence ] ;
    rr:predicateObjectMap [ rr:predicate kgo:coPresentWith ; rr:objectMap [ rr:column "y" ; rr:termType rr:IRI ] ] .


# =================================================================== промежутки состояний (state_spans, derived-states)

<#states> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT s.*, initcap(s.kind) || 'Span' AS class FROM habr_1097022.state_spans s""" ] ;
    rr:subjectMap [ rr:template "state/{key}" ; rr:graph kgg:derived-states ; rr:class kgo:StateSpan ] ;
    rr:predicateObjectMap
        [ rr:predicate rdf:type ; rr:objectMap [ rr:template "https://example.org/story-kg/ontology#{class}" ] ] ,
        [ rr:predicate schema:name ; rr:objectMap [ rr:column "name" ; rr:language "ru" ] ] ,
        [ rr:predicate kgo:stateOf ; rr:objectMap [ rr:column "entity" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate kgo:spanKind ; rr:objectMap [ rr:template "https://example.org/story-kg/concept/statekind/{kind}" ] ] ,
        [ rr:predicate kgo:spanIndex ; rr:objectMap [ rr:column "span_index" ] ] ,
        [ rr:predicate kgo:startedBy , prov:wasDerivedFrom ; rr:objectMap [ rr:column "started_by" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate kgo:firstAttestedBy ; rr:objectMap [ rr:column "first_attested_by" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate kgo:lastAttestedBy ; rr:objectMap [ rr:column "last_attested_by" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate kgo:fromRank ; rr:objectMap [ rr:column "from_rank" ] ] ,
        [ rr:predicate kgo:toRank ; rr:objectMap [ rr:column "to_rank" ] ] ,
        [ rr:predicate kgo:inDocument ; rr:object <work> ] ,
        [ rr:predicate kgo:derivationRule ; rr:object "ситуации ESO «до», «во время» и «после» событий (kgg:situation/…) одной сущности и одного вида состояния, события — по kgo:storyOrder, дате или месту в тексте с порядком по kgo:precedes, по причинам и по датам (kgo:timelineRank). Начало — событие, чья ситуация «после» вводит состояние; конец — событие, чья ситуация «после» его отрицает или вводит другое значение; ситуации «до» и «во время» подтверждают состояние; состояние, впервые названное в них, начала не имеет. Вложенные места совместимы; место «во время» перемещения и цель ухода (eso:Leaving) в линию не идут"@ru ] .


# =================================================================== термины (terms, derived-terminology)

<#terms> a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "habr_1097022.terms" ] ;
    rr:subjectMap [ rr:template "term/{slug}" ; rr:graph kgg:derived-terminology ; rr:class schema:DefinedTerm , schema:Intangible ] ;
    rr:predicateObjectMap
        [ rr:predicate schema:name ; rr:objectMap [ rr:column "name" ; rr:language "ru" ] ] ,
        [ rr:predicate kgt:denotes ; rr:objectMap [ rr:template "https://example.org/story-kg/concept/tech/{denotes}" ] ] ,
        [ rr:predicate kgo:mentionCount ; rr:objectMap [ rr:column "mention_count" ] ] ,
        [ rr:predicate schema:inDefinedTermSet ; rr:object <glossary> ] ,
        [ rr:predicate kgo:inDocument ; rr:object <work> ] .


# =================================================================== связи понятий (concept_links, derived-conceptlinks)

<#concept-links> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT l.*, 'ConceptLink' || initcap(l.kind) AS class,
               'https://example.org/story-kg/id/global/' || l.global AS global_iri
        FROM habr_1097022.concept_links l""" ] ;
    rr:subjectMap [ rr:template "conceptlink/{key}" ; rr:graph kgg:derived-conceptlinks ; rr:class kgo:ConceptLink , rdf:Statement ] ;
    rr:predicateObjectMap
        [ rr:predicate rdf:type ; rr:objectMap [ rr:template "https://example.org/story-kg/ontology#{class}" ] ] ,
        [ rr:predicate schema:name ; rr:objectMap [ rr:column "name" ; rr:language "ru" ] ] ,
        [ rr:predicate rdf:subject , prov:wasDerivedFrom ; rr:objectMap [ rr:column "concept" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate rdf:predicate ; rr:object kgo:conceptSynonymOf ] ,
        [ rr:predicate rdf:object , prov:wasDerivedFrom ; rr:objectMap [ rr:column "global_iri" ; rr:termType rr:IRI ] ] ,
        [ rr:predicate kgo:conceptLinkKind ;
          rr:objectMap [ rr:template "https://example.org/story-kg/concept/conceptlink/{kind}" ] ] ,
        [ rr:predicate kgo:conceptLinkBasis ; rr:objectMap [ rr:column "basis" ] ] ,
        [ rr:predicate kgo:conceptLinkCue ; rr:objectMap [ rr:column "cue" ] ] ,
        [ rr:predicate kgo:confidence ; rr:objectMap [ rr:column "confidence" ] ] ,
        [ rr:predicate kgo:extractionMethod ; rr:objectMap [ rr:column "method" ] ] ,
        [ rr:predicate kgo:inDocument ; rr:object <work> ] ,
        [ rr:predicate kgo:derivationRule ; rr:object "спецификации двух текстов связали понятия одним глобальным узлом (skos:exactMatch), а названия у них разные: два имени одного понятия; пара, где одно название без скобок содержит другое и ещё слова («Наследование и полиморфизм» — «Наследование», «Карго-культ матанализа» — «Карго-культ»), — вид или часть, не синоним; название «в трактовке …» — трактовка автора, не синоним"@ru ] .

<#concept-synonyms> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT concept AS x, 'https://example.org/story-kg/id/global/' || global AS y FROM habr_1097022.concept_links
        UNION
        SELECT 'https://example.org/story-kg/id/global/' || global, concept FROM habr_1097022.concept_links""" ] ;
    rr:subjectMap [ rr:column "x" ; rr:graph kgg:derived-conceptlinks ] ;
    rr:predicateObjectMap [ rr:predicate kgo:conceptSynonymOf ; rr:objectMap [ rr:column "y" ; rr:termType rr:IRI ] ] .


# =================================================================== глобальные узлы, в которых упомянута статья (граф _global)

<#mentioned-in> a rr:TriplesMap ;
    rr:logicalTable [ rr:sqlQuery """
        SELECT DISTINCT 'https://example.org/story-kg/id/global/' || g AS node
        FROM (SELECT global FROM habr_1097022.entities
              UNION SELECT global FROM habr_1097022.concepts
              UNION SELECT publisher FROM habr_1097022.article) AS x (g)
        WHERE g IS NOT NULL""" ] ;
    rr:subjectMap [ rr:column "node" ; rr:graph kgg:_global ] ;
    rr:predicateObjectMap [ rr:predicate kgo:mentionedInGraph ; rr:object kgg:habr-1097022 ] .
$ttl$) IS NOT NULL AS mapped;
