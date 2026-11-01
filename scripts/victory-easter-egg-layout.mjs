import {nativeControls,nativeTheme} from './native-ui-theme.mjs';

export function attachVictoryEasterEgg(layout,theme=nativeTheme) {
 const controls=layout.controls.find(control=>control.name==='stage')?.children??layout.controls;
 const menu=controls.find(control=>control.name==='menuPanel');
 const result=menu?.children.find(control=>control.name==='result');
 if(!result||controls.some(control=>control.name==='victoryEasterEgg'))throw Error('Expected fresh victory result controls');
 const {button,text,plate}=nativeControls(theme),positions=theme.layout.victoryEgg;
 if(!positions)throw Error('Missing victory egg theme layout');
 const style={inset:theme.layout.nativeMenu.buttonInset,fontSize:theme.font.label,colour:theme.color.goldBright,
  fill:theme.color.panelRaised,border:theme.color.gold};
 result.children.push({...button('viewEasterEgg',positions.open,'查看彩蛋',style),visible:false});
 const panel={name:'victoryEasterEgg',kind:'container',size:[...theme.canvas.base],visible:false,isolateNavigation:true,children:[
  {name:'blocker',kind:'cursorArea',size:[...theme.canvas.base],focusable:false},
  plate('thanksVeil',[positions.thanks[0],positions.thanks[1],positions.thanks[2],positions.thanks[3]+theme.space.l],theme.color.backdropVeil),
  text('thanks',positions.thanks,'感谢您的游玩~！',theme.font.heading,theme.color.goldBright),
  text('status',positions.status,'',theme.font.body,theme.color.text),
  button('close',positions.close,'返回结算',style),
 ]};
 controls.push(panel);
 return panel;
}
