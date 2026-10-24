// Executes the installed JVM's HashMap/Collections; no game classes or copied methods.
import java.nio.file.*;
import java.nio.charset.StandardCharsets;
import java.util.*;
public final class Sts1CardPoolJdk {
  public static void main(String[] args) throws Exception {
    Map<String,String[]> library = new HashMap<>();
    Map<String,String[]> curses = new HashMap<>();
    for (String line : Files.readAllLines(Paths.get(args[0]), StandardCharsets.UTF_8)) {
      String[] row = line.split("\\t", -1);
      if (library.put(row[0], row) != null) throw new AssertionError("duplicate ID");
      if (row[3].equals("CURSE")) curses.put(row[0], row);
    }
    for (Map.Entry<String,String[]> entry : library.entrySet()) System.out.println("LIBRARY\t" + entry.getKey());
    for (String id : curses.keySet()) System.out.println("CURSEMAP\t" + id);
    for (String id : curses.keySet()) {
      if (!Arrays.asList("AscendersBane","CurseOfTheBell","Necronomicurse","Pride").contains(id)) System.out.println("GETCURSE\t" + id);
    }
    for (String rarity : Arrays.asList("COMMON","UNCOMMON","RARE")) {
      List<String> red = new ArrayList<>();
      for (String[] row : library.values()) {
        if (row[1].equals("RED") && row[2].equals(rarity)) red.add(row[0]);
      }
      for (String id : red) System.out.println("RED\t" + rarity + "\t" + id);
      for (String type : Arrays.asList("ATTACK","SKILL","POWER")) {
        List<String> typed = new ArrayList<>();
        for (String id : red) if (library.get(id)[3].equals(type)) typed.add(id);
        Collections.sort(typed);
        for (String id : typed) System.out.println("SHOP\t" + rarity + "\t" + type + "\t" + id);
      }
      List<String> colorless = new ArrayList<>();
      for (String[] row : library.values()) {
        if (row[1].equals("COLORLESS") && row[2].equals(rarity) && !row[3].equals("STATUS")) colorless.add(row[0]);
      }
      Collections.sort(colorless);
      for (String id : colorless) System.out.println("COLORLESS\t" + rarity + "\t" + id);
    }
  }
}
