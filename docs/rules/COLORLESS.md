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

后续来源池切片：`abyss_class_card_pools`由固定catalog的HashMap遍历顺序登记三职业各71张非基础牌，分别保留奖励、逆序src与按sourceId排序商店桶；元数据逐项与独立catalog核对。Profiles不再继承战士src池，Run奖励不再从已实现实验子集均匀抽取。完整池中缺失的14/19/20张牌继续保留身份，Chrysalis/Metamorphosis/Discovery等依赖缺定义时在支付/随机消费前明确拒绝；这不代表三职业完整内容已可玩。新增`class_card_source_pools.lua`真实Profiles→Combat/Run回归及JS逐项目录对照。便携Node24.18.0按原30秒预算复验长presentation fixture仍超时，已输出前6组成功（含四职业逐卡渲染）；原Node22失败记录不改写。

组合执行矩阵：`colorless_catalog_execution.lua`逐张从生产Combat.new进入play/chooseCard，执行35普通+4SPECIAL的全部78个基本/升级变体；本树加药水`1a60f36`中精确Discovery模块及约定分派的隔离预加载组合已通过，Node24用时6.6秒。它验证实际入口可结算，不替代逐张数值、随机消费与复杂交互的独立预期断言。最终整合树须直接运行此fixture及药水完整渠道分片；原始无药水分支不具备Discovery模块，不能单独宣称full-check通过。

审查修复已包含：所有新持续能力显示中文名、动态数值与触发条件；每个Bomb有独立倒计时/伤害说明，图标只引用批准主题已有素材。无实体共享伤害预览在所有普通修饰后封顶，实际HP_LOSS/毒/反伤也按固定源封顶；真实BattleUI敌人意图显示1与实际回合失去1HP一致。`colorless_presentation.lua`覆盖真实UI渲染与核心预览，保留平台未验边界。
