import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync} from 'node:fs';
import {architectureSourceFormat} from './helpers/architecture-source-format.mjs';
import {preRound2UiSource,round2UiAddedPaths} from './helpers/round2-ui-source-inverse.mjs';
import {projectArtPerfSource} from './helpers/art-perf-source-composition.mjs';
import {historicalTest} from './helpers/historical-baseline-inputs.mjs';
const path='config/architecture.json';
function uncached(source){
 const formatted=JSON.stringify(JSON.parse(source),null,2)+'\n';
 const tokens=text=>text.replace(/"(?:\\.|[^"\\])*"|[ \t\r\n]+/g,token=>token.startsWith('"')?token:'');
 return {formatted,tokensEqual:tokens(source)===tokens(formatted)};
}
function outcome(fn){try{return {value:fn()};}catch(error){return {error:{name:error.name,message:error.message}};}}
test('cold and warm formatting exactly matches uncached values/errors without conflating token drift',()=>{
 const inputs=[readFileSync(path,'utf8'),'{}','{ "a": 1, "b": 2 }','{"b":2,"a":1}',
  '{"a":1,"a":1}','{"a":1.0}','{"a":1e0}','{"a":-0}','{"a":"\\u0061"}',
  '{"a":"a"}','{\r\n "a": 1\r\n}','{"a":" x \\" y "}',
  '', '{','null','[]','true','{"a":NaN}','{} trailing'];
 for(const source of inputs)for(let attempt=0;attempt<2;attempt++)
  assert.deepEqual(outcome(()=>architectureSourceFormat(path,source)),outcome(()=>uncached(source)),source);
 for(const source of ['{"a":1,"a":1}','{"a":1.0}','{"a":1e0}','{"a":-0}','{"a":"\\u0061"}'])
  assert.equal(architectureSourceFormat(path,source).tokensEqual,false,source);
 const a=architectureSourceFormat(path,'{"a":1}'),b=architectureSourceFormat(path,'{"a":2}');
 assert.notEqual(a.formatted,b.formatted);assert(Object.isFrozen(a));
 assert.throws(()=>{a.formatted='foreign';},TypeError);
});
test('only exact architecture inputs are cached and bounded eviction changes no result',()=>{
 const source='{"eviction":0}',first=architectureSourceFormat(path,source);
 assert.equal(architectureSourceFormat(path,source),first);
 assert.notEqual(architectureSourceFormat('other.json',source),first);
 assert.notEqual(architectureSourceFormat('other.json',source),architectureSourceFormat('other.json',source));
 for(let i=1;i<=8;i++)architectureSourceFormat(path,`{"eviction":${i}}`);
 const again=architectureSourceFormat(path,source);
 assert.notEqual(again,first);assert.deepEqual(again,first);
 assert.notEqual(architectureSourceFormat(path,source+'\n'),again);
});
historicalTest('warming exact architecture formatting never hides changed linked module input',()=>{
 // This inverse proves the original round-two source closure. Only this group
 // uses independent epoch files; the JSON/cache groups above still read live inputs.
 const source=readFileSync(path,'utf8'),owner=round2UiAddedPaths[0],original=readFileSync(owner,'utf8');let reads=0;
 const readSource=file=>{
  reads++;
  return projectArtPerfSource(file,readFileSync(file,'utf8'),'perf');
 };
 architectureSourceFormat(path,source);
 const before=preRound2UiSource(path,source,{readSource});
 assert.equal(typeof before,'string');assert.equal(reads,2);
 const warmed=architectureSourceFormat(path,source);
 assert.equal(architectureSourceFormat(path,source),warmed,'exact host formatting is warm before the real owner changes');
 try{
  writeFileSync(owner,original+'\n-- unreviewed linked-module drift\n');
  assert.throws(()=>preRound2UiSource(path,source,{readSource}),/linked module drift/);
  assert.equal(reads,3,'the unchanged host must reread the first linked responsibility after cache warmup');
 }finally{writeFileSync(owner,original);}
 assert.equal(preRound2UiSource(path,source,{readSource}),before);assert.equal(reads,5);
});
