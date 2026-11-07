import {nativeControls,nativeTheme} from '../../scripts/native-ui-theme.mjs';
export function expansionControls(theme=nativeTheme){
 const {button,text,plate}=nativeControls(theme),c=theme.color;
 return {name:'expansionPanel',kind:'container',position:[0,290],size:[510,112],children:[
  plate('shade',[0,0,510,112],c.panelSunken),
  ...[['shape','拼装怪物'],['selector','原生战后选牌'],['assets','官方底板对照']].map(([name,label],i)=>button(name,[(i-1)*164,29,156,36],label,{fontSize:16,inset:[8,4]})),
  text('status',[0,-20,494,55],'新增样例 · 原生表现与负载待当前候选实测',15,c.text),
 ]};
}
