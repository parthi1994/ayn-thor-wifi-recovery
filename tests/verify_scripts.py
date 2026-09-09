"""Local mock checks only; no ADB calls or real credentials."""
import os
from pathlib import Path
import subprocess
import tempfile

BASE = Path(__file__).resolve().parent
BASH = r"C:\Program Files\Git\bin\bash.exe"

def unix(path):
    s = str(path.resolve()).replace('\\', '/')
    return '/' + s[0].lower() + s[2:]

with tempfile.TemporaryDirectory(prefix='thor-test-', dir=BASE) as temp:
    root = Path(temp)
    private = root / 'private'
    private.mkdir()
    # Literal shell metacharacters must not execute and must not leak to logs.
    password = 'p@ss $(touch NEVER_CREATED) `echo LEAK` " quotes'
    (private / 'credentials').write_text('Thor Test\n' + password + '\n', encoding='utf-8', newline='\n')
    script = (BASE.parent / 'assets' / 'engine' / 'wifi_reconnect.sh').read_text(encoding='utf-8')
    script = script.replace('/data/local/thor-wifi', unix(private))
    script = script.replace('/sdcard/Download/AYN-Thor-WiFi', unix(root / 'reports'))
    (root / 'reconnect.sh').write_text(script, encoding='utf-8', newline='\n')
    harness = r'''
id() { printf '0\n'; }
stat() {
    if [ "$CASE" = unsafe ]; then echo '2000:0:777';
    elif [ -d "${@: -1}" ]; then echo '0:0:700'; else echo '0:0:600'; fi
}
timeout() { shift 3; "$@"; }
sleep() { :; }
cmd() {
    case "$2" in
        help)
            if [ "$CASE" = wpa3_unsupported ]; then modes='open|wpa2'; else modes='open|wpa2|wpa3'; fi
            printf '  connect-network <ssid> %s [<passphrase>]\n  set-wifi-enabled enabled|disabled\n' "$modes"; return 255 ;;
        start-scan) return 0 ;;
        list-scan-results)
            case "$CASE" in no_scan|cached_wpa3) echo 'No scan results'; return 0;; esac
            flags='[WPA2-PSK-CCMP][ESS]'
            case "$CASE" in wpa3*) flags='[RSN-SAE+SAE_EXT_KEY-GCMP-256+CCMP][ESS]';; mixed) flags='[RSN-PSK+SAE-CCMP][ESS]';; esac
            name='Thor Test'; age=0.8
            [ "$CASE" != prefix_only ] || name='Thor Test Guest'
            [ "$CASE" != stale ] || age='>1000.0'
            printf '  00:11:22:33:44:55 5220 -51(0:-55/1:-52) %s %s    %s\n' "$age" "$name" "$flags"
            [ "$CASE" != fallback ] || echo '00:11:22:33:44:56 2412 -50 0.8 Thor Backup    [WPA2-PSK-CCMP][ESS]'
            return 0 ;;
        set-wifi-enabled) return 0 ;;
        connect-network)
            if [ "$CASE" = fallback ] && [ "$3" = 'Thor Test' ]; then return 5; fi
            if [ "$CASE" = fallback ]; then
                [ "$3" = 'Thor Backup' ] || return 8
                expected=$(sed -n '4p' "$PRIVATE_TEST/credentials")
            else
                [ "$3" = 'Thor Test' ] || return 8
                expected=$(sed -n '2p' "$PRIVATE_TEST/credentials")
            fi
            if [ "$CASE" = wpa3 ] || [ "$CASE" = cached_wpa3 ]; then [ "$4" = wpa3 ] || return 8; else [ "$4" = wpa2 ] || return 8; fi
            [ "$5" = "$expected" ] || return 8
            echo "SENTINEL_STDOUT:$5"
            echo "SENTINEL_STDERR:$5" >&2
            return 0 ;;
        status)
            echo 'Wifi is enabled'
            if [ "$CASE" = wrong ]; then echo 'Wifi is connected to "Other Network"';
            elif [ "$CASE" = fallback ]; then echo 'Wifi is connected to "Thor Backup"';
            else echo 'Wifi is connected to "Thor Test"'; fi ;;
    esac
}
ip() { echo '16: wlan0 inet 192.0.2.2/24 scope global wlan0'; }
set -- "${SCRIPT_MODE:-}"
. "$SCRIPT_TEST"
'''
    (root / 'harness.sh').write_text(harness, encoding='utf-8', newline='\n')
    for case, expected_code in [('success', 0), ('wrong', 3), ('unsafe', 1), ('wpa3',0), ('wpa3_unsupported',3), ('mixed',0), ('prefix_only',3), ('stale',0), ('no_scan',3), ('cached_wpa3',0), ('fallback', 0)]:
        for cached in (private/'security-cache').glob('*'):
            assert cached.resolve().parent==(private/'security-cache').resolve()
            cached.unlink()
        if case == 'fallback':
            with (private / 'credentials').open('a', encoding='utf-8', newline='\n') as file:
                file.write('Thor Backup\n' + password + '\n')
        env = dict(os.environ, CASE=case, PRIVATE_TEST=unix(private), SCRIPT_TEST=unix(root / 'reconnect.sh'))
        if case=='cached_wpa3':
            before=subprocess.run([BASH,unix(root/'harness.sh')],env=dict(env,CASE='wpa3',SCRIPT_MODE='--remember-security'),cwd=root,capture_output=True,text=True,timeout=10)
            assert before.returncode==0,(before.stdout,before.stderr)
            assert 'SECURITY_SNAPSHOT_OK' in before.stdout
        result = subprocess.run([BASH, unix(root / 'harness.sh')], env=env,
                                cwd=root, capture_output=True, text=True, timeout=10)
        outputs = result.stdout + result.stderr
        for log in (root / 'reports').glob('**/*.txt'):
            outputs += log.read_text(encoding='utf-8')
        assert result.returncode == expected_code, (case, result.returncode, outputs)
        assert password not in outputs and 'SENTINEL_' not in outputs, 'Credential output leak'
        assert not (root / 'NEVER_CREATED').exists(), 'Shell injection'
        print(f'PASS reconnect {case}: literal secret handling and no secret in output')
    before=subprocess.run([BASH,unix(root/'harness.sh')],env=dict(env,CASE='wpa3_unsupported',SCRIPT_MODE='--remember-security'),cwd=root,capture_output=True,text=True,timeout=10)
    assert before.returncode!=0 and 'STOP_UNSUPPORTED_FIRMWARE' in before.stdout
    print('PASS recovery preflight refuses unsupported WPA3 before forgetting')
print('Mock validation only; does not establish real Android reconnection.')
