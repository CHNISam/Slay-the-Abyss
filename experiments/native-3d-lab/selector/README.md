# 原生战后选牌对照（TASK-102 / PR #553）

本轮时限复核：直接CLI最初通过只证明断言，不证明项目30秒预算；随后Node22与Node24在原预算均超时。仅测试夹具改为一次真实18命令基线、后续独立深拷贝，原断言保留并增加隔离断言；主执行者使用项目便携Node24经 `scripts/test-lua.mjs` 原30秒入口复跑7030ms通过。`evidence.json` 中测试文件hash对应优化前历史，当前测试hash为 `325d2c6c40a8af174a622400a8ea3653225a3533d1aa8483de23041740001905`。生产runtime/fixture未为此引入缓存。

这是同 GIL 中的**普通三选一奖励实验**，不是通用战后选牌替代。正式界面保留，任何能力缺失、取消、超时或所有权变化均回到未领取的正式奖励，不自动给牌。

## 已实现

- `fixture.lua` 用真实 `Run.new(data,42)`、`Run.startCombat('cultist_solo')`、`Run.play` / `Run.endTurn` 共18条命令击败邪教徒，取得原结算生成的奖励：`shockwave`、`clash`、`shrug_it_off`。这是显式奖励夹具，不计作自然通关。
- 构建直接复用 `render_traveler_cards.py` 和现有 `cards.json` / 中文覆盖，生成上述3牌的普通/升级共6条原生库。名称、费用、类型、完整效果同源，不手写第二套文案。
- 打开时读取**当前**候选顺序、1至3张子集和逐张升级标志，发送库引用；返回值编码请求token及当前槽，支持重复卡ID的槽语义。新牌UID仍由 `Run.claimCardReward` / `Run.obtainCard` 分配。
- Lua捕获正式 `abyss_battle_reward_owner` 快照、Run/战斗/房间/局部代次；开关模态递增奖励UI epoch。旧按钮、迟到/重复回执、换奖励、换战斗不能重复领取。
- 原生超时默认值只编码空选择；只有玩家完成且token/槽/所有权均有效才调用正式事务。原生“放弃”、脚本取消、32秒无回执均恢复正式UI、不消耗奖励。服务器在关闭完成前拒绝新窗口，避免旧窗口空回执冒认新token。

## 接口

```lua
local selector=require('abyss_3d_selector').attach(view,script.object,{
  config=expansionConfig.selector,
  send=function(name,params) -- params: {{type='integer',value=...},...}
  end,
  register=function(name,callback) -- callback({token,encodedResult,reason})
  end,
  log=function(message) end,
})
selector:start('native',true) -- true：先生成新奖励夹具
selector:classic()           -- 恢复完整正式奖励，点CARD行进入原有选牌
selector:update(dt)
selector:destroy()
```

另有 `:fixture()`、`:open()`、`:cancel(reason)`、`:status()`。包名分别为 `runtime.lua → abyss_3d_selector`、`fixture.lua → abyss_3d_selector_fixture`；父构建把 `install()` 返回的 `config` 写入扩展配置。

`install({call,mapPath,library?,output?})` 使用旧D版已成熟的工具；只写副本。`call` 返回解包对象并可跟随新 `mapPath`。`buildLibrary()` 需要已生成的 `build/lua` 数据。三个信号为 `LAB_SELECTOR_OPEN(token,count,a,b,c)`、`LAB_SELECTOR_CANCEL(token)`、`LAB_SELECTOR_REPLY(token,result,reason)`。

## 原生层级与边界

打开前隐藏根容器**所有子树**（包含整个stage、实验菜单、背景、旧输入靶区），保留根脚本供信号和超时更新；关闭后恢复并刷新正式页面。没有把布局schema的 `blockCursor/blockKeys` 当作Lua可写属性，测试也禁止这两项写入。原生窗口是否覆盖/接收点击、平台折叠后是否被原root阻挡，以及隐藏子树时脚本是否持续更新，仍须本候选实机验证。失败后应能通过原生取消/超时回到正式UI；尚不能宣称已通过。

工具历史例子在关卡第3秒打开曾不显示，第14秒正常；本模块由菜单操作触发，仍需观察首次秒数，不能以服务端opened回执证明玩家看见了窗口。当前设置25秒选择、允许放弃/折叠、单人不暂停平台时钟，32秒Lua兜底，35秒服务端关闭看门狗；它们只约束实验模态，不改变卡牌规则。

特殊奖励组、歌唱碗/祈祷转轮、其他待处理奖励事务、原版V4和库外卡牌均拒绝原生展示并保留正式界面。不能通过减少候选或删掉特殊操作来冒充替代完成。

## 75牌库与维护成本

[官方限制页](https://act.mihoyo.com/ys/ugc/tutorial/detail/mh74ae9fsg8i)的本机官方离线副本第132—136行：库上限1000条，卡牌标题/描述/标签及界面标题各1000字。**75牌×普通/升级=150条没有越过官方库上限。**旧D版和新克隆工具各自的30条、标题30字/描述200字是社区工具限制，不是平台限制。在线页面当前可访问但抓取器没有正文，数值证据来自该官方离线原文。

[官方卡牌选择器指南](https://act.mihoyo.com/ys/ugc/tutorial/detail/mh2teu0bmfbc)展示静态卡牌库及运行时库引用；当前SDK的 `invokeDeckSelector` 没有动态标题/描述参数。可按现有渲染器自动生成150条，不需要手抄文案；本轮未扩展工具guard、未构建或官方验证150条。若要支持卡牌的逐实例永久变化、特殊奖励操作，需要额外方案和证据，不能只靠普通/升级两版本。

本轮额外维护：1个选择器、4条原生UI记录、6条自动文案库、1个玩家图（当前离线207节点/编辑器计246）、3个信号、3个Lua模块（含配置）。未自制纹理/模型。实际手机性能、可读性和总维护成本优胜仍未测。

## 来源与验证

- 成熟例子：本机工具 `examples/cards/WALKTHROUGH.md`，官方样本 `mhfpf0rhlaeu_卡牌选择器.gil` SHA256 `01711e07deddbf19fe38b6c037bee80f9b19f4b6b1b3ae4b94e92f5c52846fbd`。模板通过现有 `scene_add_card_selector` 写入，没有手改官方存档。
- 候选数据/覆盖/渲染器/Run奖励实现/owner/夹具的SHA256与字节数保存在 `install().config.sourceInputs`；原生UI四记录hash和逐条全文检查由 `readbackSelector()` 提供。
- `node experiments/native-3d-lab/selector/check.mjs <base-copy.gil> <new-output>`：本轮 `.artifacts/native-selector-check-3/selector.json` 有实际编译、图及四记录全文读回；编译/写入与官方导入/选择器交互/手机实测分别报告。
- `node --test experiments/native-3d-lab/selector/selector.test.mjs`；`node node_modules/fengari-node-cli/src/lua-cli.js -e "dofile('experiments/native-3d-lab/selector/runtime.test.lua')"`：协议负对照和真实Run事务、升级、子集、UID、取消/超时/迟到/重复/代次及旧UI输入锁验证。

当前结论：值得继续测试普通奖励的原生UI复用；不能据这6条库把完整战后选牌迁移，也不能用社区工具30条限制否定150条自动库路线。
