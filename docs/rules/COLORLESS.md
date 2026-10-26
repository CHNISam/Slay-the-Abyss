# 无色牌与合法生成

固定对照：`aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`，声明版本 PC 2.3.4。原始归档摘要、版本边界及目录见 `data/reference/sts1-card-pools/registration.json`；有序池见同目录 `pools.json`。这不是原版 PC 二进制实测认证。本轮只读已审计本地归档，未引入上游源码、图片或长文案。

`abyss_colorless_cards.withCards`注册完整35张普通无色牌，及Apparition、Bite、J.A.X.、Ritual Dagger四张事件特殊牌。SPECIAL不进入普通池。Bandage Up与Bite保留HEALING资格，普通战斗生成排除Bandage Up。现有角色专用特殊牌继续由各职业模块拥有。

- `sourcePools.srcColorless`：35项固定原源总序，战斗生成使用；不按实现能力筛选。
- `sourcePools.colorlessRaw`：原始35项注册池序。
- `sourcePools.colorlessShop`：20 uncommon / 15 rare，固定目录的商店顺序。
- 三类职业生成仍使用完整的职业`src`池，不能拿现有可执行子集替代。

独立实现位置：`abyss_colorless_cards`包含成本修改、生成、UID选牌和持续能力；Combat负责能量、伤害快照、回合、暂停和恢复；Actor负责Artifact、无法格挡和无实体；Run负责永久匕首增长与跨战斗身份。商店供货由商店模块消费目录，Discovery共用药水选择模块，均需在最终整合树验证。默认运行与角色运行的无色展示共用现有主题和选牌面板。

生产定向测试：`colorless_cards.lua`、`colorless_actions.lua`、`colorless_powers.lua`、`colorless_run.lua`。覆盖基本/升级数值、完整目录边界、永久与回合成本、批次选牌先于随机插入、生成资格、X消耗、UID上限/陈旧token拒绝、Mayhem抽牌后自动出牌、五牌触发、Artifact、第三次结束爆破、击杀金币、无实体、合法跨节点匕首增长及生成复制身份。另保留Combat、PostCombatActions、NativePowerExpiration回归。没有把目录注册当作逐卡逐交互全通过。

当前证据边界：代码与上述离线测试；没有构建GIL、平台导入、键鼠输入或实机游玩。Discovery需与药水提交整合验收；三职业完整来源池与缺牌依赖继续独立处理。原有`character_presentation.lua`长fixture两次在30秒边界超时（前两职业输出成功），不提高时限、不把定向绿灯当完整Quality通过。
