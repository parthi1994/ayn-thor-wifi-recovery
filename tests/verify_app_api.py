"""Exercise catalog mutations with isolated files and mocked root/worker. No ADB."""
import os, subprocess, tempfile
from pathlib import Path
SOURCE=Path(__file__).resolve().parents[1]
BASH=r'C:\Program Files\Git\bin\bash.exe'
def unix(p):
    s=str(p.resolve()).replace('\\','/')
    return '/'+s[0].lower()+s[2:]
with tempfile.TemporaryDirectory(prefix='thor-api-') as temp:
    for case in ['save_literal','save_empty','save_invalid','save_busy','connect_selected','connect_invalid']:
        base=Path(temp)/case; base.mkdir(); p=base/'private';p.mkdir();a=base/'exchange';a.mkdir(); public=base/'catalog.txt'
        (p/'bin').mkdir();(p/'bin/workflow_guard.sh').write_text((SOURCE/'assets/engine/workflow_guard.sh').read_text(encoding='utf8'),encoding='utf8',newline='\n')
        public.write_text('SSID=Original\nMOT_DE_PASSE=Original123!\n',encoding='utf8')
        (p/'credentials').write_text('Original\nOriginal123!\n',encoding='utf8')
        secret="Literal$(never) ' # \\!"
        request=f'SSID=Chosen\nMOT_DE_PASSE={secret}\n'
        if case=='save_empty':request='# empty catalog\n'
        if case.endswith('invalid'):request='SSID=Chosen\nMOT_DE_PASSE=short\n'
        if case=='save_busy':(p/'pending').write_text('OLD_BOOT')
        (a/('selection-request.txt' if case.startswith('connect') else 'catalog-request.txt')).write_text(request,encoding='utf8')
        code=(SOURCE/'assets/engine/app_api.sh').read_text(encoding='utf8').replace('/data/local/thor-wifi',unix(p)).replace('/data/user/0/local.thor.wifiresume/files/exchange',unix(a)).replace('/sdcard/Download/Thor-Scripts/WIFI_RESEAUX.txt',unix(public)).replace('/sdcard/Download/Thor-Scripts/.WIFI_RESEAUX.tmp',unix(base/'staged.txt'))
        script=base/'api.sh';script.write_text(code,encoding='utf8',newline='\n')
        harness=base/'harness.sh';harness.write_text(r'''
id(){ echo 0; }
stat(){ echo 0:0; }
chown(){ :; }
cat(){ if [ "$1" = /proc/sys/kernel/random/boot_id ]; then echo TEST_BOOT; else command cat "$@"; fi; }
nohup(){ echo WORKER_DISPATCHED > "$TEST_DIR/worker"; }
set -- "$OP"
. "$API_SCRIPT"
''',encoding='utf8',newline='\n')
        r=subprocess.run([BASH,unix(harness)],env=dict(os.environ,TEST_DIR=unix(base),API_SCRIPT=unix(script),OP='connect' if case.startswith('connect') else 'save'),capture_output=True,text=True,timeout=10)
        assert secret not in r.stdout+r.stderr and 'Original123!' not in r.stdout+r.stderr
        if case in ['save_invalid','save_busy','connect_invalid']:
            assert r.returncode!=0,(case,r.stdout,r.stderr)
            assert public.read_text()=='SSID=Original\nMOT_DE_PASSE=Original123!\n'
            assert (p/'credentials').read_text()=='Original\nOriginal123!\n'
        elif case=='save_empty':
            assert r.returncode==0 and not (p/'credentials').exists()
            assert public.read_text()=='# empty catalog\n'
        elif case=='save_literal':
            assert r.returncode==0,(r.stdout,r.stderr)
            assert public.read_text()==request
            assert (p/'credentials').read_text()==f'Chosen\n{secret}\n'
        elif case=='connect_selected':
            assert r.returncode==0,(r.stdout,r.stderr)
            assert (p/'credentials').read_text()==f'Chosen\n{secret}\n'
            assert public.read_text()=='SSID=Original\nMOT_DE_PASSE=Original123!\n'
            assert (p/'working').exists() and (base/'worker').exists()
        assert not (p/'app-lock').exists()
        print('PASS',case)
print('No real device or saved Android networks touched.')
