# 75张旅行者比赛卡证据审计

当前读取源码`c3d2654beee31fdd011db0535228e063b657ab8a`；只读索引，不改代码/冻结hash/Backlog，不重跑套件。完整逐ID数据在[matrix.json](matrix.json)。

**纯实现结论：75/75已有实际独立基础/升级执行断言，不是只有75个定义或inverse恢复。** canonical/reference/live/release四份ID集合精确一致且去重，3基础+20普通+36罕见+16稀有；不计16状态/诅咒、39共享生成依赖、雷电或第三幕。150例通过真实Combat.play验证资源、数值、状态、选择队列和原实例去向，期望来自独立显式表。当前c3d规则shard1已SUCCESS，该150例就在此shard；不能仅因自然/设备未齐，把“75卡已实现并可离线执行”继续当未做。

复杂机制另有49个独立边界组以及消耗、虚无、固有、目标/费用、生成复制、力量/状态构筑专项；例如Feed双版本终击永久HP、Reaper实际未挡血量/反伤死亡、DoubleTap原目标和Rampage同实例成长、Corruption+DarkEmbrace+FNP+Sentinel时序、Carnage/GhostlyArmor双版本未打出虚无、Brutality+七固有开局均有实际断言。每项source段/期望/代码owner/fixture模式在JSON，引用不能自动外推为所有组合穷尽。

**公开可达性离线结论：** 72非基础均在原reward/src/typed-shop池；独立真实starter胜利→公开claim→下战同UID逐牌切片没有写HP/库存/池/RNG。75项另有starter/shop→camp upgrade→下一战公开Run/Nodes链；该组明确注入导航与资金，因此是公开API事务验证，不能叫自然取得。3基础从初始牌组，不冒充随机奖励/商店成员。概率/顺序/随机流用warrior75_acquisition、shuffle、Courier及独立XS128共享cardRandom oracle交叉覆盖；源镜像/PC版本历史及外部全局熵仍有明确边界。

## 当前标准CI边界

读取PR436 head`c3d2654beee31fdd011db0535228e063b657ab8a`的实际checks快照。POSIX engineering9/9为JS套件，不能冒充raw Lua全过。raw Lua分布在Windows13规则shard：150基础/升级执行在1（PASS）；49edge在8（快照仍进行中）；shop/camp普通在7、稀有在5、罕见在12（最新快照均PASS）；72奖励逐片跨多个shard。JSON逐项保留shard与状态。完整规则CI尚未结束，不把旧5ceef/098完整CI或旧原生诊断借成当前头通过；主控最终CI绿后可更新此层结论，无需制造重复浅测试。

## 原AC建议

- TASK47#6（完整75首发清单）已勾有实据，继续保留。#11代码/本地/平台分层盘点已有逐卡材料，继续保留。
- TASK47#8是纯“完整原池与合法依赖可执行/概率不缩水”条款，不含同候选实体设备前提。就75卡部分，本轮独立执行和真实公开渠道已支撑**实现完成/离线可执行**；待最终相关规则CI完成及状态/诅咒/共享生成依赖与概率专项合证后，可按纯条款验收，不应等同于#2/#7的自然/平台证据。不能因清单数字或inverse字节相等单独勾它。
- TASK59#3同样可以认定“75卡机制部分已实现且有独立断言”；整条还含首发遗物/药水交互，应合并这些领域的现有逐项报告后判断。不是因为自然未齐而自动否定纯代码层，也不是用150例覆盖所有道具组合。
- TASK47#2/#3/#7及TASK59#4/#5有自然构筑/同候选实际日志截图要求；75逐卡自然仍缺，当前不建议勾整条。TASK47#9还混有游戏实际验证，历史显式native只能按旧source身份保留。
- TASK47#1/#4/#5/#12/#13/#14还含Boss/敌人/事件/遗物/正式入口/平台或两幕全内容，不由75卡索引单独关闭。

## 自然观察：严格按源码分栏

- `baseline_243ae1b` / `243ae1bd888d33e500cdd868932cc09b6cb9131c`：自然取得21/75，打出18/75；3局，独立保留，不合并归属。
- `current_c3d2654` / `c3d2654beee31fdd011db0535228e063b657ab8a`：自然取得21/75，打出18/75；5局，独立保留，不合并归属。
- `driver_fix_ca838ef` / `ca838ef6f36fedc1ed55a8eeeaafe9370149cb0d`：自然取得9/75，打出8/75；1局，独立保留，不合并归属。

