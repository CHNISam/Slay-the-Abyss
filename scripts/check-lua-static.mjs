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
const renderFile = file => /^src\/lua\/abyss_(?:battle_.+|shop_ui|shop_selection|card_display)\.lua$/.test(file);
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

// Budget only this governance slice and every extracted responsibility module.
// Unrelated pre-existing Combat/UI hotspots keep their diagnostic reports.
const responsibilityRoots = {
  'src/lua/abyss_run.lua': ["function 'potionCandidate'"],
  'src/lua/abyss_run_potion_candidate.lua': [],
  'src/lua/abyss_effects.lua': ["function 'M.apply'", "function 'continueEffects'", "function 'applyOne'"],
  'src/lua/abyss_combat.lua': ["function 'queuedHandlers.effect'"],
  'src/lua/abyss_act2_ai.lua': ["function 'choose'"],
  'src/lua/abyss_character_presentation.lua': [],
  'src/lua/abyss_character_presentation_text.lua': ["function 'fragments'"],
  'src/lua/abyss_feedback.lua': [
    "function 'step'", "function 'paint'", "function 'cardShape'",
    "function 'cardFlight'", "function 'contactSound'", "function 'statusDamageLabel'",
    "function 'damageLabel'", "function 'previousActor'", "function 'playStep'",
    "function 'bannerStep'", "function 'silentIntent'", "function 'intentStep'",
    "function 'escapeStep'", "function 'deathStep'", "function 'damageText'",
    "function 'statusText'", "function 'targetText'", "function 'targetStep'",
    "function 'enterFrame'", "function 'appendShake'", "function 'paintKnockback'",
    "function 'paintMotion'", "function 'impactShape'", "function 'impactTint'",
    "function 'paintImpact'", "function 'paintShield'", "function 'numberScale'",
    "function 'paintNumber'", "function 'paintDying'",
  ],
  'src/lua/abyss_node_ui.lua': [
    "method 'self.render'", "function 'syncNodeIdentity'", "function 'syncLivingPicker'",
    "function 'syncAct2Picker'", "function 'syncNeowPicker'", "function 'syncRestPicker'",
    "function 'syncLibraryPicker'", "function 'syncAct2PurgePicker'",
    "function 'syncAct1Picker'", "function 'syncNodePicker'", "function 'nodeScreen'",
    "function 'renderNodePage'", "function 'refreshNodeNotice'", "function 'eventPickerLabel'",
    "function 'pickerLabels'", "function 'pickerCommand'", "function 'pickerFooter'",
    "function 'treasureFooter'", "function 'recallFooter'", "function 'shopFooter'",
    "function 'completedFooter'", "function 'resultFooter'", "function 'chooseFooter'",
    "function 'bindFooter'", "function 'bindTreasureBack'", "function 'bindStagedEventActions'",
  ],
  'src/lua/abyss_game_ui.lua': [
    "function 'self.refresh'", "function 'finishRunFlow'", "function 'selectMode'",
    "function 'syncMenuContext'", "function 'syncCardChoice'",
    "function 'closeStaleDeck'", "function 'openCardChoice'", "function 'syncRewardReturn'",
    "function 'refreshPotionEntry'", "function 'refreshDeckEntry'", "function 'refreshUtilities'",
    "function 'refreshMapResources'", "function 'refreshPageVisibility'", "function 'renderBattlePage'",
    "function 'renderMapPage'", "function 'renderCurrentPage'", "function 'refreshExitDialog'",
    "function 'refreshForeground'", "function 'overlaysBlocked'",
  ],
};
const responsibilityHelper = file => /^src\/lua\/abyss_(?:effects_.+|combat_effect.*|act2_ai_.+|character_presentation_.+|feedback_.+|node_ui_.+|game_ui_.+|run_potion_candidate.*)\.lua$/.test(file);
// The display adapter now aliases the extracted formatter. If a local formatter
// is reintroduced, it must not evade the budget that governs its replacement.
const optionalResponsibilityRoots = {'src/lua/abyss_character_presentation.lua': ["function 'fragments'"]};
export function reviewResponsibilityComplexity(diagnostics, sources, roots = responsibilityRoots) {
  const modules = Object.keys(sources).filter(file => file in roots || responsibilityHelper(file)).sort();
  const functions = [], errors = [];
  for (const file of Object.keys(roots)) if (!(file in sources)) errors.push({file,message:'Required responsibility module missing'});
  for (const file of modules) {
    const rows = diagnostics.filter(row => row.file === file && row.code === 'W561');
    if (rows.length !== expectedMeasurements(sources[file])) errors.push({file,message:'Incomplete responsibility complexity report'});
    const parsedSource = Buffer.from(sources[file]).toString('latin1');
    const ast = luaparse.parse(parsedSource, {
      luaVersion:'5.3', encodingMode:'pseudo-latin1', comments:false, locations:true, ranges:true,
    });
    const declarations = [];
    function visit(node) {
      if (!node || typeof node !== 'object') return;
      if (node.type === 'FunctionDeclaration') declarations.push(node);
      for (const value of Object.values(node)) {
        if (Array.isArray(value)) value.forEach(visit);
        else if (value && typeof value === 'object') visit(value);
      }
    }
    visit(ast);
    const lines = sources[file].split('\n'), offsets = [0];
    for (const line of lines) offsets.push(offsets.at(-1)+Buffer.byteLength(line)+1);
    // Luacheck counts Unicode codepoints; luaparse's latin1 AST uses bytes.
    const offset = row => row.line > 0 && row.column > 0 && row.line <= lines.length
      ? offsets[row.line-1]+Buffer.byteLength(Array.from(lines[row.line-1]).slice(0,row.column-1).join('')) : Infinity;
    luaparse.parse(parsedSource, {wait:true,luaVersion:'5.3',encodingMode:'pseudo-latin1',comments:false,ranges:true});
    const keywords = [];
    for (let token=luaparse.lex(); token.type!==luaparse.tokenTypes.EOF; token=luaparse.lex()) {
      if (token.type === luaparse.tokenTypes.Keyword && token.value === 'function') keywords.push(token.range[0]);
    }
    const functionAt = new Map();
    for (const declaration of declarations) {
      const start = keywords.find(at => declaration.range[0] <= at && at < declaration.range[1]);
      if (start === undefined || functionAt.has(start)) errors.push({file,message:'AST function keyword mapping is incomplete'});
      else functionAt.set(start,declaration);
    }
    const parsed = rows.map(row => ({row, match:/^cyclomatic complexity of (.+) is too high \(([1-9]\d*) > 0\)$/.exec(row.message)}));
    const rootRanges = [];
    const subjects=[...(roots[file] ?? []),...(optionalResponsibilityRoots[file] ?? [])];
    for (const subject of subjects) {
      const found = parsed.filter(item => item.match?.[1] === subject);
      if (!found.length && optionalResponsibilityRoots[file]?.includes(subject)) continue;
      if (found.length !== 1) { errors.push({file,message:`Required responsibility entry missing or duplicated: ${subject}`}); continue; }
      const at = offset(found[0].row);
      const declaration = functionAt.get(at);
      if (!declaration) errors.push({file,message:`Responsibility entry has no AST function: ${subject}`});
      else rootRanges.push(declaration.range);
    }
    const seen = new Set();
    for (const {row,match} of parsed) {
      if (!match) { errors.push({...row,message:'Unrecognized responsibility complexity measurement'}); continue; }
      const at = offset(row), key = match[1] === 'main chunk' ? 'main' : `function:${at}`;
      if (seen.has(key)) errors.push({...row,message:'Duplicate responsibility complexity measurement'});
      seen.add(key);
      if (key === 'main' ? row.line !== 1 || row.column !== 1 : !functionAt.has(at)) errors.push({...row,message:'Complexity measurement has no corresponding AST function/chunk'});
      if (!responsibilityHelper(file) && (key === 'main' || !rootRanges.some(([start,end]) => start <= at && at < end))) continue;
      const value = Number(match[2]), limit = 15;
      functions.push({file,line:row.line,subject:match[1],complexity:value,limit});
      if (value > limit) errors.push({...row,message:`Responsibility complexity ${value} exceeds ${limit}: ${match[1]}`});
    }
    if (!seen.has('main') || [...functionAt.keys()].some(at => !seen.has(`function:${at}`))) errors.push({file,message:'Incomplete AST function/chunk measurements'});
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
    const responsibilities=reviewResponsibilityComplexity(complexity.diagnostics,sources);
    writeFileSync('build/responsibility-complexity.json',JSON.stringify({...responsibilities,tool:complexity.tool},null,2)+'\n');
    if(unexpected.length||hard.length)throw new Error(`Lua static check failed: ${JSON.stringify([...unexpected,...hard])}`);
    if(render.errors.length)throw new Error(`UI complexity check failed: ${JSON.stringify(render.errors)}`);
    if(responsibilities.errors.length)throw new Error(`Responsibility complexity check failed: ${JSON.stringify(responsibilities.errors)}`);
    console.log(`Luacheck ${report.tool.version}: no new diagnostics; ${report.diagnostics.length} explicit historical warnings. Battle render <=10; every scoped function <=15; ${responsibilities.functions.length} governed responsibility measurements.`);
  }catch(error){console.error(error.message);process.exitCode=1;}
}
