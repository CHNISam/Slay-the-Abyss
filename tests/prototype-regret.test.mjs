import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

test('actual prototype cardEl renders Regret curse type, existing icon and defined style fallbacks',()=>{
 const html=readFileSync(process.env.ABYSS_PROTOTYPE_PATH || 'docs/design/prototype/index.html','utf8');
 const prefix=html.slice(html.indexOf('const CARDS='),html.indexOf('/* ---------- 设备与缩放'));
 const start=html.indexOf('function cardEl('),end=html.indexOf('\n}',start)+2;
 assert.ok(start>0 && end>start);
 const document={getElementById:()=>({}),createElement:()=>({
  set innerHTML(value){this.content=value;},get firstElementChild(){return {outerHTML:this.content};}
 })};
 const context=vm.createContext({document});
 vm.runInContext(prefix+html.slice(start,end),context);
 assert.ok(vm.runInContext('C.regret',context),'prototype must contain the permanent curse');
 const markup=vm.runInContext('cardEl(C.regret,{cant:true}).outerHTML',context);
 assert.match(markup,/诅咒/);assert.match(markup,/href="#i-deck"/);assert.match(markup,/data-k="图标 100122"/);
 assert.match(markup,/无法打出/);assert.match(markup,/手牌/);assert.doesNotMatch(markup,/undefined|null/);
 assert.match(html,/--t-curse:var\(--t-status\)/);assert.match(html,/--r-curse:var\(--line\)/);
});
