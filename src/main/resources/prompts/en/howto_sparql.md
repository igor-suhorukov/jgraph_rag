The tool sparql_query runs SPARQL 1.1 over the graph of the memory.
- The base IRI https://example.org/story-kg/id/habr-1097022/ is set: the article's nodes are written relative to it, `<claim_x>`, `<sec/s2>`, `<anno/…>`. The id of a node is its IRI without the base prefix. How a node's IRI is built is said in the description of its table.
- These prefixes are already declared, a query can leave them out (its own declarations work too):
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
- A query without GRAPH sees all the graphs at once, and one triple can come back several times: write DISTINCT, and COUNT(DISTINCT …) in counts.
- Text values are literals with the language tag @en: compare them with `STR(?x) = "…"` or `CONTAINS(?x, "…")`. The quotes of the article (oa:exact, oa:prefix, oa:suffix) are plain literals in Russian.
- Codes are IRIs such as `<https://example.org/story-kg/concept/stance/irony>` (kgc:stance/{code} in the descriptions of the tables). Write such an IRI in full in a query: in a prefixed name the slash has to be escaped (`kgc:stance\/irony`).
- The classes of the graph and their node counts: {{inventory}}.
