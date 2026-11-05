import test from 'node:test';
import assert from 'node:assert/strict';
const load=()=>import('./result-model.js');
test('failure never exposes the victory-only optional illustration',async()=>{
 const m=await load();const r=m.resultModel({outcome:'defeat',floor:8,hp:0,maxHp:80,battlesWon:5,deck:10});
 assert.equal(r.canViewEasterEgg,false);assert.equal(r.title,'旅途在此中断');assert.equal(r.hp,'0 / 80');assert.equal(r.time,'未记录');
});
test('double-act victory uses the project ending without inventing score or unlock progress',async()=>{
 const m=await load();const r=m.resultModel({outcome:'victory',scope:'two-acts',floor:34,hp:23,maxHp:80,battlesWon:16,deck:26,elapsedSeconds:2440});
 assert.equal(r.canViewEasterEgg,true);assert.equal(r.title,'双幕挑战完成');assert.equal(r.time,'40:40');assert.equal(r.score,null);assert.equal(r.floor,34);
});
test('malformed numeric fields cannot create impossible result values',async()=>{
 const m=await load();const r=m.resultModel({outcome:'bogus',floor:-1,hp:900,maxHp:80,battlesWon:-3,elapsedSeconds:NaN,deck:-2});
 assert.equal(r.outcome,'defeat');assert.equal(r.floor,0);assert.equal(r.hp,'80 / 80');assert.equal(r.battlesWon,0);assert.equal(r.deck,0);assert.equal(r.time,'未记录');
});
test('prototype run storage survives navigation but not a new page instance',async()=>{
 const a=await import('./run-memory.js?first');a.runMemory.setItem('run','{"hp":70}');assert.equal(a.runMemory.getItem('run'),'{"hp":70}');
 const b=await import('./run-memory.js?second');assert.equal(b.runMemory.getItem('run'),null);a.runMemory.removeItem('run');assert.equal(a.runMemory.getItem('run'),null);
});

test('ending a run snapshots results then clears route, battle and blessing sessions',async()=>{
 const {readFile}=await import('node:fs/promises');const {runInNewContext}=await import('node:vm');
 const source=await readFile(new URL('./app.js',import.meta.url),'utf8');
 // Exercise the actual app orchestration without booting the DOM-heavy lab shell.
 const endRun=source.slice(source.indexOf('function endRun('),source.indexOf('\nconst refs='));
 const calls=[];const context={runStatus:{hp:66,maxHp:80,battlesWon:2,startedAt:null},route:{current:'first',visited:['first'],pending:'second'},nodeById:new Map([['second',{floor:3}]]),current:()=>({floor:2}),freshRun:()=>({hp:80,maxHp:80,phase:'idle'}),resetBattle:(variant,run)=>calls.push(['battle',variant,run.hp]),resetBlessing:()=>calls.push(['blessing']),saveRun:()=>calls.push(['saveRun']),save:()=>calls.push(['saveRoute']),render:()=>calls.push(['render'])};
 runInNewContext(endRun+";endRun('defeat',{hp:61,deck:12})",context);
 assert.equal(context.resultData.hp,61);assert.equal(context.resultData.deck,12);assert.equal(context.resultData.floor,4);assert.equal(context.resultData.battlesWon,2);
 assert.equal(context.runStatus.phase,'idle');assert.equal(context.runStatus.hp,80);assert.equal(context.route.current,null);assert.equal(context.route.visited.length,0);assert.equal(context.route.pending,undefined);
 assert.deepEqual(calls,[['blessing'],['battle','A',80],['saveRun'],['saveRoute'],['render']]);assert.equal(context.page,'victory');
});