旧243 cohort种子2两幕胜利只归243，c3d的种子17原driver_blocked不记自然成功，ca838修复驱动阶段协议后的17另记。三份卡ID观察可比较覆盖机会，但不能凑成同候选75卡完成。采集器play仅记cardId/combat uid，没有deckUid或upgraded，因此当前自然日志不能逐牌断言打出的是基础、永久升级还是临时升级；本索引不拿master UID碰撞猜版本。设备证据也不能由离线公开命令替代。

## 逐ID目录

“取/用”仅指相应source cohort有观察；“—”是未观察，不是未实现。每行两版本完整断言均在`tests/lua/warrior75.lua`指定行，复杂机制列只列第一个索引，JSON保存全部相关test名称、行号和实际断言例。

| ID · 中文 | 稀有度 | 150矩阵行 | 机制额外证据示例 | 243 cohort | c3d cohort | ca838 seed17 |
| --- | --- | ---: | --- | --- | --- | --- |
| strike · 普通攻击 | basic | 30 | tests/lua/warrior75_edges.lua:29 | 取/用 | 取/用 | 取/用 |
| defend · 防御 | basic | 30 | tests/lua/warrior75_edges.lua:34 | 取/用 | 取/用 | 取/用 |
| bash · 破防斩 | basic | 30 | tests/lua/warrior_cards.lua:37 | 取/用 | 取/用 | 取/用 |
| anger · 连续出剑 | common | 31 | tests/lua/warrior75_edges.lua:29 | 取/用 | 取/用 | 取/用 |
| armaments · 整备武装 | common | 31 | tests/lua/warrior75_edges.lua:40 | 取/用 | 取/用 | —/— |
| body_slam · 格挡反击 | common | 31 | tests/lua/warrior_exhaust_cards.lua:85 | —/— | —/— | —/— |
| clash · 全力进攻 | common | 32 | tests/lua/warrior75_edges.lua:34 | —/— | —/— | —/— |
| cleave · 星陨剑 | common | 32 | tests/lua/thunderclap_order.lua:99 | 取/用 | 取/用 | —/— |
| clothesline · 压制斩 | common | 32 | 仅普通效果矩阵；见JSON其他机制引用 | —/— | —/— | —/— |
| flex · 蓄力 | common | 33 | tests/lua/flex.lua:1 | —/— | —/— | —/— |
| havoc · 临阵变招 | common | 33 | tests/lua/warrior75_edges.lua:222 | —/— | —/— | —/— |
| headbutt · 回身追击 | common | 33 | tests/lua/warrior75_edges.lua:51 | —/— | —/— | —/— |
| heavy_blade · 重剑斩 | common | 34 | tests/lua/warrior75_edges.lua:22 | —/— | —/— | —/— |
| iron_wave · 招架还击 | common | 34 | tests/lua/iron_wave_order.lua:1 | 取/用 | —/— | —/— |
| perfected_strike · 剑势如虹 | common | 34 | tests/lua/warrior75_edges.lua:29 | —/— | —/— | —/— |
| pommel_strike · 试探一击 | common | 35 | tests/lua/warrior75_edges.lua:29 | 取/用 | 取/用 | —/— |
| shrug_it_off · 伺机而动 | common | 35 | tests/lua/warrior_status_build.lua:198 | 取/用 | 取/用 | 取/用 |
| sword_boomerang · 回旋连斩 | common | 35 | 仅普通效果矩阵；见JSON其他机制引用 | —/— | —/— | —/— |
| thunderclap · 横扫破防 | common | 36 | tests/lua/thunderclap_order.lua:1 | 取/用 | 取/用 | —/— |
| true_grit · 稳住阵脚 | common | 36 | tests/lua/warrior75_edges.lua:187 | 取/用 | 取/用 | 取/用 |
| twin_strike · 重击 | common | 37 | tests/lua/warrior75_edges.lua:29 | 取/用 | 取/— | 取/用 |
| warcry · 调整战术 | common | 37 | tests/lua/warrior75_edges.lua:56 | —/— | —/— | —/— |
| wild_strike · 猛进斩 | common | 37 | tests/lua/warrior75_edges.lua:29 | —/— | —/— | —/— |
| battle_trance · 集中精神 | uncommon | 38 | tests/lua/warrior_status_build.lua:278 | —/— | 取/用 | —/— |
| blood_for_blood · 负伤反击 | uncommon | 38 | tests/lua/warrior75_edges.lua:109 | —/— | —/— | —/— |
| bloodletting · 透支 | uncommon | 38 | tests/lua/warrior_strength_build.lua:50 | —/— | —/— | —/— |
| burning_pact · 弃旧筹新 | uncommon | 39 | tests/lua/warrior75_edges.lua:266 | —/— | —/— | —/— |
| carnage · 抓住战机 | uncommon | 39 | tests/lua/warrior_exhaust_endturn.lua:62 | —/— | 取/用 | —/— |
| combust · 强攻压阵 | uncommon | 39 | tests/lua/warrior75_edges.lua:172 | —/— | —/— | —/— |
| dark_embrace · 临机应变 | uncommon | 40 | tests/lua/warrior75_edges.lua:162 | 取/— | 取/— | 取/— |
| disarm · 压制攻势 | uncommon | 40 | tests/lua/warrior_strength_build.lua:50 | —/— | —/— | —/— |
| dropkick · 乘隙追击 | uncommon | 41 | tests/lua/vulnerable_combo.lua:1 | —/— | —/— | —/— |
| dual_wield · 再演剑势 | uncommon | 41 | tests/lua/warrior75_edges.lua:61 | —/— | —/— | —/— |
| entrench · 加固防线 | uncommon | 41 | tests/lua/entrench.lua:1 | —/— | —/— | —/— |
| evolve · 逆境求变 | uncommon | 42 | tests/lua/warrior75_edges.lua:150 | —/— | —/— | —/— |
| feel_no_pain · 百折不挠 | uncommon | 42 | tests/lua/warrior75_edges.lua:187 | 取/— | —/— | —/— |
| fire_breathing · 逆势反攻 | uncommon | 43 | tests/lua/warrior75_edges.lua:150 | —/— | —/— | —/— |
| flame_barrier · 反击架势 | uncommon | 43 | tests/lua/warrior75_edges.lua:182 | 取/用 | 取/用 | —/— |
| ghostly_armor · 及时招架 | uncommon | 44 | tests/lua/ethereal_card_lifecycle.lua:152 | 取/用 | 取/用 | —/— |
| hemokinesis · 舍身进攻 | uncommon | 44 | tests/lua/warrior75_edges.lua:97 | 取/用 | 取/用 | —/— |
| infernal_blade · 临阵试招 | uncommon | 44 | tests/lua/warrior75_edges.lua:319 | —/— | —/— | —/— |
| inflame · 剑术精进 | uncommon | 45 | tests/lua/warrior75_edges.lua:34 | —/— | 取/用 | 取/用 |
| intimidate · 威慑 | uncommon | 45 | tests/lua/warrior_status_build.lua:49 | —/— | —/— | —/— |
| metallicize · 持续防守 | uncommon | 46 | tests/lua/warrior75_edges.lua:168 | 取/用 | 取/用 | —/— |
| power_through · 强行固守 | uncommon | 46 | tests/lua/warrior_strength_build.lua:50 | —/— | —/— | —/— |
| pummel · 疾风连斩 | uncommon | 47 | tests/lua/warrior75_edges.lua:357 | —/— | —/— | —/— |
| rage · 攻守相济 | uncommon | 47 | tests/lua/warrior75_edges.lua:132 | —/— | —/— | —/— |
| rampage · 越战越勇 | uncommon | 47 | tests/lua/warrior75_edges.lua:61 | —/— | —/— | —/— |
| reckless_charge · 疾步突进 | uncommon | 48 | tests/lua/warrior_status_build.lua:49 | —/— | —/— | —/— |
| rupture · 愈挫愈勇 | uncommon | 48 | tests/lua/warrior75_edges.lua:97 | —/— | —/— | —/— |
| searing_blow · 千锤一剑 | uncommon | 48 | tests/lua/warrior75_edges.lua:45 | —/— | —/— | —/— |
| second_wind · 弃繁守拙 | uncommon | 49 | tests/lua/warrior_status_build.lua:49 | —/— | —/— | —/— |
| seeing_red · 重整旗鼓 | uncommon | 49 | tests/lua/warrior_strength_build.lua:50 | —/— | —/— | —/— |
| sentinel · 后援守势 | uncommon | 49 | tests/lua/warrior_status_build.lua:66 | —/— | —/— | —/— |
| sever_soul · 弃守强攻 | uncommon | 50 | tests/lua/warrior75_edges.lua:196 | —/— | —/— | —/— |
| shockwave · 震慑敌阵 | uncommon | 50 | tests/lua/shockwave_group.lua:1 | 取/用 | 取/用 | —/— |
| spot_weakness · 洞察破绽 | uncommon | 51 | tests/lua/warrior_strength_build.lua:50 | —/— | —/— | —/— |
| uppercut · 挑剑破势 | uncommon | 51 | tests/lua/warrior_strength_build.lua:50 | —/— | —/— | —/— |
| whirlwind · 岩潮叠嶂 | uncommon | 52 | tests/lua/warrior75_edges.lua:121 | 取/— | 取/— | —/— |
| barricade · 永世的磐岩 | rare | 52 | tests/lua/barricade_repeat.lua:1 | —/— | —/— | —/— |
| berserk · 背水之战 | rare | 53 | tests/lua/warrior75_edges.lua:177 | —/— | —/— | —/— |
| bludgeon · 全力一击 | rare | 53 | tests/lua/warrior75_edges.lua:201 | —/— | —/— | —/— |
| brutality · 破釜沉舟 | rare | 54 | tests/lua/warrior75_edges.lua:177 | —/— | —/— | —/— |
| corruption · 孤注一掷 | rare | 54 | tests/lua/warrior75_edges.lua:215 | —/— | —/— | —/— |
| demon_form · 渐入佳境 | rare | 55 | tests/lua/warrior75_edges.lua:177 | —/— | —/— | —/— |
| double_tap · 叠势连击 | rare | 55 | tests/lua/warrior75_edges.lua:127 | —/— | —/— | —/— |
| exhume · 重拾旧策 | rare | 56 | tests/lua/warrior75_edges.lua:192 | —/— | —/— | —/— |
| feed · 乘胜壮行 | rare | 56 | tests/lua/warrior75_edges.lua:136 | —/— | —/— | —/— |
| fiend_fire · 舍尽一击 | rare | 56 | tests/lua/warrior75_edges.lua:226 | —/— | —/— | —/— |
| immolate · 摧阵一击 | rare | 56 | tests/lua/warrior_status_build.lua:49 | 取/用 | —/— | —/— |
| impervious · 坚守 | rare | 57 | tests/lua/ethereal_card_lifecycle.lua:152 | —/— | —/— | —/— |
| juggernaut · 守中有攻 | rare | 57 | tests/lua/warrior75_edges.lua:187 | —/— | —/— | —/— |
| limit_break · 剑意突破 | rare | 58 | tests/lua/warrior75_edges.lua:116 | —/— | —/— | —/— |
| offering · 奋力一搏 | rare | 58 | tests/lua/warrior75_edges.lua:104 | —/— | —/— | —/— |
| reaper · 以战养战 | rare | 58 | tests/lua/warrior75_edges.lua:146 | —/— | —/— | —/— |

