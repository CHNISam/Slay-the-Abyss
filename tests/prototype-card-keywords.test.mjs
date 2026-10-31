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
