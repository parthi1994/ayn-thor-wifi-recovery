"""Simulated /proc and timestamps: stale recovery must never cancel a live worker."""
from pathlib import Path
import subprocess,tempfile,os
BASH=r'C:\Program Files\Git\bin\bash.exe'
BASE=Path(__file__).resolve().parents[1]
def unix(p):
 s=str(p.resolve()).replace('\\','/');return '/'+s[0].lower()+s[2:]
with tempfile.TemporaryDirectory() as temp:
 for case in ['stale','fresh','alive','absent']:
  d=Path(temp)/case;d.mkdir();proc=d/'proc'/'123';proc.mkdir(parents=True)
  if case!='absent':(d/'working').write_text('BOOT')
  (proc/'cmdline').write_bytes(b'sh\0/data/local/thor-wifi/bin/workflow.sh\0worker\0' if case=='alive' else b'other\0')
  s=(BASE/'assets/engine/workflow_guard.sh').read_text().replace('/proc/',unix(d/'proc')+'/')
  (d/'guard.sh').write_text(s,encoding='utf8',newline='\n')
  harness='P='+unix(d)+'''\nstat(){ echo 100; }
date(){ if [ "$CASE" = fresh ]; then echo 105; else echo 200; fi; }
. "$P/guard.sh"
thor_clear_stale
'''
  (d/'run.sh').write_text(harness,encoding='utf8',newline='\n')
  r=subprocess.run([BASH,unix(d/'run.sh')],env=dict(os.environ,CASE=case),capture_output=True,text=True,timeout=10)
  assert r.returncode==0,(r.stdout,r.stderr)
  assert (d/'working').exists()==(case in ['fresh','alive'])
  if case=='stale':assert (d/'status').read_text().strip()=='WORKER_INTERRUPTED'
  else:assert not (d/'status').exists()
  print('PASS guard',case)
