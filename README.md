# AYN Thor Wi-Fi Recovery

A small, offline Android utility for the **AYN Thor**: keep your Wi-Fi profiles, select a network, and automate **forget → restart → reconnect** when Wi-Fi gets stuck.

**English and French** are available from the **FR / EN** button. The app also explains what each action does. This is an independent community utility, not an official AYN firmware fix.

[Download the APK](dist/Thor-WiFi-v2.1.apk) · [French guide](docs/README.fr.md) · [Build from source](#build-from-source)

## Why this exists

On the tested Thor, Wi-Fi sometimes stopped discovering or reconnecting to networks and could remain stuck after a normal restart. Diagnostics showed an existing `wlan0` interface and completed driver scans, while Android's Wi-Fi scanning service was stuck. Toggling Wi-Fi and requesting Android Wi-Fi recovery did not resolve that captured incident.

Forgetting the configured network, restarting, then adding it again restored the connection in a real test. This app automates that sequence so you do not have to retype the password. It also offers a normal connection button when a restart is unnecessary.

This is a **workaround**, not proof that every Wi-Fi failure has the same cause. Successful reconnection on Wi-Fi 6 was observed; the app does not change your router's Wi-Fi generation, channel or security mode.

## Screenshots

Real screenshots of the app's read-only demo mode. The network names are fictional; no personal profiles or passwords are shown.

![English interface](docs/screenshots/english.png)
![French interface](docs/screenshots/french.png)

## Installation

1. Copy [Thor-WiFi-v2.1.apk](dist/Thor-WiFi-v2.1.apk) to your Thor and install it. Allow installation from your chosen file manager if Android asks.
2. Open **Thor Wi-Fi** once. The app uses AYN's existing root service to install its bundled scripts. No separate script download, PC, Shizuku or network access is required after installation.
3. Add your network name and WPA2 password, or pick a name from **Saved in Android**. If the app does not already know that password, enter it once.
4. Select a network and choose **Connect** or **Forget, restart and reconnect**.

Keep the app installed and avoid force-stopping it: Android must be able to deliver its boot event. Unlock the Thor after restarting if prompted. If you have force-stopped the app, open it again before starting another recovery cycle.

## What the buttons do

| Action | Result |
|---|---|
| Add / Edit / Delete | Manages the app's list and its local text file. Deleting here keeps the network saved in Android. |
| Saved in Android | Picks an existing Android SSID; it does not extract Android's stored passwords. |
| Connect | Connects the selected network, without forgetting or restarting. |
| Forget, restart and reconnect | Confirms the selected SSID, forgets only matching Android entries, verifies removal, restarts, then reconnects after boot. Other Android networks are kept. |
| Refresh | Reloads the local profile file and current Wi-Fi state. |
| FR / EN | Chooses and remembers the interface language. |
| Wi-Fi file and help | Explains the workaround, profile storage and limitations. |

If the selected network is not saved in Android, recovery stops before restarting. Use **Connect** first. There is no factory reset and no continuous reboot loop. A connection attempt may wait roughly 90 seconds per profile, plus command timeouts.

The manual launchers remain in `Downloads/Thor-Scripts` for **Thor Settings → Run script as root**. The app's recovery button targets one selected network; manual script `10_WIFI_OUBLI_REBOOT_AUTO.sh` targets all profiles listed in the file.

## Compatibility and limitations

Tested on **AYN Thor, Android 13**, firmware `Thor_V1.0.0.377_20260206_165408_user`, main Android user. The APK requires Android 8 or later, but that minimum alone does **not** establish compatibility with other devices.

The app relies on AYN's `PServerBinder` root interface, the same interface used by **Run script as root**. Availability can vary with firmware. It does not install root, change SELinux mode, unlock the bootloader, or work as a universal Android Wi-Fi repair tool.

Supported profile format: **WPA2-PSK**, passwords of 8–63 printable ASCII characters, SSIDs of 1–32 UTF-8 bytes without control characters or leading/trailing spaces. WPA3-only, Enterprise, hidden networks and raw 64-character hexadecimal keys are not implemented. A router marketed as Wi-Fi 6/7 can still offer WPA2; Wi-Fi generation and authentication mode are different settings.

## Profile storage and privacy

Profiles are local. The APK requests the boot-completed permission and has **no Internet permission**. It contains no personal Wi-Fi configuration, telemetry or account integration.

`Downloads/Thor-Scripts/WIFI_RESEAUX.txt` stores passwords **in plain text** for editing without a PC. A root-private copy with file mode `600` in a `700` directory holds the selected profile for reboot recovery. The editor masks passwords by default and allows explicitly revealing them. This is not encrypted password-vault storage.

The app reads the file as literal text; it never evaluates it as shell code. Its root Binder commands use fixed paths, not interpolated passwords. The Android `cmd wifi connect-network` process necessarily receives the password as an argument; the scripts suppress its output, but cannot guarantee what privileged firmware logging might capture.

Share the APK or this source repository. **Do not share your profile file, private signing key, or unreviewed device logs.**

## Verification performed

- Real-device add, select, edit and delete via UI instrumentation using a temporary fictional profile; the original list was restored.
- Real-device normal connection, and a complete recovery cycle launched through the app, with association and IP address confirmed after boot. The boot receiver performed recovery; no PC reconnect/resume command was issued after reboot.
- The USB cable remained attached for observation. A physically disconnected cable test was not performed.
- French/English resource parity, language switching and help checked on the Thor. Screenshots use demo mode, which skips root setup, profile loading and mutations.
- Isolated tests cover literal passwords, malformed profiles, empty catalogs, exact SSID targeting, preservation of other networks, failure before reboot, and the stability of pending recovery credentials.
- APK signing verified; local backup and installed APK hashes compared.

These checks establish the observed connection and IP result, not Internet reachability, every game/device interaction, or a permanent firmware fix.

## Build from source

Requires Windows, PowerShell 7, JDK 17+, Android API 33 `android.jar`, Android build-tools providing `aapt`, `zipalign` and `apksigner`, and an R8/D8 jar. The build script does not download dependencies.

```powershell
./build.ps1 -JavaHome 'C:\Android\jdk' `
  -BuildTools 'C:\Android\sdk\build-tools\34.0.0' `
  -AndroidJar 'C:\Android\sdk\platforms\android-33\android.jar' `
  -R8Jar 'C:\Android\r8.jar'
```

Output: `../Build/Thor-WiFi.apk`. If no `-KeyStore` is supplied, a local development signing key is generated in the build directory (alias `thor-local`, development password `changeit`). Keep that key private and reuse it for updates. A different key cannot update an existing installation signed by another key. The private key for the distributed APK is not included.

Reference toolchain: JDK 20, API 33, build-tools 34.0.0, R8 8.7.18. Native Android views and local shell scripts only.

### Tests

The Python shell tests use Git for Windows Bash and do not contact a device:

```powershell
python tests/verify_app_api.py
python tests/verify_workflow.py
python tests/verify_scripts.py
```

`tests/NetworkStoreTest.java` runs the Android-independent profile parser tests. `tests/UiTestRunner.java` is a separate Android instrumentation test, excluded from the distributed APK. It uses temporary dummy profiles, not real passwords.

### Layout

- `java/`: UI, translation lookup, profile parser, fixed AYN bridge and boot receiver.
- `res/values/`, `res/values-fr/`: English and French text.
- `assets/install.sh`: installs the bundled engines while preserving existing profiles.
- `assets/engine/`: catalog API, targeted recovery, connection and diagnostics.
- `assets/launchers/`: one-line Thor Settings launchers.
- `dist/`: signed installable APK and SHA-256 checksum.

## Feedback

For useful bug reports, include the Thor firmware version, the action used and whether the app reports an association/IP result. Review logs before attaching them: SSIDs, MAC/IP addresses and other metadata may be present.

## License

MIT. This project is independent of AYN and Android/AOSP. Names and trademarks belong to their respective owners.
