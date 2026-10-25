import { readFileSync, writeFileSync, mkdirSync, mkdtempSync, cpSync, rmSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { tmpdir } from 'node:os';
import { randomUUID } from 'node:crypto';
import { pathToFileURL } from 'node:url';
import luaparse from 'luaparse';
import { runLua } from './test-lua.mjs';
import { sha256 } from './evidence-files.mjs';

export function classifyMutation(result,proof) {
  if(result.error)return result.error.code==='ETIMEDOUT'?'timeout':'infrastructure_error';
  if(result.signal||result.status==null)return 'infrastructure_error';
  if(result.status===0)return 'survived';
  const lines=`${result.stdout??''}\n${result.stderr??''}`.replaceAll('\\','/').split(/\r?\n/);
  return lines.some(line=>line.includes(`${proof.file}:${proof.line}:`) && line.includes(proof.marker))?'killed_by_assertion':'inconclusive';
}
function invoke(script,cwd,{timeout=15000}={}) {
  try{return runLua(script,{cwd,timeout});}catch(error){return {status:null,stdout:'',stderr:error.message,error:{code:error.cause?.code??'RUNNER_ERROR'}};}
}
export function runMutation(operator,{root=process.cwd(),runner=invoke,deadline=Date.now()+120000}={}) {
  const started=Date.now(),directory=mkdtempSync(join(tmpdir(),'abyss-mutation-'));
  const sourceFile=join(root,operator.source),rawSource=readFileSync(sourceFile),source=rawSource.toString('utf8').replaceAll('\r\n','\n');
  const rawTest=readFileSync(join(root,operator.test)),testSource=rawTest.toString('utf8').replaceAll('\r\n','\n');
  const lines=testSource.split('\n'),origins=lines.flatMap((line,i)=>line.includes(operator.assertionSource)?[i+1]:[]);
  const report={id:operator.id,sourceSha256:sha256(rawSource),testSha256:sha256(rawTest),runtime:process.version,
    diff:{before:operator.before,after:operator.after},baseline:'not_run',syntax:'not_run',status:'not_run',test:operator.test};
  try{
    if(origins.length!==1)throw new Error('Assertion origin must be unique');
    for(const dir of ['src/lua','build/lua','tests/lua'])cpSync(join(root,dir),join(directory,dir),{recursive:true});
    const baseline=runner(operator.test,directory,{timeout:Math.max(1,Math.min(15000,deadline-Date.now()))});report.baselineResult=baseline;
    if(baseline.error||baseline.status!==0){report.baseline='fail';report.status='inconclusive';return report;}
    report.baseline='pass';
    if(source.split(operator.before).length!==2){report.status='invalid_mutant';report.reason='Non-unique or missing source anchor';return report;}
    const mutant=source.replace(operator.before,operator.after);
    try{luaparse.parse(Buffer.from(mutant).toString('latin1'),{luaVersion:'5.3',encodingMode:'pseudo-latin1'});report.syntax='pass';}
    catch(error){report.syntax='fail';report.status='invalid_mutant';report.reason=error.message;return report;}
    writeFileSync(join(directory,operator.source),mutant);
    report.assertion={file:operator.test,line:origins[0],marker:operator.marker};
    const result=runner(operator.test,directory,{timeout:Math.max(1,Math.min(15000,deadline-Date.now()))});report.result=result;report.status=classifyMutation(result,report.assertion);
    return report;
  }catch(error){report.status='infrastructure_error';report.reason=error.message;return report;}
  finally{
    report.durationMs=Date.now()-started;report.originalUnchanged=sha256(readFileSync(sourceFile))===report.sourceSha256;
    // Only remove the directory returned by mkdtemp above; never a caller path.
    rmSync(directory,{recursive:true,force:true});
  }
}
if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href) {
  try{
    const operators=JSON.parse(readFileSync('config/critical-mutations.json','utf8')),started=Date.now(),results=[];
    if(operators.length!==4)throw new Error('Expected four registered operators');
    for(const operator of operators) {
      if(Date.now()-started>=120000) {results.push({id:operator.id,status:'not_run',reason:'120s round budget'});continue;}
      const result=runMutation(operator,{deadline:started+120000});results.push(result);console.log(`${result.id}: ${result.status} (${result.durationMs}ms)`);
    }
    const dir=join('build/test-strength',randomUUID());mkdirSync(dir,{recursive:true});writeFileSync(join(dir,'report.json'),JSON.stringify({scope:'Four registered Lua regressions only; not a repository-wide mutation score',results,durationMs:Date.now()-started},null,2)+'\n');
    console.log(`Mutation evidence: ${join(dir,'report.json')}`);
    if(results.some(row=>row.status!=='killed_by_assertion'||!row.originalUnchanged))process.exitCode=1;
  }catch(error){console.error(error.message);process.exitCode=1;}
}
