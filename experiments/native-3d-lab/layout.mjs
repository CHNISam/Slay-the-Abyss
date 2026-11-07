import {nativeControls,nativeTheme} from '../../scripts/native-ui-theme.mjs';

// Same viewport as the production UI. Both panels collapse away from the hand.
export function labControls(theme=nativeTheme){
  const {text,plate,button}=nativeControls(theme),c=theme.color;
  const label=(name,rect,value,size=16)=>text(name,rect,value,size,c.text);
  const action=(name,x,y,caption,w=148)=>button(name,[x,y,w,38],caption,
    {inset:[8,4],fontSize:16,fill:c.panelRaised,border:c.goldDim});
  return {name:'labPanel',kind:'container',size:[1280,720],children:[
    action('fold',-453,329,'3D 实验室 · 收起',346),
    {name:'menu',kind:'container',position:[-453,111],size:[346,398],children:[
      plate('shade',[0,0,346,398],c.panelSunken),
      label('mode', [0,170,326,30],'当前：2D · 同一套卡牌规则'),
      action('compare',-80,131,'2D / 3D 对比'),action('model',80,131,'怪物展示'),
      action('animations',-80,87,'动画连续测试'),action('combat',80,87,'完整战斗'),
      action('cards',-80,43,'卡牌对比'),action('performance',80,43,'性能配对测试'),
      action('idle',-120,-1,'待机',70),action('attack',-40,-1,'攻击',70),
      action('hit',40,-1,'受击',70),action('death',120,-1,'销毁',70),
      action('all',-80,-45,'全部连续测试'),action('stop',80,-45,'停止 / 恢复'),
      action('reset',-80,-89,'重置同种子战斗'),action('logs',80,-89,'显示 / 隐藏日志'),
      action('tween',0,-133,'卡牌 Tween A / B 对比',308),
      label('hint',[0,-174,324,42],'拖牌/点选沿用正式规则。\n销毁非死亡clip，收起可观察战场。',15),
    ]},
    {name:'diagnostics',kind:'container',position:[447,110],size:[362,440],children:[
      plate('shade',[0,0,362,440],c.panelSunken),
      label('title',[0,200,342,32],'实验结果 / 当前候选',17),
      label('status',[0,155,342,58],'初始化实验；原生视觉与手机未验证',15),
      {...label('metrics',[0,70,342,105],'OnUpdate 间隔：等待采样\nGPU / 内存 / 官方负载：无接口\n手机：UNVERIFIED',14),text:{...label('m',[0,0,0,0],'').text,content:'OnUpdate 间隔：等待采样\nGPU / 内存 / 官方负载：无接口\n手机：UNVERIFIED',fontSize:14,minFontSize:14}},
      {...label('log',[0,-100,342,220],'屏内日志（最多 12 行）',14),text:{...label('l',[0,0,0,0],'').text,content:'屏内日志（最多 12 行）',fontSize:14,minFontSize:14,align:'left'}},
    ]},
    {name:'cardSamples',kind:'container',position:[0,10],size:[540,310],visible:false,children:[
      ...[-1,0,1].map((x,i)=>({name:'sample'+(i+1),kind:'container',position:[x*180,0],size:[168,268],children:[
        plate('edge',[0,0,168,268],c.goldDim),plate('face',[0,0,164,264],c.panelRaised),
        label('name',[0,109,154,40],'当前手牌',17),label('type',[0,72,154,26],'',15),
        label('label',[0,-3,152,118],'',14),label('cost',[0,-92,154,28],'',16),
        label('note',[0,-119,154,24],'点击出牌',14),
        {name:'hit',kind:'cursorArea',size:[168,268],focusable:true},
      ]})),label('sampleTitle',[0,156,530,40],'同一手牌完整文本 · 分组变换 · 点击出牌',16),
    ]},
  ]};
}
