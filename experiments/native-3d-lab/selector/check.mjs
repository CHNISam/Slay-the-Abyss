import {mkdirSync,writeFileSync,readFileSync,copyFileSync} from 'node:fs';
import {resolve,join} from 'node:path';
import {connect,data} from '../rpc.mjs';
import {install,buildLibrary,readbackSelector} from './install.mjs';
const base=process.argv[2],out=resolve(process.argv[3]||'.artifacts/native-selector-check');
if(!base)throw Error('Usage: node selector/check.mjs <base-copy.gil> [new-output-directory]');
mkdirSync(out,{recursive:true});const copy=join(out,'base.gil');copyFileSync(base,copy);
const library=buildLibrary();const client=await connect(join(out,'mcp'));
try{
  for(const uri of ['miliastra://workflow','miliastra://platform-rules']){
    const r=await client.readResource({uri});writeFileSync(join(out,uri.split('//')[1]+'.json'),JSON.stringify(r));
  }
  let seq=0;
  const receipt=await install({mapPath:copy,library,output:out,call:async(name,args)=>{
    const result=await client.callTool({name,arguments:args},undefined,{timeout:120000});
    writeFileSync(join(out,`${++seq}-${name}.json`),JSON.stringify(result));
    return data(result);
  }});
  receipt.uiReadback=await readbackSelector(receipt.mapPath,receipt.selectorId,library.cards);
  writeFileSync(join(out,'selector.json'),JSON.stringify(receipt,null,2));
  console.log(JSON.stringify({selectorId:receipt.selectorId,graph:receipt.readback,
    fixture:library.cardIds,libraryEntries:library.cards.length,verification:receipt.verification,mapPath:receipt.mapPath}));
}finally{await client.close()}
