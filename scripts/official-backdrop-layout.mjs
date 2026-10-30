import {nativeControls,nativeTheme} from './native-ui-theme.mjs';
// Whole official colour-plate assets, observed in the editor's own contact sheets.
// Each displayed backdrop is one existing image; no shape reconstruction.
export function attachOfficialBackdrops(layout,theme=nativeTheme) {
 const {plate}=nativeControls(theme),[w,h]=theme.canvas.base,ids=theme.image.officialBackdrops;
 const menu=layout.controls.find(c=>c.name==='menuPanel');
 const characters=layout.controls.find(c=>c.name==='characterPanel');
 for(const [panel,name,id]of [[menu,'backdrop',ids.title],[characters,'veil',ids.selection]]) {
  const image=panel.children.find(c=>c.name===name);if(!image)throw Error('Missing backdrop '+name);
  Object.assign(image,{image:id,colour:theme.color.officialBackdropTint,opacity:1,size:[w,h]});
  panel.children.splice(panel.children.indexOf(image)+1,0,plate('officialBackdropVeil',[0,0,w,h],theme.color.officialBackdropVeil));
 }
 const names=['act1_1','act1_2','act1_3','act2_1','act2_2','act2_3','boss1','boss2'];
 layout.controls.unshift({name:'officialBattleBackdrop',kind:'container',size:[w,h],visible:false,children:[
  ...names.map(name=>({name,kind:'image',size:[w,h],image:ids[name],colour:theme.color.officialBackdropTint,visible:false})),
  plate('readabilityVeil',[0,0,w,h],theme.color.officialBackdropVeil)
 ]});
 return names;
}
