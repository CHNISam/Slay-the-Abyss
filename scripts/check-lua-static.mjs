import { spawnSync } from 'node:child_process';
import { readFileSync, readdirSync, mkdirSync, writeFileSync } from 'node:fs';
import luaparse from 'luaparse';
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

// This budget owns the battle controller, its extracted responsibilities and
// the shop/card views. Other pre-existing subsystems retain diagnostic reports.
const renderFile = file => /^src\/lua\/abyss_(?:battle_.+|shop_ui|card_display)\.lua$/.test(file);
const requiredRenderFiles = ['abyss_battle_ui', 'abyss_battle_card_view', 'abyss_shop_ui', 'abyss_card_display']
  .map(name => `src/lua/${name}.lua`);
function expectedMeasurements(source) {
  const ast = luaparse.parse(Buffer.from(source).toString('latin1'), {
    luaVersion:'5.3', encodingMode:'pseudo-latin1', comments:false,
  });
  let count = 1; // Luacheck also measures the module's main chunk.
  function visit(node) {
    if (!node || typeof node !== 'object') return;
    if (node.type === 'FunctionDeclaration') count++;
    for (const child of Object.values(node)) {
      if (Array.isArray(child)) child.forEach(visit);
      else if (child && typeof child === 'object') visit(child);
    }
  }
  visit(ast);
  return count;
}
export function reviewRenderComplexity(diagnostics, sources) {
  const modules = Object.keys(sources).filter(renderFile).sort(), functions = [], errors = [];
  for (const file of requiredRenderFiles) if (!(file in sources)) errors.push({file,message:'Required render module missing'});
  for (const file of modules) {
    const rows = diagnostics.filter(row => row.file === file && row.code === 'W561');
    const expected = expectedMeasurements(sources[file]);
    if (rows.length !== expected) errors.push({file,message:`Incomplete complexity report: ${rows.length}/${expected} functions/chunks`});
    const seen = new Set();
    for (const row of rows) {
      const match = /^cyclomatic complexity of (.+) is too high \(([1-9]\d*) > 0\)$/.exec(row.message);
      if (!match) { errors.push({...row,message:'Unrecognized complexity measurement'}); continue; }
      const key = `${row.line}:${row.column}`;
      if (seen.has(key)) errors.push({...row,message:'Duplicate complexity measurement'});
      seen.add(key);
      const limit = file === 'src/lua/abyss_battle_ui.lua' && match[1] === "method 'self.render'" ? 10 : 15;
      const value = Number(match[2]);
      functions.push({file,line:row.line,subject:match[1],complexity:value,limit});
      if (value > limit) errors.push({...row,message:`Render complexity ${value} exceeds ${limit}: ${match[1]}`});
    }
  }
  if (!functions.some(row => row.file === 'src/lua/abyss_battle_ui.lua' && row.subject === "method 'self.render'")) {
    errors.push({file:'src/lua/abyss_battle_ui.lua',message:'Battle render entry measurement missing'});
  }
  return {schemaVersion:1,modules,functions,errors};
}
if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href) {
  try{
    const report=runStatic(),baseline=JSON.parse(readFileSync('config/luacheck-baseline.json','utf8'));
    const unexpected=compareDiagnostics(report.diagnostics,baseline.diagnostics);
    // Undefined globals and syntax errors are never baseline exemptions.
    const hard=report.diagnostics.filter(row=>/^[WE]1/.test(row.code));
    mkdirSync('build',{recursive:true});writeFileSync('build/lua-static.json',JSON.stringify({...report,unexpected,hard},null,2)+'\n');
    const complexity=runStatic(['--max-cyclomatic-complexity','0','--only','561']);
    writeFileSync('build/lua-complexity.json',JSON.stringify(complexity,null,2)+'\n');
    const sources=Object.fromEntries(readdirSync('src/lua').filter(file=>file.endsWith('.lua'))
      .map(file=>[`src/lua/${file}`,readFileSync(`src/lua/${file}`,'utf8')]));
    const render=reviewRenderComplexity(complexity.diagnostics,sources);
    writeFileSync('build/ui-complexity.json',JSON.stringify({...render,tool:complexity.tool},null,2)+'\n');
    if(unexpected.length||hard.length)throw new Error(`Lua static check failed: ${JSON.stringify([...unexpected,...hard])}`);
    if(render.errors.length)throw new Error(`UI complexity check failed: ${JSON.stringify(render.errors)}`);
    console.log(`Luacheck ${report.tool.version}: no new diagnostics; ${report.diagnostics.length} explicit historical warnings. Battle render <=10; every scoped function <=15.`);
  }catch(error){console.error(error.message);process.exitCode=1;}
}
