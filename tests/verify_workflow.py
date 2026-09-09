"""Mock destructive calls: verify exact SSID scope and fail-closed reboot guards."""
import os
import subprocess
import tempfile
from pathlib import Path
BASE=Path(__file__).resolve().parent
BASH=r'C:\Program Files\Git\bin\bash.exe'
def unix(p):
    s=str(p.resolve()).replace('\\','/')
    return '/'+s[0].lower()+s[2:]
source=(BASE.parent/'assets/engine/workflow.sh').read_text(encoding='utf-8')
with tempfile.TemporaryDirectory(prefix='workflow-test-',dir=BASE) as tmp:
    root=Path(tmp)
    for case in ['exact_match','missing_credentials','missing_companion','forget_failed','public_literal','public_invalid','selected_only','busy_snapshot']:
        p=root/case;p.mkdir();(p/'bin').mkdir()
        if case!='missing_credentials': (p/'credentials').write_text('Home\nDummyOnly123!\n',encoding='utf-8',newline='\n')
        (p/'companion-tested').touch()
        (p/'saved').write_text('Network Id SSID Security type\n0            Home                            wpa2-psk\n0            Home                            wpa3-sae^\n1            Home Guest                      wpa2-psk\n2            Other                           wpa2-psk\n',encoding='utf-8',newline='\n')
        script=source.replace('/data/local/thor-wifi',unix(p))
        script=script.replace('/sdcard/Download/Thor-Scripts/WIFI_RESEAUX.txt',unix(p/'public.txt'))
        if case=='public_literal':
            (p/'public.txt').write_bytes(b'# local config\r\nSSID=Home\r\nMOT_DE_PASSE=literal $(touch SHOULD_NOT_EXIST) # !\r\n')
        elif case=='public_invalid':
            (p/'public.txt').write_text('SSID=Home\nMOT_DE_PASSE=short\n',encoding='utf-8',newline='\n')
        elif case in ['selected_only','busy_snapshot']:
            (p/'public.txt').write_text('SSID=Other\nMOT_DE_PASSE=OtherOnly123!\n',encoding='utf-8',newline='\n')
            if case=='busy_snapshot': (p/'pending').write_text('OLD_BOOT')
        (p/'workflow.sh').write_text(script,encoding='utf-8',newline='\n')
        harness=r'''
id(){ echo 0; }
stat(){ if [ -d "${@: -1}" ]; then echo 0:0:700; else echo 0:0:600; fi; }
cat(){ if [ "$1" = /proc/sys/kernel/random/boot_id ]; then echo TEST_BOOT; else command cat "$@"; fi; }
timeout(){ shift 3; "$@"; }
pm(){ [ "$CASE" != missing_companion ]; }
sleep(){ :; }
sync(){ :; }
reboot(){ echo reboot > "$TEST_DIR/reboot-called"; }
cmd(){
 case "$2" in
 help) printf '  forget-network <networkId>\n  connect-network <ssid> open|wpa2\n'; return 255;;
 list-networks) command cat "$TEST_DIR/saved";;
 forget-network)
   [ "$CASE" != forget_failed ] || return 1
   echo "$3" >> "$TEST_DIR/deleted"
   awk -v id="$3" '$1 != id' "$TEST_DIR/saved" > "$TEST_DIR/saved.tmp"
   mv "$TEST_DIR/saved.tmp" "$TEST_DIR/saved";;
 esac
}
set -- forget
[ "$CASE" != selected_only ] || set -- forget-selected
. "$TEST_DIR/workflow.sh"
'''
        (p/'harness.sh').write_text(harness,encoding='utf-8',newline='\n')
        result=subprocess.run([BASH,unix(p/'harness.sh')],env=dict(os.environ,CASE=case,TEST_DIR=unix(p)),capture_output=True,text=True,timeout=10)
        if case in ['exact_match','public_literal','selected_only']:
            assert result.returncode==0,(result.stdout,result.stderr)
            assert (p/'deleted').read_text().split()==['0']
            assert (p/'reboot-called').exists() and (p/'pending').exists()
            assert 'Home Guest' in (p/'saved').read_text() and 'Other' in (p/'saved').read_text()
            if case=='public_literal':
                assert 'literal $(touch SHOULD_NOT_EXIST) # !' in (p/'credentials').read_text()
                assert not (p/'SHOULD_NOT_EXIST').exists()
        else:
            assert result.returncode!=0,(case,result.stdout,result.stderr)
            assert not (p/'reboot-called').exists()
            if case=='busy_snapshot':
                assert (p/'pending').read_text()=='OLD_BOOT'
                assert (p/'credentials').read_text()=='Home\nDummyOnly123!\n'
            else: assert not (p/'pending').exists()
        assert 'DummyOnly123!' not in result.stdout+result.stderr
        assert 'literal $(' not in result.stdout+result.stderr
        print('PASS',case)
print('No real network forgotten or reboot performed by these tests.')
