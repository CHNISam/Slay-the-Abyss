import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
import {readFileSync,writeFileSync,unlinkSync} from 'node:fs';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {randomUUID} from 'node:crypto';
import {luaString} from '../scripts/build-lua-data.mjs';

test('generated host starts under native capability guards and rejects the escaped startup write',()=>{
  const source=readFileSync('src/lua/abyss_battle_ui.lua','utf8');
  const anchor='hit:SetVisible(frame.fighting==true and options.onPile~=nil and frame.active==true)';
  assert.equal(source.split(anchor).length,2,'mutation must target exactly one production line');
  const mutant=source.replace(anchor,'hit:SetVisible(frame.fighting==true); hit.interactable=options.onPile~=nil and frame.active==true');
  const entry=join(tmpdir(),`abyss-native-contract-${randomUUID()}.lua`);
  writeFileSync(entry,`ABYSS_NATIVE_MUTANT=${luaString(mutant)}\ndofile('tests/lua/support/native_startup_contract.lua')\n`);
  try {
    const result=runLua(entry);
    assert.equal(result.status,0,result.stdout+result.stderr);
    assert.match(result.stdout,/NATIVE_STARTUP_CONTRACT_PASS/);
  } finally {unlinkSync(entry);}
});

