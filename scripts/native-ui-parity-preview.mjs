// Offline browser evidence only. No game window, input capture, or native acceptance.
import { mkdirSync, writeFileSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { runLua } from './test-lua.mjs';
import { page } from './node-ui-preview.mjs';

const out=resolve(process.argv[2] || '.artifacts/native-parity/preview');
mkdirSync(out,{recursive:true});
const host=runLua('scripts/native-ui-parity-preview.lua');
if(host.status!==0)throw new Error(host.stdout+host.stderr);
const rooms=runLua('scripts/node-ui-preview.lua');
if(rooms.status!==0)throw new Error(rooms.stdout+rooms.stderr);
const scenes=[...JSON.parse(host.stdout.split('PARITY_SCENES ')[1]),...JSON.parse(rooms.stdout)];
for(const scene of scenes)writeFileSync(join(out,scene.name+'.html'),page(scene.tree));
const python=String.raw`
import json,sys
from pathlib import Path
from playwright.sync_api import sync_playwright
out=Path(sys.argv[1]); names=json.loads(sys.argv[2]); results=[]
with sync_playwright() as p:
    browser=p.chromium.launch(executable_path=r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',headless=True)
    view=browser.new_page(viewport={'width':1280,'height':720})
    for name in names:
        view.goto((out/(name+'.html')).as_uri())
        view.screenshot(path=str(out/(name+'.png')))
        results.append({'screen':name,'clipped':view.locator('.clip').all_text_contents()})
    browser.close()
(out/'text-fit.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(results,ensure_ascii=False))
`;
const result=spawnSync(process.env.ABYSS_PYTHON || 'python',['-c',python,out,JSON.stringify(scenes.map(s=>s.name))],
  {encoding:'utf8',timeout:90000,env:{...process.env,PYTHONUTF8:'1'}});
if(result.status!==0)throw new Error(result.stderr || result.error?.message);
console.log(result.stdout);
