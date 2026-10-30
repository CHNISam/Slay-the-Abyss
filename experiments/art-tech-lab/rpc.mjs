import {spawn} from 'node:child_process';
import {createInterface} from 'node:readline';
import {writeFileSync,existsSync} from 'node:fs';
import {resolve} from 'node:path';
export function bridge(){
 const entry=resolve(process.env.ART_LAB_MCP_ENTRY || '.artifacts/art-lab-runtime/node_modules/beyond-simulator-mcp/dist/index.js');
 if(!existsSync(entry))throw Error('Simulator missing: install beyond-simulator-mcp@0.5.2 under .artifacts/art-lab-runtime or set ART_LAB_MCP_ENTRY.');
 const p=spawn(process.execPath,[entry,'--workspace',process.cwd()],{stdio:['pipe','pipe','inherit'],windowsHide:true});
 let id=0;const pending=new Map();
 const fail=error=>{for(const {reject,timer} of pending.values()){clearTimeout(timer);reject(error)}pending.clear()};
 p.on('error',fail);p.on('exit',(code,signal)=>fail(Error(`Simulator exited: ${code??signal}`)));
 createInterface({input:p.stdout}).on('line',line=>{
  let r;try{r=JSON.parse(line)}catch{return fail(Error('Invalid simulator JSON-RPC response'))}
  const waiting=pending.get(r.id);if(!waiting)return;
  pending.delete(r.id);clearTimeout(waiting.timer);
  r.error?waiting.reject(Error(JSON.stringify(r.error))):waiting.accept(r.result);
 });
 const request=(method,params)=>new Promise((accept,reject)=>{const n=++id;
  const timer=setTimeout(()=>{pending.delete(n);reject(Error(`Simulator request timed out: ${method}`));p.kill()},30000);
  pending.set(n,{accept,reject,timer});p.stdin.write(JSON.stringify({jsonrpc:'2.0',id:n,method,params})+'\n');
 });
 return {request,call:async(name,args)=>{const r=await request('tools/call',{name,arguments:args});if(r.isError)throw Error(JSON.stringify(r));return r},close:()=>p.kill()};
}
if(process.argv[2]==='list'){const b=bridge();await b.request('initialize',{protocolVersion:'2024-11-05',capabilities:{},clientInfo:{name:'art-lab',version:'1'}});writeFileSync('tools.json',JSON.stringify(await b.request('tools/list',{}),null,2));b.close();}
