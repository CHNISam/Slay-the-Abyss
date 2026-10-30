import { nativeControls, nativeTheme } from './native-ui-theme.mjs';
import { potionSlotVisual } from './potion-slot-visual.mjs';

// Existing node counter, modal, shop slots and four-state utility-button tokens.
export function potionDiscardControls(theme = nativeTheme) {
  const { plate, text }=nativeControls(theme);
  const {color:c,font:f,layout:l,space:s}=theme;
  // Button tiers: primary (gold), secondary (raised neutral), ghost (quiet close),
  // danger (destructive discard). Disabled ink stays >=4.5:1 on its sunken plate.
  const tiers={
    primary:{normal:[c.goldDim,c.buttonPressedText,c.gold],hover:[c.gold,c.textOnLight,c.goldBright]},
    secondary:{normal:[c.panelRaised,c.goldBright,c.goldDim],hover:[c.buttonHover,c.goldBright,c.goldBright]},
    ghost:{normal:[c.panel,c.text,c.line],hover:[c.panelRaised,c.goldBright,c.goldDim]},
    danger:{normal:[c.panelRaised,c.danger,c.danger],hover:[c.buttonHover,c.text,c.danger]},
  };
  const button=(name,frame,label,tier='secondary',font=f.label)=>{
    const size=frame.slice(2),variants={...tiers[tier],pressed:[c.goldDim,c.buttonPressedText,c.goldBright],
      disabled:[c.panelSunken,c.textDim,c.line]};
    return {name,kind:'container',position:frame.slice(0,2),size,children:[{
      name:'hit',kind:'presetButton',size,focusable:true,
      states:Object.fromEntries(Object.keys(variants).map(state=>[state,state])),
      children:Object.entries(variants).map(([state,[fill,ink,border]])=>({name:state,kind:'container',size,
        scale:state==='pressed'?[l.exitMenu.pressedScale,l.exitMenu.pressedScale]:[1,1],children:[
          plate('border',[0,0,...size],border),plate('plate',[0,0,...size.map(v=>v-s.border*2)],fill),
          text('label',[0,0,...size.map((v,i)=>v-l.exitMenu.buttonInset[i])],label,font,ink)]}))} ]};
  };
  const [w,h]=l.modal.size,entry=l.nativeNode.topBar.potions;
  const y=-h/2+s.l+l.exitMenu.cancel[3]/2;
  const slots=l.potionDiscard, head=slots.header;
  const actionWidth=(w-s.xxl*2-s.m*2)/3, actionStep=actionWidth+s.m;
  // One unchanged management action; physical bottle silhouettes are not new
  // direct-use buttons. Runtime paints sparse inventory and actual 3/5 capacity.
  const open = button('open', [...entry.slice(0,3), l.topBar.height], '药水 0/3');
  const visual = l.potionDiscard.entryVisual;
  const palette = { normal: c.mapHeader.menuNormal, hover: c.mapHeader.menuHover,
    pressed: c.mapHeader.menuPressed, disabled: { fill: c.panelSunken, ink: c.textMuted, border: c.line } };
  for (const state of open.children[0].children) {
    const colours = palette[state.name], label = state.children.find(control => control.name === 'label');
    label.visible = false;
    state.children = [label, ...Array.from({ length: l.battlePotions.count }, (_, i) => {
      const children = potionSlotVisual(theme, {
        border: plate('border', [0, 0, ...visual.size], colours.border),
        plate: plate('plate', [0, 0, ...visual.size.map(value => value - visual.border * 2)], colours.fill),
        bottleSize: visual.bottleSize, ink: colours.ink,
      });
      children.find(control => control.name === 'bottle').visible = false;
      return { name: `slot${i + 1}`, kind: 'container', position: [visual.origin + visual.step * i, 0],
        size: [...visual.size], visible: i < 3, children };
    })];
  }
  return [
    {name:'potionEntry',kind:'container',size:[...theme.canvas.base],visible:false,children:[
      open]},
    {name:'potionPanel',kind:'container',size:[...theme.canvas.base],visible:false,children:[
      plate('veil',[0,0,...theme.canvas.base],c.backdropVeil),
      {name:'blocker',kind:'cursorArea',size:[...theme.canvas.base],focusable:false},
      plate('border',[0,0,w,h],c.goldDim),plate('face',[0,0,w-s.border*2,h-s.border*2],c.panel),
      text('title',[0,head.titleY,w-s.xxl*2,head.textHeight],'药水管理',f.title,c.goldBright),
      plate('rule',[0,head.ruleY,...head.ruleSize],c.goldDim),
      text('hint',[0,head.hintY,w-s.xxl*2,head.textHeight],'选择一瓶药水查看效果',f.label,c.textDim),
      ...Array.from({length:l.battlePotions.count},(_,i)=>({
        ...button(`slot${i+1}`,[slots.columns[i%slots.columns.length],slots.rows[Math.floor(i/slots.columns.length)],...slots.size],`槽 ${i+1}\n空槽`,'secondary',f.body),
        ...(i>=3?{visible:false}:{}),
      })),
      plate('detailWell',slots.detail,c.panelSunken),
      text('detail',slots.detail,'',f.body,c.text),
      button('cancel',[-actionStep,y,actionWidth,l.exitMenu.cancel[3]],'关闭','ghost'),
      button('use',[0,y,actionWidth,l.exitMenu.confirm[3]],'使用药水','primary'),
      button('discard',[actionStep,y,actionWidth,l.exitMenu.confirm[3]],'确认丢弃','danger'),
    ]},
  ];
}
