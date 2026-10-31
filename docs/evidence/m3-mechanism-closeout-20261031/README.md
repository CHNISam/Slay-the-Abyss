# M3 机制与取证续办

基线为PR436真实develop squash `b4f88a1f574b403f4cc68d54ee37565f3012b5ad`。主PR完整CI及交付preflight通过后于2026-10-31 18:28:43 UTC合入；本批独立从该基线收尾后续发现，不改背景、角色或幕数。

## 实际修复

- 昆虫标本：原版先把整数maxHealth转binary32，再乘`.75f`并转整数。旧移植遗漏输入转换，合法大HP `16777217`得到12582913，原版为12582912。最小增加输入float32，常规敌人HP结果保持；独立固定表及公开Run输入先RED后GREEN，涵盖舍入、房间资格和Neow低当前HP。没有扩大数值域或修改旧golden。
- 正常规则取证driver：Living Wall初次forget/change/grow先不传UID，公开进入`choose_card`后再选；grow读取公开upgradeCards。旧driver在seed17第38动作过早传UID，被生产正确拒绝。修后同seed公开两步完成后正常战败16层。玩家节点算法未修改。

## 新增强证据

| 范围 | 实际内容 |
| --- | --- |
| 四遗物公共链 | Eternal Feather实际营地进入只触发一次；Letter Opener真实第三技能群伤与跨回合/新战斗重置；Hand Drill真实破盾首伤及后续易伤；Brimstone真实开战和连续回合力量队列 |
| Colorless Potion | 4原版源文件锁、34非HEALING完整源序、两瓶14次独立draw；Bark复制、0费、满手入弃牌、旧token及资源原子拒绝，另有少retrieval消费精准变异 |
| Snecko/Insect | 独立XS128和binary32预期；Snecko真实抽牌/后续抽牌费用与每次随机流，57组Insect房间/HP边界；真实Git CRLF checkout保持源身份 |
| Sword Boomerang | 10原始源码SHA/Git blob，24案例/68次逐击独立target/HP/bound/value/words/counter；活敌重选、击杀后重选、清场停耗、单敌仍耗；真实UI余输入与3负控 |

根组合标准Node测试54/54通过、零skip（189.8秒）；完整工程门禁318模块/5002测量/1833依赖、固定Luacheck零新增、四变异均杀死、原生合同4/4通过。日志为`aux-combined-focused.log.gz`、`aux-engineering.log.gz`。每个Lua夹具仍为原30秒。Sword按8个薄JS入口分摊24短案例，精确注册合同防遗漏/重复，原向量未改；这些本地结果不能代替本批最终HEAD完整CI。

`review-*.json`是各片非作者独审；`m3-insect-history-followup.json`保留9项既有整源/owner/负控真实通过，不因未出现历史源失败而新增宽松逆层。最终组合还需精确head/base聚合独审与正常CI集成。

## 完整索引与范围

`indexes/{relic-153,card-75,potion-rng}/matrix.json.gz`逐字保留只读索引，来源为主候选c3d2654；75牌/153遗物/33药水及16类RNG owner分别分列实现、具体断言、公共/受控入口、独立期望及自然/设备证据。它们是可检查的静态索引，不能把ID数、source inverse或断言引用数当作动态通过。人读报告保留原始`report.md.raw.gz`，可读版本只规范行尾空白。后续补测和Insect修复以本目录独审及新测试为准，不倒改c3d旧索引为当前结果。

自然流程分源保存于`normal-runs/c3d2654/`和`normal-runs/ca838ef/`。前者5局为4次正常战败和一次真实driver阻塞；后者为修复后的同seed17正常战败。旧243来源三局仍在既有M3目录。每组源码身份、4策略指纹、逐动作gz、覆盖、真实失败和字节清单各自保留，不混称同一候选；不把新Run构造隔离记作Host重开。自然卡牌观察仍只是完整75中的子集。

任务保持原Backlog逐AC事实边界：没有官方GIL、导入/ready、实体PC/手机或容量证据；全件自然与部分完整组合/随机消费要求仍开放。普通代码合入不等于完整M3或发布许可，没有发布或创建Tag。

## 主PR真实合后证明

`main-integration/`保存PR436精确C3D的原逻辑preflight及真实squash/develop push证据。主合后b4f88a1完整Quality27项与inventory已成功，原校验结果`merged_passed`，parent/tree严格一致。原CLI因代理无法读取ZIP而失败；同一GitHub artifact由连接器下载并核digest/大小/身份，未改的原collect/receipt/verify与原CLI最终PR六守卫实际通过，不宣称CLI网络下载成功。TASK76仅“回归通过并PR合入”AC3据此勾选，真实设备相关条款保持未完成，当前M3新增已证实AC净数18。
