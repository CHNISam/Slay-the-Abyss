// Reuse the approved 12-card native forge grid; add only back covers/retry.
import {nativeControls,nativeTheme} from './native-ui-theme.mjs';
export function augmentMatchEventPicker(picker,theme=nativeTheme){
  const {text,plate,frame,hit}=nativeControls(theme),{color:c,font:f,space:s}=theme;
  const {forge}=theme.layout.nativeNode,[w,h]=theme.layout.card.size;
  const grid=picker.children.find(item=>item.name==='forgeGrid');
  if(!grid||grid.children.length!==12)throw new Error('Match requires the existing complete forge grid');
  for(const [index,card]of grid.children.entries()){
    if(card.children.some(item=>item.name==='matchBack'))throw new Error('Match back already installed');
    const overhang=theme.layout.card.trim.costOverhang;
    const back={name:'matchBack',kind:'container',size:[w+overhang*2,h+overhang*2],visible:false,children:[
      plate('plate',frame([0,0],[w+overhang*2,h+overhang*2]),c.panelSunken),
      {...plate('glyph',frame([0,s.xl],[theme.layout.card.artIcon,theme.layout.card.artIcon]),c.geo),image:theme.icon.geo},
      text('label',frame([0,-s.xxl],[w-s.l,Math.max(f.body*2,theme.layout.nativeText.lineHeight)]),'石牌 '+(index+1),f.body,c.goldBright)]};
    const hitIndex=card.children.findIndex(item=>item.name==='hit');
    if(hitIndex<0)throw new Error('Match requires the existing card hit area');
    card.children.splice(hitIndex,0,back);
  }
  const size=[forge.label[2],theme.layout.nativeNode.confirm[3]],faceSize=size.map(n=>n-s.border*2),hidden=control=>({...control,visible:false});
  picker.children.push({name:'matchRetry',kind:'container',position:[0,forge.page[1]],size,visible:false,children:[
    plate('border',frame([0,0],size),c.gold),
    plate('normal',frame([0,0],faceSize),c.panelRaised),
    hidden(plate('disabled',frame([0,0],faceSize),c.panelSunken)),
    hidden(plate('hover',frame([0,0],faceSize),c.buttonHover)),
    hidden(plate('pressed',frame([0,0],faceSize),c.buttonPressedFill)),
    hidden(plate('selected',frame([0,0],faceSize),c.buttonPressedFill)),
    text('label',frame([0,0],[size[0]-s.l,size[1]]),'重新结算',f.body,c.goldBright),hit(size)]});
  return picker;
}
