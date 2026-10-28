package jgraphrag;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

final class Scorer {

    record Verdict(boolean correct, String reason) {
    }

    private static final Pattern NUMBER = Pattern.compile("-?\\d+(?:[.,]\\d+)?");
    private static final Pattern SAYS_NO = Pattern.compile("(^|\\W)(false|нет|no)(\\W|$)|не опроверг");
    private static final Pattern SAYS_YES = Pattern.compile("(^|\\W)(true|да|yes)(\\W|$)|опровергнут");
    private static final String VALUE = "value";
    private static final String COUNTS = "counts";
    private static final String QUOTE = "quote";

    private final List<String> article;

    Scorer(List<String> articleLines) {
        this.article = articleLines;
    }

    @SuppressWarnings("unchecked")
    Verdict score(Map<String, Object> gold, Agent.Answer a) {
        String kind = (String) gold.get("kind");
        if (a == null) {
            return new Verdict(false, "no answer handed in");
        }
        if ("none".equals(kind)) {
            if (!a.noAnswer()) {
                return new Verdict(false, "answered a question the article does not answer");
            }
            boolean empty = a.values().stream().allMatch(v -> v.get("key").isBlank() && v.get(VALUE).isBlank());
            return new Verdict(true, empty ? "no_answer" : "no_answer with values");
        }
        if (a.noAnswer()) {
            return new Verdict(false, "said no_answer");
        }
        Map<String, String> labels = labels(gold.get("labels"), gold.get("ids"));
        return switch (kind) {
            case "number" -> number(gold, a);
            case "numbers" -> numbers((List<Map<String, Object>>) gold.get("values"), a);
            case "set" -> set((List<Object>) gold.get("ids"), labels, a);
            case COUNTS -> counts((Map<String, Object>) gold.get(COUNTS), labels, a);
            case "record" -> fields((Map<String, Object>) gold.get("fields"), labels, a);
            case QUOTE -> quote(((Number) gold.get("line")).intValue(), (String) gold.get("must_contain"), a);
            default -> throw new IllegalArgumentException("answer kind " + kind);
        };
    }

    static String norm(String s) {
        String t = s.strip();
        if (t.startsWith("<") && t.endsWith(">")) {
            t = t.substring(1, t.length() - 1);
        }
        if (t.startsWith(MemoryServer.BASE)) {
            t = t.substring(MemoryServer.BASE.length());
        }
        t = withoutTrailingSlashes(t);
        int slash = t.lastIndexOf('/');
        return (slash >= 0 && slash < t.length() - 1 ? t.substring(slash + 1) : t).toLowerCase(Locale.ROOT);
    }

    static String text(String s) {
        return s.replace('ё', 'е').replace('Ё', 'Е').replaceAll("\\s+", " ").strip().toLowerCase(Locale.ROOT);
    }

    private static Map<String, String> labels(Object labels, Object ids) {
        Map<String, String> out = new HashMap<>();
        if (labels instanceof Map<?, ?> m) {
            m.forEach((k, v) -> {
                for (Object label : v instanceof List<?> l ? l : List.of(v)) {
                    out.put(text(String.valueOf(label)), norm(String.valueOf(k)));
                }
            });
        } else if (labels instanceof List<?> l && ids instanceof List<?> i) {
            for (int j = 0; j < Math.min(l.size(), i.size()); j++) {
                out.put(text(String.valueOf(l.get(j))), norm(String.valueOf(i.get(j))));
            }
        }
        return out;
    }

    private static String resolve(Map<String, String> entry, Set<String> goldIds, Map<String, String> labels) {
        for (String s : List.of(entry.get("key"), entry.get(VALUE))) {
            if (s.isBlank()) {
                continue;
            }
            String id = norm(s);
            if (goldIds.contains(id)) {
                return id;
            }
            String byLabel = labels.get(text(s));
            if (byLabel != null) {
                return byLabel;
            }
        }
        return norm(entry.get("key"));
    }

    static List<Double> numbersIn(String s) {
        List<Double> out = new ArrayList<>();
        Matcher m = NUMBER.matcher(s.replace('\u00A0', ' '));
        while (m.find()) {
            out.add(Double.parseDouble(m.group().replace(',', '.')));
        }
        return out;
    }

    private static Verdict number(Map<String, Object> gold, Agent.Answer a) {
        double value = ((Number) gold.get(VALUE)).doubleValue();
        double tol = gold.get("tolerance") == null ? 0 : ((Number) gold.get("tolerance")).doubleValue();
        List<Double> seen = new ArrayList<>();
        a.values().forEach(v -> seen.addAll(numbersIn(v.get(VALUE))));
        seen.addAll(numbersIn(a.answer()));
        return seen.stream().anyMatch(x -> Math.abs(x - value) <= tol + 1e-9)
                ? new Verdict(true, "number") : new Verdict(false, "number " + value + " not in " + seen);
    }

