import {resolve,join} from 'node:path';
import {pathToFileURL} from 'node:url';
import {readFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {sha256} from '../../scripts/evidence-files.mjs';

// Use the upstream tool's own validated method in process. Its optional HTTP
// daemon needs an unsigned PowerShell ACL script rejected by this machine;
// no execution-policy change or global installation is needed for offline tools.
export async function shapeTools(workspace,{root=process.env.MILIASTRA_SHAPE_ROOT||resolve('.artifacts/miliastra-upstream')}={}){
  const registryPath=join(root,'src/tool-registry.mjs');
  const commit=execFileSync('git',['-C',root,'rev-parse','HEAD'],{encoding:'utf8',windowsHide:true}).trim();
  if(commit!=='f32c8b05415b64e3c2698535c1aee45b105f3304')throw Error('Upstream shape implementation differs from pinned experiment revision');
  const {toolRegistry,invokeTool}=await import(pathToFileURL(registryPath));
  const definitions=new Map(toolRegistry({workspace}).filter(t=>['scene_add_shape_prefab','scene_preview_shapes'].includes(t.name)).map(t=>[t.name,t]));
  if(definitions.size!==2)throw Error('Pinned upstream shape tools unavailable');
  return {provenance:{root,sourceCommit:'f32c8b05415b64e3c2698535c1aee45b105f3304',transport:'upstream_validated_offline_method',
    registrySha256:sha256(readFileSync(registryPath)),encoderSha256:sha256(readFileSync(join(root,'src/scene-save.mjs')))},
    call:async(name,args)=>{const def=definitions.get(name);if(!def)throw Error('Not an offline shape tool: '+name);return invokeTool(def,args);}};
}
