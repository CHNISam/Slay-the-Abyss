# 清除诅咒祭坛：来源、生产接线与验收边界

归属TASK-13.1.2，当前主关口M3。先完成初代STS1 PC A0单人Ironclad第一幕完整首发涉及内容池；二代以后基于一代工程扩展。本片不改版本、不合并、不发布。

## 固定来源

读取固定第三方反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0` 的事件及直接方法链；不将它称为官方开源、正版构建认证或原作本轮实测。事件 `events/shrines/FountainOfCurseRemoval.java` 的SHA256为 `9c5e9e7c7cb32f747a85251c8f02eff71d47bcbd4396c1b5423d54bcb015ff36`，Git blob为 `4ed9a1a70f81cfa8086824dd3319abaa918deaf9`。九份完整来源身份另存 `docs/rules/evidence/sts1-fountain-source.json`；原文只保留在忽略的 `.artifacts/fountain-source-review/`。

独立来源复核确认：isCursed只查永久牌组，排除AscendersBane、CurseOfTheBell、Necronomicurse，资格不排瓶装；实际移除逆序处理，并额外排除inBottleFlame/inBottleLightning，不排Tornado。进入时消耗一次性条目，选择离开也不归还。空移除组仍能正常结束。事件本身不调用increaseMaxHp或heal。

CardGroup.removeCard还调用牌的onRemoveFromMasterDeck及遗物onMasterDeckChange：Parasite移除会降低最大生命，Du-Vu Doll重算诅咒数；Darkstone Periapt的+6属于获得诅咒而非清除。当前合法诅咒只有Regret且无移除效果，现有13件遗物没有上述实质移除钩子。其他诅咒的移除尚未实现，命令在任何删牌前原子拒绝；不会跳过它们后假装清除成功。完整诅咒与遗物钩子继续由父任务及TASK-14.1负责。

## 生产入口

`EventPool.contentId['Fountain of Cleansing']` → `Nodes.enter`（永久牌组资格）→ `Nodes.eventOptions/chooseEvent` → `abyss_fountain.cleanse` → 既有节点完成事务。原生`abyss_node_ui`展示净化/离开及实际移除数量，零移除不打开空选牌器。

当前默认`restricted-seven`保持原状，**没有**改成受限八事件池或重分概率。本片接入已有full目录及正式显式节点入口；全部25事件尚未齐备，所以不宣称默认自然路线已能遇到泉水。full路由测试把可抽池收窄为本事件以隔离事务，这是路由夹具，不是完整原池概率或自然获取证据。完整池切换、资格、钩子及逐项自然平台验收仍由TASK-13.1.2/12.5/47承接。

## 输入与预期

- 永久组含两张Regret和一张Strike：净化逆序删除两个诅咒UID，保留Strike及其身份，生命/上限/金币/UID计数/战斗临时牌/RNG不变。
- Flame/Lightning瓶装、三张特殊诅咒：保留；Tornado标记不额外保护。仅瓶装诅咒仍满足资格，净化可零移除结束。
- 无永久诅咒但战斗手牌有诅咒：不获得事件资格；入口失败不消费地图、池或RNG。
- 非法选项、未支持移除钩子、重复确认：拒绝且不部分丢资源；离开保留诅咒但条目已在进入时消耗。
- 原生界面：两项按钮，净化后显示真实移除数量，零移除不陷入空picker，离开后保留结果页。

## 本轮结果

源码与生产接线已实现。修前红例因contentId缺失失败（`nil ~= fountain`），修后主线程独立复跑核心7/7、原生UI3/3、未知事件13组；既有清单CLI和13项Node清单、语法检查通过。实现代理另留节点21组、Living Wall10组通过日志，主线程已读取结果，但不把读取日志当作独立复跑。原始日志在本树`.artifacts/fountain-event/`。未运行全量npm check。

独立来源复核完成；最终代码的第二位子代理审查被平台用量上限中断，随后由Codex直接检查diff并复跑定向测试，不宣称完成了独立代码复审。没有重试受限代理。

候选构建与完整源码读回通过：冻结源 `0b8d325f4452d4b5851240c7b567e4b7f16e8754`，仅增量写入event_pool/fountain/node_ui/nodes四个模块，原副本hash不变。新副本为本树 `.artifacts/fountain-candidate-0b8d325/scenes/saves/abyss-fountain-test.gil`，SHA256 `8a9945e040e16250ca37c381b3b1e0698e26b754c001378949aa3f0723af5925`。62模块源码均匹配固定源，其中61份逐字节相同，abyss_fountain仅在既有审计允许的CRLF/LF规范化后相同，两侧原始hash分别保留；不声称62份逐字节相同。UI2824/max60，静态0错误/33警告；图审计仅既有身份、服务端类型、非空载荷、监控信号与启用挂载范围，未认证节点参数及运行语义。`liveWrite=0`。摘要见[同源候选](../evidence/fountain-candidate-0b8d325.json)。官方导入：未验证。同候选真实试玩：未验证。当前UI门禁未验收；父任务全部AC及M3保持未通过。