    private static Verdict numbers(List<Map<String, Object>> gold, Agent.Answer a) {
        Set<String> ids = new HashSet<>();
        gold.forEach(g -> ids.add(norm(String.valueOf(g.get("id")))));
        int found = 0;
        for (Map<String, Object> g : gold) {
            double value = ((Number) g.get(VALUE)).doubleValue();
            String id = norm(String.valueOf(g.get("id")));
            boolean hit = a.values().stream().anyMatch(v -> norm(v.get("key")).equals(id)
                    || numbersIn(v.get(VALUE)).stream().anyMatch(x -> Math.abs(x - value) <= 1e-9));
            found += hit ? 1 : 0;
        }
        long extra = a.values().stream()
                .filter(v -> !ids.contains(norm(v.get("key"))) && !numbersIn(v.get(VALUE)).isEmpty())
                .filter(v -> gold.stream().noneMatch(g -> numbersIn(v.get(VALUE)).stream()
                        .anyMatch(x -> Math.abs(x - ((Number) g.get(VALUE)).doubleValue()) <= 1e-9)))
                .count();
        if (found < gold.size()) {
            return new Verdict(false, "found " + found + " of " + gold.size());
        }
        return extra == 0 ? new Verdict(true, "numbers") : new Verdict(false, extra + " extra values");
    }

    private static Verdict set(List<Object> gold, Map<String, String> labels, Agent.Answer a) {
        Set<String> want = new HashSet<>();
        gold.forEach(g -> want.add(norm(String.valueOf(g))));
        Set<String> got = new HashSet<>();
        for (Map<String, String> v : a.values()) {
            if (!v.get("key").isBlank() || !v.get(VALUE).isBlank()) {
                got.add(resolve(v, want, labels));
            }
        }
        if (got.equals(want)) {
            return new Verdict(true, "set");
        }
        Set<String> missing = new HashSet<>(want);
        missing.removeAll(got);
        Set<String> extra = new HashSet<>(got);
        extra.removeAll(want);
        return new Verdict(false, "missing " + missing + ", extra " + extra);
    }

    private static Verdict counts(Map<String, Object> gold, Map<String, String> labels, Agent.Answer a) {
        Map<String, Double> want = new HashMap<>();
        gold.forEach((k, v) -> want.put(norm(k), ((Number) v).doubleValue()));
        Map<String, Double> got = new HashMap<>();
        for (Map<String, String> v : a.values()) {
            List<Double> n = numbersIn(v.get(VALUE));
            if (!n.isEmpty()) {
                got.put(resolve(v, want.keySet(), labels), n.get(0));
            }
        }
        got.values().removeIf(x -> x == 0);
        want.values().removeIf(x -> x == 0);
        return got.equals(want) ? new Verdict(true, COUNTS) : new Verdict(false, "counts " + got + " vs " + want);
    }

    private static Verdict fields(Map<String, Object> fields, Map<String, String> labels, Agent.Answer a) {
        StringBuilder all = new StringBuilder(text(a.answer()));
        Set<String> ids = new HashSet<>();
        for (Map<String, String> v : a.values()) {
            all.append(' ').append(text(v.get("key"))).append(' ').append(text(v.get(VALUE)));
            ids.add(norm(v.get("key")));
            if (!v.get(VALUE).isBlank()) {
                ids.add(norm(v.get(VALUE)));
            }
        }
        String haystack = all.toString();
        List<String> missing = new ArrayList<>();
        for (Map.Entry<String, Object> f : fields.entrySet()) {
            Object want = f.getValue();
            boolean ok;
            if (Boolean.FALSE.equals(want)) {
                ok = SAYS_NO.matcher(haystack).find();
            } else if (Boolean.TRUE.equals(want)) {
                ok = SAYS_YES.matcher(haystack).find();
            } else {
                String s = String.valueOf(want);
                ok = ids.contains(norm(s)) || haystack.contains(withoutTrailingSlashes(text(s)))
                        || labels.entrySet().stream().anyMatch(l -> l.getValue().equals(norm(s)) && haystack.contains(l.getKey()));
            }
            if (!ok) {
                missing.add(f.getKey());
            }
        }
        return missing.isEmpty() ? new Verdict(true, "record") : new Verdict(false, "missing fields " + missing);
    }

    static String withoutTrailingSlashes(String s) {
        int end = s.length();
        while (end > 0 && s.charAt(end - 1) == '/') {
            end--;
        }
        return s.substring(0, end);
    }

    private Verdict quote(int line, String mustContain, Agent.Answer a) {
        for (Map<String, Object> e : a.evidence()) {
            int l = ((Number) e.get("line")).intValue();
            String q = text(String.valueOf(e.get(QUOTE)));
            if (l == line && l >= 1 && l <= article.size() && q.contains(text(mustContain))
                    && !q.isEmpty() && text(article.get(l - 1)).contains(q)) {
                return new Verdict(true, QUOTE);
            }
        }
        return new Verdict(false, "no verbatim quote on line " + line + " holding «" + mustContain + "»");
    }
}
