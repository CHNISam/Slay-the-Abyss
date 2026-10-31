# ColorlessPotion 公开效果与独立消费证明

基线 `ca838ef6f36fedc1ed55a8eeeaafe9370149cb0d`（其父为冻结候选c3d2654）。这是 **TEST_ADDED**：原生产实现首轮即符合新增预期，没有生产缺陷RED，不改玩家模块、池、数值、既有断言或预算。driver阶段协议续办与本片可独立审查；没有推送或修改冻结主PR。

## 原始来源

本轮逐份读取固定镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`：

- `potions/ColorlessPotion.java:34` 将 `DiscoveryAction(true, potency)` 加入动作队列，基础potency为1。
- `potions/AbstractPotion.java:632` 在持有SacredBark时把potency乘2。
- `dungeons/AbstractDungeon.java:961–977` 用cardRandomRng从srcColorless原序中排除HEALING后均匀抽身份，不做稀有度抽样。
- `actions/unique/DiscoveryAction.java:41` 在每次update开头生成三张不同ID的候选，重复身份重新抽；首次显示，retrieval update又生成一组未使用候选，然后复制选中牌并设置本回合0费。amount1一份，Bark amount2两份；满手溢出到弃牌。

四份来源文件的SHA256保存在新fixture；没有复制方法体。来源是社区反编译镜像，不是正版PC二进制认证。`srcColorless`的35项次序及HEALING标签来自已冻结的独立牌库注册/HashMap目录；排除Bandage Up后保留34项。

## 新增标准测试

`tests/colorless-potion-source.test.mjs` 读取 `tools/oracles/sts1_colorless_potion.py` 的固定独立预期。该解释器不导入生产Lua、生产采样器或本地卡定义；复用既有独立XS128整数模型。原始生成器及两个冻结输入仍按原字节hash校验，新增文件明确LF属性，不软化hash或重写旧金样。

固定seed23是用于覆盖分支的受控输入：连续两瓶共14次身份wrapper调用，在第二次可见候选组和第二次未使用retrieval组均发生重复拒绝。普通与真实公开取得的SacredBark两种状态使用相同候选/随机流；Bark只改变复制数，不翻倍候选生成次数。

实际通过公开 `Run.obtainPotion`、`Run.usePotion`、`Run.chooseCard`：

- 完整34项source-order池与非HEALING候选身份逐项核对；每次bound、返回index、前后双64位word和counter逐调用匹配。
- 两次均选择正基础费用的Apotheosis，产物是本回合0费的独立战斗UID，catalog基础费用与永久牌组不变。
- 初始手牌9张；第一瓶普通放1张/Bark放1张另弃1张。第二瓶在10张满手时普通弃1张/Bark弃2张，所有复制实例保留0费。
- 非法索引、消费过的token以及上一瓶token误投下一瓶owner，完整Run状态均不变；不改变能量、金币、HP、maxHP或其它随机owner。
- 临时模块精确删除unused retrieval生成，新证明必须在 `colorless retrieval stream 1` 处失败；这是真实测试敏感性验证，不是生产缺陷。

普通/Bark各自一次Lua调用，均继续默认30秒；没有增加全33重复运行。现有真实Git CRLF checkout回归仅追加新oracle/fixture，保留旧原始字节断言，并在core.autocrlf=true的真实clone中执行两个oracle --check；未固定的control确实CRLF，所有认证输入仍为精确LF。标准命令：`node --test --test-concurrency=1 tests/colorless-potion-source.test.mjs`。

## 验证边界

这是显式ID战斗及手牌9张的受控fixture，库存通过公开API取得，但不代表自然获取。只建模本地“打开+一次retrieval”的消费投影；真实PC等待帧可能再次update，未据此宣称完整PC帧/UUID/视觉随机流重放。没有新自然两幕胜利、官方导入/ready、PC或实体手机证明。原243、c3、ca838三个自然cohort产物未改。

本轮标准结果：Colorless正向/精确突变2/2通过；真实Git CRLF checkout1/1通过；Python --check、JS语法和git diff --check通过。运行日志在主控外部附件，不充当自然/平台证据。
