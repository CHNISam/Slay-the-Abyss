# 猎人剩余卡牌离线实现

本片在显式 Silent Profile 的61张基础上增加14张，当前75张普通职业牌含4张基础牌，非基础来源母集仍是原71张。没有删池、按实现子集重抽、改稀有度或改概率。不是默认发布开启、完整自然构筑、平台导入或实机验收。

事实来源为固定社区反编译树 `319009d5df0a82d9fb0f23cc22322286c6a87ec0`，ZIP SHA256 `3f42bd7dde08126a9a8a02fc8eed8856c7b8b0dda551f50c62ced838e41ed458`；不是官方源码或经正版PC二进制认证。先审 `docs/drafts/class-final/unintegrated-final-components.tar.gz` 的定义和动作草案，再逐项对照固定Java。旧Final没有Distraction/Alchemize运行实现，旧sourceUid也不能代替现有deckUid；运行逻辑按当前生产接口重写，未直接恢复旧草案。

逐文件审阅输入指纹保留于 `tests/fixtures/silent-final-source-lock.json`（14张源卡及动作/能力/药水/AbstractCard共28份文件）；只提交摘要，不复制Java实现。

运行模块：`src/lua/abyss_silent_final_cards.lua` 登记14张、9种能力及其动作、选牌和回调；`src/lua/abyss_silent_potions.lua` 只随Silent runtime登记Cunning Potion与Ghost in a Jar。`config/architecture.json`列出层次及只在动作回调执行的延迟导入。没有修改共享 `data/potions.json`；正常商店/奖励/Entropic/Alchemize读取实际准备后的同一目录。无实体沿用共享伤害边界。

| 卡牌 | 固定源核对及落点 |
|---|---|
| Distraction | 技能src顺序、HEALING排除；在card.use构造期消费cardRng并锁定身份；BOT生成、本回合0费、消耗 |
| Endless Agony | 4/6伤害；真实抽到后TOP生成统计复制，临时UID、满手入弃牌，不递归触发抽牌 |
| Masterful Stab | 12/16伤害；每次实际正HP损失增费，手/抽/弃覆盖，排除消耗/使用中；保留费用差 |
| Setup | 1/0费；选择同一UID置顶；只在战斗基础cost>0时freeToPlayOnce，X不伪装为0费 |
| Well-Laid Plans | 1/2张手动保留，可不选；结束伤害与能力不会因选择续跑重复，虚无牌仍消耗 |
| Bullet Time | 3/2费；先NoDraw（可被Artifact挡），再当前可修改手牌本回合0费，不改X/不可打出的哨兵值 |
| Burst | 1/2个技能额外使用；purge重播保留同一永久身份，旧技能也走真实队列/手动弃牌；不重复实体入堆 |
| Corpse Explosion | 6/9中毒和独立尸爆减益，各自消耗Artifact；死者最大HP×层数，null-owner THORNS，毒/Choke死亡也进入同一钩子 |
| Doppelganger | X能量快照、升级+1、Chemical X+2；次回合Energized和DrawCardNextTurn，消耗 |
| Nightmare | 3/2费；选择统计复制并resetAttributes；叠层保留最早模板，次回合普通抽牌前生成，无永久deckUid |
| Phantasmal Killer | 1/0费；下回合DoubleDamage优先级6；普通伤害在力量/活力后×2，按回合衰减 |
| Tools of the Trade | 1/0费；优先级25，正常抽牌后额外抽再手动弃，真实回合队列可暂停恢复 |
| Alchemize | 1/0费、HEALING、消耗；card.use锁定limited=true的Silent完整33瓶源采样；使用持续potionRng，满槽/Sozu仍消费源随机 |
| Wraith Form | 3费；2/3无实体与独立-1 Wraith减益；Artifact分别处理，自己回合结束再施加敏捷减少，无实体按round衰减 |

两瓶是Alchemize完整池必要依赖：Cunning Potion先构造Shiv+，BOT生成3份（Bark6），满手溢出弃牌且只获临时UID，Master Reality不会再次升级已升级小刀；Ghost in a Jar BOT施加1无实体（Bark2），优先级75，受到伤害/HP_LOSS最多1，round末减少。两瓶有战斗、商店和库存共用说明。Bark本身的自然遗物获取不在本片；测试显式提供其被动目录定义，未伪称已实现该遗物渠道。

测试入口：`silent_final_smoke.lua`最初因缺Distraction真实RED；`silent_final_runtime.lua`覆盖新增14张基本/升级28次实际出牌及跨回合；`silent_final_edges.lua`覆盖重复弃牌选择、击杀后After Image、Artifact、毒与Choke尸爆、费用差、抽牌复制及事务；`silent_final_potions.lua`覆盖真实Run两瓶、Bark溢出、失败回滚及Alchemize持续RNG；`silent_full_matrix.lua`逐张执行全部75张两版，Reflex/Tactician走真实弃牌触发，其余走真实play/choice，共150个命令用例。矩阵通过只说明构造上下文可执行，具体数值与结算仍由既有Silent专项和新增边界断言证明。

`silent_final_presentation.lua`用实际Presentation与CardDisplay检查150版说明、动态数值替换、Wraith敏捷损失/Nightmare所选卡牌及Bark后两瓶数字；整数格式首次RED后修为统一numbers.integer，避免2.0/3.0混入核心说明。该离线格式检查不等于平台可读性与交互验收。

`silent_final_sources.lua`是受控连续来源流→真实领取/购买命令的闭包用例：71/71非基础卡随机抽取后真实领取、71/71从真实货架购买，以及固定冷启动种子两瓶购买已通过；不是正常地图全程。native卡能力钩子按实际状态/登记工作，`nativeRageHandled`只对已有Rage分派去重，不检查职业身份；foreign WLP也覆盖native回合保留续跑。跨职业完整合并目录由TASK-59拥有，不能把此处组合夹具当作该目录交付。

此片不更改Backlog完成状态；最终整合树完整Quality、自然构筑与平台显示/交互仍需父任务独立验收。
