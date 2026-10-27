#!/usr/bin/env python3
"""The article's knowledge base as two SQL dumps, one per language: data/habr_1097022.ru.sql and
data/habr_1097022.en.sql. Each holds the schema habr_1097022 with its comments, the rows, and the R2RML mapping,
registered with kb.add_mapping(); it loads into a database where pg_knowledge_base is installed.

The Russian dump is the Story-KG tables as they are (schema.sql, data.sql, mapping.ttl of SRC). The English one is the
same rows with every Russian text translated by the translation memory data/i18n/ru-en.tsv: names, descriptions, claims,
replies, conditions, the comments of the schema, the texts of the mapping; literals tagged @en instead of @ru. The quotes
of the article (evidence.quote, prefix, suffix) stay as they are: they are the verbatim text of the Russian article that
the line numbers and the offsets of the W3C selectors point into. The names of arguments and objections are cut from
their claims as Story-KG cuts them, so the English ones are cut from the English claims.

  make_dumps.py SRC_DIR          (SRC_DIR holds schema.sql, data.sql, mapping.ttl; writes into data/)
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CYR = re.compile("[А-Яа-яЁё]")
KEEP = {("evidence", "quote"), ("evidence", "prefix"), ("evidence", "suffix")}
INSERT = re.compile(r"INSERT INTO (\w+) \(([^)]*)\) VALUES \((.*)\)$", re.S)
COMMENT = re.compile(r"COMMENT ON (\w+) ([\w.]+) IS\s+('(?:[^']|'')*'(?:\s+'(?:[^']|'')*')*)$", re.S)
QUADS = ("10 158 квадов", "10 154 квада")
NAME_PREFIX = {"Довод: ": "Argument: ", "Возражение: ": "Objection: "}


def statements(text):
    """(start, end) of the SQL statements of a text: split at semicolons outside quotes, -- comments skipped."""
    out, start, q, i = [], 0, False, 0
    while i < len(text):
        if not q and text.startswith("--", i):
            j = text.find("\n", i)
            i = len(text) if j < 0 else j
            continue
        if text[i] == "'":
            q = not q
        elif text[i] == ";" and not q:
            out.append((start, i))
            start = i + 1
        i += 1
    return out


def sql_string(s, i):
    """The text of the quoted SQL string at s[i] ('' is an escaped quote) and the index after it."""
    j, buf = i + 1, []
    while True:
        if s[j] == "'" and j + 1 < len(s) and s[j + 1] == "'":
            buf.append("'")
            j += 2
        elif s[j] == "'":
            return "".join(buf), j + 1
        else:
            buf.append(s[j])
            j += 1


def until_comma(s, i):
    """The index of the first comma at or after s[i], or the length of s."""
    j = s.find(",", i)
    return len(s) if j < 0 else j


def sql_values(s):
    """The values of a VALUES list: ('str', decoded text) or ('raw', token)."""
    out, i = [], 0
    while i < len(s):
        if s[i] in " ,\n":
            i += 1
        elif s[i] == "'":
            text, i = sql_string(s, i)
            out.append(("str", text))
        else:
            j = until_comma(s, i)
            out.append(("raw", s[i:j].strip()))
            i = j
    return out


def array_string(body, i):
    """The text of the double-quoted array element at body[i] (\\ escapes the next character) and the index after it."""
    j, buf = i + 1, []
    while body[j] != '"':
        if body[j] == "\\":
            j += 1
        buf.append(body[j])
        j += 1
    return "".join(buf), j + 1


def array_elements(lit):
    body, out, i = lit[1:-1], [], 0
    while i < len(body):
        if body[i] == ",":
            i += 1
        elif body[i] == '"':
            text, i = array_string(body, i)
            out.append(("q", text))
        else:
            j = until_comma(body, i)
            out.append(("u", body[i:j]))
            i = j
    return out


def array_literal(elements):
    def one(kind, e):
        if kind == "u" and e and not re.search(r'[\s,{}"\\]', e) and e.upper() != "NULL":
            return e
        return '"' + e.replace("\\", "\\\\").replace('"', '\\"') + '"'
    return "{" + ",".join(one(k, e) for k, e in elements) + "}"


def quote(s):
    return "'" + s.replace("'", "''") + "'"


def short(s, n):
    """derive_frames5.py's short(): spaces collapsed, cut to n characters with «…»."""
    s = re.sub(r"\s+", " ", s).strip()
    return s if len(s) <= n else s[:n - 1].rstrip() + "…"


