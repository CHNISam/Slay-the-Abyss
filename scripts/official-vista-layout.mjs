// Lightweight scenery assembled from verified official UI shapes/plates.
// These are abstract ruins, not a claim that the library contains landscape photos.
// Source IDs: image-library/plate-mono_01.jpg and plate-mono_02.jpg in the installed toolchain.
import {nativeControls, nativeTheme} from './native-ui-theme.mjs';

export const officialVistaVariants=Object.freeze(['title','act1','act2']);
export function sceneBackdrop(theme=nativeTheme,variant='title') {
  if(!officialVistaVariants.includes(variant))throw Error('Unknown official vista '+variant);
  const {plate}=nativeControls(theme),im=theme.image,c=theme.color,v=c.vista;
  const [w,h]=theme.canvas.base;
  const image=(name,id,x,y,width,height,colour,opacity=1)=>({name,kind:'image',position:[x,y],size:[width,height],image:id,colour,opacity});
  const children=[plate('sky',[0,0,w,h],v.sky)];
  if(variant==='title')children.push(
    image('halo',im.glowWide,w*.28,h*.16,w*.6,h*.8,c.geoDeep,.22),
    image('farTower',im.ruin,w*.34,-h*.05,w*.1,h*.72,v.far),
    image('tower',im.ruin,w*.28,-h*.04,w*.075,h*.75,v.mid),
    image('sealGlow',im.glow,w*.28,h*.29,w*.2,w*.2,c.geo,.3),
    image('sealRing',im.ring,w*.28,h*.29,w*.11,w*.11,c.goldDim,.8),
    image('sealCore',im.disc,w*.28,h*.29,w*.036,w*.036,c.goldBright,.8),
    image('leftPillar',im.ruin,-w*.38,-h*.18,w*.05,h*.39,v.near),
    image('brokenPillar',im.ruin,-w*.29,-h*.24,w*.038,h*.24,v.mid),
    image('leftWall',im.ruinWall,-w*.19,-h*.32,w*.2,h*.15,v.near),
    image('shards',im.shards,w*.27,h*.29,w*.17,h*.18,c.goldDim,.35),
    image('horizon',im.fadeLine,0,-h*.35,w*.85,h*.025,c.geoDeep,.45)
  );
  if(variant==='act1')children.push(
    image('distantLight',im.glowWide,w*.32,h*.1,w*.7,h*.8,c.geoDeep,.18),
    image('rearWall',im.ruinWall,w*.28,-h*.12,w*.36,h*.43,v.far),
    image('rearPillar',im.ruin,w*.4,-h*.03,w*.065,h*.72,v.mid),
    image('brokenLeft',im.ruin,-w*.42,-h*.07,w*.065,h*.64,v.mid),
    image('leftBase',im.ruinWall,-w*.38,-h*.29,w*.2,h*.16,v.near),
    image('lowPillar',im.ruin,-w*.3,-h*.22,w*.045,h*.32,v.near),
    image('sealRing',im.ring,w*.32,h*.2,w*.14,w*.14,c.geoDeep,.33),
    image('sealGlow',im.glow,w*.32,h*.2,w*.16,w*.16,c.goldDim,.18),
    image('rubbleLeft',im.shards,-w*.41,-h*.34,w*.23,h*.14,v.near),
    image('rubbleRight',im.shards,w*.43,-h*.33,w*.16,h*.18,c.goldDim,.2),
    image('horizon',im.fadeLine,0,-h*.32,w*.9,h*.025,c.geoDeep,.3)
  );
  if(variant==='act2')children.push(
    image('coolLight',im.glowWide,-w*.32,h*.19,w*.8,h*.8,c.block,.13),
    image('farArchLeft',im.ruin,-w*.27,-h*.04,w*.055,h*.7,v.far),
    image('farArchRight',im.ruin,w*.23,-h*.04,w*.055,h*.7,v.far),
    image('archLintel',im.ruinWall,-w*.02,h*.26,w*.54,h*.085,v.mid),
    image('nearColumnLeft',im.ruin,-w*.45,-h*.03,w*.09,h*.83,v.near),
    image('nearColumnRight',im.ruin,w*.44,-h*.03,w*.09,h*.83,v.near),
    image('leftBeam',im.beam,-w*.34,h*.1,w*.025,h*.65,c.block,.12),
    image('rightBeam',im.beam,w*.33,h*.08,w*.02,h*.68,c.block,.1),
    image('fallenLintel',im.ruinWall,w*.35,-h*.33,w*.26,h*.14,v.mid),
    image('fragments',im.shards,-w*.35,-h*.34,w*.23,h*.16,v.near),
    image('floorLine',im.fadeLine,0,-h*.32,w*.9,h*.018,c.block,.22)
  );
  children.push(plate('ground',[0,-h*.46,w,h*.14],v.ground),
    image('vignette',im.vignette,0,0,w,h,v.shade,.4));
  return {name:'officialVista_'+variant,kind:'container',size:[w,h],visible:false,children};
}
