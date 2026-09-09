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
        help) printf '  connect-network <ssid> open|wpa2 [<passphrase>]\n  set-wifi-enabled enabled|disabled\n'; return 255 ;;
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
            [ "$4" = wpa2 ] || return 8
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
. "$SCRIPT_TEST"
'''
    (root / 'harness.sh').write_text(harness, encoding='utf-8', newline='\n')
    for case, expected_code in [('success', 0), ('wrong', 3), ('unsafe', 1), ('fallback', 0)]:
        if case == 'fallback':
            with (private / 'credentials').open('a', encoding='utf-8', newline='\n') as file:
                file.write('Thor Backup\n' + password + '\n')
        env = dict(os.environ, CASE=case, PRIVATE_TEST=unix(private), SCRIPT_TEST=unix(root / 'reconnect.sh'))
        result = subprocess.run([BASH, unix(root / 'harness.sh')], env=env,
                                cwd=root, capture_output=True, text=True, timeout=10)
        outputs = result.stdout + result.stderr
        for log in (root / 'reports').glob('**/*.txt'):
            outputs += log.read_text(encoding='utf-8')
        assert result.returncode == expected_code, (case, result.returncode, outputs)
        assert password not in outputs and 'SENTINEL_' not in outputs, 'Credential output leak'
        assert not (root / 'NEVER_CREATED').exists(), 'Shell injection'
        print(f'PASS reconnect {case}: literal secret handling and no secret in output')
print('Mock validation only; does not establish real Android reconnection.')
