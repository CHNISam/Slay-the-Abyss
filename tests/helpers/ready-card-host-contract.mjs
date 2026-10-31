// Preserve the original 38 battle/shop/picker hosts and the twelve release
// starter-deck faces. Expected paths are independent of the production walker.
const cards=(prefix,count,suffix='')=>Array.from({length:count},(_,i)=>`SlayTheAbyss/stage/${prefix}${i+1}${suffix}`);
export const expectedReadyCardGameHosts=[
 ...cards('battlePanel/card',10),...cards('nodePanel/shopView/card',7),
 ...cards('nodePanel/pickerView/card',6),
 ...['before','after','target'].map(name=>`SlayTheAbyss/stage/nodePanel/pickerView/${name}`),
 ...cards('nodePanel/pickerView/forgeGrid/card',12),
 ...cards('characterPanel/deckView/deckCard',12,'/face'),
];
export function readyCardHolderPaths(tree){
 const paths=[];
 function visit(node,parent=[]){
  const path=[...parent,node.name];
  if(node.name==='artSamples')paths.push(parent.join('/'));
  for(const child of node.children??node.controls??[])visit(child,path);
 }
 visit(tree);return paths;
}
