# 四小魔编组与开战事务

2026-10-24，TASK-15.18。基于已合 PR174 的 `b757705ee4220c3d50ecd121631b65748f94ed6e` 集成；12个改动前既有文件已逐项核对该提交的 Git blob，与本地冻结输入一致。本片只修 `gremlin_gang` 成员选择，不改任何敌人生命、伤害、AI、medium_slimes、地图遭遇概率或原有奖励测试分片。

## 来源与准确边界

固定社区反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`，不是官方源码认证，也没有与正版PC二进制hash比对或运行原作。13份来源文件的原字节、SHA256和Git blob随审查证据封存；没有搬运第三方实现代码或画面资产。

- [MonsterHelper.spawnGremlins](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/helpers/MonsterHelper.java#L731-L759)：有序池为 mad、mad、sneaky、sneaky、fat、fat、shield、wizard（ID均带 `_gremlin`）。四次从当前剩余池取一项并只删除该项，保留抽取槽序，不排序、不追加洗牌。首次种类权重2:2:2:1:1，后续按剩余项变化；不是五类等概率选四只。
- [Random.random(int)](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/random/Random.java#L49-L57)含上界，四次 miscRng 参数严格7、6、5、4；Lua索引另加1。
- 原方法每选一槽便构造该敌人，[setHp](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/AbstractMonster.java#L751-L760)使用monsterHpRng；[MonsterRoom](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/rooms/MonsterRoom.java#L49-L55)整组生成后才初始化所有槽位的aiRng roll。MonsterGroup不打乱数组。
- [AbstractDungeon:1727–1731](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/dungeons/AbstractDungeon.java#L1727-L1731)按seed+floor重建房间流，而当前项目跨节点保留run.miscRng。本片沿用174的当前流，不全局reseed。HP/AI/牌序仍共用Combat的历史LCG，未在本片重做。

MonsterHelper SHA256：`e6a60cdfa7af881d5f128a9532664ea33f32e71239cda49f3983fceac95a10e1`；AbstractDungeon SHA256：`8fa0712818487a360c72950d053fe77e1a35efa967080723d15c69037092fd26`。完整原作流、消费时序与PC同seed同楼层同组仍留TASK-16.1，绝不由本片宣称完成。

## 接线

1. 删除本遭遇误导性的固定五敌 `enemies`，用 `gremlinPool` 八项及 `gremlinCount=4` 表达。schema限定该ID、精确池顺序/重复权重和四槽，校验全池引用/tier，拒绝与静态/Boolean分支混用。按四个最大可能出场项计算含分裂父体的槽上界，不能把八候选当八敌，也没有放宽其他遭遇五槽校验。
2. Run.startCombat复用174的misc克隆和成功后提交。先抽完整四ID，再按槽序交给一次既有Combat.new；包括抽牌后遗物的全部开战步骤成功才提交。未新增模块、公共API或通用事务框架；Nodes暂存事务无需改动。
3. “先选四ID、再构造”并不复制Java的misc/HP交错全局轨迹；仅在misc与Combat流独立、构造不消耗misc的当前前提下，保持各流内部顺序、成员顺序与HP/AI槽位对应。显式Combat敌人数组仍是显式数组，不会触发隐式遭遇选择。
4. 扫描生产消费者：Map只取ID/tier/楼层，不读成员数组；数据编译递归保留全池；图标检查使用完整敌人定义清单，不因一次四槽漏掉第五类。压力审计改报战斗实际初始敌人数。

## 红绿与回归

- 先红：新增schema21项中20红，Lua专项29组中26红；旧源码6个真实入口均五敌、misc零消费。随后schema21/21、Lua29/29通过。
- 独立oracle用原始池索引的“已使用集合＋剩余排名”，不读取生产JSON、不调用生产选择器生成期望。1680条合法有序索引全穷举，只截获构造边界的实选数组，不构造1680个完整世界。共354个不同有序类型组，首槽mad/sneaky/fat各420，shield/wizard各210；354种组不等概率。
- 5个来源字面量向量另跑真实Run/Combat，验证当前已推进misc、四次精确范围、槽序、HP/AI对应、重复种类独立ID/状态/意图及每战新池。无注入seed0/1/42/65535及seed42预推进11次也有固定结果；这是当前流回归，不是PC golden。
- 真实普通节点seed1/f10_l2、天然问号转战seed60/f8_l1均+4，保留问号符号、eventRng和概率更新；查看/重复进入不重抽。两条定向入口用Map.choose沿合法边定位前沿，不冒充此前各战已打完。
- direct/普通/问号各覆盖真实构造后的返回失败、抛错及遗物尾段失败/抛错。旧run/map每层嵌套表引用与字段全部不变，恢复后重试等于新鲜成功。非法ID、楼层、遗物、阶段、节点与地图归属拒绝不消费。其余17遭遇按独立成员字面量保持原构造与消费规则（small_slimes仍一Boolean）。
- 六个独立突变均被杀掉：有放回、五类等权、删掉同类全部项、逆序输出、含上界偏一、提前提交misc。
- 原生Lua全161文件通过，包括真实battleLayout的五槽UI；Python17项通过；JS语法与数据验证通过。Node初跑1030项中1029过，唯一失败为地图导出桥缺Fengari；明确排除该桥后1029项通过。另16个依赖Fengari的测试文件未执行，不把原生Lua当Fengari认证。未安装软件/依赖，未使用用户Codex，未运行完整npm check；当前提交正式CI由集成方核对。

旧夹具只迁移错误前提：Shield改用合法含Shield的seed60并检查另外三槽合计7格挡/自身0；Fat与死后Weak队列改用seed0恰一Fat，原事件顺序断言保留；Wizard改用seed0第二槽并保留每槽一次首roll；Sneaky对每个实际入选实例仍检HP10–14及攻击9，并覆盖全部五种HP和未入选情况；small_slimes保留其他16静态组，gremlin独立专项覆盖；遭遇总覆盖仍18组/256地图种子。五敌UI改为显式低层五演员夹具，容量/位置/数值断言未减为四槽。

## 原策略五seed结果

原样运行现有m2-resource-audit与默认m2-autoplay-policy，固定1、2、3、36、42，不改数值、卡组、路线或出牌规则来造赢：

- 1：16层败，5胜、17牌、24金币。
- 2：16层败，5胜、15牌、103金币。
- 3：16层败，5胜、17牌、19金币。
- 36：16层败，7胜、18牌、135金币。
- 42：6层败，3胜、12牌、144金币。

五局均正常0生命失败，账本与重开清洁断言通过；exit0代表审计完成，不代表通关。seed1真实玩到10层，以fat/fat/mad/sneaky四敌开战，misc从1到5；原牌组/合法命令战胜该组后继续到16层失败。这条是完整游玩到目标战斗的补证，不仅是前沿定位。其余四局本轮未遇小魔群。不能从五样本估胜率，也不复用此前17层胜利作为本片胜利证据。

本片未平台编译、官方导入或原神实机；未认证本片17层胜利、完整原作随机流或TASK-15全池/平台验收。
