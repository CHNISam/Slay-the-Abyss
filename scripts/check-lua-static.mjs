import { spawnSync } from 'node:child_process';
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { requireLuaTool } from './setup-lua-static.mjs';

export function parseDiagnostics(output) {
  return output.split(/\r?\n/).filter(line=>line.trim()).map(line=>{
    const match=line.match(/^(.*?):(\d+):(\d+)(?:-(\d+))?: \(([WE]\d+)\) (.*)$/);
    if(!match)throw new Error(`Unrecognized Luacheck output: ${line}`);
    return {file:match[1].replaceAll('\\','/'),line:Number(match[2]),column:Number(match[3]),code:match[5],message:match[6]};
  });
}
export function compareDiagnostics(actual,baseline) {
  const remaining=baseline.map(row=>JSON.stringify(row));
  return actual.filter(row=>{const at=remaining.indexOf(JSON.stringify(row));if(at<0)return true;remaining.splice(at,1);return false;});
}
export function runStatic(args=[]) {
  const tool=requireLuaTool();
  const version=spawnSync(tool.file,['--version'],{encoding:'utf8',timeout:10000});
  if(version.error||version.status!==0||!version.stdout.startsWith(`Luacheck: ${tool.version}`))throw new Error(`Luacheck version/tool error: ${version.error?.message||version.stderr}`);
  const result=spawnSync(tool.file,['src/lua','--formatter','plain','--codes','--ranges','--no-color',...args],{encoding:'utf8',timeout:30000,maxBuffer:4*1024*1024});
  if(result.error||result.signal||![0,1].includes(result.status)||result.stderr.trim())throw new Error(`Luacheck execution failed: ${result.error?.message||result.stderr||result.status}`);
  return {tool,diagnostics:parseDiagnostics(result.stdout),exitCode:result.status};
}
if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href) {
  try{
    const report=runStatic(),baseline=JSON.parse(readFileSync('config/luacheck-baseline.json','utf8'));
    const unexpected=compareDiagnostics(report.diagnostics,baseline.diagnostics);
    // Undefined globals and syntax errors are never baseline exemptions.
    const hard=report.diagnostics.filter(row=>/^[WE]1/.test(row.code));
    mkdirSync('build',{recursive:true});writeFileSync('build/lua-static.json',JSON.stringify({...report,unexpected,hard},null,2)+'\n');
    if(unexpected.length||hard.length)throw new Error(`Lua static check failed: ${JSON.stringify([...unexpected,...hard])}`);
    const complexity=runStatic(['--max-cyclomatic-complexity','0','--only','561']);
    writeFileSync('build/lua-complexity.json',JSON.stringify(complexity,null,2)+'\n');
    console.log(`Luacheck ${report.tool.version}: no new diagnostics; ${report.diagnostics.length} explicit historical warnings. Complexity is diagnostic only.`);
  }catch(error){console.error(error.message);process.exitCode=1;}
}
