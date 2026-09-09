package local.thor.wifiresume;
/** Live association and address only; a previous workflow success is not state. */
public final class WifiState {
    public static String connectedSsid(String state) {
        String ssid=""; boolean address=false;
        for(String line:state.split("\n")) {
            String prefix="Wifi is connected to ";
            if(line.startsWith(prefix)) {
                String value=line.substring(prefix.length()).trim();
                if(value.length()>=2 && value.startsWith("\"") && value.endsWith("\""))
                    ssid=value.substring(1,value.length()-1);
            }
            if(line.matches(".*\\bwlan0\\s+inet6?\\s+.*")) address=true;
        }
        return address?ssid:"";
    }
}
