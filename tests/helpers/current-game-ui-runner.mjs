import assert from 'node:assert/strict';
import {mkdtempSync,readFileSync,writeFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,resolve} from 'node:path';
import lua from 'luaparse';
import {createHash} from 'node:crypto';
import {luaString,toLua} from '../../scripts/build-lua-data.mjs';
export const currentGameUiFixture='tests/lua/game_ui.lua';
export const currentGameUiGroups=Object.freeze([[1,2,3,4],[5],[6,7,8,9,10,11,12],[13,14,15,16]].map(Object.freeze));
export const currentGameUiNames=Object.freeze([
  "menu shows only current version and keeps start/exit available without announcements",
  "new encounter resets stale target before the first attack-card tap",
  "menu starts real map, enters actual encounter, consumes reward and unlocks next layer",
  "defeat returns to menu and restart replaces the complete same-run state",
  "node panels compose through Boss16, independent treasure17 then restart",
  "same-run result records active time and victories, freezes on results and resets on restart",
  "result settlement sends each outcome once and cannot restart while official settlement is pending",
  "settlement callback failure is visible and retryable without claiming official completion",
  "menu keeps the introduction and start without route or control instructions",
  "result page shows only the recorded run stats in the approved four cells",
  "repeated settlement clicks, clicks during reveal and restart attempts submit exactly once",
  "result reveal settles exactly on approved frames and feedback motion never hides controls",
  "viewport scales each device uniformly and covers wider canvas outside the stage",
  "host defers defeat routing until the final feedback banner and releases result input once",
  "native lifecycle loads every composed control and registers its listeners only once",
  "startup failure is visible without log subscription and hides the dead start button"
]);
export const currentGameUiBodySha256=Object.freeze([
 "5b8ce1cda58cb679f937f8a983110c117fe787af79425dd39680028fa8e89269",
 "ed01879b2fd25f41b0d4525916ffc608a3eb1abe3a7aa7cc0257d329162ff198",
 "f77a42049e56de4b9b74c3ab1bccf0d57d6c02f055e33893bf3569ecfc5ea5cd",
 "c23c5126547396b7872a467e8696e44a497a74b9c6028623b3b0cbeb375e823c",
 "303a4a764678ac849c3e0e8ad50cded0781783455997149c1ad18031218d4e1c",
 "520ed56af5f77a4f380d400e2d1d868519b7fc131a12406611dbc5301bf4f291",
 "61a49a64acce8aa9f57c87d954ce489e1c397b5a756ddd42320ab28d62e870a5",
 "028b6db3e89369a63621df8725568b651da2cc2b986254e223f899a34608ac99",
 "a00c31a53ae355343e4f1ebbdd465116912bc751130f9f8c332f60445e8d21e4",
 "ff9b85b2bd5607be85008d15004bccd6f21913e7d759d3239c2d24e4df1dd629",
 "d8f464aaa8a5406c5cac598c4484a7c26c5dd277cb30dee960c6cb0ff419da31",
 "e0469074873efd592b70460cb387cee8072658e4743a3bfb45dc068eaf191421",
 "9c2967e9963bbee43624e7552250c25b0ab7f97464f9879c8e7583de945e0cf0",
 "accab671fbb076e5172d9462dd93a675b625a2d50097b8a4ddb8eac2a01f114b",
 "50e468aaaaa36c06bb954771723e358865daa79621ea273b3629e6bb0b5bcefa",
 "510c9f68b90c7cc4848ccef129d7e3ebe306cf930c747a3b1ead65febf3eb7c6"
]);
export function validateCurrentGameUiGroups(groups){
 assert(groups.every(g=>Array.isArray(g)&&g.length>0),'empty current entry group');
 assert.deepEqual(groups.flat(),Array.from({length:16},(_,i)=>i+1),'current entry groups must cover each original case exactly once in order');
}
export function inspectCurrentGameUiSource(source){
 source=source.replaceAll('\r\n','\n');
 const ast=lua.parse(source,{luaVersion:'5.3',ranges:true});
 const cases=ast.body.filter(n=>n.type==='CallStatement'&&n.expression.base?.name==='test');
 assert.equal(cases.length,16,'exact 16 original current entry cases');
 assert.deepEqual(cases.map(n=>JSON.parse(n.expression.arguments[0].raw)),currentGameUiNames,'original current entry case identities');
 const bodies=cases.map(n=>source.slice(...n.expression.arguments[1].range));
 assert.deepEqual(bodies.map(body=>createHash('sha256').update(body).digest('hex')),currentGameUiBodySha256,'original complete case bodies must remain intact');
 return bodies;
}
export function verifyCurrentGameUiGroup(stdout,group){
 const rows=stdout.split(/\r?\n/).filter(line=>line.startsWith('CURRENT_GAME_UI_CASE\t')).map(line=>line.split('\t'));
 assert.deepEqual(rows.map(r=>Number(r[1])),group,'missing, duplicate, skipped or extra current entry cases');
 for(const row of rows)assert.equal(row[2],currentGameUiNames[Number(row[1])-1],'current entry case identity mismatch');
 assert.deepEqual(stdout.split(/\r?\n/).filter(line=>line.startsWith('LUA_GAME_UI_GROUP_PASS ')),[`LUA_GAME_UI_GROUP_PASS ${group.length}`],'complete group marker required exactly once');
 assert(!/^LUA_GAME_UI_PASS /m.test(stdout),'child cannot certify the full original fixture');
}
export function runCurrentGameUi(runLua,script,{timeout=60000,cwd=process.cwd(),caseName}={}){
 const deadline=performance.now()+timeout;
 assert.equal(script.replaceAll('\\','/'),currentGameUiFixture,'only exact current game UI fixture');
 assert.equal(caseName,undefined,'all original current entry groups must execute');
 assert(Number.isFinite(timeout)&&timeout>0&&timeout<=60000,'original total current entry deadline cannot be extended');
 validateCurrentGameUiGroups(currentGameUiGroups);
 inspectCurrentGameUiSource(readFileSync(resolve(cwd,script),'utf8'));
 const remaining=()=>{const left=Math.floor(deadline-performance.now());assert(left>0,'current entry total deadline exhausted');return left;};
 const directory=mkdtempSync(join(tmpdir(),'abyss-current-entry-'));
 let last;const output=[];const errors=[];
 try{
  for(const [index,group]of currentGameUiGroups.entries()){
   const wrapper=join(directory,`group-${index+1}.lua`);
   writeFileSync(wrapper,`ABYSS_CURRENT_ENTRY_GROUP=${toLua(group)}\ndofile(${luaString(resolve(cwd,script))})\n`);
   last=runLua(wrapper,{cwd,timeout:remaining()});
   output.push(last.stdout??'');errors.push(last.stderr??'');
   remaining();
   if(last.status!==0)return {...last,stdout:output.join('\n'),stderr:errors.join('\n')};
   verifyCurrentGameUiGroup(last.stdout,group);
  }
  return {...last,status:0,stdout:output.join('\n')+'\nLUA_GAME_UI_PASS 16\n',stderr:errors.join('\n')};
 }finally{rmSync(directory,{recursive:true,force:true});}
}
