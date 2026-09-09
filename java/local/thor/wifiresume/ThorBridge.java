package local.thor.wifiresume;
import java.nio.charset.StandardCharsets;

/** Fixed commands only: no SSID or password is interpolated into Binder commands. */
public final class ThorBridge {
    public static String execute(String operation) throws Exception {
        final String command;
        switch (operation) {
            case "bootstrap": command = "/system/bin/sh /data/user/0/local.thor.wifiresume/files/bootstrap/install.sh"; break;
            case "resume": command = "/system/bin/sh /data/local/thor-wifi/bin/workflow.sh resume"; break;
            case "snapshot": case "save": case "connect": case "forget":
                command = "/system/bin/sh /data/local/thor-wifi/bin/app_api.sh " + operation; break;
            default: throw new IllegalArgumentException("Unsupported operation");
        }
        Class<?> parcel = Class.forName("android.os.Parcel");
        Object request = parcel.getMethod("obtain").invoke(null);
        Object reply = parcel.getMethod("obtain").invoke(null);
        try {
            Object binder = Class.forName("android.os.ServiceManager").getMethod("getService", String.class).invoke(null, "PServerBinder");
            if (binder == null) throw new IllegalStateException("AYN root service unavailable");
            parcel.getMethod("writeStringArray", String[].class).invoke(request, (Object)new String[]{command, "0"});
            boolean handled = (Boolean)Class.forName("android.os.IBinder").getMethod("transact", int.class, parcel, parcel, int.class).invoke(binder, 0, request, reply, 0);
            if (!handled) throw new IllegalStateException("AYN transaction rejected");
            byte[] bytes = (byte[])parcel.getMethod("createByteArray").invoke(reply);
            return bytes == null ? "" : new String(bytes, StandardCharsets.UTF_8);
        } finally {
            parcel.getMethod("recycle").invoke(request);
            parcel.getMethod("recycle").invoke(reply);
        }
    }
}
