# 第二幕夜行者（Vampires）独立切片

TASK-61 AC2；比赛仍仅岩系旅行者前两幕，不增加持久存档、职业或发布范围。

## 来源与规则

独立行为参考为第三方反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`，不是官方开放源码或正版二进制认证。实际读取12份固定源的路径、Git blob与URL登记在 `tests/fixtures/vampires-source-contract.json`；不复制Java、原文叙事或美术。

- 入事件缓存 `ceil(float32(float32(maxHp) * float32(0.3)))`，最多扣当时上限减1，并缓存是否持有血瓶。入场后果汁改变上限不重算价格。
- 接受先按缓存值降低当前生命上限并夹紧当前生命，再从牌组末尾逐张移除 `STARTER_STRIKE`，最后通过正式取得事务获得5张新UID「噬咬」。不是移除全部攻击牌或全部“打击”标签牌；升级、瓶装的初始打击也会被移除，零初始打击仍获得5张。
- 献血瓶替代不扣生命上限，先失去血瓶，再执行相同换牌。仅移除canonical `blood_vial`：源BloodVial没有onUnequip覆盖，基类该钩子为空，已有战前治疗按当前所有权触发；不新建广义遗物移除系统。
- 卡牌移除走现有 `Run.removeCard` 的卡牌移除/牌组变化钩子；取得走 `Run.obtainCard`，熔融之卵自然升级每张新攻击牌，不手动伪造升级。
- 接受、献瓶和拒绝均先到结果页，再独立离开。命令自身不消耗seeded RNG；原始13事件池、顺序、资格和抽取不变，不重抽或缩池。
- `Nodes.chooseEvent`原有完整事务拥有回滚；中途取得失败时费用、移除、血瓶、牌组/UID、事件阶段和随机流全部恢复。原创V4的初始打击源标签不猜测，保留明确拒绝边界；本轮验收仅生产岩系旅行者。

## 本地验证

```sh
npm run build:data
npm run build:ui
npm run build:theme
node --test --test-concurrency=1 tests/vampires-event.test.mjs
npm run check:architecture
npm run check:syntax
```

核心11组通过真实Nodes/Run检查生命缓存、瓶装/升级打击、五张新UID、血瓶与熔融之卵、晚失败/异常回滚、完整池抽取、下一场真实战斗中的噬咬和血瓶治疗差异。生成原生控件5组检查中文标题/选项、两种交换、拒绝、结果/离开、陈旧输入及失败后恢复；仅原生引擎方法为mock。

补充回归包括float32敏感的50→16及16777217→5033165、既有四源初始打击兼容，以及原创V4未明标签的原子拒绝；不代表其他职业新增公开验收。

先红后绿：未接线时真实Nodes返回 `event_unavailable`；未绑定标题时生成控件显示“未知事件”。实现后对应行为测试通过。开发过程中另外纠正两个测试夹具错误：C.play要求目标索引而非敌人ID；UI差分会执行参考与实际命令两次，晚失败注入按每四次取得拒绝，两边条件一致。

## 未验收

未生成本轮GIL，未官方导入、未取得真实ready、未PC/实体安卓试玩或自然遇到/通关。上述控制边界与原生控件模拟不能替代平台证据。历史来源投影仍需最终组合精确接续；不更换旧来源、放宽断言或凭局部检查宣称完整CI/M3通过。

## 本轮检查结果

- Vampires最终3项Node测试全部通过（11核心组+5原生控件组，零跳过）；日志 `/tmp/vampires-final.log`。
- Vampires/Ghosts/Act2事件核心及原生界面相关批次13项全部通过，零跳过；日志 `/tmp/vampires-related.log`。补充边界之后再次通过Vampires完整专项。
- 数据、原生UI、主题构建及JavaScript语法通过；架构281模块通过；质量扫描4451/4451测量；Luacheck零新增诊断、28项显式历史warning。复用隔离目录内经仓库固定SHA256校验的既有Luacheck工具，无下载/安装。
- `tests/event-production-source-inverse.test.mjs`真实运行6项，3通过/3失败，原始日志 `/tmp/vampires-event-source-proof.log`。失败为新增源码未纳入完整历史投影，最先被拒绝的是 `config/architecture.json`；未改旧证明、未放宽断言。由最终组合线程串行增加精确外层来源投影，旧来源与未知漂移拒绝保留。
- 未运行最终组合完整 `npm test`/`npm run check` 或远端CI；不能报整体验收全绿。
