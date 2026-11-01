import test from 'node:test';
import assert from 'node:assert/strict';
import { analyzeSources } from '../scripts/check-architecture.mjs';

test('AST boundaries distinguish imports, shadowing, dynamic access, syntax and cycles',async()=>{
  const mod=await import('../scripts/check-architecture.mjs');
  const layers={a:'core',b:'core',ui:'ui'};
  const check=sources=>mod.analyzeSources(sources,{layers},{theme:'builder'});
  assert.deepEqual(check({a:'-- require("ui")\nlocal text=[=[中文 require("ui")]=]\nlocal function f() return require("b") end',b:'return math.max(1,2)',ui:'return require("a")'}).errors,[]);
  assert.deepEqual(check({a:'local require=function(x) return x end; require("ui")'}).errors,[]);
  for(const [code,match] of [
    ['local function unused() return require("theme") end',/core.*theme/],
    ['return require("missing")',/unknown module/],['return require(prefix .. "b")',/dynamic/],
    ['local loader=require; return loader("b")',/dynamic/],['return game.GetPlayer()',/platform/],
    ['return _G["game"]',/indirect/],['return _ENV.game',/indirect/],['return load("return 1")',/dynamic/],
    ['local =',/parse/],
  ]) assert(check({a:code}).errors.some(e=>match.test(e.message)),code);
  assert(check({a:'return require("b")',b:'return require("a")'}).errors.some(e=>/cycle/.test(e.message)));
  assert(check({unknown:'return {}'}).errors.some(e=>/classif/.test(e.message)));
  assert.deepEqual(mod.analyzeSources({fresh:'return math.abs(-1)'},{layers:{fresh:'core'}},{}).errors,[]);
  const callbacks={a:'local M={}\nfunction M.later() return require("b") end\nreturn M',b:'return require("a")'};
  assert(mod.analyzeSources(callbacks,{layers:{a:'core',b:'core'}},{}).errors.some(e=>/cycle/.test(e.message)));
  const reviewed={layers:{a:'core',b:'core'},deferredImports:[{from:'a',to:'b',reason:'Reviewed callback after initialization'}]};
  assert.deepEqual(mod.analyzeSources(callbacks,reviewed,{}).errors,[]);
  assert(mod.analyzeSources({...callbacks,a:'return require("b")'},reviewed,{}).errors.some(e=>/cycle/.test(e.message)));
  assert(mod.analyzeSources(callbacks,{...reviewed,layers:{a:'core',b:'ui'}},{}).errors.some(e=>/core cannot depend/.test(e.message)));
});

const deferredPolicy = {
  layers: {a:'core', b:'core'},
  deferredImports: [{from:'a', to:'b', reason:'Reviewed callback after initialization'}],
};

test('deferred import exceptions must still match an actual function-scoped require',()=>{
  for (const [label, sources] of [
    ['removed import', {a:'return {}', b:'return {}'}],
    ['deleted importer', {b:'return {}'}],
    ['module-level import', {a:'return require("b")', b:'return {}'}],
    ['shadowed require', {a:'local require=function(x) return x end; return function() return require("b") end', b:'return {}'}],
    ['comment and string', {a:'-- require("b")\nreturn function() return [=[require("b")]=] end', b:'return {}'}],
    ['different dependency', {a:'return function() return require("a") end', b:'return {}'}],
  ]) {
    const report=analyzeSources(sources,deferredPolicy,{});
    assert(report.errors.some(error=>error.file==='config/architecture.json'
      && /Stale deferred import exception: a -> b/.test(error.message)),label);
  }
});

test('duplicate deferred import exceptions fail even with different review reasons',()=>{
  const sources={a:'return function() return require("b") end', b:'return require("a")'};
  const policy={...deferredPolicy, deferredImports:[
    ...deferredPolicy.deferredImports,
    {from:'a',to:'b',reason:'A second explanation does not make this a distinct exception'},
  ]};
  assert(analyzeSources(sources,policy,{}).errors.some(error=>error.file==='config/architecture.json'
    && /Duplicate deferred import exception: a -> b/.test(error.message)));
});

test('one reviewed pair permits repeated deferred calls while module-level calls retain cycle checks',()=>{
  const deferred='local function first() return require("b") end\nreturn function() return function() return require("b") end end';
  const sources={a:deferred,b:'return require("a")'};
  const report=analyzeSources(sources,deferredPolicy,{});
  assert.deepEqual(report.errors,[]);
  assert.equal(report.edges.filter(edge=>edge.from==='a' && edge.reviewedDeferred).length,2);
  const mixed=analyzeSources({...sources,a:'local b=require("b")\n'+deferred},deferredPolicy,{});
  assert(mixed.errors.some(error=>/Dependency cycle/.test(error.message)));
  assert(!mixed.errors.some(error=>/Stale deferred/.test(error.message)));
});
