import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { collectEngineeringInputs } from '../scripts/check-engineering-quality.mjs';
import { runEngineering } from '../scripts/check-engineering.mjs';

test('each invocation collects fresh sources, architecture and both Luacheck passes exactly once',()=>{
  let revision=0;const calls=[];
  const dependencies={
    discover:()=>({'src/lua/a.lua':`return ${++revision}`}),
    policy:()=>({layers:{a:'core'}}),
    analyze:(sources,policy)=>{calls.push(['architecture',sources.a,policy.layers.a]);return {errors:[]};},
    lint:args=>{calls.push(['lint',args]);return {diagnostics:[],tool:{version:'1.2.0'}};},
  };
  const first=collectEngineeringInputs(dependencies),second=collectEngineeringInputs(dependencies);
  assert.equal(first.sources['src/lua/a.lua'],'return 1');
  assert.equal(second.sources['src/lua/a.lua'],'return 2');
  assert.deepEqual(calls,[['architecture','return 1','core'],['lint',[]],['lint',['--max-cyclomatic-complexity','0','--only','561']],
    ['architecture','return 2','core'],['lint',[]],['lint',['--max-cyclomatic-complexity','0','--only','561']]]);
});

test('combined entry shares the same in-memory inputs across all three existing gates',()=>{
  const shared={architecture:{errors:[]}},seen=[];
  runEngineering({collect:()=>shared,
    quality:(args,collect)=>{assert.deepEqual(args,[]);seen.push(collect());return {errors:[]};},
    architecture:report=>{assert.equal(report,shared.architecture);return report;},
    staticCheck:inputs=>{seen.push(inputs);return {errors:[]};},
  });
  assert.deepEqual(seen,[shared,shared]);
});

test('collection failures and existing gate failures propagate',()=>{
  assert.throws(()=>runEngineering({collect:()=>{throw Error('tool missing');},quality:(_args,collect)=>collect()}),/tool missing/);
  const gates={collect:()=>({architecture:{errors:[]}}),quality:(_args,collect)=>{collect();return {errors:[]};},architecture:()=>({errors:[]}),staticCheck:()=>({errors:[]})};
  for(const gate of ['quality','architecture','staticCheck']) {
    assert.throws(()=>runEngineering({...gates,[gate]:()=>{throw Error(`${gate} failed`);}}),new RegExp(`${gate} failed`));
    assert.throws(()=>runEngineering({...gates,[gate]:()=>({errors:[{message:`${gate} rejected`}]})}),new RegExp(`${gate} rejected`));
  }
});


test('a failed shared collection writes a fresh failed quality report',()=>{
  const directory=mkdtempSync(join(tmpdir(),'engineering-failure-')),cwd=process.cwd(),exitCode=process.exitCode;
  try {
    process.chdir(directory);
    assert.throws(()=>runEngineering({collect:()=>{throw Error('tool missing');}}),/tool missing/);
    const report=JSON.parse(readFileSync('build/engineering-quality.json','utf8'));
    assert.equal(report.status,'failed');
    assert.deepEqual(report.errors,[{message:'tool missing'}]);
    assert.equal(process.exitCode,1);
  }finally {process.chdir(cwd);process.exitCode=exitCode;rmSync(directory,{recursive:true,force:true});}
});
import { reviewNodeUiSize } from '../scripts/check-lua-static.mjs';
test('Node UI size reports are identical for independent and shared discovery orders',()=>{
  const sources={'src/lua/abyss_node_ui.lua':'return {}\n','src/lua/abyss_node_ui_input.lua':'local function input() end\nreturn {}\n'};
  assert.deepEqual(reviewNodeUiSize(sources),reviewNodeUiSize(Object.fromEntries(Object.entries(sources).reverse())));
});