def unescape(s):
    out, i = [], 0
    while i < len(s):
        if s[i] == "\\" and i + 1 < len(s):
            out.append({"n": "\n", "t": "\t", "\\": "\\"}[s[i + 1]])
            i += 2
        else:
            out.append(s[i])
            i += 1
    return "".join(out)


def memory():
    """(kind, Russian) → English, from data/i18n/ru-en.tsv."""
    tm = {}
    lines = (ROOT / "data/i18n/ru-en.tsv").read_text(encoding="utf-8").splitlines()
    for line in lines[1:]:
        kind, _, ru, en = line.split("\t")
        tm[(kind, unescape(ru))] = unescape(en)
    return tm


def inserts(data):
    """(start, end, offset of INSERT INTO in the statement, its match) of every SQL statement of data."""
    rows = []
    for start, end in statements(data):
        stmt = data[start:end]
        k = stmt.find("INSERT INTO")
        m = INSERT.match(stmt[k:].strip()) if k >= 0 else None
        rows.append((start, end, k, m))
    return rows


def claim_texts(rows, tm):
    """Claim id → (Russian text, English text): the names of arguments and objections are cut from them."""
    claims = {}
    for _, _, _, m in rows:
        if m and m.group(1) == "claims":
            v = dict(zip([c.strip() for c in m.group(2).split(",")], sql_values(m.group(3))))
            claims[v["id"][1]] = (v["text"][1], tm[("value", v["text"][1])])
    return claims


def cut_name(ru_name, claim_id, claims):
    """The English name of an argument or objection, cut from its English claim as the Russian one is cut."""
    prefix = next(p for p in NAME_PREFIX if ru_name.startswith(p))
    ru_text, en_text = claims[claim_id]
    rest = ru_name[len(prefix):]
    n = next((n for n in range(20, 400) if short(ru_text, n) == rest and len(ru_text) > n), None)
    if n is None:
        if rest != short(ru_text, 10_000):
            raise ValueError(f"{ru_name!r} is not cut from claim {claim_id}")
        n = 90
    return NAME_PREFIX[prefix] + short(en_text, n)


def translate_array(v, tm):
    # two Russian forms of one word («раза», «раз») are one English word: an element once
    elements = {}
    for kind, e in array_elements(v):
        elements.setdefault(tm[("value", e)] if CYR.search(e) else e, kind)
    return array_literal([(kind, e) for e, kind in elements.items()])


def translate_value(table, col, v, row, claims, tm):
    """The SQL literal of the English text of the string v in a column of a row."""
    if not CYR.search(v) or (table, col) in KEEP:
        return quote(v)
    if table == "arguments" and col == "name":
        return quote(cut_name(v, row["conclusion"][1], claims))
    if table == "conflicts" and col in ("name", "review_name"):
        return quote(cut_name(v, row["attacker" if col == "name" else "attacked"][1], claims))
    if v.startswith("{") and v.endswith("}"):
        return quote(translate_array(v, tm))
    return quote(tm[("value", v)])


def translate_insert(m, claims, tm):
    table, cols = m.group(1), [c.strip() for c in m.group(2).split(",")]
    values = sql_values(m.group(3))
    row = dict(zip(cols, values))
    new = [v if t != "str" else translate_value(table, col, v, row, claims, tm) for col, (t, v) in zip(cols, values)]
    return f"INSERT INTO {table} ({', '.join(cols)}) VALUES ({', '.join(new)})"


def translate_data(data, tm):
    rows = inserts(data)
    claims = claim_texts(rows, tm)
    out, pos = [], 0
    for start, end, k, m in rows:
        if m:
            out.append(data[pos:start + k])
            out.append(translate_insert(m, claims, tm))
            pos = end
    out.append(data[pos:])
    return "".join(out)


def translate_schema(schema, tm):
    out, pos = [], 0
    for start, end in statements(schema):
        stmt = schema[start:end]
        k = stmt.find("COMMENT ON")
        m = COMMENT.match(stmt[k:].strip()) if k >= 0 else None
        if not m:
            continue
        text = "".join(x.replace("''", "'") for x in re.findall(r"'((?:[^']|'')*)'", m.group(3)))
        if not CYR.search(text):
            continue
        out.append(schema[pos:start + k])
        out.append(f"COMMENT ON {m.group(1)} {m.group(2)} IS {quote(tm[('comment', text)])}")
        pos = end
    out.append(schema[pos:])
    lines = [tm[("schema", line)] if CYR.search(line) else line for line in "".join(out).split("\n")]
    return "\n".join(lines)


