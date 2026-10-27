### arguments
Выведенный фрейм «Аргументы» (derived-arguments): довод — вывод и посылки (kgo:Argument, узлы argument/{key}, часть карты аргументации статьи — schema:isPartOf argument-map)
- key text — Ключ узла: 12 знаков SHA-1. IRI — argument/{key}
- name text — Название. RDF: schema:name @ru
- conclusion text — Вывод — id утверждения. RDF: kgo:conclusion
- premises text[] — Посылки — id утверждений. RDF: kgo:premise
- premise_role text — Роль посылок. RDF: kgo:premiseRole → kgc:claim/{код}
- внешний ключ: FOREIGN KEY (conclusion) REFERENCES habr_1097022.claims(id)

### article
Фрейм 1 «Документ»: статья (узел work: schema:Article, BlogPosting, TechArticle), её исходный файл и его состояние, счётчики Хабра, издатель, учётная запись автора на Хабре, описания графов статьи. Одна строка. Колонки style_…, argmap_… и отклика — выведенные сводки по статье (derived-stylometry, derived-arguments, derived-ratings): узлы style/{style_key}, argument-map и response с именами «Стиль текста: {slug}», «Карта аргументации ({slug})», «Отклик на статью: {title}». Узлы стека техники (techstack), словаря понятий (terms) и словаря терминов (glossary) отображение строит из названия и таблиц entities, concepts, relations, terms
- slug text — Имя статьи в Story-KG; пространство IRI её узлов https://example.org/story-kg/id/{slug}/, граф статьи kgg:{slug}
- title text — Заголовок. RDF: schema:name и schema:headline @ru
- description text — Аннотация. RDF: schema:description @ru
- types text[] — Классы статьи (qname). RDF: rdf:type
- post_type text — Тип публикации на Хабре (postType). RDF: schema:additionalType
- genres text[] — Жанры. RDF: schema:genre @ru, тройка на элемент
- tags text[] — Теги автора (user_tags). RDF: schema:keywords — дважды: строкой и строкой @ru
- about text[] — Главные предметы статьи: id сущностей и понятий. RDF: schema:about
- mentions text[] — Люди, упомянутые в статье. RDF: schema:mentions
- author text — Автор — id сущности. RDF: schema:author; второй schema:author — kge:habr-user/{author_nick}
- published timestamp without time zone — Дата публикации. RDF: schema:datePublished; она же vcard:rev карточки автора
- language text — Язык текста. RDF: schema:inLanguage
- habr_id integer — Номер статьи на Хабре. RDF: schema:identifier (строкой)
- url text — Адрес статьи. RDF: schema:sameAs
- score integer — Рейтинг статьи (score). RDF: kgo:score
- reading_count integer — Просмотры (readingCount): счётчик work#stat-readingCount, schema:ReadAction. RDF: schema:userInteractionCount
- comments_count integer — Комментарии (commentsCount): счётчик schema:CommentAction
- favorites_count integer — Закладки (favoritesCount): счётчик schema:BookmarkAction
- votes_count integer — Голоса (votesCount): счётчик schema:VoteAction
- votes_plus integer — Плюсы (votesCountPlus): счётчик schema:LikeAction
- votes_minus integer — Минусы (votesCountMinus): счётчик schema:DislikeAction
- publisher text — Издатель — глобальный узел kge:{publisher} (schema:Organization, kgo:OnlineCommunity). RDF: schema:publisher; в графе _global — kgo:mentionedInGraph
- publisher_name text — Название издателя. RDF: schema:name узла издателя (строкой)
- publisher_url text — Сайт издателя. RDF: schema:url издателя и foaf:accountServiceHomepage учётной записи автора
- author_nick text — Ник автора на Хабре: узлы kge:habr-user/{ник} (schema:Person, schema:name, schema:alternateName) и kge:habr-account/{ник} (foaf:OnlineAccount, foaf:accountName, sioc:account_of)
- author_score integer — Карма автора (authorScore). RDF: kgo:accountScore учётной записи на Хабре
- author_votes integer — Голоса за карму автора (authorVotesCount). RDF: kgo:accountVotesCount
- source_file text — Исходный файл в корпусе: узел src:{файл} (schema:MediaObject) с schema:name и schema:identifier; статья ссылается на него schema:encoding, он на неё — schema:encodesCreativeWork
- source_format text — Формат файла. RDF: schema:encodingFormat
- source_bytes integer — Размер файла. RDF: schema:contentSize «{N} bytes»
- source_chars integer — Длина текста в символах. RDF: kgo:charCount
- source_sha256 text — SHA-256 файла. RDF: kgo:sha256 файла и его состояния src:{файл}#state-{12 знаков}
- source_date timestamp with time zone — Время версии файла, к которой привязаны смещения цитат. RDF: oa:sourceDate состояния (oa:TimeState)
- spec_file text — Спецификация, из которой компилятор построил граф статьи. RDF: dcterms:source графа kgg:{slug} (граф по умолчанию, вместе с prov:wasDerivedFrom и prov:wasGeneratedBy)
- mentions_method text — Как построен индекс упоминаний. RDF: kgo:extractionMethod графа kgg:{slug}-mentions @ru (граф по умолчанию)
- narrative_person text — Выведено (derived-narrative): лицо повествования. RDF: kgo:narrativePersonType → kgc:person/{код}
- narrative_person_basis text — Выведено (derived-narrative): основание вывода. RDF: kgo:narrativePersonBasis
- like_share numeric — Выведено (derived-ratings): доля плюсов среди голосов. RDF: kgo:likeShare узла response; его счётчики (kgo:viewCount, kgo:likeCount…) — счётчики Хабра этой таблицы (reading_count, votes_plus…)
- comments_per_1000_views numeric — Выведено (derived-ratings): комментариев на 1000 просмотров. RDF: kgo:commentsPerThousandViews
- bookmarks_per_1000_views numeric — Выведено (derived-ratings): закладок на 1000 просмотров. RDF: kgo:bookmarksPerThousandViews
- style_key text — Выведено (derived-stylometry): ключ узла профиля стиля style/{ключ} (kgo:TextStyleProfile)
- style_word_count integer — Выведено (derived-stylometry): слов. RDF: kgo:styleWordCount
- style_sentence_count integer — Выведено (derived-stylometry): предложений. RDF: kgo:styleSentenceCount
- style_paragraph_count integer — Выведено (derived-stylometry): абзацев. RDF: kgo:styleParagraphCount
- style_mean_sentence_length numeric — Выведено (derived-stylometry): средняя длина предложения в словах. RDF: kgo:meanSentenceLength
- style_median_sentence_length numeric — Выведено (derived-stylometry): медианная длина предложения. RDF: kgo:medianSentenceLength
- style_mean_paragraph_length numeric — Выведено (derived-stylometry): средняя длина абзаца. RDF: kgo:meanParagraphLength
- style_type_token_ratio numeric — Выведено (derived-stylometry): доля разных слов. RDF: kgo:typeTokenRatio
- style_hapax_share numeric — Выведено (derived-stylometry): доля слов, встреченных один раз. RDF: kgo:hapaxShare
- style_function_word_share numeric — Выведено (derived-stylometry): доля служебных слов. RDF: kgo:functionWordShare
- argmap_argument_count integer — Выведено (derived-arguments): доводов в карте аргументации. RDF: kgo:argumentCount
- argmap_claim_count integer — Выведено (derived-arguments): утверждений в карте. RDF: kgo:claimCount
- argmap_conflict_count integer — Выведено (derived-arguments): возражений. RDF: kgo:conflictCount
- argmap_contested_claim_count integer — Выведено (derived-arguments): оспоренных утверждений. RDF: kgo:contestedClaimCount
- argmap_evidence_share numeric — Выведено (derived-arguments): доля утверждений с опорой на наблюдения. RDF: kgo:evidenceShare
- argmap_depth integer — Выведено (derived-arguments): глубина дерева доводов. RDF: kgo:maxDepth
- argmap_main_claims text[] — Выведено (derived-arguments): главные тезисы. RDF: kgo:mainClaim
- внешний ключ: FOREIGN KEY (author) REFERENCES habr_1097022.entities(id)

