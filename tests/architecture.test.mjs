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

test('initialization calls cannot borrow a deferred import exception',()=>{
  for(const [label,a] of [
    ['IIFE','return (function() return require("b") end)()'],
    ['local direct call','local function loadB() return require("b") end; return loadB()'],
    ['local function expression','local loadB=function() return require("b") end; return loadB()'],
    ['local alias','local function loadB() return require("b") end; local alias=loadB; return alias()'],
    ['assigned alias','local function loadB() return require("b") end; local alias; alias=loadB; return alias()'],
    ['assigned local','local loadB; loadB=function() return require("b") end; return loadB()'],
    ['forward local declaration','local loadB; function loadB() return require("b") end; return loadB()'],
    ['nested direct call','local function outer() local function inner() return require("b") end; return inner() end; return outer()'],
    ['returned function call','return (function() return function() return require("b") end end)()()'],
    ['returned local alias','local function factory() local function loadB() return require("b") end; return loadB end; local alias=factory(); return alias()'],
    ['second return expression still executes','local function factory() return function() return 1 end, (function() return require("b") end)() end; return factory()()'],
    ['StringCallExpression','return (function() return require "b" end) "argument"'],
    ['TableCallExpression','return (function() return require "b" end) {}'],
    ['conditional initialization','if enabled then local function loadB() return require("b") end; loadB() end'],
    ['repeat scope','repeat local function loadB() return require("b") end until loadB()'],
    ['local recursive call','local function again() require("b"); return again() end; return again()'],
  ]) {
    const report=analyzeSources({a,b:'return require("a")'},deferredPolicy,{});
    assert(report.errors.some(error=>/Dependency cycle/.test(error.message)),label);
    assert(report.errors.some(error=>/Stale deferred import exception/.test(error.message)),label);
    assert.equal(report.edges.find(edge=>edge.from==='a').reviewedDeferred,false,label);
  }
});

test('uninvoked callbacks and lexical shadows remain deferred',()=>{
  for(const [label,a] of [
    ['uninvoked local','local function later() return require("b") end; return later'],
    ['uninvoked nested IIFE','return function() return (function() return require("b") end)() end'],
    ['returned callback','return (function() return function() return require("b") end end)()'],
    ['shadowed local','local function loadB() return require("b") end; do local function loadB() return 1 end; loadB() end; return loadB'],
    ['loop local','local function loadB() return require("b") end; for loadB in iterator do loadB() end; return loadB'],
    ['local initializer scope','local function loadB() return require("b") end; do local loadB=function() return 1 end; local loadB=loadB; loadB() end; return loadB'],
    ['recursive aliases without invocation','local first,second; first=function() return second() end; second=function() require("b"); return first() end; return first'],
    ['alias before reassignment','local f=function() return 1 end; local old=f; f=function() return require("b") end; old(); return f'],
    ['uninvoked mutator','local f=function() return 1 end; local function later() f=function() return require("b") end end; f(); return later'],
    ['only first return is invoked','local function f() return function() return 1 end, function() return require("b") end end; return f()()'],
    ['alias before assignment is not a future function','local f; local old=f; f=function() return require("b") end; old(); return f'],
    ['implicit nil reassignment is unknown','local f=function() return require("b") end; local unused; unused,f=1; f()'],
    ['shadowed parameter','local function loadB() return require("b") end; local function invoke(loadB) return loadB() end; invoke(function() return 1 end); return loadB'],
  ])assert.deepEqual(analyzeSources({a,b:'return require("a")'},deferredPolicy,{}).errors,[],label);
});

test('an immediate and a deferred require retain their individual execution classification',()=>{
  const a='local function now() return require("b") end; now(); return function() return require("b") end';
  const report=analyzeSources({a,b:'return require("a")'},deferredPolicy,{});
  assert.deepEqual(report.edges.filter(edge=>edge.from==='a').map(edge=>edge.reviewedDeferred),[false,true]);
  assert(report.errors.some(error=>/Dependency cycle/.test(error.message)));
  assert(!report.errors.some(error=>/Stale deferred/.test(error.message)));
});

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
