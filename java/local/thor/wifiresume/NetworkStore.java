package local.thor.wifiresume;
import java.nio.charset.StandardCharsets;
import java.util.*;

/** Literal text format shared with WIFI_RESEAUX.txt. Never source/eval this file. */
public final class NetworkStore {
    public static final class Network {
        public final String ssid, password;
        public Network(String ssid, String password) { validate(ssid, password); this.ssid=ssid; this.password=password; }
    }
    public static void validate(String ssid, String password) {
        if(ssid == null || ssid.isEmpty() || ssid.getBytes(StandardCharsets.UTF_8).length > 32 || !ssid.equals(ssid.trim()) || ssid.matches("(?s).*[\\p{Cntrl}].*"))
            throw new IllegalArgumentException("SSID : 1 à 32 octets, sans espace au début ou à la fin ni caractère de contrôle.");
        if(password == null || password.length()<8 || password.length()>63 || !password.matches("[ -~]+"))
            throw new IllegalArgumentException("Mot de passe WPA2 : 8 à 63 caractères ASCII imprimables.");
    }
    public static List<Network> parse(String text) {
        List<Network> result=new ArrayList<>(); String pending=null; Set<String> seen=new HashSet<>();
        for(String line:text.replace("\r\n","\n").split("\n",-1)) {
            if(line.isEmpty() || line.startsWith("#")) continue;
            if(line.startsWith("SSID=") && pending==null) pending=line.substring(5);
            else if(line.startsWith("MOT_DE_PASSE=") && pending!=null) {
                Network n=new Network(pending,line.substring(13));
                if(!seen.add(n.ssid)) throw new IllegalArgumentException("Un SSID apparaît plusieurs fois dans le fichier.");
                result.add(n); pending=null;
            } else throw new IllegalArgumentException("Format attendu : SSID= puis MOT_DE_PASSE=, sans guillemets ajoutés.");
        }
        if(pending!=null) throw new IllegalArgumentException("Il manque le mot de passe d'un réseau.");
        return result;
    }
    public static String format(List<Network> networks) {
        StringBuilder s=new StringBuilder("# Thor Wi-Fi : identifiants en clair, selon votre choix.\n# Deux lignes par réseau ; WPA2 / WPA3 auto ; ne pas ajouter de guillemets.\n");
        Set<String> seen=new HashSet<>();
        for(Network n:networks) {
            validate(n.ssid,n.password);
            if(!seen.add(n.ssid)) throw new IllegalArgumentException("Ce SSID existe déjà.");
            s.append("\nSSID=").append(n.ssid).append("\nMOT_DE_PASSE=").append(n.password).append('\n');
        }
        return s.toString();
    }
    public static List<String> known(String rows) {
        Set<String> names=new LinkedHashSet<>();
        for(String row:rows.split("\n")) {
            if(!row.matches("^\\s*[0-9]+\\s+.*")) continue;
            String n=row.replaceFirst("^\\s*[0-9]+\\s+", "").replaceFirst("\\s+\\S+\\s*$", "").replaceFirst("\\s+$", "");
            if(!n.isEmpty()) names.add(n);
        }
        return new ArrayList<>(names);
    }
}