### attitudes
Установки (ментальные состояния): раздел attitudes спецификации — чья, какая, к чему (kgo:Attitude)
- id text — id из спецификации
- holder text — Чья установка — id. RDF: kgo:holder
- type text — Вид: belief, trust… RDF: kgo:attitudeType → kgc:attitude/{код}
- target text — К чему — узел. RDF: kgo:attitudeTarget
- target_text text — К чему — словами. RDF: kgo:attitudeTarget @ru
- name text — Название. RDF: schema:name @ru
- description text — Описание. RDF: schema:description @ru
- affect_class text — Выведено (derived-affect): CognitiveAttitude или AffectiveDisposition (kgo:). RDF: rdf:type
- affect_kind text — Выведено (derived-affect): вид аффекта. RDF: kgo:affectKind → kgc:affectkind/{код}
- valence text — Выведено (derived-emotions): знак. RDF: kgo:valence → kgc:valence/{код}
- outcome_key text — Выведено (derived-outcomes): итог установки outcome/{ключ} (kgo:AttitudeOutcome): kgo:intention — установка, kgo:intentionKind «attitude:{type}», schema:name — description
- outcome_event text — Выведено (derived-outcomes): событие-итог — id. RDF: kgo:outcomeEvent
- outcome_status text — Выведено (derived-outcomes): статус. RDF: kgo:outcomeStatus → kgc:outcome/{код}
- outcome_verdict text — Выведено (derived-outcomes): вердикт. RDF: kgo:outcomeVerdict → kgc:outcome/{код}
- внешний ключ: FOREIGN KEY (holder) REFERENCES habr_1097022.entities(id)
- внешний ключ: FOREIGN KEY (outcome_event) REFERENCES habr_1097022.events(id)

### claims
Утверждения: раздел claims спецификации — тезисы, доводы, примеры, ограничения (schema:Claim). Выведенные доводы и возражения — в arguments и conflicts
- id text — id из спецификации
- text text — Текст утверждения. RDF: schema:text @ru
- role text — Роль в рассуждении: thesis, argument, example, counterexample, opinion, criticism, limitation… RDF: kgo:claimRole → kgc:claim/{код}
- zone text — Риторическая зона: problem, method, result, discussion, limitation, conclusion. RDF: kgo:rhetoricalZone → kgc:rhetoricalzone/{код}
- author text — Чьё утверждение, если не автора статьи — id. RDF: schema:author
- supports text[] — Какие утверждения поддерживает. RDF: kgo:supports
- attacks text[] — Какие утверждения опровергает. RDF: kgo:attacks
- about text[] — О чём: id сущностей, понятий, наблюдений. RDF: schema:about
- внешний ключ: FOREIGN KEY (author) REFERENCES habr_1097022.entities(id)

