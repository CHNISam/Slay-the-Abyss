import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';import path from 'node:path';import os from 'node:os';
import {runLua} from '../scripts/test-lua.mjs';import {root,repo,themeSource,createSave,verifyAssets,moduleSources} from '../experiments/native-ui-preview/build.mjs';
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
function lua(parts,marker,{theme=false}={}){const dir=fs.mkdtempSync(path.join(os.tmpdir(),'native-ui-test-'));const file=path.join(dir,'test.lua');const prelude='package.path='+JSON.stringify(path.join(root,'battle/?.lua').replaceAll('\\','/'))+'..";"..package.path\n'+(theme?'package.preload.abyss_theme=function()\n'+themeSource()+'\nend\n':'');fs.writeFileSync(file,prelude+parts.map(read).join('\n'));try{const r=runLua(file,{timeout:30000});assert.equal(r.status,0,r.stdout+r.stderr);assert.equal(r.stderr,'');assert.match(r.stdout,marker);}finally{fs.rmSync(dir,{recursive:true,force:true});}}
test('menu source recurrence and interrupted navigation',()=>lua(['menu/controller.lua','menu/controller.test.lua'],/MENU_SEMANTIC_PASS assertions=63/));
test('shop approved easing, ownership, purchase and navigation',()=>lua(['shop/controller.lua','shop/controller.test.lua'],/SHOP_CONTROLLER_PASS/));
test('approved dashed arrow geometry',()=>lua(['battle/arrow.test.lua'],/ARROW_PASS checks=6/));
test('real Run command semantics retain rollback and event frames',()=>lua(['battle/semantic.test.lua'],/SEMANTIC_PASS/,{theme:true}));
test('battle adapter ownership, carry and hover-union regressions',()=>lua(['battle/test-prefix.lua','battle/scene.lua','battle/test-suffix.lua'],/PASS semantic selection\/cancel; stale ownership; live geometry; steady idle zero setters; carry capture visibility; failed setter retry; explicit Run.play/,{theme:true}));
test('all four native templates compile with unique controls and no embedded image data',()=>{for(const scene of ['menu','shop','battle','map']){const s=createSave(scene),ids=[];const walk=n=>{ids.push(n.id);for(const c of n.children??[])walk(c);};walk(s.assets.server.root.children[0]);assert.equal(new Set(ids).size,ids.length);assert.equal(s.assets.scripts.length,1);assert(!JSON.stringify(s).includes('data:image/'));assert(!JSON.stringify(s).includes('/workspace/'));}});
test('missing assets fail instead of loading unrelated official aliases',()=>assert.throws(()=>verifyAssets('menu',path.join(os.tmpdir(),'nonexistent-native-ui-private-cache')),/Required private asset/));
test('stale build modules cannot replace production Lua source',t=>{
 const realReadDir=fs.readdirSync;
 const realReadFile=fs.readFileSync;
 t.mock.method(fs,'readdirSync',function(dir,...args){const files=realReadDir.call(this,dir,...args);return path.resolve(dir)===path.join(repo,'build/lua')?[...files,'abyss_run.lua']:files;});
 t.mock.method(fs,'readFileSync',function(file,...args){return path.resolve(file)===path.join(repo,'build/lua/abyss_run.lua')?'return {stale=true}':realReadFile.call(this,file,...args);});
 assert.throws(()=>moduleSources(),/Generated module conflicts with source: abyss_run/);
});
test('only declared generated data modules enter the bundle',()=>{
 const sources=moduleSources();
 assert(sources.has('abyss_data')&&sources.has('abyss_original_v4_data')&&sources.has('abyss_theme'));
 assert(!sources.has('abyss_ui_templates'));
 assert.equal(sources.get('abyss_run'),fs.readFileSync(path.join(repo,'src/lua/abyss_run.lua'),'utf8'));
});
test('battle energy keeps the approved position and continuous dark-red outline',()=>{
 const battle=createSave('battle').assets.server.root.children[0].children.find(n=>n.name==='battle');
 const energy=battle.children.find(n=>n.name==='energy');
 assert.equal(energy.enableOutline,true);
 assert.equal(energy.outlineColor,0xff4c2425);
 assert.equal(energy.text,'3/3');
 assert.equal(energy.fontSize,29);
 for(const transform of Object.values(energy.transformByPlatform))assert.deepEqual(transform.offset,{x:-511,y:-233});
});
