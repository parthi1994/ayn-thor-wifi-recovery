import local.thor.wifiresume.NetworkStore;
import java.util.*;
public class NetworkStoreTest {
    private static void check(boolean b){if(!b)throw new AssertionError();}
    private static void invalid(Runnable r){try{r.run();throw new AssertionError("invalid accepted");}catch(IllegalArgumentException expected){}}
    public static void main(String[] args){
        String secret="a' $(not-executed) # \\";
        NetworkStore.Network n=new NetworkStore.Network("Home = café",secret);
        String text=NetworkStore.format(Collections.singletonList(n));
        check(NetworkStore.parse(text.replace("\n","\r\n")).get(0).password.equals(secret));
        check(NetworkStore.parse(NetworkStore.format(Collections.emptyList())).isEmpty());
        invalid(()->NetworkStore.parse("SSID=Home\n"));
        invalid(()->NetworkStore.parse("MOT_DE_PASSE=Example123\n"));
        invalid(()->NetworkStore.parse("SSID=Home\nMOT_DE_PASSE=Example123\nSSID=Home\nMOT_DE_PASSE=Example456\n"));
        invalid(()->new NetworkStore.Network(" Home","Example123"));
        invalid(()->new NetworkStore.Network("Home","short"));
        invalid(()->new NetworkStore.Network("Home","newline\nsecret"));
        invalid(()->new NetworkStore.Network("ééééééééééééééééé","Example123"));
        check(NetworkStore.known("Network Id SSID Security type\n0   Home                            wpa2-psk\n0   Home                            wpa3-sae^\n1   Home Guest                      wpa2-psk\n").equals(Arrays.asList("Home","Home Guest")));
        System.out.println("PASS: literal roundtrip, CRLF, empty list, duplicate/malformed rejection, byte limits, known SSID deduplication.");
    }
}
