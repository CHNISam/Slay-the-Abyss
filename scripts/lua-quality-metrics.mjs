import { readdirSync, readFileSync } from 'node:fs';
import { join, relative } from 'node:path';
import luaparse from 'luaparse';
import { sha256 } from './evidence-files.mjs';

export function discoverSources(root=process.cwd()) {
  const sources={};
  function scan(directory) {
    for(const entry of readdirSync(directory,{withFileTypes:true}).sort((a,b)=>a.name.localeCompare(b.name,'en'))) {
      const path=join(directory,entry.name);
      // A link must not silently move a responsibility outside the scan.
      if(entry.isSymbolicLink())throw new Error(`Linked source entry is not supported: ${path}`);
      if(entry.isDirectory())scan(path);
      else if(entry.name.endsWith('.lua'))sources[relative(root,path).replaceAll('\\','/')]=readFileSync(path,'utf8');
    }
  }
  scan(join(root,'src/lua'));
  if(!Object.keys(sources).length)throw new Error('No Lua sources discovered');
  return sources;
}

const symbol = node => node?.type==='Identifier' ? node.name
  : node?.type==='MemberExpression' ? `${symbol(node.base)}${node.indexer}${symbol(node.identifier)}` : null;

function functionLocations(source) {
  const parsed=Buffer.from(source).toString('latin1');
  const options={luaVersion:'5.3',encodingMode:'pseudo-latin1',locations:true,ranges:true,comments:false};
  const ast=luaparse.parse(parsed,options);
  luaparse.parse(parsed,{...options,wait:true});
  const keywords=[];
  for(let token=luaparse.lex();token.type!==luaparse.tokenTypes.EOF;token=luaparse.lex()) {
    if(token.type===luaparse.tokenTypes.Keyword&&token.value==='function')keywords.push(token);
  }
  const lines=source.split('\n'),functions=[],counts=new Map();
  function visit(node,parent,key,index,owner='$') {
    if(!node||typeof node!=='object')return;
    if(node.type==='FunctionDeclaration') {
      const token=keywords.find(t=>t.range[0]>=node.range[0]&&t.range[0]<node.range[1]);
      if(!token)throw new Error('AST function keyword missing');
      const assigned=['LocalStatement','AssignmentStatement'].includes(parent?.type)&&key==='init'
        ? symbol(parent.variables[index]) : parent?.type==='TableKeyString' ? symbol(parent.key) : null;
      const name=symbol(node.identifier)??assigned??'<anonymous>';
      const identity=`${owner}/${name}`,ordinal=(counts.get(identity)??0)+1;
      counts.set(identity,ordinal);
      const id=`${identity}#${ordinal}`;
      const line=token.line,column=token.range[0]-token.lineStart;
      const unicodeColumn=Array.from(Buffer.from(lines[line-1]).subarray(0,column).toString('utf8')).length+1;
      functions.push({id,name,kind:'function',constructorName:/(?:^|[.:])(?:new|create)$/.test(name),
        line,column:unicodeColumn,endLine:node.loc.end.line,lines:node.loc.end.line-node.loc.start.line+1});
      owner=id;
    }
    for(const [childKey,value] of Object.entries(node))if(!['loc','range','comments','globals'].includes(childKey)) {
      if(Array.isArray(value))value.forEach((child,i)=>visit(child,node,childKey,i,owner));
      else if(value&&typeof value==='object')visit(value,node,childKey,0,owner);
    }
  }
  visit(ast);
  return functions;
}

export function measureSources(sources,diagnostics) {
  const modules=[],errors=[];
  const files=Object.keys(sources).sort();
  if(!files.length)errors.push({message:'No Lua sources measured'});
  for(const row of diagnostics)if(!(row.file in sources))errors.push({...row,message:'Complexity measurement has unknown source file'});
  for(const file of files) {
    const source=sources[file].replaceAll('\r\n','\n');
    const lines=source.length ? source.split('\n').length-(source.endsWith('\n')?1:0) : 0;
    try {
      const functions=[{id:'$',name:'<chunk>',kind:'chunk',constructorName:false,line:1,column:1,endLine:Math.max(1,lines),lines},
        ...functionLocations(source)];
      const positions=new Map(functions.map(f=>[`${f.kind}:${f.line}:${f.column}`,f]));
      if(positions.size!==functions.length)errors.push({file,message:'Duplicate AST function positions'});
      const seen=new Set();
      for(const row of diagnostics.filter(r=>r.file===file)) {
        const match=/^cyclomatic complexity of (.+) is too high \(([1-9]\d*) > 0\)$/.exec(row.message);
        if(row.code!=='W561'||!match||!/^(?:main chunk|function|(?:function|method) '[^']+')$/.test(match[1])
          ||!Number.isSafeInteger(Number(match[2]))) {
          errors.push({...row,message:'Unrecognized complexity measurement'});continue;
        }
        const kind=match[1]==='main chunk'?'chunk':'function';
        const key=`${kind}:${row.line}:${row.column}`,fn=positions.get(key);
        if(!fn)errors.push({...row,message:'Complexity measurement has no AST function/chunk'});
        else if(seen.has(key))errors.push({...row,message:'Duplicate complexity measurement'});
        else {fn.complexity=Number(match[2]);seen.add(key);}
      }
      for(const [key,fn] of positions)if(!seen.has(key))errors.push({file,line:fn.line,message:`Missing complexity measurement: ${fn.id}`});
      modules.push({file,sha256:sha256(source),lines,functions});
    } catch(error) {errors.push({file,message:`Lua AST failed: ${error.message}`});}
  }
  return {modules,errors};
}

// Strongly connected components keep the full edge set, including reviewed
// deferred imports. They describe structural cycles, not a runtime-load verdict.
export function dependencyCycles(nodes,edges) {
  const adjacency=new Map([...nodes].sort().map(n=>[n,[]]));
  for(const edge of edges)if(adjacency.has(edge.from)&&adjacency.has(edge.to))adjacency.get(edge.from).push(edge.to);
  const indexes=new Map(),low=new Map(),stack=[],active=new Set(),components=[];
  let next=0;
  function visit(name) {
    indexes.set(name,next);low.set(name,next++);stack.push(name);active.add(name);
    for(const to of adjacency.get(name)) {
      if(!indexes.has(to)){visit(to);low.set(name,Math.min(low.get(name),low.get(to)));}
      else if(active.has(to))low.set(name,Math.min(low.get(name),indexes.get(to)));
    }
    if(low.get(name)!==indexes.get(name))return;
    const members=[];
    let popped;
    do {popped=stack.pop();active.delete(popped);members.push(popped);}while(popped!==name);
    if(members.length>1||adjacency.get(name).includes(name)) {
      members.sort();const memberSet=new Set(members);
      const internal=edges.filter(e=>memberSet.has(e.from)&&memberSet.has(e.to))
        .sort((a,b)=>a.from.localeCompare(b.from,'en')||a.to.localeCompare(b.to,'en')||(a.line??0)-(b.line??0));
      components.push({members,edges:internal});
    }
  }
  for(const name of adjacency.keys())if(!indexes.has(name))visit(name);
  return components.sort((a,b)=>a.members.join('\0').localeCompare(b.members.join('\0'),'en'));
}
