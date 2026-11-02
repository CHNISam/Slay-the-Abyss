// Simulator inspect.box is pre-transform, pointer coordinates are bottom-left.
export function inspectorPointerCenter(ancestry){
 const box=ancestry.at(-1)?.box;if(!box)throw Error('Target has no inspector box');
 let x=box.left+box.width/2,y=box.bottom+box.height/2;
 for(const n of [...ancestry].reverse()){
  if(!n.box)continue;
  const cx=n.box.left+n.box.width/2,cy=n.box.bottom+n.box.height/2;
  const dx=(x-cx)*(n.localScaleX??1),dy=(y-cy)*(n.localScaleY??1),angle=(n.localRotationZ??0)*Math.PI/180;
  x=cx+dx*Math.cos(angle)-dy*Math.sin(angle);y=cy+dx*Math.sin(angle)+dy*Math.cos(angle);
 }
 return{x,y};
}
