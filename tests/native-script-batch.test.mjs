import test from 'node:test';
import assert from 'node:assert/strict';
import luaparse from 'luaparse';
import {validateNativeLua} from '../scripts/native-script-batch.mjs';
import {writeScriptBatch} from '../scripts/native-script-batch.mjs';
import {mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {pathToFileURL} from 'node:url';
import {fixtureMapBytes,installNativeToolchainFixture,readFixtureScripts} from './helpers/native-toolchain-fixture.mjs';
function syntax(source){try{luaparse.parse(source,{luaVersion:'5.3'});return null;}catch(error){return error;}}
test('batch writer preserves native syntax and unavailable-API checks',()=>{
 for(const source of ['io.open("x")','os.execute("x")','coroutine.create(function()end)','load("x")','package.loaded.x=1','debug.getinfo(1)','string.dump(function()end)'])
  assert.throws(()=>validateNativeLua(source,syntax),/Unsupported native Lua API/);
 assert.throws(()=>validateNativeLua('function broken(',syntax),/Lua syntax/);
 assert.throws(()=>validateNativeLua('',syntax),/Empty/);
 assert.doesNotThrow(()=>validateNativeLua('-- io.open("x")\nlocal text="package.loaded"; return os.clock()',syntax));
});

test('batch additions preserve existing filenames and avoid existing and pending export collisions',async t=>{
 const dir=mkdtempSync(join(tmpdir(),'abyss-batch-files-'));t.after(()=>rmSync(dir,{recursive:true,force:true}));
 const tool=join(dir,'tool');installNativeToolchainFixture(tool,'export class Client {}');
 const wire=await import(pathToFileURL(join(tool,'src/scene/wire.mjs')));
 const {clientScriptRecord}=await import(pathToFileURL(join(tool,'src/scene-save.mjs')));
 const input=join(dir,'base.gil');
 writeFileSync(input,fixtureMapBytes([{name:'abyss_old',file:'abyss_new.lua',source:'return 1'},
  {name:'abyss_other',file:'script_3.lua',source:'return 2'}]));
 const output=writeScriptBatch(input,[{name:'abyss_new',source:'return 3'},
  {name:'script_3_2',source:'return 4'},{name:'abyss_old',source:'return 5'}],dir,{...wire,clientScriptRecord,luaSyntaxError:syntax});
 const rows=readFixtureScripts(output);
 assert.equal(rows.length,4);assert.equal(new Set(rows.map(row=>row.file)).size,4,'exported Lua files must be unique');
 assert.equal(rows.find(row=>row.name==='abyss_old').file,'abyss_new.lua');
 assert.equal(rows.find(row=>row.name==='abyss_new').file,'script_3_2.lua');
 assert.equal(rows.find(row=>row.name==='script_3_2').file,'script_4.lua');
 for(const [name,source]of [['abyss_old','return 5'],['abyss_other','return 2'],['abyss_new','return 3'],['script_3_2','return 4']])
  assert.equal(rows.find(row=>row.name===name).source,source);
 assert.equal(readFixtureScripts(input).length,2,'base map must stay untouched');
});
