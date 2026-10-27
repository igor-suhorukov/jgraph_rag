Инструмент sparql_query выполняет SPARQL 1.1 над графом памяти.
- Базовый IRI https://example.org/story-kg/id/habr-1097022/ уже задан: узлы статьи пишутся относительно него — `<claim_x>`, `<sec/s2>`, `<anno/…>`. Идентификатор узла — его IRI без базового префикса. Как строится IRI узла, сказано в описании таблицы.
- Эти префиксы уже объявлены, в запросе их можно не писать (свои объявления тоже работают):
  PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
  PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
  PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
  PREFIX schema: <http://schema.org/>
  PREFIX kgo: <https://example.org/story-kg/ontology#>
  PREFIX kgc: <https://example.org/story-kg/concept/>
  PREFIX kgg: <https://example.org/story-kg/graph/>
  PREFIX kge: <https://example.org/story-kg/id/global/>
  PREFIX kgt: <https://example.org/story-kg/ontology/tech#>
  PREFIX oa: <http://www.w3.org/ns/oa#>
  PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
  PREFIX prov: <http://www.w3.org/ns/prov#>
  PREFIX dcterms: <http://purl.org/dc/terms/>
  PREFIX foaf: <http://xmlns.com/foaf/0.1/>
  PREFIX sioc: <http://rdfs.org/sioc/ns#>
  PREFIX vcard: <http://www.w3.org/2006/vcard/ns#>
  PREFIX bbo: <https://www.irit.fr/recherches/MELODI/ontologies/BBO#>
  PREFIX eso: <http://www.newsreader-project.eu/domain-ontology#>
  PREFIX qb: <http://purl.org/linked-data/cube#>
- Запрос без GRAPH видит все графы сразу, и одна тройка может прийти несколько раз: пиши DISTINCT, а в подсчётах — COUNT(DISTINCT …).
- Текстовые значения — литералы с языковой меткой @ru: сравнивай через `STR(?x) = "…"` или `CONTAINS(?x, "…")`. Цитаты статьи (oa:exact, oa:prefix, oa:suffix) — литералы без метки.
- Коды — IRI вида `<https://example.org/story-kg/concept/stance/irony>` (в описании таблиц — kgc:stance/{код}). В запросе пиши такой IRI целиком: в имени с префиксом косую черту надо экранировать (`kgc:stance\/irony`).
- Классы графа и число узлов в них: {{inventory}}.
