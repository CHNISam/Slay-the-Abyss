import { nativeControls, nativeTheme } from './native-ui-theme.mjs';

// Existing node counter, modal, shop slots and four-state utility-button tokens.
export function potionDiscardControls(theme = nativeTheme) {
  const { plate, text }=nativeControls(theme);
  const {color:c,font:f,layout:l,space:s}=theme;
  const button=(name,frame,label)=>{
    const size=frame.slice(2),variants={normal:[c.panelRaised,c.goldBright,c.goldDim],
      hover:[c.buttonHover,c.goldBright,c.goldBright],pressed:[c.goldDim,c.buttonPressedText,c.goldBright],
      disabled:[c.panelSunken,c.textMuted,c.line]};
    return {name,kind:'container',position:frame.slice(0,2),size,children:[{
      name:'hit',kind:'presetButton',size,focusable:true,
      states:Object.fromEntries(Object.keys(variants).map(state=>[state,state])),
      children:Object.entries(variants).map(([state,[fill,ink,border]])=>({name:state,kind:'container',size,
        scale:state==='pressed'?[l.exitMenu.pressedScale,l.exitMenu.pressedScale]:[1,1],children:[
          plate('border',[0,0,...size],border),plate('plate',[0,0,...size.map(v=>v-s.border*2)],fill),
          text('label',[0,0,...size.map((v,i)=>v-l.exitMenu.buttonInset[i])],label,f.label,ink)]}))} ]};
  };
  const [w,h]=l.modal.size,entry=l.nativeNode.topBar.potions;
  const y=-h/2+s.l+l.exitMenu.cancel[3]/2;
  const slots=l.nativeNode.shop.potions;
  return [
    {name:'potionEntry',kind:'container',size:[...theme.canvas.base],visible:false,children:[
      button('open',[...entry.slice(0,3),l.topBar.height],'药水 0/3')]},
    {name:'potionPanel',kind:'container',size:[...theme.canvas.base],visible:false,children:[
      plate('veil',[0,0,...theme.canvas.base],c.backdropVeil),
      {name:'blocker',kind:'cursorArea',size:[...theme.canvas.base],focusable:false},
      plate('border',[0,0,w,h],c.goldDim),plate('face',[0,0,w-s.border*2,h-s.border*2],c.panel),
      text('title',[0,h/2-s.xxl-l.exitMenu.title[3]/2,w-s.xxl*2,l.exitMenu.title[3]],'丢弃药水',f.heading,c.goldBright),
      text('hint',[0,l.exitMenu.title[1]+s.xxl,w-s.xxl*2,l.nativeText.lineHeight],'选择旧药水，再确认丢弃以腾出空槽。',f.label,c.textDim),
      ...slots.columns.map((x,i)=>button(`slot${i+1}`,[x-slots.columns[1],l.exitMenu.message[1],...slots.size],`槽 ${i+1}\n空槽`)),
      text('detail',[0,l.exitMenu.status[1]-s.xxl,w-s.xxl*2,l.exitMenu.message[3]],'',f.body,c.text),
      button('cancel',[l.exitMenu.cancel[0],y,...l.exitMenu.cancel.slice(2)],'关闭'),
      button('discard',[l.exitMenu.confirm[0],y,...l.exitMenu.confirm.slice(2)],'确认丢弃'),
    ]},
  ];
}
