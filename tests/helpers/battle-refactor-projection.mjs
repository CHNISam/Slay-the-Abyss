import {tryBattleGovernanceSource} from './battle-ui-governance-inverse.mjs';
import {tryApprovedBattleRefactorSource} from './approved-battle-responsibilities.mjs';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const bytes=readFileSync('tests/fixtures/battle-ui-refactor-projection.json','utf8').replaceAll('\r\n','\n');
assert.equal(createHash('sha256').update(bytes).digest('hex'),'a774d2c33c106ccfff8c0dda1cf54781a6cd544c7e31e4271006dc188caa4e8d','complete frozen Battle UI projection identity');
const snapshot=JSON.parse(bytes);
const digest=s=>createHash('sha256').update(s.replaceAll('\r\n','\n')).digest('hex');
// Historical replay only. Live UI and input tests load the actual responsibility modules.
export function preBattleRefactorSource(path,source){
 const approved=tryApprovedBattleRefactorSource(path,source);
 if(approved!==undefined)return approved;
 if(path!=='src/lua/abyss_battle_ui.lua'||source===null||digest(source)===digest(snapshot.before))return source;
 assert.equal(digest(source),snapshot.hashes[path],'unreviewed integrated retirement source drift: complete Battle UI composition identity');
 for(const [file,expected]of Object.entries(snapshot.hashes))
  assert.equal(digest(readFileSync(file,'utf8')),expected,'unreviewed integrated retirement source drift: Battle UI responsibility: '+file);
 return snapshot.before;
}

// Older replay layers must retain their own exact intermediate witnesses.
export function preBattleRefactorLayer(path,source){
 const governance=tryBattleGovernanceSource(path,source);
 if(governance!==undefined)return governance;
 const approved=tryApprovedBattleRefactorSource(path,source);
 if(approved!==undefined)return approved;
 if(path!=='src/lua/abyss_battle_ui.lua'||source===null)return source;
 const normalized=source.replaceAll('\r\n','\n');
 return digest(normalized)===snapshot.hashes[path]?preBattleRefactorSource(path,normalized):normalized;
}
