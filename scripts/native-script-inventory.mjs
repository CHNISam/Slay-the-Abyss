import {readFileSync} from 'node:fs';
// Read only section 50. Computing which UI controls mount each module is not
// needed for payload identity and causes a module × UI traversal in the tool.
export function embeddedScripts({mapPath,includeSource=false},{container,fields,one}) {
 const root=container(readFileSync(mapPath));
 const text=(data,id)=>fields(data).find(f=>f.id===id&&f.wire===2)?.data.toString('utf8');
 return {scripts:fields(one(root,50)).filter(f=>f.id===1&&f.wire===2).map(f=>({name:text(f.data,2),file:text(f.data,3),
  ...(includeSource?{source:text(f.data,5)}:{})}))};
}