### code_listings
Выведенный фрейм «Код» (derived-code): блоки кода статьи (schema:SoftwareSourceCode, узлы code/{n} с промежутком текста code/{n}#span) и шаг процесса, который они показывают
- n integer — Номер блока кода в статье. IRI — code/{n}
- name text — Название. RDF: schema:name @ru
- language text — Язык. RDF: schema:programmingLanguage
- line_count integer — Строк. RDF: kgo:codeLineCount
- section text — Раздел. RDF: schema:isPartOf
- process text — Процесс шага — id
- step text — Шаг, который показывает код. RDF: kgo:codeOfStep; у шага — kgo:stepCode
- step_basis text — Как найден шаг. RDF: kgo:stepCodeBasis
- start_pos integer — Начало блока в символах текста. RDF: oa:start
- end_pos integer — Конец блока в символах текста. RDF: oa:end
- внешний ключ: FOREIGN KEY (process, step) REFERENCES habr_1097022.process_steps(process, step)
- внешний ключ: FOREIGN KEY (section) REFERENCES habr_1097022.sections(id)

### concept_links
Выведенный фрейм «Связи понятий» (derived-conceptlinks): понятие статьи и глобальное понятие — синонимы (kgo:ConceptLink и kgo:ConceptLink{Kind}, rdf:Statement; узлы conceptlink/{key}); kgo:conceptSynonymOf — в обе стороны
- key text — Ключ узла: 12 знаков SHA-1. IRI — conceptlink/{key}
- name text — Название. RDF: schema:name @ru
- concept text — Понятие статьи — id. RDF: rdf:subject
- global text — Глобальное понятие kge:{global}. RDF: rdf:object
- kind text — Вид связи: synonym… RDF: kgo:conceptLinkKind → kgc:conceptlink/{код}
- basis text — Основание. RDF: kgo:conceptLinkBasis
- cue text — Подсказка правила. RDF: kgo:conceptLinkCue
- confidence numeric — Уверенность. RDF: kgo:confidence
- method text — Способ. RDF: kgo:extractionMethod
- внешний ключ: FOREIGN KEY (concept) REFERENCES habr_1097022.concepts(id)

### concepts
Фрейм 9 «Понятия»: раздел concepts спецификации — механизмы, методы, структуры данных, явления (schema:DefinedTerm, skos:Concept) словаря понятий статьи terms (skos:inScheme, schema:inDefinedTermSet). Отличия и части — в таблице relations, вклад методов в качества — в contributions
- id text — id из спецификации; IRI — https://example.org/story-kg/id/habr-1097022/{id}
- name text — Название. RDF: schema:name и skos:prefLabel @ru
- alt_names text[] — Другие названия. RDF: skos:altLabel @ru
- kind text — Вид понятия: mechanism, technique, component, datastructure, variant, phenomenon… RDF: kgo:conceptKind → kgc:conceptkind/{код}
- definition text — Определение. RDF: skos:definition и schema:description @ru
- description text — Пояснение. RDF: schema:description @ru
- global text — Глобальное понятие Story-KG. RDF: skos:exactMatch kge:{global}; в графе _global — kgo:mentionedInGraph
- broader text[] — Более общие понятия. RDF: skos:broader
- narrower text[] — Более частные понятия. RDF: skos:narrower
- related text[] — Связанные понятия. RDF: skos:related
- counter_measures text[] — Чем бороться с явлением. RDF: kgo:counterMeasure
- procedure text — Процедура метода — id процесса. RDF: kgo:hasProcedure
- goal text — Цель метода. RDF: kgo:methodGoal @ru
- arises_when text — Когда возникает явление. RDF: kgo:arisesWhen @ru
- manifestation text — Как проявляется явление. RDF: kgo:manifestation @ru
- mechanism text — Механизм явления. RDF: kgo:phenomenonMechanismText @ru
- mention_count integer — Сколько раз названо в тексте. RDF: kgo:mentionCount, граф упоминаний
- stack_role text — Выведено (derived-techstack): роль в стеке техники статьи. RDF: kgo:techRole → kgc:techrole/{код}
- extraction_basis text — Выведено (derived-provenance): основание извлечения. RDF: kgo:extractionBasis → kgc:basis/{код}
- definition_key text — Выведено (derived-definitions): ключ узла definition/{ключ} (kgo:Definition: kgo:defines — понятие, kgo:definiendum — name, kgo:definiens — definition, kgo:definitionPattern «concept»)
- problem_key text — Выведено (derived-problems): ключ узла problem/{ключ} (kgo:Phenomenon: kgo:phenomenonConcept — понятие, schema:name — name)
- внешний ключ: FOREIGN KEY (procedure) REFERENCES habr_1097022.processes(id)

### conflicts
Выведенные фреймы «Аргументы» и «Достоверность» (derived-arguments, derived-credibility): возражение — утверждение, опровергающее другое (kgo:Conflict, conflict/{key}), и оценка опровергнутого (schema:ClaimReview, review/{key})
- key text — Ключ обоих узлов: 12 знаков SHA-1
- attacked text — Опровергаемое утверждение — id. RDF: kgo:conflictedClaim; у оценки — schema:itemReviewed
- attacker text — Опровергающее утверждение — id. RDF: kgo:conflictingClaim; у оценки — kgo:reviewingClaim
- rebutted boolean — Возражение отбито. RDF: kgo:attackRebutted
- verdict text — Вердикт оценки: disputed… RDF: kgo:verdict → kgc:verdict/{код}, граф derived-credibility
- name text — Название возражения. RDF: schema:name @ru
- review_name text — Название оценки. RDF: schema:name @ru, граф derived-credibility
- внешний ключ: FOREIGN KEY (attacked) REFERENCES habr_1097022.claims(id)
- внешний ключ: FOREIGN KEY (attacker) REFERENCES habr_1097022.claims(id)

### contributions
Вклад метода в качество (kgo:Contribution, узлы contribution/{key}): из поля benefits понятия. Понятие ссылается на вклад kgo:benefit; schema:name — «{название понятия}: {effect}»
- key text — Ключ узла: 12 знаков SHA-1. IRI — contribution/{key}
- concept text — Метод — id понятия. RDF: kgo:contributionOf
- type text — help — помогает, hurt — мешает. RDF: kgo:contributionType → kgc:contribution/{код}
- effect_kind text — benefit или cost. RDF: kgo:effectKind → kgc:effectkind/{код}
- effect text — Что даёт метод. RDF: kgo:effectText @ru
- quality text — Атрибут качества ISO/IEC 25010: time_behaviour, resource_utilization… RDF: kgo:qualityAttribute → kgc:quality/{код}
- внешний ключ: FOREIGN KEY (concept) REFERENCES habr_1097022.concepts(id)

### copresence
Выведенный фрейм «Совместное присутствие» (derived-copresence): кто с кем встречается в тексте (kgo:CoPresence, kgo:PersonCoPresence; узлы copresence/{key}); люди получают kgo:coPresentWith
- key text — Ключ узла: 12 знаков SHA-1. IRI — copresence/{key}
- name text — Название. RDF: schema:name @ru
- persons text[] — Кто — id. RDF: kgo:coPresent
- talks text[] — В каких репликах вместе — id. RDF: kgo:coPresentInTalk и prov:wasDerivedFrom
- talk_count integer — Реплик. RDF: kgo:coPresentTalkCount
- kind text — Вид. RDF: kgo:coPresenceKind → kgc:copresencekind/{код}
- basis text — Основание: conversation… RDF: kgo:coPresenceBasis → kgc:copresencebasis/{код}

### datasets
Выведенный фрейм «Эксперименты» (derived-experiments): наблюдения одной величины — набор измерений (qb:DataSet, kgo:MeasurementSet; сравнение — kgo:Experiment, kgo:Benchmark). Узел {id}; наблюдения ссылаются на него qb:dataSet, он на них — prov:wasDerivedFrom
- id text — id из поля dataset спецификации
- types text[] — Классы (qname). RDF: rdf:type
- name text — Название. RDF: schema:name @ru
- measure text — Измеряемая величина. RDF: kgo:measureLabel @ru
- condition text — Контекст набора. RDF: kgo:conditionText @ru
- units text[] — Единицы. RDF: schema:unitText
- series_kind text — Что меняется: comparison (объект), conditions (условие), timeline (дата). RDF: kgo:seriesKind → kgc:series/{код}
- subjects text[] — Что испытывается — id. RDF: kgo:subjectUnderTest
- section text — Раздел статьи. RDF: kgo:contextSection
- observation_count integer — Наблюдений в наборе. RDF: kgo:observationCount
- best_observation text — Лучшее наблюдение — id. RDF: kgo:bestObservation
- better_is text — Что лучше: lower или higher. RDF: kgo:betterIs
- внешний ключ: FOREIGN KEY (best_observation) REFERENCES habr_1097022.observations(id)
- внешний ключ: FOREIGN KEY (section) REFERENCES habr_1097022.sections(id)

### dialogues
Выведенный фрейм «Диалог» (derived-dialogue): подряд идущие реплики раздела с чередованием говорящих (kgo:Dialogue, узлы dialogue/{key}); реплики ссылаются на диалог kgo:inDialogue, он на них — prov:wasDerivedFrom
- key text — Ключ узла: 12 знаков SHA-1. IRI — dialogue/{key}
- name text — Название. RDF: schema:name @ru
- section text — Раздел. RDF: kgo:contextSection
- participants text[] — Участники — id. RDF: kgo:dialogueParticipant
- turn_count integer — Ходов. RDF: kgo:turnCount
- внешний ключ: FOREIGN KEY (section) REFERENCES habr_1097022.sections(id)

### discourse_relations
Выведенный фрейм «Связи дискурса» (derived-discourse): связка двух частей текста — причина, следствие (kgo:DiscourseRelation и kgo:Discourse{Sense}, узлы discourse/{key})
- key text — Ключ узла: 12 знаков SHA-1. IRI — discourse/{key}
- name text — Название. RDF: schema:name @ru
- sense text — Смысл связи: result, reason… RDF: kgo:discourseSense → kgc:discourserelation/{код}
- connective text — Связка: поэтому, потому что… RDF: kgo:discourseConnective @ru
- scope text — Внутри предложения или между ними. RDF: kgo:discourseScope → kgc:discoursescope/{код}
- section text — Раздел. RDF: schema:isPartOf и prov:wasDerivedFrom
- arg1_claim text — Утверждение первой части — id. RDF: kgo:discourseArg1Claim
- arg1_start integer — Начало первой части. RDF: kgo:discourseArg1Start
- arg1_end integer — Конец первой части. RDF: kgo:discourseArg1End
- arg2_claim text — Утверждение второй части — id. RDF: kgo:discourseArg2Claim
- arg2_start integer — Начало второй части. RDF: kgo:discourseArg2Start
- arg2_end integer — Конец второй части. RDF: kgo:discourseArg2End
- внешний ключ: FOREIGN KEY (arg1_claim) REFERENCES habr_1097022.claims(id)
- внешний ключ: FOREIGN KEY (arg2_claim) REFERENCES habr_1097022.claims(id)
- внешний ключ: FOREIGN KEY (section) REFERENCES habr_1097022.sections(id)

### entities
Фреймы 5, 6, 8 «Люди, организации, предметы»: раздел entities спецификации — люди, программы, библиотеки, статьи, организации. Связи между ними — в таблице relations
- id text — id из спецификации; IRI — https://example.org/story-kg/id/habr-1097022/{id}
- types text[] — Классы (qname): schema:Person, schema:SoftwareApplication… RDF: rdf:type
- name text — Имя. RDF: schema:name @ru
- alt_names text[] — Другие названия. RDF: schema:alternateName @ru
- hidden_labels text[] — Написания для поиска (постгрес, кликхаус). RDF: skos:hiddenLabel @ru
- description text — Описание. RDF: schema:description @ru
- roles text[] — Роль в тексте: author, narrator, protagonist, major. RDF: kgo:characterRole → kgc:role/{код}
- global text — Глобальный узел Story-KG, общий для всех текстов. RDF: owl:sameAs kge:{global}; в графе _global — kge:{global} kgo:mentionedInGraph kgg:habr-1097022
- same_as text — Другой внешний узел того же объекта. RDF: owl:sameAs kge:{same_as}
- tech_role text — Роль в технике: database, framework_library… RDF: kgo:techRole → kgc:techrole/{код}
- discourse_position integer — Позиция в сюжете: смещение первого упоминания. RDF: kgo:discoursePosition
- sensitivity text — Чувствительность сведений: personal. RDF: kgo:sensitivity → kgc:sensitivity/{код}
- url text — Адрес. RDF: schema:url
- code_repository text — Репозиторий исходного кода. RDF: schema:codeRepository
- author text — Автор произведения или кода — id. RDF: schema:author
- about text[] — О чём произведение — id. RDF: schema:about
- contacts_sensitivity text — Есть карточка контактов {id}#vcard (vcard:Individual: vcard:fn — имя, vcard:rev — дата статьи); значение — её kgo:sensitivity. Персона ссылается на карточку kgo:contactCard
- account_service text — Учётная запись {id}#account-{сервис}_{имя} (foaf:OnlineAccount, sioc:UserAccount): сервис. RDF: schema:description @ru; персона ссылается на запись foaf:account
- account_name text — Имя учётной записи. RDF: foaf:accountName
- account_service_url text — Сайт сервиса. RDF: foaf:accountServiceHomepage
- account_url text — Адрес учётной записи. RDF: schema:url
- mention_count integer — Сколько раз названа в тексте. RDF: kgo:mentionCount, граф упоминаний
- stack_role text — Выведено (derived-techstack): роль в стеке техники статьи. RDF: kgo:techRole; стек ссылается на узел kgo:stackComponent
- внешний ключ: FOREIGN KEY (author) REFERENCES habr_1097022.entities(id)

### events
Фреймы 13–14 «События»: раздел events спецификации — события и действия schema.org с классами ESO
- id text — id из спецификации
- types text[] — Классы (qname): schema:Event, schema:AssessAction, eso:Creating… RDF: rdf:type
- name text — Название. RDF: schema:name @ru
- description text — Описание. RDF: schema:description @ru
- frame text — Фрейм FrameNet из спецификации. RDF: kgo:frame → fn:{фрейм}
- agent text — Кто действует. RDF: schema:agent
- object text — Над чем. RDF: schema:object
- instrument text — Чем. RDF: schema:instrument
- date_text text — Дата словами из текста. RDF: kgo:dateText @ru
- factuality text — Фактичность: actual… RDF: kgo:factuality → kgc:factuality/{код}
- precedes text[] — Какие события следуют. RDF: kgo:precedes
- causes text[] — Причина каких событий. RDF: kgo:causes
- caused_by text — Следствие какого события. RDF: kgo:causedBy
- motivated_by text — Что побудило — id. RDF: kgo:motivatedBy
- discourse_position integer — Позиция в сюжете: смещение первого упоминания. RDF: kgo:discoursePosition
- creates text — Что создано (ESO Creating). RDF: eso:creating-theme; ситуации до и после — узлы и графы kgg:situation/habr-1097022/{id}#pre|#post (eso:Situation, kgo:situationOf) с eso:exist false и true
- timeline_rank integer — Выведено (derived-states): место на шкале времени. RDF: kgo:timelineRank
- lifecycle_stage text — Выведено (derived-creations): стадия жизненного цикла. RDF: kgo:lifecycleStage → kgc:creationstage/{код}
- fn_frame text — Выведено (derived-framenet): фрейм FrameNet по классу ESO. RDF: kgo:frame → fn:{фрейм}
- fn_frame_choice text — Выведено (derived-framenet): как выбран фрейм. RDF: kgo:frameChoice → kgc:framechoice/{код}
- fn_frame_match text — Выведено (derived-framenet): точность соответствия. RDF: kgo:frameMatch → kgc:framematch/{код}
- fn_frame_mapping text — Выведено (derived-framenet): соответствие ESO — FrameNet. RDF: kgo:frameMapping → kge:{…}
- fn_roles jsonb — Выведено (derived-framenet): элементы фрейма {"{роль}": "{id}"}. RDF: fe:{роль} {id}
- dialog_act text — Выведено (derived-dialogue): событие — речевой акт (kgo:CommunicationEvent) с функцией. RDF: kgo:communicativeFunction → kgc:dialogact/{код}
- speaker text — Выведено (derived-dialogue): говорящий. RDF: kgo:speaker
- внешний ключ: FOREIGN KEY (agent) REFERENCES habr_1097022.entities(id)
- внешний ключ: FOREIGN KEY (speaker) REFERENCES habr_1097022.entities(id)

### evidence
Фрейм 3 «Привязка к тексту» (W3C Web Annotation): цитата статьи, на которую опирается узел. Строка — аннотация anno/{key} (oa:Annotation); её цель (oa:SpecificResource с oa:hasSource и oa:hasState) и селекторы цитаты (oa:TextQuoteSelector) и позиции (oa:TextPositionSelector) — пустые узлы, их строит отображение. Здесь же первые упоминания (граф упоминаний) и цитаты выведенных фреймов. Путь в графе от аннотации: oa:hasBody — узел; oa:hasTarget → kgo:line, kgo:inSection; oa:hasTarget → oa:hasSelector → oa:exact, oa:prefix, oa:suffix (селектор цитаты) и oa:start, oa:end (селектор позиции)
- key text — Ключ аннотации: 12 знаков SHA-1; first-… — первое упоминание, d-… — цитата выведенного фрейма. IRI — anno/{key}
- about text — Узел, который цитата подтверждает: id или путь (rel/…, theme/…, definition/…). RDF: oa:hasBody
- graph text — Граф аннотации: habr-1097022, habr-1097022-mentions или derived-…
- motivation text — Назначение цитаты: describing, classifying, identifying, linking. RDF: oa:motivatedBy → oa:{код}
- first_mention boolean — Первое упоминание узла в тексте. RDF: kgo:firstMention у узла about
- comment text — Пояснение к цитате. RDF: rdfs:comment @ru
- section text — Раздел цитаты. RDF: kgo:inSection цели аннотации (oa:hasTarget → kgo:inSection)
- line integer — Строка исходного файла. RDF: kgo:line цели аннотации (oa:hasTarget → kgo:line)
- quote text — Цитата дословно. RDF: oa:exact селектора цитаты (oa:hasTarget → oa:hasSelector → oa:exact)
- prefix text — Текст перед цитатой. RDF: oa:prefix селектора цитаты (oa:hasTarget → oa:hasSelector → oa:prefix)
- suffix text — Текст после цитаты. RDF: oa:suffix селектора цитаты (oa:hasTarget → oa:hasSelector → oa:suffix)
- start_pos integer — Начало цитаты в символах текста. RDF: oa:start селектора позиции (oa:hasTarget → oa:hasSelector → oa:start; xsd:nonNegativeInteger)
- end_pos integer — Конец цитаты в символах текста. RDF: oa:end селектора позиции (oa:hasTarget → oa:hasSelector → oa:end)
- внешний ключ: FOREIGN KEY (section) REFERENCES habr_1097022.sections(id)

### hubs
Хабы Хабра, в которых опубликована статья: узлы kge:habr-hub/{slug} (skos:Concept схемы kge:habr-hubs). Статья ссылается на них kgo:hub
- slug text — Код хаба в Story-KG (транслит названия)
- name text — Название хаба. RDF: skos:prefLabel @ru
- views_rank integer — Выведено (derived-ratings): место статьи в рейтинге хаба по просмотрам. RDF: schema:position элемента списка kge:habr-hub/{slug}#by-views
- views_rank_key text — Выведено (derived-ratings): ключ элемента списка response#hub-{ключ} (schema:ListItem); отклик ссылается на него kgo:hubPosition

### idea_links
Выведенный фрейм «Идеи» (derived-ideas): кто автор идеи, произведения или кода (kgo:IdeaLink и kgo:Idea{Kind}, узлы idea/{key}); объект получает prov:qualifiedAttribution и prov:wasAttributedTo
- key text — Ключ узла: 12 знаков SHA-1. IRI — idea/{key}
- name text — Название. RDF: schema:name @ru
- object text — Идея, произведение, код — id. RDF: kgo:ideaObject и prov:wasDerivedFrom
- person text — Чья — id. RDF: kgo:ideaPerson и prov:agent
- kind text — Вид связи: origin… RDF: kgo:ideaKind → kgc:ideakind/{код}
- role text — Роль человека: authored… RDF: kgo:ideaRole и prov:hadRole → kgc:idearole/{код}
- stance text — Как текст говорит об идее: cites… RDF: kgo:ideaStance → kgc:ideastance/{код}
- year integer — Год. RDF: kgo:ideaYear (xsd:gYear)
- basis text — Основание. RDF: kgo:ideaBasis → kgc:ideabasis/{код}
- внешний ключ: FOREIGN KEY (person) REFERENCES habr_1097022.entities(id)

### media
Выведенный фрейм «Ссылки и медиа» (derived-media): ссылки статьи (link/{key}: репозитории, статьи; kgo:linkedFrom — статья) и картинки (image/{key}; schema:isPartOf — статья)
- kind text — link или image — первая часть IRI
- key text — Ключ узла: 12 знаков SHA-1
- types text[] — Классы (qname). RDF: rdf:type
- name text — Текст ссылки. RDF: schema:name @ru
- url text — Адрес. RDF: schema:url; у картинки — schema:contentUrl
- link_kind text — Вид ссылки: repository, article… RDF: kgo:linkKind → kgc:link/{код}
- section text — Раздел. RDF: kgo:contextSection
- внешний ключ: FOREIGN KEY (section) REFERENCES habr_1097022.sections(id)

### methods
Выведенный фрейм «Методы» (derived-methods, derived-contributions): карточка метода (kgo:Method, method/{key}) — из понятия вида «метод» или из процесса без такого понятия; польза метода (kgo:benefit) — из contributions его понятия
- key text — Ключ узла: 12 знаков SHA-1. IRI — method/{key}
- name text — Название. RDF: schema:name @ru
- concept text — Понятие метода — id. RDF: kgo:methodConcept
- procedure text — Процедура — id процесса. RDF: kgo:hasProcedure
- kind text — Вид. RDF: kgo:methodKind → kgc:conceptkind/{код}
- confidence numeric — Уверенность правила. RDF: kgo:confidence
- section text — Раздел. RDF: kgo:contextSection
- внешний ключ: FOREIGN KEY (concept) REFERENCES habr_1097022.concepts(id)
- внешний ключ: FOREIGN KEY (procedure) REFERENCES habr_1097022.processes(id)
- внешний ключ: FOREIGN KEY (section) REFERENCES habr_1097022.sections(id)

### narratives
Вложенные рассказы: раздел narratives спецификации (kgo:EmbeddedNarrative) — здесь рамка статьи, спор автора со знакомым архитектором. Колонки вставного рассказа — выведенный фрейм derived-insets
- id text — id из спецификации
- name text — Название. RDF: schema:name @ru
- description text — Описание. RDF: schema:description @ru
- type text — Вид рассказа: anecdote… RDF: kgo:narrativeType → kgc:narrative/{код}
- factuality text — Фактичность. RDF: kgo:factuality → kgc:factuality/{код}
- told_by text — Рассказчик — id. RDF: kgo:toldBy
- characters text[] — Персонажи — id. RDF: schema:character
- moral text — Мораль — id утверждения. RDF: kgo:moral
- level integer — Уровень вложенности. RDF: kgo:narrativeLevel
- span_start integer — Начало рассказа в символах текста. RDF: oa:start селектора промежутка kgo:textSpan
- span_end integer — Конец рассказа в символах текста. RDF: oa:end
- inset_class text — Выведено (derived-insets): класс вставного рассказа: InsetAnecdote… RDF: rdf:type kgo:Inset и kgo:{класс}
- diegetic_level integer — Выведено (derived-insets): степень по Женетту. RDF: kgo:diegeticLevel
- diegetic_level_kind text — Выведено (derived-insets): RDF: kgo:diegeticLevelKind → kgc:diegeticlevel/{код}
- audience_kind text — Выведено (derived-insets): кому рассказано. RDF: kgo:insetAudienceKind → kgc:insetaudience/{код}
- narrator_kind text — Выведено (derived-insets): кто рассказывает. RDF: kgo:insetNarratorKind → kgc:insetnarrator/{код}
- narrator_basis text — Выведено (derived-insets): как найден рассказчик. RDF: kgo:insetNarratorBasis → kgc:insetbasis/{код}
- purpose text — Выведено (derived-insets): зачем рассказ. RDF: kgo:insetPurpose → kgc:insetpurpose/{код}
- внешний ключ: FOREIGN KEY (moral) REFERENCES habr_1097022.claims(id)
- внешний ключ: FOREIGN KEY (told_by) REFERENCES habr_1097022.entities(id)

### observations
Наблюдения и измерения: раздел observations спецификации — числа статьи (schema:Observation, schema:QuantitativeValue): что, сколько, в чём, при каких условиях. Выведенные колонки — единицы и величины (derived-quantities)
- id text — id из спецификации
- variable text — Что измерено. RDF: schema:variableMeasured и schema:name @ru
- value numeric — Число. RDF: schema:value — xsd:integer у целых, xsd:double у дробных
- value_range text — Значение-диапазон как в тексте («51-86»). RDF: schema:value @ru
- unit text — Единица как в тексте: мс, с, %, раз. RDF: schema:unitText @ru
- condition text — Условия: система, планировщик, хранилище, запрос. RDF: kgo:conditionText @ru
- dataset text — Набор измерений — id из поля dataset спецификации; карточка набора — в datasets (у набора из одного наблюдения её нет, поэтому внешнего ключа нет). RDF: qb:dataSet в графе статьи и в derived-experiments (там же rdf:type qb:Observation)
- about text[] — О чём — id. RDF: schema:observationAbout
- unit_code text — Выведено (derived-quantities): единица по словарю: millisecond, percent… RDF: kgo:unit → kgc:unit/{код}
- quantity_kind text — Выведено (derived-quantities): род величины: time, ratio… RDF: kgo:quantityKind → kgc:quantitykind/{код}
- base_unit text — Выведено (derived-quantities): базовая единица. RDF: kgo:baseUnit → kgc:unit/{код}
- value_in_base_unit numeric — Выведено (derived-quantities): значение в базовой единице. RDF: kgo:valueInBaseUnit
- min_value numeric — Выведено (derived-quantities): нижняя граница диапазона. RDF: schema:minValue
- max_value numeric — Выведено (derived-quantities): верхняя граница диапазона. RDF: schema:maxValue
- min_in_base_unit numeric — Выведено (derived-quantities): нижняя граница в базовой единице. RDF: kgo:minValueInBaseUnit
- max_in_base_unit numeric — Выведено (derived-quantities): верхняя граница в базовой единице. RDF: kgo:maxValueInBaseUnit
- carriers text[] — Выведено (derived-quantities): носители величины — id. RDF: kgo:carrier
- carrier_basis text — Выведено (derived-quantities): по какому полю найдены носители. RDF: kgo:carrierBasis
- observed_property text — Выведено (derived-quantities): измеряемое свойство — id. RDF: kgo:observedProperty
- property_basis text — Выведено (derived-quantities): как найдено свойство. RDF: kgo:propertyBasis
- count_noun text — Выведено (derived-quantities): что считается. RDF: kgo:countNoun @ru

### passages
Выведенный фрейм «Фрагменты» (derived-passages): часть раздела с одним режимом изложения (kgo:Passage, kgo:ModePassage; узлы passage/{key})
- key text — Ключ узла: 12 знаков SHA-1. IRI — passage/{key}
- section text — Раздел. RDF: kgo:passageSection и prov:wasDerivedFrom
- mode text — Режим изложения. RDF: kgo:discourseMode → kgc:discoursemode/{код}
- blocks integer — Абзацев. RDF: kgo:passageBlocks
- chars integer — Символов. RDF: kgo:passageChars
- внешний ключ: FOREIGN KEY (section) REFERENCES habr_1097022.sections(id)

### process_flows
Переходы между шагами: узлы {process}.flow{n} (bbo:SequenceFlow; с условием — bbo:ConditionalSequenceFlow и условие {process}.flow{n}-cond, bbo:ConditionExpression)
- process text — Процесс — id. RDF: bbo:has_container
- n integer — Номер перехода в процессе; IRI — {process}.flow{n}
- source text — Откуда — код шага. RDF: bbo:has_sourceRef
- target text — Куда — код шага. RDF: bbo:has_targetRef
- condition text — Условие перехода из шлюза. RDF: rdfs:label @ru узла условия
- внешний ключ: FOREIGN KEY (process, source) REFERENCES habr_1097022.process_steps(process, step)
- внешний ключ: FOREIGN KEY (process, target) REFERENCES habr_1097022.process_steps(process, step)

### process_steps
Шаги процесса BBO: узлы {process}.{step} (bbo:StartEvent, Task, ServiceTask, ExclusiveGateway, EndEvent) в процессе (bbo:has_container). Соседей (bbo:has_incoming, has_outgoing, has_previousFlowNode, has_nextFlowNode) отображение берёт из process_flows
- process text — Процесс — id
- step text — Код шага в процессе (s0, t1, g1, e1); IRI — {process}.{step}
- type text — Класс шага: StartEvent, Task, ServiceTask, ExclusiveGateway, EndEvent (bbo:)
- name text — Название. RDF: bbo:name (строкой) и schema:name @ru
- uses_tool text[] — Чем выполняется шаг — id. RDF: kgo:usesTool
- stack_tools text[] — Выведено (derived-techstack): компоненты стека на шаге. RDF: kgo:usesTool
- внешний ключ: FOREIGN KEY (process) REFERENCES habr_1097022.processes(id)

### processes
Фрейм 21 «Процессы» (BBO): раздел processes спецификации — процесс (bbo:Process); шаги — process_steps, переходы — process_flows; bbo:has_flowElements отображение берёт из них
- id text — id из спецификации
- name text — Название. RDF: bbo:name (строкой) и schema:name @ru
- applies_to text — К кому применяется — id. RDF: kgo:appliesTo
- precondition text — Предусловие. RDF: kgo:precondition @ru
- result text — Результат. RDF: kgo:processResult @ru
- process_kind text — Выведено (derived-origins): вид процесса. RDF: kgo:processKind → kgc:processkind/{код}
- внешний ключ: FOREIGN KEY (applies_to) REFERENCES habr_1097022.entities(id)

### quotations
Фрейм 24 «Речь»: реплики спора автора со знакомым архитектором (schema:Quotation, часть статьи — schema:isPartOf)
- id text — id реплики: rep01…
- speaker text — Кто говорит — id. RDF: schema:creator и schema:spokenByCharacter
- addressees text[] — Кому — id. RDF: kgo:addressee
- speech_act text — Речевой акт: question, directive, assertive, expressive, commissive. RDF: kgo:speechAct → kgc:speechact/{код}
- stance text — Позиция говорящего: disagree, agree, irony. RDF: kgo:stance → kgc:stance/{код}
- stance_target text — К какой реплике позиция. RDF: kgo:stanceTarget
- text text — Реплика (дословный фрагмент). RDF: schema:text @ru
- description text — Роль реплики в споре. RDF: schema:description @ru
- about text[] — О чём реплика: id технического слоя. RDF: schema:about
- dialogue text — Выведено (derived-dialogue): диалог — ключ. RDF: kgo:inDialogue
- turn_index integer — Выведено (derived-dialogue): номер хода в диалоге. RDF: kgo:turnIndex
- responds_to text — Выведено (derived-dialogue): на какую реплику отвечает. RDF: kgo:respondsTo
- answers text — Выведено (derived-dialogue): на какой вопрос отвечает. RDF: kgo:answers
- внешний ключ: FOREIGN KEY (answers) REFERENCES habr_1097022.quotations(id)
- внешний ключ: FOREIGN KEY (dialogue) REFERENCES habr_1097022.dialogues(key)
- внешний ключ: FOREIGN KEY (responds_to) REFERENCES habr_1097022.quotations(id)
- внешний ключ: FOREIGN KEY (speaker) REFERENCES habr_1097022.entities(id)
- внешний ключ: FOREIGN KEY (stance_target) REFERENCES habr_1097022.quotations(id)

### relations
Фрейм 11 «Отношения»: n-арный узел rel/{key} (kgo:Relationship, rdf:Statement) — кто, какое свойство, с кем, подпись, отличие. Прямую тройку «subject predicate object» строит отображение; kgo:differsFrom и kgo:integratesWith — в обе стороны
- key text — Ключ узла: 12 знаков SHA-1. IRI — rel/{key}
- subject text — Кто — id. RDF: rdf:subject
- predicate text — Свойство (qname): kgo:usesTool, kgo:implements, kgo:integratesWith, kgo:differsFrom, schema:isPartOf, schema:isBasedOn. RDF: rdf:predicate
- object text — С кем — id. RDF: rdf:object
- label text — Подпись. RDF: kgo:relationLabel @ru
- feature text — Чем отличаются (для kgo:differsFrom). RDF: kgo:distinguishingFeature @ru
- in_stack boolean — Выведено (derived-techstack): отношение входит в стек техники статьи. RDF: kgo:stackRelation и prov:wasDerivedFrom узла techstack

### sections
Фрейм 2 «Структура текста»: шапка (fm), вступление (body) и разделы s1…s5 — узлы sec/{id} с промежутком текста sec/{id}#span (oa:SpecificResource и oa:TextPositionSelector sec/{id}#span-selector)
- id text — Код раздела. RDF: kgo:sectionId; IRI — sec/{id}
- kind text — Класс раздела: Section или FrontMatter (kgo:)
- name text — Заголовок. RDF: schema:name @ru
- level integer — Уровень заголовка. RDF: kgo:level
- line integer — Строка начала в исходном файле. RDF: kgo:line
- parent text — Объемлющий раздел; пусто — статья целиком (work). RDF: schema:isPartOf
- start_pos integer — Начало раздела в символах текста. RDF: oa:start (xsd:nonNegativeInteger)
- end_pos integer — Конец раздела в символах текста. RDF: oa:end
- mentions text[] — Сущности и понятия, названные в разделе. RDF: schema:mentions, граф упоминаний kgg:habr-1097022-mentions
- main_claim text — Выведено (derived-passages): главный тезис раздела. RDF: kgo:mainClaim
- main_claim_supports integer — Выведено (derived-passages): сколько доводов его поддерживает. RDF: kgo:mainClaimSupports
- terms text[] — Выведено (derived-terminology): термины, упомянутые в разделе. RDF: schema:mentions term/{slug}
- внешний ключ: FOREIGN KEY (main_claim) REFERENCES habr_1097022.claims(id)
- внешний ключ: FOREIGN KEY (parent) REFERENCES habr_1097022.sections(id)

### state_spans
Выведенный фрейм «Состояния» (derived-states): промежуток сюжета, когда сущность существует или пребывает в состоянии (kgo:StateSpan и kgo:ExistenceSpan; узлы state/{key})
- key text — Ключ узла: 12 знаков SHA-1. IRI — state/{key}
- name text — Название. RDF: schema:name @ru
- entity text — Чьё состояние — id. RDF: kgo:stateOf
- kind text — Вид: existence… RDF: kgo:spanKind → kgc:statekind/{код}
- span_index integer — Номер промежутка у сущности. RDF: kgo:spanIndex
- started_by text — Событие начала — id. RDF: kgo:startedBy и prov:wasDerivedFrom
- first_attested_by text — Первое событие, где состояние видно. RDF: kgo:firstAttestedBy
- last_attested_by text — Последнее такое событие. RDF: kgo:lastAttestedBy
- from_rank integer — С какого места шкалы времени. RDF: kgo:fromRank
- to_rank integer — По какое место. RDF: kgo:toRank
- внешний ключ: FOREIGN KEY (entity) REFERENCES habr_1097022.entities(id)
- внешний ключ: FOREIGN KEY (started_by) REFERENCES habr_1097022.events(id)

### style_keywords
Выведенный фрейм «Стилометрия» (derived-stylometry): ключевые слова статьи по логарифму правдоподобия (kgo:StyleKeyword, узлы style/{article.style_key}/kw/{key}); профиль стиля — колонки style_… в article
- key text — Ключ узла: 12 знаков SHA-1
- rank integer — Место в списке. RDF: kgo:keywordRank
- lemma text — Слово (лемма). RDF: kgo:keywordLemma @ru
- count integer — Сколько раз в тексте. RDF: kgo:keywordCount
- log_likelihood numeric — Логарифм правдоподобия. RDF: kgo:keywordLogLikelihood

### terms
Выведенный фрейм «Терминология» (derived-terminology): термины словаря техники в тексте (schema:DefinedTerm, узлы term/{slug}) словаря glossary статьи; первое упоминание — в evidence
- slug text — Код термина. IRI — term/{slug}
- name text — Термин. RDF: schema:name @ru
- denotes text — Понятие словаря техники. RDF: kgt:denotes → kgc:tech/{код}
- mention_count integer — Сколько раз в тексте. RDF: kgo:mentionCount

### theme_links
Выведенный фрейм «Темы» (derived-themes): привязка статьи, её тем и понятий к рубрикам тем Story-KG (kgo:ThemeLink, kgo:ThemeLinkTopic; узлы themelink/{key}); субъект получает skos:broadMatch рубрики
- key text — Ключ узла: 12 знаков SHA-1. IRI — themelink/{key}
- name text — Название. RDF: schema:name @ru
- subject text — Что привязано: work, theme/{slug} или id понятия. RDF: kgo:themeSubject и prov:wasDerivedFrom
- theme text — Рубрика тем Story-KG: databases… RDF: kgo:themeValue → kgc:theme/{код}
- matched text — По какому слову найдено. RDF: kgo:themeMatched @ru
- basis text — Основание: name, keyword. RDF: kgo:themeBasis → kgc:themebasis/{код}

### themes
Темы статьи: узлы theme/{slug} (schema:DefinedTerm, skos:Concept) — хабы и темы из спецификации; статья ссылается на них kgo:theme. Привязка к рубрикам тем Story-KG — в theme_links
- slug text — Код темы (транслит названия). IRI — theme/{slug}
- name text — Название. RDF: schema:name и skos:prefLabel @ru
