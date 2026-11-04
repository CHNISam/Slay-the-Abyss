import luaparse from 'luaparse';
import { readFileSync, readdirSync, mkdirSync, writeFileSync } from 'node:fs';
import { join, resolve, basename } from 'node:path';
import { pathToFileURL } from 'node:url';
import { generatedRuntimeModules } from './build-native-candidate.mjs';
import { sha256 } from './evidence-files.mjs';

// Resolve statically visible initialization calls, not arbitrary Lua execution.
// Only single-write locals assigned by their declaring function before the
// reference are resolved. Reassigned/captured writes remain unknown, rather than
// activating a future callback through an old alias. This is not flow analysis:
// parameter callbacks, logical-expression callees, table dispatch and dynamic
// return values are not inferred. Explicit deferred-pair review is still required.
function initializationFunctions(ast) {
  const references=new WeakMap(),calls=new Map(),returns=new Map();
  const scope=parent=>({parent,bindings:new Map()});
  const lookup=(env,name)=>env?.bindings.get(name)??(env?.parent?lookup(env.parent,name):undefined);
  const bind=(env,name,owner)=>{const binding={owner,writes:[]};env.bindings.set(name,binding);return binding;};
  const assign=(binding,value,node,owner)=>binding?.writes.push({value,position:node.range[0],owner});
  const add=(map,key,value)=>{if(!map.has(key))map.set(key,[]);map.get(key).push(value);};
  const children=node=>Object.entries(node).filter(([key])=>!['loc','range','comments','globals'].includes(key));
  function walk(node,env,owner=null) {
    if(!node||typeof node!=='object')return;
    if(Array.isArray(node)){for(const child of node)walk(child,env,owner);return;}
    if(node.type==='Identifier'){references.set(node,lookup(env,node.name));return;}
    if(node.type==='FunctionDeclaration') {
      if(node.identifier?.type==='Identifier') {
        const binding=node.isLocal?bind(env,node.identifier.name,owner):lookup(env,node.identifier.name);
        assign(binding,node,node,owner);
      }
      const inner=scope(env);
      for(const parameter of node.parameters)if(parameter.type==='Identifier')bind(inner,parameter.name,node);
      walk(node.body,inner,node);return;
    }
    if(node.type==='LocalStatement') {
      walk(node.init,env,owner);
      for(const [index,variable] of node.variables.entries()) {
        const binding=bind(env,variable.name,owner);if(node.init[index])assign(binding,node.init[index],node,owner);
      }
      return;
    }
    if(node.type==='AssignmentStatement') {
      walk(node.init,env,owner);walk(node.variables,env,owner);
      for(const [index,variable] of node.variables.entries())if(variable.type==='Identifier')
        assign(lookup(env,variable.name),node.init[index],node,owner);
      return;
    }
    // A call used as a callee/initializer consumes its first result only.
    if(node.type==='ReturnStatement'&&node.arguments[0])add(returns,owner,node.arguments[0]);
    if(['CallExpression','StringCallExpression','TableCallExpression'].includes(node.type))add(calls,owner,node);
    if(['IfClause','ElseifClause','ElseClause','DoStatement','WhileStatement','RepeatStatement',
      'ForNumericStatement','ForGenericStatement'].includes(node.type)) {
      const inner=scope(env);
      // Loop bounds/iterators are evaluated outside their new local variables.
      for(const [key,child] of children(node))if(!['body','condition','variable','variables'].includes(key))walk(child,env,owner);
      for(const variable of node.variables??(node.variable?[node.variable]:[]))bind(inner,variable.name,owner);
      if(node.type!=='RepeatStatement')walk(node.condition,env,owner);
      walk(node.body,inner,owner);
      if(node.type==='RepeatStatement')walk(node.condition,inner,owner);
      return;
    }
    for(const [,child] of children(node))walk(child,env,owner);
  }
  walk(ast,scope(null));
  function targets(node,seen=new Set()) {
    if(!node||seen.has(node))return [];
    const next=new Set(seen);next.add(node);
    if(node.type==='FunctionDeclaration')return [node];
    if(node.type==='Identifier') {
      const binding=references.get(node),write=binding?.writes[0];
      return binding?.writes.length===1&&write.owner===binding.owner&&write.position<node.range[0]
        ?targets(write.value,next):[];
    }
    if(['CallExpression','StringCallExpression','TableCallExpression'].includes(node.type))
      return targets(node.base,next).flatMap(fn=>(returns.get(fn)??[]).flatMap(value=>targets(value,next)));
    return [];
  }
  const eager=new Set(),pending=[null];
  while(pending.length)for(const call of calls.get(pending.pop())??[])for(const fn of targets(call.base))
    if(!eager.has(fn)){eager.add(fn);pending.push(fn);}
  return eager;
}

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
    const eager=initializationFunctions(ast);
    function visit(node,parent,key,owner=null) {
      if(!node||typeof node!=='object')return;
      if(Array.isArray(node)){for(const child of node)visit(child,parent,key,owner);return;}
      const call=['CallExpression','StringCallExpression','TableCallExpression'].includes(node.type);
      if(call && node.base?.type==='Identifier' && node.base.name==='require' && !node.base.isLocal) {
        const args=node.arguments??(node.argument?[node.argument]:[]),target=args[0];
        if(args.length!==1||target?.type!=='StringLiteral')say(node,'Unregistered dynamic require');
        else {
          const to=target.value;
          const reviewedDeferred=owner!==null&&!eager.has(owner)&&deferredImports.has(`${name}:${to}`);
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
        visit(child,node,childKey,node.type==='FunctionDeclaration'?node:owner);
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
  const boundaryIds=new Set();
  const policyError=message=>errors.push({file:'config/architecture.json',line:1,message});
  if(policy.dependencyBoundaries!==undefined&&!Array.isArray(policy.dependencyBoundaries))
    policyError('dependencyBoundaries must be an array');
  for(const rule of Array.isArray(policy.dependencyBoundaries)?policy.dependencyBoundaries:[]) {
    if(!rule||typeof rule!=='object'){policyError('Invalid dependency boundary');continue;}
    const {id,from,forbiddenTargets,reason}=rule;
    if(typeof id!=='string'||!id.trim()||boundaryIds.has(id))policyError('Invalid or duplicate dependency boundary id');
    boundaryIds.add(id);
    if(typeof reason!=='string'||!reason.trim())policyError(`Dependency boundary ${id} needs a reason`);
    let valid=true;
    for(const [key,members] of Object.entries({from,forbiddenTargets})) {
      if(!Array.isArray(members)||!members.length||new Set(members).size!==members.length
        ||members.some(name=>typeof name!=='string'||!nodes.includes(name))) {
        policyError(`Dependency boundary ${id} needs unique known modules in ${key}`);valid=false;
      }
    }
    if(valid)for(const edge of edges)if(from.includes(edge.from)&&forbiddenTargets.includes(edge.to))
      errors.push({file:`src/lua/${edge.from}.lua`,line:edge.line,
        message:`Dependency boundary ${id}: ${edge.from} cannot depend on ${edge.to}`});
  }
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
