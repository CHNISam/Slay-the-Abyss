import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

test('prototype keeps source strike tags discoverable by hover and 350ms hold after shortening bodies',()=>{
 const html=readFileSync('docs/design/prototype/index.html','utf8');
 const definitions=JSON.parse(readFileSync('data/cards.json','utf8')).cards;
 const tips=[],timers=new Map();let serial=0;
 const canvas={append:el=>tips.push(el)};
 const document={getElementById:()=>canvas,createElement:()=>({
  set innerHTML(value){this.content=value;},get firstElementChild(){return {outerHTML:this.content,listeners:{},
   addEventListener(name,fn){this.listeners[name]=fn;},remove(){}};}
 })};
 const context=vm.createContext({document,setTimeout(fn,ms){timers.set(++serial,{fn,ms});return serial;},clearTimeout(id){timers.delete(id);}});
 const start=html.indexOf('function cardEl('),end=html.indexOf('\n}',start)+2;
 const tipStart=html.indexOf('let tipEl=null;'),tipEnd=html.indexOf('\nfunction pop(',tipStart);
 vm.runInContext(html.slice(html.indexOf('const CARDS='),html.indexOf('/* ---------- 设备与缩放'))+html.slice(start,end)+html.slice(tipStart,tipEnd),context);
 for(const definition of definitions){
  const tagged=definition.strikeTag===true;
  assert.equal(vm.runInContext(`C[${JSON.stringify(definition.id)}].strikeTag===true`,context),tagged,definition.id);
  const el=vm.runInContext(`cardEl(C[${JSON.stringify(definition.id)}])`,context);
  if(!tagged)continue;
  assert.match(el.outerHTML,/攻击 · 打击类/);
  assert.doesNotMatch(el.outerHTML,/打击类牌。/);
  el.listeners.mouseenter();assert.match(tips.at(-1).outerHTML,/带有打击标签.*计入剑势如虹/);
  const count=tips.length;el.listeners.touchstart();
  const hold=[...timers.values()].find(t=>t.ms===350);assert.ok(hold);
  assert.equal(tips.length,count,'press must wait for the long-press threshold');
  el.listeners.touchend();assert.ok(![...timers.values()].includes(hold),'short release must cancel pending help');
  timers.clear();el.listeners.touchstart();[...timers.values()].find(t=>t.ms===350).fn();
  assert.match(tips.at(-1).outerHTML,/打击类/);timers.clear();
 }
});

function interactionFixture(kind='battle'){
 const html=readFileSync('docs/design/prototype/index.html','utf8');
 const timers=new Map();let serial=0,renders=0,purchases=0;
 const document={getElementById:()=>({append(){}}),createElement:()=>({set innerHTML(value){this.content=value;},get firstElementChild(){return {outerHTML:this.content,listeners:{},
  addEventListener(name,fn,options){this.listeners[name]={fn,capture:options===true||options?.capture===true};},remove(){}};}})};
 const context=vm.createContext({document,setTimeout(fn,ms){timers.set(++serial,{fn,ms});return serial;},clearTimeout(id){timers.delete(id);},
  B:{busy:false,sel:-1},dragJustEnded:false,card:{id:'strike'},playable:()=>true,renderBattle(){renders++;},
  RUN:{deck:[]},buy(key,price,commit){purchases++;commit();},k:'c0',p:30,x:60,id:'strike'});
 const start=html.indexOf('function cardEl('),end=html.indexOf('\n}',start)+2;
 const tipStart=html.indexOf('let tipEl=null;'),tipEnd=html.indexOf('\nfunction pop(',tipStart);
 vm.runInContext(html.slice(html.indexOf('const CARDS='),html.indexOf('/* ---------- 设备与缩放'))+html.slice(start,end)+html.slice(tipStart,tipEnd)+'\nvar el=cardEl(C.strike),i=0;',context);
 const handler=kind==='battle'?html.match(/el\.onclick=\(e\)=>\{e\.stopPropagation\(\);if\(B\.busy[\s\S]*?renderBattle\(\)\};/)[0]
  :html.match(/el\.onclick=\(\)=>buy\(k,p,\(\)=>RUN\.deck\.push\(\{id,up:false\}\),x\+74,170\)/)[0]+';';
 vm.runInContext(handler,context);
 const el=context.el;
 function event(name,id=7,x=10,y=20){
  const touch={identifier:id,clientX:x,clientY:y};
  if(name==='touchstart')el.listeners.pointerdown?.fn({pointerId:id,pointerType:'touch'});
  el.listeners[name]?.fn({changedTouches:[touch],touches:name==='touchend'||name==='touchcancel'?[]:[touch]});
 }
 function click(id=7){let stopped=false,prevented=false;
  const e={pointerId:id,pointerType:'touch',detail:1,stopPropagation(){},stopImmediatePropagation(){stopped=true;},preventDefault(){prevented=true;}};
  const listener=el.listeners.click;if(listener?.capture)listener.fn(e);
  if(!stopped)el.onclick(e);
  return prevented;
 }
 function hold(){const t=[...timers.values()].find(t=>t.ms===350);assert.ok(t);t.fn();}
 return {context,el,event,click,hold,timers,counts:()=>({renders,purchases,selected:context.B.sel,deck:context.RUN.deck.length})};
}

test('real battle and shop card handlers consume only a successful hold release click',()=>{
 for(const kind of ['battle','shop']){
  const f=interactionFixture(kind);f.event('touchstart');f.hold();f.event('touchend');
  assert.equal(f.click(),true,'completed hold must prevent the synthetic click');
  assert.deepEqual(f.counts(),{renders:0,purchases:0,selected:-1,deck:0},kind+' hold must stay read-only');
  f.event('touchstart');f.event('touchend');assert.equal(f.click(),false,'next short tap must execute');
  assert.equal(kind==='battle'?f.counts().renders:f.counts().purchases,1);
 }
});

test('hover, cancelled/moved/foreign holds and stale timers cannot eat a new legal tap',()=>{
 for(const mode of ['hover','cancel','move','old-timer','new-start','foreign-end']){
  const f=interactionFixture();
  if(mode==='hover')f.el.listeners.mouseenter.fn();
  else{
   f.event('touchstart');const old=[...f.timers.values()].find(t=>t.ms===350);
   if(mode==='cancel'){f.hold();f.event('touchcancel');}
   if(mode==='move'){f.event('touchmove',7,40,20);old.fn();}
   if(mode==='old-timer'){f.event('touchend');old.fn();}
   if(mode==='new-start'){f.hold();f.event('touchend');}
   if(mode==='foreign-end'){f.hold();f.event('touchend',8);f.event('touchcancel');}
  }
  f.event('touchstart',9);f.event('touchend',9);assert.equal(f.click(9),false,mode);
  assert.equal(f.counts().renders,1,mode+' must retain the next legitimate action');
 }
});

test('hold click grant matches its pointer and is retired by a fresh pointer down',()=>{
 const f=interactionFixture();f.event('touchstart');f.hold();f.event('touchend');
 let stopped=false;
 f.el.listeners.click.fn({pointerId:8,pointerType:'touch',detail:1,preventDefault(){stopped=true;},stopImmediatePropagation(){stopped=true;}});
 assert.equal(stopped,false,'foreign pointer cannot consume the release grant');
 assert.equal(f.click(7),true,'original pointer still owns its release click');
 const g=interactionFixture();g.event('touchstart');g.hold();g.event('touchend');
 g.el.listeners.pointerdown.fn({pointerId:3,pointerType:'mouse'});
 assert.equal(g.click(7),false,'new pointer down retires an unreceived old synthetic click');
 assert.equal(g.counts().renders,1);
});
