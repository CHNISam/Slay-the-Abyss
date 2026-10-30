// Pure formatting only: callers still execute every projection and proof guard.
// Exact source strings (not parsed values/digests) distinguish all token drift.
const cache=new Map();
const tokens=text=>text.replace(/"(?:\\.|[^"\\])*"|[ \t\r\n]+/g,token=>token.startsWith('"')?token:'');
export function architectureSourceFormat(path,source){
 const cacheable=path==='config/architecture.json'&&typeof source==='string';
 if(cacheable&&cache.has(source))return cache.get(source);
 const formatted=JSON.stringify(JSON.parse(source),null,2)+'\n';
 const result=Object.freeze({formatted,tokensEqual:tokens(source)===tokens(formatted)});
 if(cacheable){
  if(cache.size===8)cache.delete(cache.keys().next().value);
  cache.set(source,result);
 }
 return result;
}
