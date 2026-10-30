# 新绘怪物：逐实例显示

本轮移植原版逐实例位置、绘制顺序、命中框、召唤插入和死亡时序；不保留按存活数等分、缩放、首领居中或自创死亡下沉。新画共享源数据，实例的身份、坐标、颜色和生命期各自独立。千星只负责把这些结果写到控件。

## 已核对的原版实现与对应代码

固定来源：社区反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`。它不是已认证的正版构建，也不等于开源授权。本轮不分发 Java 源码、原作贴图或 Spine 资产。

- [MonsterGroup.update/render](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/MonsterGroup.java#L235-L283)：逐个更新、逐个绘制，每只都有输出，不能只挑一个物种。对应已有 `EnemyView.slots`、`abyss_battle_render_actors`，以及 `abyss_monster_art.new/select/write` 对每个实际显示行的独立输出池。
- [AbstractMonster.update/render](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/AbstractMonster.java#L706-L748)：位置、动画偏移、颜色和透明度属于实例。原 Java 对象身份在本项目对应唯一 `actor.id`；`definitionId` 只查画稿。已有反馈及 ActorPainter 继续负责动作，`MonsterArt.pose` 只把结果写到对应控件。
- [AbstractMonster.die/dispose](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/AbstractMonster.java#L845-L876)：濒死显示和最终清理分开。沿用现有 `pendingFeedback/dying/deaths/escaping`；清理图池不能改变死亡状态或清掉另一只怪的反馈。
- [SpawnMonsterAction.update](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/SpawnMonsterAction.java#L40-L69)：创建、入队和初始化属于召唤动作。继续使用现有召唤模块；绘图不调用初始化、选招、插队或 RNG。

## 原版行为与控件边界

`abyss_monster_source_geometry` 保存63个原构造几何定义（含hard Jaw变体），`abyss_monster_source_positions` 保存普通遭遇偏移；既有动态队形继续使用 `sourcePosition`。Wizard的x−35、Chosen的y−20等构造位移只加一次。原版 `drawX=WIDTH*0.75+offsetX*xScale`、`drawY=340*yScale+offsetY*yScale` 统一转换到1280×720居中、Y向上的坐标系，不随其他怪死亡重排。矩形命中框使用原构造宽高/偏移，按原列表顺序命中第一只；新绘方形画稿的固定框不是原作贴图/Spine尺寸。

召唤位置按原 `SpawnMonsterAction` 遍历**整个**原列表，统计resolved drawX严格更小的实例后插入；不是扫描到首个更大值就停，也不忽略尸体。游戏/RNG逻辑不搬进渲染器。Byrd高度使用显式独立cosmetic流，不能偷用战斗或misc RNG，也不把该流声称为原版全局MathUtils熵的逐值重放。

死亡从已经呈现的致命接触帧开始，独立于动作队列；正常1.8秒、fast1.0秒，严格越过计时终点才清理。沿用已有feedback时间所有者，不另造计时框架；后续死亡提示不重置已开始/已结束的实例。透明度按原TintEffect递推，冻结致命接触时已绘制RGB，不下沉、拉扁或新增金色爆裂；玩家死亡仍是独立路径。

原版没有“最多5个drawable对象”的显示截断。本轮用既有 `InstantiateClientUIControl` / `DestroyClientUIControl` 按actor.id创建、复用、终态回收完整单位模板，含生命、意图、状态、命中与反馈控件；每actor模板647控件，其中600图元；每个实际Power另有7控件，UNKNOWN/STUN每个活粒子复用该7控件模板（仅icon可见），状态无10格/两行上限。超过单父节点60子节点时分层分页，不提高父节点门槛，也不借用手牌的10-pool/64-create预算。一次clone调用不等于只创建一个控件。未绑定index0的离线输出不是可玩候选；实际候选须注册并读回模板index。分配/绑定失败显式报错并保留清理所有权，不静默漏怪或逐帧重试。

18张新绘测试画稿绑定19个敌人ID，具体关系只以 `data/presentation/native-monster-art.json` 为准。未覆盖物种仍用旧图库；不能把这批称为全部42种完成。源图不等于真机画面，JSON/Lua回放相同也不等于与PNG像素相同。六实例的真实生成模板模拟控件回归与121节点轻量分页测试是不同证据，不能推导121份完整图的性能。官方导入、PC/安卓表现、实际最大drawable峰值、正式容量及最终画质均未验收。

## HUD移植与尚未等价的图形资源

HP宽度与位置使用原hitbox底边（20高度、中心−18）；intent64命中框位于hitbox顶部+32，128图形独立于新画稿正方形边界。名称按原hoverTimer、fadeLerpSnap和exp10Out悬停显示，不永久占一行；原字体度量、MOVE_NAME_BG纹理和health显示动画仍未核对为等价。Power按实际源列表顺序单行输出，desktop48/mobile55步长，数量右上对齐；本地许可glyph替代原atlas，48原单位只是替代图形框，不声称原packed atlas大小。

`source-monster-intents.json`保存42种130招式的setMove枚举证据。世界intent选择器与tooltip严格分离：全部ATTACK变体使用伤害总量的7档攻击图；STUN无底图，UNKNOWN底图不绘制。原7档texture身份保留，但当前许可glyph资源没有原七张剑图；UNKNOWN/STUN的时序与intentAlpha见下节；debuff旋转/bob等其余效果未完整移植，不把现阶段说成完整原版像素/动画效果。

## 原版意图粒子输出

UNKNOWN/STUN分别移植原独立0.5/0.67秒生成周期和1.5/2秒生命周期；UNKNOWN三相序号保持模块级，按原怪物列表顺序推进。渲染重入不推进时间；显示按behind→base→after→damage分层，死亡/逃跑时隐藏但已有粒子仍按原时钟更新。使用独立RandomXS128视觉流，绝不消费游戏随机流；固定初始视觉seed不是原版全局熵复现。UNKNOWN问号和STUN星形采用项目已有允许图标；原tinyStar2 atlas尺寸不可用，因此显式使用16×16替代尺寸，不宣称原版像素/packed bounds。原版BattleStart消息展开在本项目现有进入战斗显示边界触发首次showIntent；玩家回合和已验证受击转态重置，rollMove不是重置。


## 已选招式与正在显示的意图

`abyss_monster_displayed_intent` 对应原 `createIntent` / `applyPowers`：只有createIntent复制已选招式的枚举、基础伤害与连击字段；applyPowers使用**当前已选招式的基础伤害**重算，却保留此前已显示的枚举/连击次数。这一看似不一致的原行为没有被“修正”。当前42种的15个多段招式保存显式源boolean，不以次数大于1猜测。普通render/tick不触发重算，不从状态hash猜回调。

既有动作生产者在实际接受的Apply/Reduce/Remove/ChangeStance边界附加明确 `sourceIntentPowers` 来源；无既有事件的成功NoDraw、正数减层或同姿态动作使用零时长呈现通知。Feedback同步消费这些通知，不插入额外动画帧、声音或动作等待。全体怪物刷新而非只刷新状态目标。Poison直接扣层、Guardian原始数值变化和被拒绝/重复动作不能假称同一回调。Artifact消费和回合衰减仍包含现有引擎的队列压缩；Strength/Dex归零的后续独立Remove边界、Spawn入组前仅新怪的applyPowers尚未完整移植，不能宣称所有原版回调均已等价。

`Events.frame`在捕获时分离可变intents/effects，防止后续Book选招增加段数、Hexaghost按HP重设Divider时改写历史帧；仅在后续显示时复制已经变异的对象无法修复历史。实际双同种实例与原AI setter回归验证该边界。世界输出已验证真实Guardian：新选基础32与旧4连击相组合，力量回调全体重算，直接未标记状态写入不刷新。InfoContent详情仍保留旧说明行，尚未完整替换为原updateIntentTip的显示枚举/动态伤害文案，不扩大世界输出测试的结论。

背包/牌堆视图隐藏时保留同一战斗意图时钟及序号，实际deck overlay暂停更新；重新显示不调用createIntent或重置粒子。源码其他有条件继续room.update的屏幕不能由此一概推出等价。原VFX取证缓存少一个末尾LF；补回该LF后六个文件均匹配固定Git blob，语义没有差异，不把规范化缓存称为逐字节原文件。
