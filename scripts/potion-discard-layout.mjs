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
  const slots=l.potionDiscard;
  const actionWidth=(w-s.xxl*2-s.m*2)/3, actionStep=actionWidth+s.m;
  return [
    {name:'potionEntry',kind:'container',size:[...theme.canvas.base],visible:false,children:[
      button('open',[...entry.slice(0,3),l.topBar.height],'药水 0/3')]},
    {name:'potionPanel',kind:'container',size:[...theme.canvas.base],visible:false,children:[
      plate('veil',[0,0,...theme.canvas.base],c.backdropVeil),
      {name:'blocker',kind:'cursorArea',size:[...theme.canvas.base],focusable:false},
      plate('border',[0,0,w,h],c.goldDim),plate('face',[0,0,w-s.border*2,h-s.border*2],c.panel),
      text('title',[0,h/2-s.xxl-l.exitMenu.title[3]/2,w-s.xxl*2,l.exitMenu.title[3]],'药水管理',f.heading,c.goldBright),
      text('hint',[0,l.exitMenu.title[1]+s.xxl,w-s.xxl*2,l.nativeText.lineHeight],'选择药水，可使用战外药水或确认丢弃。',f.label,c.textDim),
      ...Array.from({length:l.battlePotions.count},(_,i)=>({
        ...button(`slot${i+1}`,[slots.columns[i%slots.columns.length],slots.rows[Math.floor(i/slots.columns.length)],...slots.size],`槽 ${i+1}\n空槽`),
        ...(i>=3?{visible:false}:{}),
      })),
      text('detail',slots.detail,'',f.body,c.text),
      button('cancel',[-actionStep,y,actionWidth,l.exitMenu.cancel[3]],'关闭'),
      button('use',[0,y,actionWidth,l.exitMenu.confirm[3]],'使用药水'),
      button('discard',[actionStep,y,actionWidth,l.exitMenu.confirm[3]],'确认丢弃'),
    ]},
  ];
}
