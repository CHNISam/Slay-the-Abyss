/* Independent source interpretation, not original game execution.
 * Uses the host JDK HashMap and Collections.shuffle to avoid substituting
 * alphabetical/library insertion order for RelicLibrary.populateRelicPool.
 * Input: source-fact TSV (library, tier, ID), then fixed RNG nextLong TSV.
 * No game classes, production Lua, or copied decompiled methods are loaded.
 */
import java.nio.file.*;
import java.util.*;

class Sts1RelicPoolVectors {
    static final List<String> TIERS = List.of("common", "uncommon", "rare", "shop", "boss");

    static String json(Object value) {
        if (value == null) return "null";
        if (value instanceof String) return "\"" + ((String)value).replace("\\", "\\\\").replace("\"", "\\\"") + "\"";
        if (value instanceof Map) {
            List<String> pairs = new ArrayList<>();
            ((Map<?, ?>)value).forEach((k, v) -> pairs.add(json(k.toString()) + ":" + json(v)));
            return "{" + String.join(",", pairs) + "}";
        }
        if (value instanceof Collection) {
            List<String> items = new ArrayList<>();
            for (Object item : (Collection<?>)value) items.add(json(item));
            return "[" + String.join(",", items) + "]";
        }
        return value.toString();
    }

    static Map<String, List<String>> pools(List<HashMap<String, String>> libraries, Set<String> locked) {
        Map<String, List<String>> result = new LinkedHashMap<>();
        for (String tier : TIERS) {
            List<String> ids = new ArrayList<>();
            for (HashMap<String, String> library : libraries)
                library.forEach((id, rarity) -> { if (rarity.equals(tier) && !locked.contains(id)) ids.add(id); });
            result.put(tier, ids);
        }
        return result;
    }

    public static void main(String[] args) throws Exception {
        HashMap<String, String> shared = new HashMap<>(), red = new HashMap<>();
        for (String line : Files.readAllLines(Path.of(args[0]))) {
            String[] row = line.split("\t");
            (row[0].equals("shared") ? shared : red).put(row[2], row[1]);
        }
        List<HashMap<String, String>> libraries = List.of(shared, red);
        Map<String, Object> output = new LinkedHashMap<>();
        output.put("provenance", "Independent fixed-source interpretation using host JDK containers/shuffle; not PC game execution");
        output.put("jdk", System.getProperty("java.version"));
        output.put("sourceCommit", "319009d5df0a82d9fb0f23cc22322286c6a87ec0");
        output.put("unshuffled", pools(libraries, Set.of()));
        List<Object> cases = new ArrayList<>();
        for (String line : Files.readAllLines(Path.of(args[1]))) {
            String[] row = line.split("\t");
            for (String profile : row[0].equals("0") ? List.of("all-unlocked", "synthetic-lock-mask", "remove-owned-after-shuffle") : List.of("all-unlocked")) {
                Set<String> locked = profile.equals("synthetic-lock-mask") ? Set.of("Akabeko", "Dead Branch", "Turnip", "Pandora's Box") : Set.of();
                Set<String> owned = profile.equals("remove-owned-after-shuffle") ? Set.of("Anchor", "Membership Card", "Sozu") : Set.of();
                Map<String, List<String>> queues = pools(libraries, locked);
                List<String> consumed = new ArrayList<>();
                for (int i = 0; i < TIERS.size(); i++) {
                    consumed.add(row[i + 1]);
                    List<String> queue = queues.get(TIERS.get(i));
                    Collections.shuffle(queue, new Random(Long.parseUnsignedLong(row[i + 1], 16)));
                    queue.removeIf(owned::contains);
                }
                Map<String, Object> entry = new LinkedHashMap<>();
                entry.put("seed", row[0]); entry.put("profile", profile);
                entry.put("locked", new TreeSet<>(locked)); entry.put("removedAfterShuffle", new TreeSet<>(owned));
                entry.put("randomLongHex", consumed); entry.put("relicRngCounterAfter", 5); entry.put("queues", queues);
                cases.add(entry);
            }
        }
        output.put("cases", cases);
        System.out.println(json(output));
    }
}
