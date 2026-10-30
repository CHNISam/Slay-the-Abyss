import luaparse from 'luaparse';
import { readFileSync, readdirSync, mkdirSync, writeFileSync } from 'node:fs';
import { join, resolve, basename } from 'node:path';
import { pathToFileURL } from 'node:url';
import { generatedRuntimeModules } from './build-native-candidate.mjs';
import { sha256 } from './evidence-files.mjs';

export function analyzeSources(sources,policy,generated=generatedRuntimeModules) {
  const errors=[],edges=[],nodes=Object.keys(sources).sort(),layers=policy.layers;
  const deferredImports=new Set((policy.deferredImports??[]).map(row=>`${row.from}:${row.to}`));
  for(const name of nodes) {
    const source=sources[name],layer=layers[name];
    const say=(node,message)=>errors.push({file:`src/lua/${name}.lua`,line:node?.loc?.start.line??1,message});
    if(!['core','ui','platform'].includes(layer))say(null,'Module needs explicit classification');
    let ast;
    try{ast=luaparse.parse(Buffer.from(source).toString('latin1'),{luaVersion:'5.3',locations:true,ranges:true,scope:true,encodingMode:'pseudo-latin1'});}
    catch(error){say(null,`Lua parse failed: ${error.message}`);continue;}
    function visit(node,parent,key,depth=0) {
      if(!node||typeof node!=='object')return;
      if(Array.isArray(node)){for(const child of node)visit(child,parent,key,depth);return;}
      const call=['CallExpression','StringCallExpression','TableCallExpression'].includes(node.type);
      if(call && node.base?.type==='Identifier' && node.base.name==='require' && !node.base.isLocal) {
        const args=node.arguments??(node.argument?[node.argument]:[]),target=args[0];
        if(args.length!==1||target?.type!=='StringLiteral')say(node,'Unregistered dynamic require');
        else {
          const to=target.value;
          const reviewedDeferred=depth>0&&deferredImports.has(`${name}:${to}`);
          edges.push({from:name,to,line:node.loc.start.line,reviewedDeferred});
          if(!(to in sources)&&!(to in generated))say(node,`unknown module ${to}`);
          if(layer==='core'&&layers[to]!=='core')say(node,`core cannot depend on ${to}`);
          if(layer==='ui'&&layers[to]==='platform')say(node,`UI cannot depend on platform ${to}`);
        }
      }
      if(node.type==='Identifier' && node.isLocal===false) {
        if(layer==='core' && ['game','script','GI','Enum','Color'].includes(node.name))say(node,`core cannot access platform global ${node.name}`);
        if(['_G','_ENV','getfenv','setfenv'].includes(node.name))say(node,`Unregistered indirect environment access ${node.name}`);
        if(['load','loadfile','dofile','package'].includes(node.name))say(node,`Unregistered dynamic loading ${node.name}`);
        if(node.name==='require' && !(key==='base' && ['CallExpression','StringCallExpression','TableCallExpression'].includes(parent?.type)))say(node,'Unregistered dynamic require alias/assignment');
      }
      for(const [childKey,child] of Object.entries(node))if(!['loc','range','comments','globals'].includes(childKey))
        visit(child,node,childKey,depth+(node.type==='FunctionDeclaration'?1:0));
    }
    visit(ast);
  }
  const seenDeferredImports=new Set();
  for(const {from,to} of policy.deferredImports??[]) {
    const key=`${from}:${to}`;
    if(seenDeferredImports.has(key))errors.push({file:'config/architecture.json',line:1,message:`Duplicate deferred import exception: ${from} -> ${to}`});
    else if(!edges.some(edge=>edge.from===from&&edge.to===to&&edge.reviewedDeferred))
      errors.push({file:'config/architecture.json',line:1,message:`Stale deferred import exception: ${from} -> ${to}`});
    seenDeferredImports.add(key);
  }
  const active=new Set(),done=new Set();
  function cycle(name,trail=[]) {
    if(active.has(name)){errors.push({file:`src/lua/${name}.lua`,line:1,message:`Dependency cycle: ${[...trail,name].join(' -> ')}`});return;}
    if(done.has(name))return;
    active.add(name);for(const edge of edges.filter(edge=>edge.from===name&&!edge.reviewedDeferred))if(edge.to in sources)cycle(edge.to,[...trail,name]);
    active.delete(name);done.add(name);
  }
  nodes.forEach(name=>cycle(name));
  return {schemaVersion:1,parser:'luaparse@0.3.1',sourceHashes:Object.fromEntries(nodes.map(name=>[name,sha256(sources[name])])),nodes,edges,errors};
}
export function checkArchitecture(root=process.cwd()) {
  const sources=Object.fromEntries(readdirSync(join(root,'src/lua')).filter(file=>file.endsWith('.lua')).sort().map(file=>[basename(file,'.lua'),readFileSync(join(root,'src/lua',file),'utf8')]));
  return analyzeSources(sources,JSON.parse(readFileSync(join(root,'config/architecture.json'),'utf8')));
}
export function main(report=checkArchitecture()) {
  mkdirSync('build',{recursive:true});writeFileSync('build/architecture.json',JSON.stringify(report,null,2)+'\n');
  for(const error of report.errors)console.error(`${error.file}:${error.line}: ${error.message}`);
  if(report.errors.length)throw new Error('Architecture check failed');
  console.log(`Architecture passed: ${report.nodes.length} modules, ${report.edges.length} edges; build/architecture.json`);
  return report;
}
if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href) {
  try{main();}catch(error){console.error(error.message);process.exitCode=1;}
}
