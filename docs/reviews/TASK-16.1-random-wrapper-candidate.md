# TASK-16.1：Random 包装器的隔离子集候选

2026-10-23；只读核对 develop `ed39f4653ddb555391c0dfe5a4507d1f58387171`。PR81 原语已合入，Git blob `1a9b8abd5f822cd937618ff488824dc08fd4c8f8` 在本候选保持不变。仅新增包装器、独立测试、固定向量和本文四文件。不改生产 RNG、EnemyAI、地图、数据、共享战斗内核、任务元数据或认领。TASK-12.4 / W1 / PR62 继续归 @codex-map17；TASK-15 继续归 @Codex；TASK-16.1 完整验收不因本切片完成。

## 固定只读来源

- [STS Random.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/random/Random.java)：49–96行的计数、闭区间整数、Boolean 和 float；24–47行的构造、copy 和 setCounter。
- [libGDX RandomXS128.java](https://github.com/libgdx/libgdx/blob/3b1fda1fc2e1f6b3c74851471870062d871ed16f/gdx/src/com/badlogic/gdx/math/RandomXS128.java)：nextInt 委托带拒绝采样的 nextLong；Boolean 用最低位，float 用高24位。上游 Apache-2.0 及原语边界见 [PR81说明](TASK-16.1-rng-primitive-candidate.md)。

STS 是固定反编译镜像，不是官方认证的PC构建；固定libGDX版本与目标游戏依赖的匹配仍待认证。本日期为文本核对日期，不是原作观察日期。没有执行、复制粘贴或编译下载的上游实现，没有安装依赖。固定向量由独立编写的Python大整数数学解释生成，不是原版游戏或官方库执行Oracle。

## 显式 Lua ABI

入口为 `tools/candidates/sts_random.lua`，不自动加载到生产系统；调用以仓库根目录为当前目录。无Java重载推断。

- `fromSeed(seed)`：复用PR81的规范signed64十进制字符串。counter初始0。禁止第二参数，不支持seed+counter重放构造，也没有无参/全局随机初始化。
- `randomInt(state, maximum)`：Java signed32整数参数；仅支持maximum < 2147483647，使maximum+1不溢出。合法非负值返回0..maximum，含两端；0也消耗一次。负值属于已支持Java类型但非法bound，先加counter，再由原语抛错，不消耗raw。
- `randomIntBetween(state, minimum, maximum)`：两端必须是signed32整数，且数学差值 maximum−minimum 必须落在[-2147483648,2147483646]，明确排除Java中间运算溢出的跨度。合法次序返回闭区间，等端也消耗一次。倒序且差值仍在支持范围时，先加counter，再因非正bound抛错，raw不变。
- `randomBoolean(state)`：恰好一次raw输出的最低位是否为1，绝不以float<0.5替代。额外chance参数拒绝。
- `randomBooleanChance(state,chance)`：只接受[0,1]内恰好可表示为IEEE binary32的Lua number，包括零、1、次正规数；拒绝NaN/无穷、范围外、字符串及不能精确表示的double。不是把任意Lua number隐式舍入为float。一次原语nextFloat后严格比较 `< chance`，相等为false；0/1也抽取，不提前返回。
- `randomFloat(state)`：无缩放nextFloat，高24位除2^24，结果0..1−2^-24。额外范围参数拒绝。
- `snapshot(state)`：独立普通表 `{words={hex0,hex1},counter=signed32}`；hex各16位小写。`restore(snapshot)`创建独立完整状态；`cloneState(state)`是对象状态克隆。内部状态为`{primitive=PR81状态,counter=signed32}`；各操作先验证普通表、精确字段及嵌套状态，无元表，不调用输入元方法。

所有抽取接口及fromSeed拒绝额外参数，包括显式nil额外参数。unsupported Lua ABI（类型、范围、概率表示、溢出跨度、额外参数）或坏状态均在任何修改前拒绝。这是候选有意收窄的接口，不声称复刻Java所有错误输入。特别是Java接受范围外float概率，而此处不接受；Java的整数溢出边界也不在该候选支持域。

概率合法性通过二进制精确缩放验证：normal归一化后检查24位有效数字，subnormal检查2^-149网格。石颚兽请求的0.5625、0.35699999332427978515625、0.41600000858306884765625可直接使用；普通double 0.357/0.416明确拒绝，不能偷偷换阈值。

## counter 与恢复的关键区别

counter是public draw调用次数的Java signed32计数，每次+1，2147483647之后明确回绕为−2147483648；不是Lua无界整数。一个bounded调用可能为了拒绝采样消耗多次raw，但counter只增加1。支持域内非法bound在counter增加后抛错也保持来源行为。counter回绕的成功/失败路径用常量时间边界用例验证，不循环数十亿次。

原版`Random(seed,counter)`从种子新建后反复调用`random(999)`，即nextInt(1000)；不是给计数器赋值，也不记忆之前的调用类型。负counter构造参数不会迭代，最终counter为0。`setCounter(target)`先检查target大于当前，再用Java signed32差值target−counter作为循环次数；只有差值不溢出时才按该正差值反复调用无参Boolean。例如counter=−2147483648、target=0时，差值溢出为负数，循环零次。相等或较小仅记录错误，不回退、不重新播种。二者推进方式不同：前者可拒绝重抽，后者每次一个raw。因此seed+counter并非一般意义上的精确恢复；不能把counter当成raw偏移。两者均不在本切片实现。

完整双状态字+counter快照仅证明候选对象精确续算，不是原作游戏存档兼容格式。原版copy先创建无参Random，间接消耗全局MathUtils随机，再覆盖状态；cloneState故意没有该全局副作用，不能声称与copy全局行为相同。

## 测试证据与局限

固定JSON保存独立Python生成器全文和SHA256，可提取后用已安装Python运行并逐字段复现完整文件；日常测试只读取JSON，不运行生成器或联网。6个signed64种子（含0、负数、极值和2780424839485660359）各80次混合调用，逐次核对输出、双状态和counter。另有反解状态强制首raw为ffffffffffffffff：16次闭区间0..2调用实际17次raw、counter=16；不靠随机碰撞稀有拒绝分支。

定制raw端点区分Boolean低位与float高位，覆盖相等概率/0/1、次正规与normal网格、石颚兽精确参数；覆盖负bound、unsupported ABI、signed32计数回绕、快照续算与深层隔离、坏状态/元表、额外参数。TDD第一轮8组行为失败（缺候选文件），实现后9组全过；再加入额外参数测试先失败，补明确拒绝后10组全过。fixture自检也是1组。

实际系统liblua5.4执行同一Node测试生成的Lua，只有本地执行器替换：最终10/10组通过。14个独立负向变异均检出，包括错误开区间、漏计数、不回绕、错误Boolean来源、概率<=、允许double/非法次正规、克隆别名、丢counter、跳过状态校验、错误失败原子性、额外抽取及丢额外参数拒绝。变异后还原并重新10/10。Node语法检查通过，嵌入生成器完整复现，PR81原语Git blob核验一致。

正式`node --test tests/sts1-random-wrapper-candidate.test.mjs`已尝试：fixture自检通过，其余9组因既有fengari-node-cli缺失而不能执行，未安装绕过。隔离材料工作目录的`npm run check`已尝试，因缺少check-syntax.mjs停止，不能宣称聚合全绿。系统Lua证据不是Fengari/Windows或千星实机验证；当前SHA正式CI及独立复审需另行核对。

没有scaled-float、long/double重载、原版全局copy、seed+counter或setCounter；没有虚构独立aiRng种子、流初始化、调用次序或LCG近似。PR88未来调用者仍须自己保证首动先抽主roll、仅请求时抽条件Boolean、正确记录历史；该选择器与生产EnemyAI在本切片均未接线。W1、TASK-15/16.1严格一致性及平台AC继续保留。
