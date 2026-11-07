// One material replacement specimen. Native ID 107134 was visually inspected
// in the editor contact sheet plate-colour_03.jpg; it is not a reconstructed PNG.
export const materialSample=Object.freeze({
  name:'labMaterialBackdrop',image:107134,veilImage:100001,
  content:'official purple patterned plate; intentionally different art from custom landscape',
  kind:'native-image-background',status:'structural-only',runtimeStatus:'runtime-unverified',
  role:'low-cost art-direction fallback; not demonstrated savings in the current battle',
  sourceSheet:'src/scene/image-library/plate-colour_03.jpg',
  sourceTileId:107134,drawnImages:2,totalControls:3,
});
export function assetControls({size=[1280,720],visible=false}={}){
  return {name:materialSample.name,kind:'container',size,visible,children:[
    {name:'nativeImage',kind:'image',size,image:materialSample.image,colour:'#ffffff'},
    {name:'readabilityVeil',kind:'image',size,image:materialSample.veilImage,colour:'#101323',opacity:.24},
  ]};
}
export function installAssetControls(layout){
  const stage=layout.controls.find(c=>c.name==='stage');
  if(!stage||stage.children.some(c=>c.name===materialSample.name))throw Error('Expected fresh experiment stage');
  // Above stage backdrops, below all battle HUD, cards and input surfaces.
  const battle=stage.children.findIndex(c=>c.name==='battlePanel');
  if(battle<0)throw Error('Missing real battle panel');
  stage.children.splice(battle,0,assetControls());
  return layout;
}
