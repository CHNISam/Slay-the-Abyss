import {readFileSync,writeFileSync} from 'node:fs';
import {join} from 'node:path';
export function validateNativeLua(source,luaSyntaxError) {
 if(typeof source!=='string'||!source.trim())throw Error('Empty native Lua');
 const stripped=source.replace(/--\[\[[\s\S]*?\]\]/g,'').replace(/--[^\n]*/g,'').replace(/"(?:[^"\\\n]|\\.)*"|'(?:[^'\\\n]|\\.)*'/g,'""');
 const forbidden=[/\bcoroutine\s*\./,/\bio\s*\./,/\bstring\s*\.\s*dump\b/,
  /\bos\s*\.\s*(?!time\b|date\b|clock\b|difftime\b)[A-Za-z_]+/,/\bdebug\s*\.\s*(?!traceback\b)[A-Za-z_]+/,
  /(?<![.:\w])(?:loadfile|dofile|load)\s*\(/,/\bpackage\s*\./];
 if(forbidden.some(pattern=>pattern.test(stripped)))throw Error('Unsupported native Lua API');
 const broken=luaSyntaxError(source);if(broken)throw Error('Lua syntax: '+broken.message);
}
export function writeScriptBatch(mapPath,updates,workspace,{container,fields,field,one,replace,wrap,clientScriptRecord,luaSyntaxError}) {
 const bytes=readFileSync(mapPath),root=container(bytes),section=fields(one(root,50));
 const records=section.filter(f=>f.id===1&&f.wire===2);
 const number=(data,id)=>Number(fields(data).find(f=>f.id===id&&f.wire===0)?.value??0);
 const text=(data,id)=>fields(data).find(f=>f.id===id&&f.wire===2)?.data.toString('utf8');
 const existing=new Map(records.map(f=>[text(f.data,2),f]));
 let next=Math.max(1073741825,...records.map(f=>number(f.data,1)))+1;
 const replacements=new Map(),usedFiles=new Set(records.map(f=>text(f.data,3)));
 for(const update of updates){
  if(replacements.has(update.name))throw Error('Duplicate batch script '+update.name);
  const source=update.source??readFileSync(update.sourceFile,'utf8');
  validateNativeLua(source,luaSyntaxError);
  const had=existing.get(update.name),id=had?number(had.data,1):next++;
  if(id>0xffffffff)throw Error('Native script ID overflow');
  let file=had?text(had.data,3):(/^[A-Za-z0-9_-]{1,40}$/.test(update.name)?`${update.name}.lua`:`script_${id-1073741825}.lua`);
  if(!had&&usedFiles.has(file)){
   const stem=`script_${id-1073741825}`;file=stem+'.lua';
   for(let suffix=2;usedFiles.has(file);suffix++)file=stem+'_'+suffix+'.lua';
  }
  usedFiles.add(file);
  const record=clientScriptRecord({id,name:update.name,file,source,variables:update.variables??[]});
  const kept=had&&!update.variables?fields(had.data).filter(f=>(f.id===7||f.id===8)&&f.wire===2).map(f=>f.raw):[];
  replacements.set(update.name,field(1,2,Buffer.concat([record,...kept])));
 }
 const rebuilt=section.map(f=>{if(f.id!==1||f.wire!==2)return f.raw;const name=text(f.data,2),out=replacements.get(name);replacements.delete(name);return out??f.raw;});
 rebuilt.push(...replacements.values());
 const out=join(workspace,'batch-scripts.gil');writeFileSync(out,wrap(bytes,replace(root,50,2,Buffer.concat(rebuilt))),{flag:'wx'});return out;
}
