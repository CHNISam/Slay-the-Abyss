import { mkdirSync, existsSync, readFileSync, writeFileSync, chmodSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { spawnSync } from 'node:child_process';
import { inside, sha256 } from './evidence-files.mjs';

export function luaTool() {
  const tools=JSON.parse(readFileSync(new URL('../config/lua-tools.json',import.meta.url),'utf8'));
  const platform=tools[process.platform];if(!platform||process.arch!=='x64')throw new Error('Pinned Luacheck supports Windows/Linux x64');
  return {...platform,version:tools.version,file:resolve('build/tools/luacheck',platform.asset),url:`${tools.repository}/releases/download/v${tools.version}/${platform.asset}`};
}
export function requireLuaTool() {
  const tool=luaTool();
  if(!existsSync(tool.file))throw new Error('Luacheck missing; run npm run setup:lua-static');
  inside(process.cwd(),tool.file);
  if(sha256(readFileSync(tool.file))!==tool.sha256)throw new Error('Luacheck binary hash mismatch');
  return tool;
}
if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href) {
  try{
    const tool=luaTool();mkdirSync('build/tools/luacheck',{recursive:true});inside(process.cwd(),'build/tools/luacheck');
    if(!existsSync(tool.file)) {
      // curl honors the runner's documented HTTPS_PROXY; Node 22 fetch does not.
      const result=spawnSync(process.platform==='win32'?'curl.exe':'curl',['--fail','--location','--silent','--show-error','--max-time','60',tool.url],{timeout:65000,maxBuffer:16*1024*1024});
      if(result.error||result.status!==0)throw new Error(`Luacheck download: ${result.error?.message||result.stderr?.toString()||result.status}`);
      const bytes=result.stdout;if(sha256(bytes)!==tool.sha256)throw new Error('Downloaded binary hash mismatch');
      writeFileSync(tool.file,bytes,{flag:'wx'});
    }
    requireLuaTool();if(process.platform!=='win32')chmodSync(tool.file,0o755);
    console.log(`Pinned Luacheck ${tool.version}: ${tool.sha256}`);
  }catch(error){console.error(error.message);process.exitCode=1;}
}
