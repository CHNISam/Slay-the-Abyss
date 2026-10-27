# 古老文字（Back to Basics）本地切片

TASK-61仍未整体完成。本切片不证明13普通事件、四职业自然连续章节或任何平台验收。

来源为 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0` 的 BackToBasics、八张初始牌、CardGroup、GridCardSelectScreen、CancelButton、AbstractPlayer、AbstractDungeon，以及Bash/PommelStrike负对照。16份只读摘要、Git blob与URL见 `tests/fixtures/back-to-basics-source-contract.json`。它是反编译镜像的读取证据，不是官方PC字节认证；产品没有复制Java代码或素材。

- **优雅**：免费选择一张非瓶装、可清除的永久牌，复用既有 `Run.removeCard` 及Parasite等移除钩子。空合法组不打开选牌，直接进入结果。支持现有全部职业，包括原创V4。
- **简洁**：仅匹配来源明确带 STARTER_STRIKE/STARTER_DEFEND 的八个ID：`Strike_R/Defend_R`、`Strike_G/Defend_G`、`Strike_B/Defend_B`、`Strike_P/Defend_P`。所有尚可升级目标一次升级，包含瓶装牌，不改UID/瓶装标记。BASIC稀有度、显示名、初始牌组成员和通用STRIKE标签均不是资格。没有目标是有效结果；已知来源目标缺定义或缺可执行升级则事务拒绝，不伪装零目标成功。
- 原创HT2/AR2/FR2/RD2没有可证实的初始打击/防御标签映射，**仅简洁明确不可用**。这是当前实现边界，不是原版事件的职业规则，不猜对应卡。
- 两个分支都保留结果页，另一次 **离开** 才返回地图。重复/跨阶段选择、旧UID、重复UID、瓶装后失效选择及移除异常不能推进或提交部分状态；不消费金币或规则RNG。
- 来源调用四参 `open(group,1,msg,false)`：`forUpgrade=false, forTransform=false, canCancel=true, forPurge=false, anyNumber=false`。其内部canCancel并非Beggar的七参false；正常事件不会显示Cancel。本地沿用既有选牌控件，不新增取消命令、付费、退款或可选跳过机制。

接线为 `abyss_event_pool` 原有第二幕13项中的精确映射 → `abyss_act2_events` → `abyss_back_to_basics`；正式Nodes与现有NodeUI均经过测试。默认受限七事件池未变，完整实验池没有删项、重权重或重抽。

验证文件：`tests/lua/back_to_basics_event.lua`（17组公开事务）、`tests/lua/back_to_basics_ui.lua`（9组生成控件、原生接口mock）。完整源码门禁与回归由交付记录另列。没有官方客户端输入、导入、实机UI或自然全程证据；`NOT_RUN`不提升为通过。
