import {readFileSync,mkdirSync,writeFileSync} from 'node:fs';
import {resolve,join,dirname} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {createRequire} from 'node:module';
import {toLua} from '../../../scripts/build-lua-data.mjs';
const here=dirname(fileURLToPath(import.meta.url)),repo=resolve(here,'../../..');
const require=createRequire(import.meta.url);
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
const types={attack:'攻击',skill:'技能',power:'能力',status:'状态',curse:'诅咒'};
export function buildLibrary({root=repo,seed=42,python=process.env.ABYSS_PYTHON||'python'}={}){
  if(!Number.isSafeInteger(seed)||seed<0||seed>65535)throw Error('Selector fixture seed must be 0..65535');
  const cli=require.resolve('fengari-node-cli/src/lua-cli.js');
  const code=`package.path='build/lua/?.lua;src/lua/?.lua;'..package.path;local F=dofile('experiments/native-3d-lab/selector/fixture.lua');local R=require('abyss_run');local run,meta=F.make(require('abyss_data'),${seed});print('SELECTOR_COMMANDS '..meta.commands);for _,id in ipairs(R.rewardOptions(run))do print('SELECTOR_ID '..id)end`;
  const output=execFileSync(process.execPath,[cli,'-e',code],{cwd:root,encoding:'utf8',timeout:30000,windowsHide:true});
  const ids=[...output.matchAll(/^SELECTOR_ID ([a-z0-9_]+)\r?$/gm)].map(m=>m[1]);
  if(ids.length!==3||new Set(ids).size!==3)throw Error('Expected three distinct real fixture reward IDs');
  const rendered=JSON.parse(execFileSync(python,['tools/render_traveler_cards.py','data/cards.json','data/presentation/traveler.zh-CN.json'],{cwd:root,encoding:'utf8',timeout:30000,windowsHide:true}));
  const source=JSON.parse(readFileSync(join(root,'data/cards.json'),'utf8'));
  const definitions=Object.fromEntries(source.cards.map(c=>[c.id,c]));
  const presentation=Object.fromEntries(rendered.cards.map(c=>[c.id,c]));
  const cards=[];
  for(const id of ids)for(const upgraded of [false,true]){
    const display=presentation[id],def=definitions[id];
    if(!display||!def)throw Error('Fixture reward lacks checked presentation: '+id);
    const body=upgraded?display.upgradeText:display.text,cost=upgraded?display.upgradeCost:display.cost;
    const title=display.name+(upgraded?'＋':''),description=`${types[def.type]||def.type} · 能量 ${cost}\n${body}`;
    if([...title].length>30||[...description].length>200||/[{}]/.test(description))throw Error('Native selector cannot preserve the full card text: '+id);
    cards.push({cardId:id,upgraded,number:cards.length+1,title,description,body,cost,type:def.type,
      icon:def.type==='attack'?91001:def.type==='skill'?91011:91016,label:'选择此牌'});
  }
  const inputs=['data/cards.json','data/presentation/traveler.zh-CN.json','tools/render_traveler_cards.py',
    'src/lua/abyss_run.lua','src/lua/abyss_run_settlement.lua','src/lua/abyss_battle_reward_owner.lua',
    'experiments/native-3d-lab/selector/fixture.lua'];
  return {schemaVersion:1,seed,encounter:'cultist_solo',fixtureKind:'real_run_commands_reward_fixture',
    fixtureCommands:Number(output.match(/^SELECTOR_COMMANDS (\d+)/m)?.[1]),cardIds:ids,cards,
    sourceInputs:inputs.map(path=>{const bytes=readFileSync(join(root,path));return {path,sha256:hash(bytes),bytes:bytes.length}}),
    limits:{normalThreeCardRewardOnly:true,libraryCards:cards.length,toolLibraryLimit:30,dynamicText:false,
      officialLibraryLimit:1000,officialTextLimit:1000,officialLimitSource:'https://act.mihoyo.com/ys/ugc/tutorial/detail/mh74ae9fsg8i',
      unsupportedMechanisms:['singing_bowl','prayer_wheel','cardRewardGroups','pendingCardRewardSelection','originalV4','offered_cards_outside_library']}};
}
export function graphSource({graph,selectorId,librarySize}){
  if(!graph||!Number.isSafeInteger(graph.graphId)||!Number.isSafeInteger(selectorId)||selectorId<=0||librarySize<1||librarySize>30)throw Error('Selector graph requires actual IDs and bounded library');
  const reply=(token,result,reason)=>`f.sendSignal(REPLY,player,${token},${result},${reason});`;
  const invoke=count=>`f.invokeDeckSelector(player,${selectorId}n,25,[${Array.from({length:count},(_,i)=>`token*16n+${i+1}n`).join(',')}],[${['a','b','c'].slice(0,count)}],1n,1n,DecisionRefreshMode.CannotRefresh,0n,0n,[token*16n]);`;
  return `/// <reference types="genshin-ts" />
import {g,defineSignal} from 'genshin-ts/runtime/core'
import {DecisionRefreshMode,SelectCompletionReason} from 'genshin-ts/definitions/enum'
const OPEN=defineSignal('LAB_SELECTOR_OPEN',[['token','int'],['count','int'],['a','int'],['b','int'],['c','int']] as const)
const CANCEL=defineSignal('LAB_SELECTOR_CANCEL',[['token','int']] as const)
const REPLY=defineSignal('client:LAB_SELECTOR_REPLY',[['player','entity'],['token','int'],['result','int'],['reason','str']] as const)
g.server({id:${graph.graphId},name:${JSON.stringify(graph.name)},variables:{pendingToken:0n,lastToken:0n,closing:false}})
.onSignal(OPEN,(evt,f)=>{
 const players=f.getListOfPlayerEntitiesOnTheField();if(players.length!==1)return;const player=players[0];
 const token=evt.params.token,count=evt.params.count,a=evt.params.a,b=evt.params.b,c=evt.params.c;
 if(token<=0n||token>100000000n){${reply('token','0n',"'error:token'")}return;}
 if(f.get('pendingToken')!==0n){${reply('token','0n',"'busy:previous_selector'")}return;}
 if(token<=f.get('lastToken')){${reply('token','0n',"'stale:token'")}return;}
 if(count<1n||count>3n||a<1n||a>${librarySize}n||count>=2n&&(b<1n||b>${librarySize}n)||count===3n&&(c<1n||c>${librarySize}n)){${reply('token','0n',"'error:library_reference'")}return;}
 f.set('lastToken',token);f.set('pendingToken',token);f.set('closing',false);
 if(count===1n){${invoke(1)}}else if(count===2n){${invoke(2)}}else{${invoke(3)}}
 f.startTimer(player,'LS_WATCHDOG',false,[35]);${reply('token','0n',"'opened:await_selection'")}
})
.onSignal(CANCEL,(evt,f)=>{
 const players=f.getListOfPlayerEntitiesOnTheField();if(players.length!==1)return;const player=players[0];const token=evt.params.token;
 if(token!==f.get('pendingToken')){${reply('token','0n',"'cancelled:already_closed'")}return;}
 f.set('closing',true);f.closeDeckSelector(player,${selectorId}n);${reply('token','0n',"'closing:await_native_event'")}
})
.on('whenDeckSelectorIsComplete',(evt,f)=>{
 if(evt.deckSelectorIndex!==${selectorId}n)return;const player=evt.targetPlayer,token=f.get('pendingToken');if(token===0n)return;
 let result=0n;if(evt.selectionResultList.length===1)result=evt.selectionResultList[0];
 if(result!==0n&&result!==token*16n&&result!==token*16n+1n&&result!==token*16n+2n&&result!==token*16n+3n)return;
 f.stopTimer(player,'LS_WATCHDOG');
 const wasClosing=f.get('closing');f.set('pendingToken',0n);f.set('closing',false);
 if(wasClosing){${reply('token','0n',"'cancelled:node_close'")}return;}
 if(evt.completionReason===SelectCompletionReason.CompletedByPlayer&&evt.selectionResultList.length===1){${reply('token','result',"'selected'")}}
 else if(evt.completionReason===SelectCompletionReason.Timeout){${reply('token','0n',"'timeout'")}}
 else if(evt.completionReason===SelectCompletionReason.ClosedManually){${reply('token','0n',"'cancelled:player'")}}
 else{${reply('token','0n',"'cancelled:other'")}}
})
.on('whenTimerIsTriggered',(evt,f)=>{
 if(evt.timerName!=='LS_WATCHDOG')return;const token=f.get('pendingToken');if(token===0n)return;
 const players=f.getListOfPlayerEntitiesOnTheField();if(players.length!==1)return;const player=players[0];f.set('closing',true);f.closeDeckSelector(player,${selectorId}n);
 ${reply('token','0n',"'error:native_event_timeout_restore_classic'")}
})
`;
}
export async function install({call,mapPath,library=buildLibrary(),output}={}){
  if(typeof call!=='function'||!mapPath)throw Error('Selector install requires call and a save copy');
  const invoke=async(name,args={})=>{const result=await call(name,{mapPath,...args});if(result.mapPath)mapPath=result.mapPath;return result};
  const selected=await invoke('scene_add_card_selector',{name:'LAB_REWARD_SELECTOR',title:'战后选牌对照 · 原生窗口',seconds:25,
    cards:library.cards.map(({title,description,icon,label})=>({title,description,icon,label})),canGiveUp:true,canFold:true,pauseWhenAlone:false,showTime:true});
  if(!Number.isSafeInteger(selected.selectorId)||selected.selectorId<=0)throw Error('Native selector did not return a real ID');
  for(const [name,parameters] of [
    ['LAB_SELECTOR_OPEN',[{name:'token',type:'integer'},{name:'count',type:'integer'},{name:'a',type:'integer'},{name:'b',type:'integer'},{name:'c',type:'integer'}]],
    ['LAB_SELECTOR_CANCEL',[{name:'token',type:'integer'}]],
    ['LAB_SELECTOR_REPLY',[{name:'token',type:'integer'},{name:'result',type:'integer'},{name:'reason',type:'string'}]],
  ])await invoke('scene_add_signal',{name,parameters});
  const graph=await invoke('scene_add_graph',{name:'LAB_REWARD_SELECTOR',attachToPrefab:'player',kind:'server'});
  const code=graphSource({graph,selectorId:selected.selectorId,librarySize:library.cards.length});
  const compiled=await invoke('write_graphs',{graphs:[{graphId:graph.graphId,code}]});
  if(compiled.failed||compiled.errors?.length||compiled.written?.length!==1)throw Error('Selector graph did not compile/write: '+JSON.stringify(compiled));
  const inspected=await invoke('inspect_map');const readback=inspected.graphs.find(g=>g.id===graph.graphId);
  if(!readback||readback.nodeCount<=0)throw Error('Selector graph readback missing');
  const config={...library,selectorId:selected.selectorId,graphId:graph.graphId,available:true,seconds:25};
  const receipt={kind:'native-selector-static-experiment',mapPath,selectorId:selected.selectorId,graph,readback,config,
    code,compiled,maintenance:{nativeSelectorTemplates:1,uiRecords:4,serverGraphs:1,signals:3,luaModules:3,libraryEntries:library.cards.length},
    verification:{compiled:true,graphReadback:true,officialImport:'not_run',nativeSelection:'not_run',mobile:'not_run'}};
  if(output){mkdirSync(output,{recursive:true});writeFileSync(join(output,'selector.ts'),code);writeFileSync(join(output,'selector.json'),JSON.stringify(receipt,null,2));writeFileSync(join(output,'abyss_3d_selector_config.lua'),'return '+toLua(config)+'\n');}
  return receipt;
}
// Read the four records actually written, independently of the graph compiler.
export async function readbackSelector(mapPath,selectorId,cards,{toolRoot=process.env.MILIASTRA_MCP_ROOT||'D:/MiliastraTools/genshin-miliastra-mcp'}={}){
  const {container,fields,one}=await import(pathToFileURL(join(toolRoot,'src/scene/wire.mjs')));
  const root=container(readFileSync(mapPath));
  const rows=fields(one(root,9)).filter(f=>f.id===502&&f.wire===2)
    .map(f=>({id:Number(one(f.data,501,0)),data:f.data}));
  const wanted=Array.from({length:4},(_,i)=>selectorId+i);
  const records=wanted.map(id=>{const matches=rows.filter(r=>r.id===id);if(matches.length!==1)throw Error('Selector UI record missing/duplicated: '+id);return matches[0]});
  for(const panel of [records[1],records[3]])for(const card of cards){
    for(const value of [card.title,card.description,card.label])if(!panel.data.includes(Buffer.from(value)))throw Error('Native selector UI text readback differs: '+card.cardId);
  }
  return {recordIds:wanted,records:records.map(r=>({id:r.id,sha256:hash(r.data),bytes:r.data.length})),
    fullCardTextMatches:true,libraryEntries:cards.length,scope:'Written native selector records only; does not prove text visibility or interaction in the game'};
}
