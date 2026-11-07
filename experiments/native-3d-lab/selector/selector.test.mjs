import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFileSync} from 'node:fs';
import {graphSource,buildLibrary,readbackSelector} from './install.mjs';
function harness(){
  const handlers={},vars={},replies=[],invocations=[],closed=[];
  const reason={CompletedByPlayer:'selected',Timeout:'timeout',ClosedManually:'cancelled',ClosedByNodeGraph:'node_closed'};
  const g={server(spec){Object.assign(vars,spec.variables);return {onSignal(name,fn){handlers[name]=fn;return this},on(name,fn){handlers[name]=fn;return this}}}};
  const f={getListOfPlayerEntitiesOnTheField:()=>['player'],get:key=>vars[key],set:(key,value)=>vars[key]=value,
    sendSignal:(_name,_player,token,result,reason)=>replies.push({token,result,reason}),
    invokeDeckSelector:(...args)=>invocations.push(args),closeDeckSelector:(...args)=>closed.push(args),startTimer(){},stopTimer(){}};
  const code=graphSource({graph:{graphId:101,name:'_GSTS_SELECTOR'},selectorId:201,librarySize:6})
    .replace(/^import .*\r?\n/gm,'').replace(/ as const/g,'');
  vm.runInNewContext(code,{g,defineSignal:name=>name,DecisionRefreshMode:{CannotRefresh:0},SelectCompletionReason:reason});
  return {handlers,vars,replies,invocations,closed,
    open:(token=1n,count=3n,a=1n,b=3n,c=5n)=>handlers.LAB_SELECTOR_OPEN({params:{token,count,a,b,c}},f),
    cancel:token=>handlers.LAB_SELECTOR_CANCEL({params:{token}},f),
    complete:(list,completionReason=reason.CompletedByPlayer,id=201n)=>handlers.whenDeckSelectorIsComplete({targetPlayer:'player',selectionResultList:list,completionReason,deckSelectorIndex:id},f),
    watchdog:()=>handlers.whenTimerIsTriggered({timerName:'LS_WATCHDOG',eventSourceEntity:'player'},f)};
}
test('dynamic library subset and token-coded results preserve slot identity including repeated card IDs',()=>{
  const h=harness();h.open(1n,2n,6n,1n,0n);
  assert.deepEqual(Array.from(h.invocations[0][3]),[17n,18n]);
  assert.deepEqual(Array.from(h.invocations[0][4]),[6n,1n]);
  assert.deepEqual(Array.from(h.invocations[0][10]),[16n]);
  h.open(2n);assert.equal(h.replies.at(-1).reason,'busy:previous_selector');
  h.complete([33n]);assert.equal(h.vars.pendingToken,1n,'stale encoded result cannot finish a newer owner');
  h.complete([18n]);assert.equal(h.replies.at(-1).reason,'selected');assert.equal(h.replies.at(-1).result,18n);
  const count=h.replies.length;h.complete([18n]);assert.equal(h.replies.length,count,'duplicate completion ignored');
});
test('cancel and watchdog drain the old native window before another token can open',()=>{
  const h=harness();h.open();h.cancel(1n);h.open(2n);
  assert.equal(h.replies.at(-1).reason,'busy:previous_selector');assert.equal(h.closed.length,1);
  h.complete([],'node_closed');assert.equal(h.replies.at(-1).reason,'cancelled:node_close');assert.equal(h.vars.pendingToken,0n);
  h.open(2n);assert.equal(h.vars.pendingToken,2n);h.watchdog();
  assert.equal(h.replies.at(-1).reason,'error:native_event_timeout_restore_classic');
  h.open(3n);assert.equal(h.replies.at(-1).reason,'busy:previous_selector');
  h.complete([33n]);assert.equal(h.replies.at(-1).reason,'cancelled:node_close','late selection after close cannot grant');
});
test('native timeout/default never becomes a player selection and wrong selector events are ignored',()=>{
  const h=harness();h.open();h.complete([17n],'selected',999n);assert.equal(h.vars.pendingToken,1n);
  h.complete([16n],'timeout');assert.equal(h.replies.at(-1).reason,'timeout');assert.equal(h.replies.at(-1).result,0n);
  h.open(2n,3n,7n,1n,3n);assert.equal(h.replies.at(-1).reason,'error:library_reference');
  assert.equal(h.invocations.length,1);
});
test('real rules reward fixture library reuses checked full text and both upgrade versions',()=>{
  const library=buildLibrary();
  assert.deepEqual(library.cardIds,['shockwave','clash','shrug_it_off']);assert.equal(library.fixtureCommands,18);
  assert.equal(library.cards.length,6);assert.equal(library.limits.dynamicText,false);
  for(const id of library.cardIds){
    const pair=library.cards.filter(c=>c.cardId===id);assert.equal(pair.length,2);
    assert.equal(pair[1].upgraded,true);assert.equal(pair[1].title,pair[0].title+'＋');
    assert.ok(pair.every(c=>c.description.includes(c.body)&&c.description.includes(c.cost)));
    assert.notEqual(pair[0].body,pair[1].body);
  }
  assert.ok(library.sourceInputs.every(r=>/^[a-f0-9]{64}$/.test(r.sha256)&&r.bytes>0));
});
test('current off-line compiled selector records contain the complete exact library copy',async t=>{
  let receipt;try{receipt=JSON.parse(readFileSync('.artifacts/native-selector-check-3/selector.json','utf8'))}catch{t.skip('Run selector/check.mjs for current static record evidence');return}
  const read=await readbackSelector(receipt.mapPath,receipt.selectorId,receipt.config.cards);
  assert.equal(read.fullCardTextMatches,true);assert.equal(read.recordIds.length,4);
});