## 未发现与仍未知

本次没有发现具体75卡生产未实现或数值错误，未为制造结果新建浅测试。当前断言层的具体未知是未结束的当前规则shard、自然版本未记录和未覆盖自然ID（逐行可查），以及超出75审计的道具/合法依赖整合。旧matrix中的“当前5ceef2c”“pending currentCI”等文字是历史身份，不能覆盖本轮c3d事实。所有原版期望均源自固定社区源码与独立手抄/模型；未实际启动原版PC二进制作对照。

### 具体机制缺测：sword_boomerang

已定位实现`abyss_card_actions.lua:373`逐击重算存活敌人并调用cardRandom。现独立150例只给单敌人，断言基础总伤9、升级总伤12；`support/card_actions_registry_fixture.lua:53`还有damageRandom分发守恒，但那是原实现比较，不是独立原作随机序列oracle。未在本轮索引范围找到多敌人每击目标、致死后重选、每击cardRandomRng状态/次数的独立预期。故该项是具体oracle覆盖未知，不是已复现生产缺陷；不为凑覆盖新造浅测试。它阻止把“所有特殊机制均独立原版验证”当作已穷尽，不推翻75牌基础/升级真实执行已过的纯实现事实。

来源概率证据另有`tools/oracles/sts1_card_pools.py`独立JDK HashMap池序及JDK检查、`sts1_card_random_chain.py`的70非HEALING/28攻击生成池与共享随机链。矩阵把raw src构造池与实际生成过滤分开：Feed/Reaper虽在合法奖励/商店中，不冒充非HEALING战斗生成成员。领取固定seed并不独立证明概率。

最新CI只读快照：11/13 Windows规则shard成功，尚在运行：rules (4/13), rules (8/13)。这只取证，不改变测试、门槛或冻结来源。

## 后续独立候选（不回写旧 source 的已验证范围）

`66834507de8f902633b441081950cf38a2a0ae05`（基 ca838）为飞剑回旋补充 24 个逐击独立原版 XS128 向量，通过公开取得/Run.play及真实UI listener链；29/29 focused tests PASS，每片3.79–4.90秒。无生产代码修改，标为TEST_ADDED。详见`/workspace/cloud-reports/m3-sword-random-report.json`；尚待主控独审与后续批集成，不把该候选证据归入原c3d CI，也不补自然/升级版本/deckUid或设备缺项。