def translate_mapping(mapping, tm):
    lines = [tm[("mapping", line)] if CYR.search(line) else line for line in mapping.split("\n")]
    return "\n".join(lines).replace('rr:language "ru"', 'rr:language "en"')


HEADER = {
    "ru": """-- База знаний статьи «Мой PostgreSQL быстрее твоего и почти догнал ClickHouse» (habr.com/ru/articles/1097022)
-- на русском: схема habr_1097022 с комментариями, строки и отображение R2RML, которое читает их как граф знаний.
-- Загружается в базу, где установлен pg_knowledge_base (CREATE EXTENSION pg_knowledge_base) и он есть в
-- shared_preload_libraries:  psql -v ON_ERROR_STOP=1 -f habr_1097022.ru.sql
-- Собран tools/make_dumps.py из таблиц Story-KG; английский двойник — habr_1097022.en.sql.
""",
    "en": """-- The knowledge base of the article "My PostgreSQL is faster than yours and has almost caught up with ClickHouse"
-- (habr.com/ru/articles/1097022) in English: schema habr_1097022 with its comments, the rows, and the R2RML mapping that
-- reads them as a knowledge graph. The quotes of the article (evidence.quote, prefix, suffix) are verbatim Russian text:
-- the line numbers and character offsets of the evidence point into the Russian article.
-- Loads into a database where pg_knowledge_base is installed (CREATE EXTENSION pg_knowledge_base) and is in
-- shared_preload_libraries:  psql -v ON_ERROR_STOP=1 -f habr_1097022.en.sql
-- Made by tools/make_dumps.py from the Story-KG tables and the translation memory data/i18n/ru-en.tsv; the Russian
-- original is habr_1097022.ru.sql.
""",
}
MAPPING_HEAD = {
    "ru": "-- ============================================================== отображение R2RML таблиц в граф знаний\n",
    "en": "-- ============================================================== the R2RML mapping of the tables to the knowledge graph\n",
}


def dump(lang, schema, data, mapping):
    if "$ttl$" in mapping:
        raise ValueError("the mapping holds $ttl$")
    return (HEADER[lang] + "\n" + schema.rstrip() + "\n\n" + data.rstrip() + "\n\n" + MAPPING_HEAD[lang]
            + "SELECT kb.add_mapping('habr_1097022', $ttl$" + mapping.rstrip() + "\n$ttl$) IS NOT NULL AS mapped;\n")


def check_english(text):
    """No Russian left in the English dump but in the quotes of the article."""
    bad = []
    for start, end in statements(text):
        stmt = text[start:end]
        k = stmt.find("INSERT INTO")
        m = INSERT.match(stmt[k:].strip()) if k >= 0 else None
        if m:
            for col, (t, v) in zip([c.strip() for c in m.group(2).split(",")], sql_values(m.group(3))):
                if CYR.search(v) and (m.group(1), col) not in KEEP:
                    bad.append(f"{m.group(1)}.{col}: {v[:60]}")
        elif CYR.search(stmt):
            bad.append(stmt.strip()[:80])
    if bad:
        raise ValueError("Russian left in the English dump:\n" + "\n".join(bad[:20]))


def main():
    src = Path(sys.argv[1])
    schema = (src / "schema.sql").read_text(encoding="utf-8")
    data = (src / "data.sql").read_text(encoding="utf-8")
    mapping = (src / "mapping.ttl").read_text(encoding="utf-8")
    tm = memory()
    ru_schema = schema.replace(QUADS[0], QUADS[1]).replace(" Схема без данных: проект для просмотра.", "")
    en_schema = translate_schema(schema, tm)
    ru = dump("ru", ru_schema, data, mapping)
    en = dump("en", en_schema, translate_data(data, tm), translate_mapping(mapping, tm))
    check_english(en)
    for lang, text in (("ru", ru), ("en", en)):
        path = ROOT / "data" / f"habr_1097022.{lang}.sql"
        path.write_text(text, encoding="utf-8")
        print(path, len(text), "characters")


if __name__ == "__main__":
    main()
