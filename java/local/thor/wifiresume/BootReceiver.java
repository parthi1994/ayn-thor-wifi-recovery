package local.thor.wifiresume;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
public final class BootReceiver extends BroadcastReceiver {
    public void onReceive(Context context, Intent intent) {
        if (!Intent.ACTION_BOOT_COMPLETED.equals(intent.getAction())) return;
        final PendingResult pending = goAsync();
        new Thread(() -> {
            try { ThorBridge.execute("resume"); }
            catch (Exception ignored) { /* Pending root marker remains for PC/manual retry. */ }
            finally { pending.finish(); }
        }, "ThorWifiResume").start();
    }
}
