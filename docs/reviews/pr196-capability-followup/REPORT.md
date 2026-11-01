# PR196 能力门禁有限接续复核

## 结论

**旧评审的 Clash / Whirlwind 具体获取、营地升级与变换门禁缺口，在冻结新 head 上闭环。** 独立真实入口 16 组通过，未知 condition / costMode / effect 仍拒绝，不能用泛放行替代此结果。只对这两张牌与相关能力门禁作有限 review，不批准全部 75 张、不替代当前 SHA CI、完整随机池、平台或自然构筑验收。

- PR：https://github.com/CHNISam/Slay-the-Abyss/pull/196
- 检验 head：`9a4cf64fb6c0f435bb8ad61a3f68f0549a2d03bf`。
- base：`3ed8bf4b88a950c4736ec2d68e83f141d415c4db`。开始和结束远端读回 head 相同；结束时 PR open、未合并。
- 已读实际 AGENTS、SCOPE、HANDOFF、TASK-16/16.1 首页与附件、相关 PR 文件差异。两个任务均 In Progress / @Codex，未认领或写入。执行 `backlog instructions overview` 返回 command not found，不安装 CLI、不以直接 Markdown 编辑替代。

## 新 head 的实测

1. **真实商店→营地→下一战**：Clash seed 7 / slot 2 / 53 金币；Whirlwind seed 16 / slot 1 / 81 金币。未改库存或牌池，公开 Nodes 购买生成永久 UID 11、扣至 0 金币；重复购买原子拒绝；营地升级次数为 1，永久 UID 不变；下一战的 hand/draw 中以同一 UID、升级状态存在。
2. **真实 Combat 控制**：两牌普通/升级在 3 能量时分别造成 14/18、15/24 伤害，能量分别保留 3、归 0。Clash 与 Defend 同手仍因 requires_only_attacks 不可打，但能力登记为真；Whirlwind 0 能量可合法执行零次伤害。这避免以临时可打条件替代永久能力登记。
3. **完整 72 槽变换池，定点各取一次**：通过 Nodes.enter 的显式 Living Wall 事件夹具及公开 chooseLivingWallCard，Clash 当前 common 源序槽 9、Whirlwind 源 uncommon 槽 40 均取得成功。删除 UID 1、追加新未升级 UID 11、next UID 变 12；misc 精确从 counter 7 到 8，两个 word 均为 slot−1；生命、金币和其他三条检查的随机流不变；重复选择原子拒绝。没有缩池、跳过未知项或重抽。
4. **安全负控 9 组**：unknown condition、unknown costMode、unknown effect 各自在 Capability、营地升级和完整池 transform 入口拒绝。营地返回 card_not_upgradeable，transform 返回 event_content_unavailable。拒绝前后整个 Run 深值和全部原有 table 引用都不变，保留 UID、RNG 和待选择阶段。
5. **登记非战士牌的有限控制**：Regret、Dazed、Slimed、Wound、Burn 通过；逐个改为未知 ID 后均拒绝。此项不宣称它们所有战斗规则完成独立验收。

生产差异是精确接受 `only_attacks_in_hand` 与 `all_energy`，不是删除 guard。效应仍由 Effects.supported 判定；未知类型/状态/诅咒依然有限登记。能力文件 blob：`b5293a9811810bca891c177344548098c6af5bc0`。

源码：https://github.com/CHNISam/Slay-the-Abyss/blob/9a4cf64fb6c0f435bb8ad61a3f68f0549a2d03bf/src/lua/abyss_card_capability.lua

## 防止假绿的反证

仅在本目录中的隔离运行装载旧门禁或故意错误门禁，未改 frozen runtime 源文件：

- 旧门禁原 blob `613f56b14f8e055d5a6eae8e6611ae6b7e1cea2d`：商店对照仍把 Clash / Whirlwind 换成 Cleave / Sever Soul，两项通道测试均失败。
- 同一真实购买、进入营地后才切换旧门禁：两牌均实际返回 card_not_upgradeable，两项正例均失败，重现原营地缺口。
- 旧门禁的完整池 transform：两牌都返回 event_content_unavailable，两个正例失败，三个未知项负控仍通过。
- blanket true 故障门禁：9 个未知字段负控全部失败。故本轮通过不是通过削弱拒绝保护取得。

初跑记录 13/16，三个失败都来自测试沿用历史 Clash 槽 12 的断言。读取固定源夹具后发现它按 current common 的实际顺序，Clash 是槽 9；旧交叉探针用 data.sourcePools.src.common 构池是槽 12。改正夹具断言后 16/16。保留最初失败日志，不把这次夹具纠正写成生产修复。

## 来源与边界

运行源来自精确 head 的 Git tree，79 件相关文件逐 Git blob 对齐；JSON 经该头原始 validate-data / build-lua-data 重建，使用系统现成 Lua 5.4 runner。包含全部相关运行模块，但仅执行这里的两卡定向探针，没有重新跑 75 全集、全量 npm 或平台。

路径前缀沿真实 Map 边跳过前序房间战斗，资金是精确价格夹具；Living Wall 是显式事件入口且 transformContext 是完整固定源池夹具，不声称进入正常事件概率池或原池 owner 全接线。无用户电脑/Codex、无安装、无远端写入、无生产或其他 worker 文件修改。所有新增物只在本 review 目录。是否合并由 root 结合其他 review 与精确 head 的完整 CI 决定。

完整日志在 `evidence/`；源身份在 `context/verified-sources.json`；复跑命令见 `REPRODUCE.md`。旧评审编号 5640112422 / 5640112573 仅作为先前任务提供的线索，本轮直接以实际旧门禁与新 head 再现验证。
