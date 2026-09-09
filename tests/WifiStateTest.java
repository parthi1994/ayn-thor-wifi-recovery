package local.thor.wifiresume;
public final class WifiStateTest {
    public static void main(String[] args) {
        String associated="Wifi is enabled\nWifi is connected to \"Home \\\" test\"\n";
        if(!WifiState.connectedSsid(associated).isEmpty())throw new AssertionError("Association without IP");
        if(!WifiState.connectedSsid(associated+"16: wlan0 inet 192.0.2.2/24 scope global wlan0").equals("Home \\\" test"))throw new AssertionError("Exact quoted SSID");
        if(!WifiState.connectedSsid("Wifi is disconnected\n16: wlan0 inet 192.0.2.2/24 scope global wlan0").isEmpty())throw new AssertionError("Stale IP alone");
        if(!WifiState.connectedSsid("Wifi is connected to \"Home\"\n16: wlan0 inet6 2001:db8::1/64 scope global wlan0").equals("Home"))throw new AssertionError("IPv6");
        System.out.println("PASS live Wi-Fi state");
    }
}
