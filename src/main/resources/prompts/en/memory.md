### arguments
The derived frame "Arguments" (derived-arguments): an argument is a conclusion with premises (kgo:Argument, nodes argument/{key}, part of the article's argument map: schema:isPartOf argument-map)
- key text — Key of the node: 12 characters of SHA-1. IRI argument/{key}
- name text — Name. RDF: schema:name @en
- conclusion text — Conclusion: the id of a claim. RDF: kgo:conclusion
- premises text[] — Premises: ids of claims. RDF: kgo:premise
- premise_role text — Role of the premises. RDF: kgo:premiseRole → kgc:claim/{code}
- foreign key: FOREIGN KEY (conclusion) REFERENCES habr_1097022.claims(id)

### article
Frame 1 "Document": the article (node work: schema:Article, BlogPosting, TechArticle), its source file and the file's state, Habr's counters, the publisher, the author's Habr account, the descriptions of the article's graphs. One row. The style_…, argmap_… and response columns are derived summaries of the article (derived-stylometry, derived-arguments, derived-ratings): the nodes style/{style_key}, argument-map and response named "Text style: {slug}", "Argument map ({slug})", "Response to the article: {title}". The nodes of the tech stack (techstack), the concept vocabulary (terms) and the glossary (glossary) are built by the mapping from the title and the tables entities, concepts, relations, terms
- slug text — The article's name in Story-KG; the IRI space of its nodes is https://example.org/story-kg/id/{slug}/, the article's graph kgg:{slug}
- title text — Title. RDF: schema:name and schema:headline @en
- description text — Abstract. RDF: schema:description @en
- types text[] — Classes of the article (qname). RDF: rdf:type
- post_type text — Publication type on Habr (postType). RDF: schema:additionalType
- genres text[] — Genres. RDF: schema:genre @en, a triple per element
- tags text[] — The author's tags (user_tags). RDF: schema:keywords, twice: as a plain string and as an @en string
- about text[] — Main subjects of the article: ids of entities and concepts. RDF: schema:about
- mentions text[] — People mentioned in the article. RDF: schema:mentions
- author text — Author: the id of an entity. RDF: schema:author; a second schema:author is kge:habr-user/{author_nick}
- published timestamp without time zone — Publication date. RDF: schema:datePublished; also vcard:rev of the author's card
- language text — Language of the text. RDF: schema:inLanguage
- habr_id integer — The article's number on Habr. RDF: schema:identifier (as a string)
- url text — The article's address. RDF: schema:sameAs
- score integer — The article's rating (score). RDF: kgo:score
- reading_count integer — Views (readingCount): the counter work#stat-readingCount, schema:ReadAction. RDF: schema:userInteractionCount
- comments_count integer — Comments (commentsCount): a schema:CommentAction counter
- favorites_count integer — Bookmarks (favoritesCount): a schema:BookmarkAction counter
- votes_count integer — Votes (votesCount): a schema:VoteAction counter
- votes_plus integer — Upvotes (votesCountPlus): a schema:LikeAction counter
- votes_minus integer — Downvotes (votesCountMinus): a schema:DislikeAction counter
- publisher text — Publisher: the global node kge:{publisher} (schema:Organization, kgo:OnlineCommunity). RDF: schema:publisher; in the _global graph, kgo:mentionedInGraph
- publisher_name text — Publisher's name. RDF: schema:name of the publisher's node (as a string)
- publisher_url text — Publisher's site. RDF: schema:url of the publisher and foaf:accountServiceHomepage of the author's account
- author_nick text — The author's nickname on Habr: the nodes kge:habr-user/{nick} (schema:Person, schema:name, schema:alternateName) and kge:habr-account/{nick} (foaf:OnlineAccount, foaf:accountName, sioc:account_of)
- author_score integer — The author's karma (authorScore). RDF: kgo:accountScore of the Habr account
- author_votes integer — Votes for the author's karma (authorVotesCount). RDF: kgo:accountVotesCount
- source_file text — Source file in the corpus: the node src:{file} (schema:MediaObject) with schema:name and schema:identifier; the article refers to it with schema:encoding, the file to the article with schema:encodesCreativeWork
- source_format text — File format. RDF: schema:encodingFormat
- source_bytes integer — File size. RDF: schema:contentSize "{N} bytes"
- source_chars integer — Length of the text in characters. RDF: kgo:charCount
- source_sha256 text — SHA-256 of the file. RDF: kgo:sha256 of the file and of its state src:{file}#state-{12 characters}
- source_date timestamp with time zone — Time of the file version the quote offsets refer to. RDF: oa:sourceDate of the state (oa:TimeState)
- spec_file text — The specification the compiler built the article's graph from. RDF: dcterms:source of the graph kgg:{slug} (default graph, together with prov:wasDerivedFrom and prov:wasGeneratedBy)
- mentions_method text — How the mention index is built. RDF: kgo:extractionMethod of the graph kgg:{slug}-mentions @en (default graph)
- narrative_person text — Derived (derived-narrative): narrative person. RDF: kgo:narrativePersonType → kgc:person/{code}
- narrative_person_basis text — Derived (derived-narrative): the basis of the inference. RDF: kgo:narrativePersonBasis
- like_share numeric — Derived (derived-ratings): share of upvotes among the votes. RDF: kgo:likeShare of the response node; its counters (kgo:viewCount, kgo:likeCount…) are this table's Habr counters (reading_count, votes_plus…)
- comments_per_1000_views numeric — Derived (derived-ratings): comments per 1000 views. RDF: kgo:commentsPerThousandViews
- bookmarks_per_1000_views numeric — Derived (derived-ratings): bookmarks per 1000 views. RDF: kgo:bookmarksPerThousandViews
- style_key text — Derived (derived-stylometry): key of the style profile node style/{key} (kgo:TextStyleProfile)
- style_word_count integer — Derived (derived-stylometry): words. RDF: kgo:styleWordCount
- style_sentence_count integer — Derived (derived-stylometry): sentences. RDF: kgo:styleSentenceCount
- style_paragraph_count integer — Derived (derived-stylometry): paragraphs. RDF: kgo:styleParagraphCount
- style_mean_sentence_length numeric — Derived (derived-stylometry): mean sentence length in words. RDF: kgo:meanSentenceLength
- style_median_sentence_length numeric — Derived (derived-stylometry): median sentence length. RDF: kgo:medianSentenceLength
- style_mean_paragraph_length numeric — Derived (derived-stylometry): mean paragraph length. RDF: kgo:meanParagraphLength
- style_type_token_ratio numeric — Derived (derived-stylometry): share of distinct words. RDF: kgo:typeTokenRatio
- style_hapax_share numeric — Derived (derived-stylometry): share of words met once. RDF: kgo:hapaxShare
- style_function_word_share numeric — Derived (derived-stylometry): share of function words. RDF: kgo:functionWordShare
- argmap_argument_count integer — Derived (derived-arguments): arguments in the argument map. RDF: kgo:argumentCount
- argmap_claim_count integer — Derived (derived-arguments): claims in the map. RDF: kgo:claimCount
- argmap_conflict_count integer — Derived (derived-arguments): objections. RDF: kgo:conflictCount
- argmap_contested_claim_count integer — Derived (derived-arguments): contested claims. RDF: kgo:contestedClaimCount
- argmap_evidence_share numeric — Derived (derived-arguments): share of claims resting on observations. RDF: kgo:evidenceShare
- argmap_depth integer — Derived (derived-arguments): depth of the argument tree. RDF: kgo:maxDepth
- argmap_main_claims text[] — Derived (derived-arguments): main theses. RDF: kgo:mainClaim
- foreign key: FOREIGN KEY (author) REFERENCES habr_1097022.entities(id)

### attitudes
Attitudes (mental states): the attitudes section of the specification: whose, which, toward what (kgo:Attitude)
- id text — id from the specification
- holder text — Whose attitude: an id. RDF: kgo:holder
- type text — Kind: belief, trust… RDF: kgo:attitudeType → kgc:attitude/{code}
- target text — Toward what: a node. RDF: kgo:attitudeTarget
- target_text text — Toward what, in words. RDF: kgo:attitudeTarget @en
- name text — Name. RDF: schema:name @en
- description text — Description. RDF: schema:description @en
- affect_class text — Derived (derived-affect): CognitiveAttitude or AffectiveDisposition (kgo:). RDF: rdf:type
- affect_kind text — Derived (derived-affect): kind of affect. RDF: kgo:affectKind → kgc:affectkind/{code}
- valence text — Derived (derived-emotions): sign. RDF: kgo:valence → kgc:valence/{code}
- outcome_key text — Derived (derived-outcomes): outcome of the attitude outcome/{key} (kgo:AttitudeOutcome): kgo:intention the attitude, kgo:intentionKind "attitude:{type}", schema:name the description
- outcome_event text — Derived (derived-outcomes): the outcome event: an id. RDF: kgo:outcomeEvent
- outcome_status text — Derived (derived-outcomes): status. RDF: kgo:outcomeStatus → kgc:outcome/{code}
- outcome_verdict text — Derived (derived-outcomes): verdict. RDF: kgo:outcomeVerdict → kgc:outcome/{code}
- foreign key: FOREIGN KEY (holder) REFERENCES habr_1097022.entities(id)
- foreign key: FOREIGN KEY (outcome_event) REFERENCES habr_1097022.events(id)

### claims
Claims: the claims section of the specification: theses, arguments, examples, limitations (schema:Claim). Derived arguments and objections are in arguments and conflicts
- id text — id from the specification
- text text — Text of the claim. RDF: schema:text @en
- role text — Role in the reasoning: thesis, argument, example, counterexample, opinion, criticism, limitation… RDF: kgo:claimRole → kgc:claim/{code}
- zone text — Rhetorical zone: problem, method, result, discussion, limitation, conclusion. RDF: kgo:rhetoricalZone → kgc:rhetoricalzone/{code}
- author text — Whose claim, if not the author's: an id. RDF: schema:author
- supports text[] — Which claims it supports. RDF: kgo:supports
- attacks text[] — Which claims it refutes. RDF: kgo:attacks
- about text[] — What it is about: ids of entities, concepts, observations. RDF: schema:about
- foreign key: FOREIGN KEY (author) REFERENCES habr_1097022.entities(id)

### code_listings
The derived frame "Code" (derived-code): the article's code blocks (schema:SoftwareSourceCode, nodes code/{n} with the text span code/{n}#span) and the process step they show
- n integer — Number of the code block in the article. IRI code/{n}
- name text — Name. RDF: schema:name @en
- language text — Language. RDF: schema:programmingLanguage
- line_count integer — Lines. RDF: kgo:codeLineCount
- section text — Section. RDF: schema:isPartOf
- process text — Process of the step: an id
- step text — The step the code shows. RDF: kgo:codeOfStep; for the step, kgo:stepCode
- step_basis text — How the step was found. RDF: kgo:stepCodeBasis
- start_pos integer — Start of the block in characters of the text. RDF: oa:start
- end_pos integer — End of the block in characters of the text. RDF: oa:end
- foreign key: FOREIGN KEY (process, step) REFERENCES habr_1097022.process_steps(process, step)
- foreign key: FOREIGN KEY (section) REFERENCES habr_1097022.sections(id)

### concept_links
The derived frame "Concept links" (derived-conceptlinks): a concept of the article and a global concept are synonyms (kgo:ConceptLink and kgo:ConceptLink{Kind}, rdf:Statement; nodes conceptlink/{key}); kgo:conceptSynonymOf in both directions
- key text — Key of the node: 12 characters of SHA-1. IRI conceptlink/{key}
- name text — Name. RDF: schema:name @en
- concept text — Concept of the article: an id. RDF: rdf:subject
- global text — The global concept kge:{global}. RDF: rdf:object
- kind text — Kind of link: synonym… RDF: kgo:conceptLinkKind → kgc:conceptlink/{code}
- basis text — Basis. RDF: kgo:conceptLinkBasis
- cue text — The rule's cue. RDF: kgo:conceptLinkCue
- confidence numeric — Confidence. RDF: kgo:confidence
- method text — Method. RDF: kgo:extractionMethod
- foreign key: FOREIGN KEY (concept) REFERENCES habr_1097022.concepts(id)

### concepts
Frame 9 "Concepts": the concepts section of the specification: mechanisms, methods, data structures, phenomena (schema:DefinedTerm, skos:Concept) of the article's concept vocabulary terms (skos:inScheme, schema:inDefinedTermSet). Differences and parts are in the table relations, the contributions of methods to qualities in contributions
- id text — id from the specification; IRI https://example.org/story-kg/id/habr-1097022/{id}
- name text — Name. RDF: schema:name and skos:prefLabel @en
- alt_names text[] — Other names. RDF: skos:altLabel @en
- kind text — Kind of concept: mechanism, technique, component, datastructure, variant, phenomenon… RDF: kgo:conceptKind → kgc:conceptkind/{code}
- definition text — Definition. RDF: skos:definition and schema:description @en
- description text — Explanation. RDF: schema:description @en
- global text — A global Story-KG concept. RDF: skos:exactMatch kge:{global}; in the _global graph, kgo:mentionedInGraph
- broader text[] — Broader concepts. RDF: skos:broader
- narrower text[] — Narrower concepts. RDF: skos:narrower
- related text[] — Related concepts. RDF: skos:related
- counter_measures text[] — What counters the phenomenon. RDF: kgo:counterMeasure
- procedure text — The method's procedure: the id of a process. RDF: kgo:hasProcedure
- goal text — The method's goal. RDF: kgo:methodGoal @en
- arises_when text — When the phenomenon arises. RDF: kgo:arisesWhen @en
- manifestation text — How the phenomenon shows itself. RDF: kgo:manifestation @en
- mechanism text — The mechanism of the phenomenon. RDF: kgo:phenomenonMechanismText @en
- mention_count integer — How many times it is named in the text. RDF: kgo:mentionCount, in the mention graph
- stack_role text — Derived (derived-techstack): role in the article's tech stack. RDF: kgo:techRole → kgc:techrole/{code}
- extraction_basis text — Derived (derived-provenance): basis of the extraction. RDF: kgo:extractionBasis → kgc:basis/{code}
- definition_key text — Derived (derived-definitions): key of the node definition/{key} (kgo:Definition: kgo:defines the concept, kgo:definiendum the name, kgo:definiens the definition, kgo:definitionPattern "concept")
- problem_key text — Derived (derived-problems): key of the node problem/{key} (kgo:Phenomenon: kgo:phenomenonConcept the concept, schema:name the name)
- foreign key: FOREIGN KEY (procedure) REFERENCES habr_1097022.processes(id)

### conflicts
The derived frames "Arguments" and "Credibility" (derived-arguments, derived-credibility): an objection is a claim refuting another (kgo:Conflict, conflict/{key}), and the assessment of the refuted one (schema:ClaimReview, review/{key})
- key text — Key of both nodes: 12 characters of SHA-1
- attacked text — The refuted claim: an id. RDF: kgo:conflictedClaim; for the assessment, schema:itemReviewed
- attacker text — The refuting claim: an id. RDF: kgo:conflictingClaim; for the assessment, kgo:reviewingClaim
- rebutted boolean — The objection is rebutted. RDF: kgo:attackRebutted
- verdict text — Verdict of the assessment: disputed… RDF: kgo:verdict → kgc:verdict/{code}, graph derived-credibility
- name text — Name of the objection. RDF: schema:name @en
- review_name text — Name of the assessment. RDF: schema:name @en, graph derived-credibility
- foreign key: FOREIGN KEY (attacked) REFERENCES habr_1097022.claims(id)
- foreign key: FOREIGN KEY (attacker) REFERENCES habr_1097022.claims(id)

### contributions
A method's contribution to a quality (kgo:Contribution, nodes contribution/{key}): from the concept's benefits field. The concept refers to the contribution with kgo:benefit; schema:name is "{name of the concept}: {effect}"
- key text — Key of the node: 12 characters of SHA-1. IRI contribution/{key}
- concept text — The method: the id of a concept. RDF: kgo:contributionOf
- type text — help helps, hurt hinders. RDF: kgo:contributionType → kgc:contribution/{code}
- effect_kind text — benefit or cost. RDF: kgo:effectKind → kgc:effectkind/{code}
- effect text — What the method gives. RDF: kgo:effectText @en
- quality text — ISO/IEC 25010 quality attribute: time_behaviour, resource_utilization… RDF: kgo:qualityAttribute → kgc:quality/{code}
- foreign key: FOREIGN KEY (concept) REFERENCES habr_1097022.concepts(id)

### copresence
The derived frame "Co-presence" (derived-copresence): who meets whom in the text (kgo:CoPresence, kgo:PersonCoPresence; nodes copresence/{key}); the people get kgo:coPresentWith
- key text — Key of the node: 12 characters of SHA-1. IRI copresence/{key}
- name text — Name. RDF: schema:name @en
- persons text[] — Who: ids. RDF: kgo:coPresent
- talks text[] — In which replies together: ids. RDF: kgo:coPresentInTalk and prov:wasDerivedFrom
- talk_count integer — Replies. RDF: kgo:coPresentTalkCount
- kind text — Kind. RDF: kgo:coPresenceKind → kgc:copresencekind/{code}
- basis text — Basis: conversation… RDF: kgo:coPresenceBasis → kgc:copresencebasis/{code}

### datasets
The derived frame "Experiments" (derived-experiments): observations of one quantity make a set of measurements (qb:DataSet, kgo:MeasurementSet; a comparison is kgo:Experiment, kgo:Benchmark). Node {id}; the observations refer to it with qb:dataSet, it to them with prov:wasDerivedFrom
- id text — id from the dataset field of the specification
- types text[] — Classes (qname). RDF: rdf:type
- name text — Name. RDF: schema:name @en
- measure text — The measured quantity. RDF: kgo:measureLabel @en
- condition text — Context of the set. RDF: kgo:conditionText @en
- units text[] — Units. RDF: schema:unitText
- series_kind text — What varies: comparison (the object), conditions (a condition), timeline (the date). RDF: kgo:seriesKind → kgc:series/{code}
- subjects text[] — What is tested: ids. RDF: kgo:subjectUnderTest
- section text — Section of the article. RDF: kgo:contextSection
- observation_count integer — Observations in the set. RDF: kgo:observationCount
- best_observation text — The best observation: an id. RDF: kgo:bestObservation
- better_is text — Which is better: lower or higher. RDF: kgo:betterIs
- foreign key: FOREIGN KEY (best_observation) REFERENCES habr_1097022.observations(id)
- foreign key: FOREIGN KEY (section) REFERENCES habr_1097022.sections(id)

### dialogues
The derived frame "Dialogue" (derived-dialogue): consecutive replies of a section with alternating speakers (kgo:Dialogue, nodes dialogue/{key}); the replies refer to the dialogue with kgo:inDialogue, it to them with prov:wasDerivedFrom
- key text — Key of the node: 12 characters of SHA-1. IRI dialogue/{key}
- name text — Name. RDF: schema:name @en
- section text — Section. RDF: kgo:contextSection
- participants text[] — Participants: ids. RDF: kgo:dialogueParticipant
- turn_count integer — Turns. RDF: kgo:turnCount
- foreign key: FOREIGN KEY (section) REFERENCES habr_1097022.sections(id)

### discourse_relations
The derived frame "Discourse relations" (derived-discourse): a connective linking two parts of the text, a reason or a result (kgo:DiscourseRelation and kgo:Discourse{Sense}, nodes discourse/{key})
- key text — Key of the node: 12 characters of SHA-1. IRI discourse/{key}
- name text — Name. RDF: schema:name @en
- sense text — Sense of the relation: result, reason… RDF: kgo:discourseSense → kgc:discourserelation/{code}
- connective text — Connective, translated into English: therefore, because… RDF: kgo:discourseConnective @en
- scope text — Within a sentence or between sentences. RDF: kgo:discourseScope → kgc:discoursescope/{code}
- section text — Section. RDF: schema:isPartOf and prov:wasDerivedFrom
- arg1_claim text — Claim of the first part: an id. RDF: kgo:discourseArg1Claim
- arg1_start integer — Start of the first part. RDF: kgo:discourseArg1Start
- arg1_end integer — End of the first part. RDF: kgo:discourseArg1End
- arg2_claim text — Claim of the second part: an id. RDF: kgo:discourseArg2Claim
- arg2_start integer — Start of the second part. RDF: kgo:discourseArg2Start
- arg2_end integer — End of the second part. RDF: kgo:discourseArg2End
- foreign key: FOREIGN KEY (arg1_claim) REFERENCES habr_1097022.claims(id)
- foreign key: FOREIGN KEY (arg2_claim) REFERENCES habr_1097022.claims(id)
- foreign key: FOREIGN KEY (section) REFERENCES habr_1097022.sections(id)

### entities
Frames 5, 6, 8 "People, organizations, things": the entities section of the specification: people, programs, libraries, articles, organizations. The links between them are in the table relations
- id text — id from the specification; IRI https://example.org/story-kg/id/habr-1097022/{id}
- types text[] — Classes (qname): schema:Person, schema:SoftwareApplication… RDF: rdf:type
- name text — Name. RDF: schema:name @en
- alt_names text[] — Other names. RDF: schema:alternateName @en
- hidden_labels text[] — Spellings for search (postgres, clickhouse). RDF: skos:hiddenLabel @en
- description text — Description. RDF: schema:description @en
- roles text[] — Role in the text: author, narrator, protagonist, major. RDF: kgo:characterRole → kgc:role/{code}
- global text — A global Story-KG node shared by all texts. RDF: owl:sameAs kge:{global}; in the _global graph, kge:{global} kgo:mentionedInGraph kgg:habr-1097022
- same_as text — Another external node of the same object. RDF: owl:sameAs kge:{same_as}
- tech_role text — Role in technology: database, framework_library… RDF: kgo:techRole → kgc:techrole/{code}
- discourse_position integer — Position in the story: the offset of the first mention. RDF: kgo:discoursePosition
- sensitivity text — Sensitivity of the information: personal. RDF: kgo:sensitivity → kgc:sensitivity/{code}
- url text — Address. RDF: schema:url
- code_repository text — Source code repository. RDF: schema:codeRepository
- author text — Author of the work or code: an id. RDF: schema:author
- about text[] — What the work is about: an id. RDF: schema:about
- contacts_sensitivity text — There is a contact card {id}#vcard (vcard:Individual: vcard:fn the name, vcard:rev the date of the article); the value is its kgo:sensitivity. The person refers to the card with kgo:contactCard
- account_service text — The account {id}#account-{service}_{name} (foaf:OnlineAccount, sioc:UserAccount): the service. RDF: schema:description @en; the person refers to the account with foaf:account
- account_name text — Account name. RDF: foaf:accountName
- account_service_url text — The service's site. RDF: foaf:accountServiceHomepage
- account_url text — Address of the account. RDF: schema:url
- mention_count integer — How many times it is named in the text. RDF: kgo:mentionCount, in the mention graph
- stack_role text — Derived (derived-techstack): role in the article's tech stack. RDF: kgo:techRole; the stack refers to the node with kgo:stackComponent
- foreign key: FOREIGN KEY (author) REFERENCES habr_1097022.entities(id)

### events
Frames 13–14 "Events": the events section of the specification: schema.org events and actions with ESO classes
- id text — id from the specification
- types text[] — Classes (qname): schema:Event, schema:AssessAction, eso:Creating… RDF: rdf:type
- name text — Name. RDF: schema:name @en
- description text — Description. RDF: schema:description @en
- frame text — FrameNet frame from the specification. RDF: kgo:frame → fn:{frame}
- agent text — Who acts. RDF: schema:agent
- object text — On what. RDF: schema:object
- instrument text — With what. RDF: schema:instrument
- date_text text — Date in words from the text. RDF: kgo:dateText @en
- factuality text — Factuality: actual… RDF: kgo:factuality → kgc:factuality/{code}
- precedes text[] — Which events follow. RDF: kgo:precedes
- causes text[] — Which events it causes. RDF: kgo:causes
- caused_by text — Which event it is a consequence of. RDF: kgo:causedBy
- motivated_by text — What prompted it: an id. RDF: kgo:motivatedBy
- discourse_position integer — Position in the story: the offset of the first mention. RDF: kgo:discoursePosition
- creates text — What is created (ESO Creating). RDF: eso:creating-theme; the situations before and after are nodes and graphs kgg:situation/habr-1097022/{id}#pre|#post (eso:Situation, kgo:situationOf) with eso:exist false and true
- timeline_rank integer — Derived (derived-states): place on the timeline. RDF: kgo:timelineRank
- lifecycle_stage text — Derived (derived-creations): life-cycle stage. RDF: kgo:lifecycleStage → kgc:creationstage/{code}
- fn_frame text — Derived (derived-framenet): FrameNet frame by the ESO class. RDF: kgo:frame → fn:{frame}
- fn_frame_choice text — Derived (derived-framenet): how the frame was chosen. RDF: kgo:frameChoice → kgc:framechoice/{code}
- fn_frame_match text — Derived (derived-framenet): precision of the match. RDF: kgo:frameMatch → kgc:framematch/{code}
- fn_frame_mapping text — Derived (derived-framenet): the ESO to FrameNet mapping. RDF: kgo:frameMapping → kge:{…}
- fn_roles jsonb — Derived (derived-framenet): frame elements {"{role}": "{id}"}. RDF: fe:{role} {id}
- dialog_act text — Derived (derived-dialogue): the event is a speech act (kgo:CommunicationEvent) with a function. RDF: kgo:communicativeFunction → kgc:dialogact/{code}
- speaker text — Derived (derived-dialogue): the speaker. RDF: kgo:speaker
- foreign key: FOREIGN KEY (agent) REFERENCES habr_1097022.entities(id)
- foreign key: FOREIGN KEY (speaker) REFERENCES habr_1097022.entities(id)

### evidence
Frame 3 "Anchoring in the text" (W3C Web Annotation): a quote of the article a node rests on. A row is the annotation anno/{key} (oa:Annotation); its target (oa:SpecificResource with oa:hasSource and oa:hasState) and the selectors of the quote (oa:TextQuoteSelector) and of the position (oa:TextPositionSelector) are blank nodes the mapping builds. The first mentions (mention graph) and the quotes of derived frames are here too. The quotes are verbatim text of the article, in Russian. The path in the graph from the annotation: oa:hasBody, the node; oa:hasTarget → kgo:line, kgo:inSection; oa:hasTarget → oa:hasSelector → oa:exact, oa:prefix, oa:suffix (the quote selector) and oa:start, oa:end (the position selector)
- key text — Key of the annotation: 12 characters of SHA-1; first-… is a first mention, d-… a quote of a derived frame. IRI anno/{key}
- about text — The node the quote supports: an id or a path (rel/…, theme/…, definition/…). RDF: oa:hasBody
- graph text — Graph of the annotation: habr-1097022, habr-1097022-mentions or derived-…
- motivation text — Purpose of the quote: describing, classifying, identifying, linking. RDF: oa:motivatedBy → oa:{code}
- first_mention boolean — First mention of the node in the text. RDF: kgo:firstMention of the node about
- comment text — Note on the quote. RDF: rdfs:comment @en
- section text — Section of the quote. RDF: kgo:inSection of the annotation's target (oa:hasTarget → kgo:inSection)
- line integer — Line of the source file. RDF: kgo:line of the annotation's target (oa:hasTarget → kgo:line)
- quote text — The quote, verbatim (in the language of the article). RDF: oa:exact of the quote selector (oa:hasTarget → oa:hasSelector → oa:exact)
- prefix text — Text before the quote. RDF: oa:prefix of the quote selector (oa:hasTarget → oa:hasSelector → oa:prefix)
- suffix text — Text after the quote. RDF: oa:suffix of the quote selector (oa:hasTarget → oa:hasSelector → oa:suffix)
- start_pos integer — Start of the quote in characters of the text. RDF: oa:start of the position selector (oa:hasTarget → oa:hasSelector → oa:start; xsd:nonNegativeInteger)
- end_pos integer — End of the quote in characters of the text. RDF: oa:end of the position selector (oa:hasTarget → oa:hasSelector → oa:end)
- foreign key: FOREIGN KEY (section) REFERENCES habr_1097022.sections(id)

### hubs
Habr hubs the article is published in: the nodes kge:habr-hub/{slug} (skos:Concept of the scheme kge:habr-hubs). The article refers to them with kgo:hub
- slug text — Code of the hub in Story-KG (a transliteration of the name)
- name text — Name of the hub. RDF: skos:prefLabel @en
- views_rank integer — Derived (derived-ratings): the article's place in the hub's ranking by views. RDF: schema:position of the list item kge:habr-hub/{slug}#by-views
- views_rank_key text — Derived (derived-ratings): key of the list item response#hub-{key} (schema:ListItem); the response refers to it with kgo:hubPosition

### idea_links
The derived frame "Ideas" (derived-ideas): who is the author of an idea, a work or code (kgo:IdeaLink and kgo:Idea{Kind}, nodes idea/{key}); the object gets prov:qualifiedAttribution and prov:wasAttributedTo
- key text — Key of the node: 12 characters of SHA-1. IRI idea/{key}
- name text — Name. RDF: schema:name @en
- object text — Idea, work, code: an id. RDF: kgo:ideaObject and prov:wasDerivedFrom
- person text — Whose: an id. RDF: kgo:ideaPerson and prov:agent
- kind text — Kind of link: origin… RDF: kgo:ideaKind → kgc:ideakind/{code}
- role text — The person's role: authored… RDF: kgo:ideaRole and prov:hadRole → kgc:idearole/{code}
- stance text — How the text speaks of the idea: cites… RDF: kgo:ideaStance → kgc:ideastance/{code}
- year integer — Year. RDF: kgo:ideaYear (xsd:gYear)
- basis text — Basis. RDF: kgo:ideaBasis → kgc:ideabasis/{code}
- foreign key: FOREIGN KEY (person) REFERENCES habr_1097022.entities(id)

### media
The derived frame "Links and media" (derived-media): the article's links (link/{key}: repositories, articles; kgo:linkedFrom the article) and pictures (image/{key}; schema:isPartOf the article)
- kind text — link or image, the first part of the IRI
- key text — Key of the node: 12 characters of SHA-1
- types text[] — Classes (qname). RDF: rdf:type
- name text — Text of the link. RDF: schema:name @en
- url text — Address. RDF: schema:url; for a picture, schema:contentUrl
- link_kind text — Kind of link: repository, article… RDF: kgo:linkKind → kgc:link/{code}
- section text — Section. RDF: kgo:contextSection
- foreign key: FOREIGN KEY (section) REFERENCES habr_1097022.sections(id)

### methods
The derived frame "Methods" (derived-methods, derived-contributions): a method card (kgo:Method, method/{key}) from a concept of the kind "method" or from a process without such a concept; the method's benefit (kgo:benefit) comes from the contributions of its concept
- key text — Key of the node: 12 characters of SHA-1. IRI method/{key}
- name text — Name. RDF: schema:name @en
- concept text — Concept of the method: an id. RDF: kgo:methodConcept
- procedure text — Procedure: the id of a process. RDF: kgo:hasProcedure
- kind text — Kind. RDF: kgo:methodKind → kgc:conceptkind/{code}
- confidence numeric — Confidence of the rule. RDF: kgo:confidence
- section text — Section. RDF: kgo:contextSection
- foreign key: FOREIGN KEY (concept) REFERENCES habr_1097022.concepts(id)
- foreign key: FOREIGN KEY (procedure) REFERENCES habr_1097022.processes(id)
- foreign key: FOREIGN KEY (section) REFERENCES habr_1097022.sections(id)

### narratives
Embedded narratives: the narratives section of the specification (kgo:EmbeddedNarrative); here the frame of the article, the author's dispute with his architect friend. The columns of the inset story are the derived frame derived-insets
- id text — id from the specification
- name text — Name. RDF: schema:name @en
- description text — Description. RDF: schema:description @en
- type text — Kind of narrative: anecdote… RDF: kgo:narrativeType → kgc:narrative/{code}
- factuality text — Factuality. RDF: kgo:factuality → kgc:factuality/{code}
- told_by text — Narrator: an id. RDF: kgo:toldBy
- characters text[] — Characters: ids. RDF: schema:character
- moral text — Moral: the id of a claim. RDF: kgo:moral
- level integer — Nesting level. RDF: kgo:narrativeLevel
- span_start integer — Start of the narrative in characters of the text. RDF: oa:start of the selector of the span kgo:textSpan
- span_end integer — End of the narrative in characters of the text. RDF: oa:end
- inset_class text — Derived (derived-insets): class of the inset story: InsetAnecdote… RDF: rdf:type kgo:Inset and kgo:{class}
- diegetic_level integer — Derived (derived-insets): Genette's narrative level. RDF: kgo:diegeticLevel
- diegetic_level_kind text — Derived (derived-insets): RDF: kgo:diegeticLevelKind → kgc:diegeticlevel/{code}
- audience_kind text — Derived (derived-insets): whom it is told to. RDF: kgo:insetAudienceKind → kgc:insetaudience/{code}
- narrator_kind text — Derived (derived-insets): who tells it. RDF: kgo:insetNarratorKind → kgc:insetnarrator/{code}
- narrator_basis text — Derived (derived-insets): how the narrator was found. RDF: kgo:insetNarratorBasis → kgc:insetbasis/{code}
- purpose text — Derived (derived-insets): what the story is for. RDF: kgo:insetPurpose → kgc:insetpurpose/{code}
- foreign key: FOREIGN KEY (moral) REFERENCES habr_1097022.claims(id)
- foreign key: FOREIGN KEY (told_by) REFERENCES habr_1097022.entities(id)

### observations
Observations and measurements: the observations section of the specification, the numbers of the article (schema:Observation, schema:QuantitativeValue): what, how much, in what, under which conditions. The derived columns are units and quantities (derived-quantities)
- id text — id from the specification
- variable text — What is measured. RDF: schema:variableMeasured and schema:name @en
- value numeric — The number. RDF: schema:value, xsd:integer for integers, xsd:double for fractions
- value_range text — A range value as in the text ("51-86"). RDF: schema:value @en
- unit text — The unit as in the text: ms, s, %, times. RDF: schema:unitText @en
- condition text — Conditions: system, planner, storage, query. RDF: kgo:conditionText @en
- dataset text — Set of measurements: the id from the dataset field of the specification; the set's card is in datasets (a set of a single observation has none, so there is no foreign key). RDF: qb:dataSet in the article's graph and in derived-experiments (where rdf:type qb:Observation is too)
- about text[] — What it is about: an id. RDF: schema:observationAbout
- unit_code text — Derived (derived-quantities): the unit from the vocabulary: millisecond, percent… RDF: kgo:unit → kgc:unit/{code}
- quantity_kind text — Derived (derived-quantities): kind of quantity: time, ratio… RDF: kgo:quantityKind → kgc:quantitykind/{code}
- base_unit text — Derived (derived-quantities): base unit. RDF: kgo:baseUnit → kgc:unit/{code}
- value_in_base_unit numeric — Derived (derived-quantities): value in the base unit. RDF: kgo:valueInBaseUnit
- min_value numeric — Derived (derived-quantities): lower bound of the range. RDF: schema:minValue
- max_value numeric — Derived (derived-quantities): upper bound of the range. RDF: schema:maxValue
- min_in_base_unit numeric — Derived (derived-quantities): lower bound in the base unit. RDF: kgo:minValueInBaseUnit
- max_in_base_unit numeric — Derived (derived-quantities): upper bound in the base unit. RDF: kgo:maxValueInBaseUnit
- carriers text[] — Derived (derived-quantities): carriers of the quantity: ids. RDF: kgo:carrier
- carrier_basis text — Derived (derived-quantities): by which field the carriers were found. RDF: kgo:carrierBasis
- observed_property text — Derived (derived-quantities): the measured property: an id. RDF: kgo:observedProperty
- property_basis text — Derived (derived-quantities): how the property was found. RDF: kgo:propertyBasis
- count_noun text — Derived (derived-quantities): what is counted. RDF: kgo:countNoun @en

### passages
The derived frame "Passages" (derived-passages): part of a section in one mode of discourse (kgo:Passage, kgo:ModePassage; nodes passage/{key})
- key text — Key of the node: 12 characters of SHA-1. IRI passage/{key}
- section text — Section. RDF: kgo:passageSection and prov:wasDerivedFrom
- mode text — Mode of discourse. RDF: kgo:discourseMode → kgc:discoursemode/{code}
- blocks integer — Paragraphs. RDF: kgo:passageBlocks
- chars integer — Characters. RDF: kgo:passageChars
- foreign key: FOREIGN KEY (section) REFERENCES habr_1097022.sections(id)

### process_flows
Transitions between steps: nodes {process}.flow{n} (bbo:SequenceFlow; with a condition, bbo:ConditionalSequenceFlow and the condition {process}.flow{n}-cond, bbo:ConditionExpression)
- process text — Process: an id. RDF: bbo:has_container
- n integer — Number of the transition in the process; IRI {process}.flow{n}
- source text — From where: the code of a step. RDF: bbo:has_sourceRef
- target text — To where: the code of a step. RDF: bbo:has_targetRef
- condition text — Condition of the transition out of a gateway. RDF: rdfs:label @en of the condition node
- foreign key: FOREIGN KEY (process, source) REFERENCES habr_1097022.process_steps(process, step)
- foreign key: FOREIGN KEY (process, target) REFERENCES habr_1097022.process_steps(process, step)

### process_steps
Steps of a BBO process: nodes {process}.{step} (bbo:StartEvent, Task, ServiceTask, ExclusiveGateway, EndEvent) in the process (bbo:has_container). The mapping takes the neighbours (bbo:has_incoming, has_outgoing, has_previousFlowNode, has_nextFlowNode) from process_flows
- process text — Process: an id
- step text — Code of the step in the process (s0, t1, g1, e1); IRI {process}.{step}
- type text — Class of the step: StartEvent, Task, ServiceTask, ExclusiveGateway, EndEvent (bbo:)
- name text — Name. RDF: bbo:name (as a string) and schema:name @en
- uses_tool text[] — What performs the step: an id. RDF: kgo:usesTool
- stack_tools text[] — Derived (derived-techstack): components of the stack at the step. RDF: kgo:usesTool
- foreign key: FOREIGN KEY (process) REFERENCES habr_1097022.processes(id)

### processes
Frame 21 "Processes" (BBO): the processes section of the specification: a process (bbo:Process); its steps are in process_steps, its transitions in process_flows; the mapping takes bbo:has_flowElements from them
- id text — id from the specification
- name text — Name. RDF: bbo:name (as a string) and schema:name @en
- applies_to text — What it applies to: an id. RDF: kgo:appliesTo
- precondition text — Precondition. RDF: kgo:precondition @en
- result text — Result. RDF: kgo:processResult @en
- process_kind text — Derived (derived-origins): kind of process. RDF: kgo:processKind → kgc:processkind/{code}
- foreign key: FOREIGN KEY (applies_to) REFERENCES habr_1097022.entities(id)

### quotations
Frame 24 "Speech": the replies of the author's dispute with his architect friend (schema:Quotation, part of the article: schema:isPartOf)
- id text — id of the reply: rep01…
- speaker text — Who speaks: an id. RDF: schema:creator and schema:spokenByCharacter
- addressees text[] — To whom: an id. RDF: kgo:addressee
- speech_act text — Speech act: question, directive, assertive, expressive, commissive. RDF: kgo:speechAct → kgc:speechact/{code}
- stance text — The speaker's stance: disagree, agree, irony. RDF: kgo:stance → kgc:stance/{code}
- stance_target text — Which reply the stance is toward. RDF: kgo:stanceTarget
- text text — The reply, translated into English (the original wording is quoted in evidence). RDF: schema:text @en
- description text — The role of the reply in the dispute. RDF: schema:description @en
- about text[] — What the reply is about: ids of the technical layer. RDF: schema:about
- dialogue text — Derived (derived-dialogue): the dialogue, a key. RDF: kgo:inDialogue
- turn_index integer — Derived (derived-dialogue): number of the turn in the dialogue. RDF: kgo:turnIndex
- responds_to text — Derived (derived-dialogue): which reply it responds to. RDF: kgo:respondsTo
- answers text — Derived (derived-dialogue): which question it answers. RDF: kgo:answers
- foreign key: FOREIGN KEY (answers) REFERENCES habr_1097022.quotations(id)
- foreign key: FOREIGN KEY (dialogue) REFERENCES habr_1097022.dialogues(key)
- foreign key: FOREIGN KEY (responds_to) REFERENCES habr_1097022.quotations(id)
- foreign key: FOREIGN KEY (speaker) REFERENCES habr_1097022.entities(id)
- foreign key: FOREIGN KEY (stance_target) REFERENCES habr_1097022.quotations(id)

### relations
Frame 11 "Relations": an n-ary node rel/{key} (kgo:Relationship, rdf:Statement): who, which property, with whom, label, difference. The mapping builds the direct triple "subject predicate object"; kgo:differsFrom and kgo:integratesWith in both directions
- key text — Key of the node: 12 characters of SHA-1. IRI rel/{key}
- subject text — Who: an id. RDF: rdf:subject
- predicate text — Property (qname): kgo:usesTool, kgo:implements, kgo:integratesWith, kgo:differsFrom, schema:isPartOf, schema:isBasedOn. RDF: rdf:predicate
- object text — With whom: an id. RDF: rdf:object
- label text — Label. RDF: kgo:relationLabel @en
- feature text — How they differ (for kgo:differsFrom). RDF: kgo:distinguishingFeature @en
- in_stack boolean — Derived (derived-techstack): the relation belongs to the article's tech stack. RDF: kgo:stackRelation and prov:wasDerivedFrom of the node techstack

### sections
Frame 2 "Text structure": the header (fm), the introduction (body) and the sections s1…s5, nodes sec/{id} with the text span sec/{id}#span (oa:SpecificResource and oa:TextPositionSelector sec/{id}#span-selector)
- id text — Section code. RDF: kgo:sectionId; IRI sec/{id}
- kind text — Section class: Section or FrontMatter (kgo:)
- name text — Heading. RDF: schema:name @en
- level integer — Heading level. RDF: kgo:level
- line integer — Starting line in the source file. RDF: kgo:line
- parent text — Enclosing section; empty means the whole article (work). RDF: schema:isPartOf
- start_pos integer — Start of the section in characters of the text. RDF: oa:start (xsd:nonNegativeInteger)
- end_pos integer — End of the section in characters of the text. RDF: oa:end
- mentions text[] — Entities and concepts named in the section. RDF: schema:mentions, in the mention graph kgg:habr-1097022-mentions
- main_claim text — Derived (derived-passages): main thesis of the section. RDF: kgo:mainClaim
- main_claim_supports integer — Derived (derived-passages): how many arguments support it. RDF: kgo:mainClaimSupports
- terms text[] — Derived (derived-terminology): terms mentioned in the section. RDF: schema:mentions term/{slug}
- foreign key: FOREIGN KEY (main_claim) REFERENCES habr_1097022.claims(id)
- foreign key: FOREIGN KEY (parent) REFERENCES habr_1097022.sections(id)

### state_spans
The derived frame "States" (derived-states): a stretch of the story in which an entity exists or is in a state (kgo:StateSpan and kgo:ExistenceSpan; nodes state/{key})
- key text — Key of the node: 12 characters of SHA-1. IRI state/{key}
- name text — Name. RDF: schema:name @en
- entity text — Whose state: an id. RDF: kgo:stateOf
- kind text — Kind: existence… RDF: kgo:spanKind → kgc:statekind/{code}
- span_index integer — Number of the stretch for the entity. RDF: kgo:spanIndex
- started_by text — The starting event: an id. RDF: kgo:startedBy and prov:wasDerivedFrom
- first_attested_by text — The first event where the state is visible. RDF: kgo:firstAttestedBy
- last_attested_by text — The last such event. RDF: kgo:lastAttestedBy
- from_rank integer — From which place on the timeline. RDF: kgo:fromRank
- to_rank integer — Up to which place. RDF: kgo:toRank
- foreign key: FOREIGN KEY (entity) REFERENCES habr_1097022.entities(id)
- foreign key: FOREIGN KEY (started_by) REFERENCES habr_1097022.events(id)

### style_keywords
The derived frame "Stylometry" (derived-stylometry): keywords of the article by log-likelihood (kgo:StyleKeyword, nodes style/{article.style_key}/kw/{key}); the style profile is the style_… columns of article
- key text — Key of the node: 12 characters of SHA-1
- rank integer — Place in the list. RDF: kgo:keywordRank
- lemma text — The word (lemma), translated into English. RDF: kgo:keywordLemma @en
- count integer — How many times in the text. RDF: kgo:keywordCount
- log_likelihood numeric — Log-likelihood. RDF: kgo:keywordLogLikelihood

### terms
The derived frame "Terminology" (derived-terminology): terms of the technology vocabulary in the text (schema:DefinedTerm, nodes term/{slug}) of the article's glossary; the first mention is in evidence
- slug text — Code of the term. IRI term/{slug}
- name text — Term. RDF: schema:name @en
- denotes text — Concept of the technology vocabulary. RDF: kgt:denotes → kgc:tech/{code}
- mention_count integer — How many times in the text. RDF: kgo:mentionCount

### theme_links
The derived frame "Themes" (derived-themes): binding of the article, its themes and concepts to Story-KG's theme headings (kgo:ThemeLink, kgo:ThemeLinkTopic; nodes themelink/{key}); the subject gets skos:broadMatch of the heading
- key text — Key of the node: 12 characters of SHA-1. IRI themelink/{key}
- name text — Name. RDF: schema:name @en
- subject text — What is bound: work, theme/{slug} or the id of a concept. RDF: kgo:themeSubject and prov:wasDerivedFrom
- theme text — Story-KG theme heading: databases… RDF: kgo:themeValue → kgc:theme/{code}
- matched text — The word it was found by, translated into English. RDF: kgo:themeMatched @en
- basis text — Basis: name, keyword. RDF: kgo:themeBasis → kgc:themebasis/{code}

### themes
Themes of the article: nodes theme/{slug} (schema:DefinedTerm, skos:Concept), the hubs and the themes from the specification; the article refers to them with kgo:theme. The binding to Story-KG's theme headings is in theme_links
- slug text — Code of the theme (a transliteration of the name). IRI theme/{slug}
- name text — Name. RDF: schema:name and skos:prefLabel @en
