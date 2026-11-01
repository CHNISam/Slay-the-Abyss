# 重复施放永世的磐岩：限定修复记录

## 固定来源与边界

只读对照社区反编译镜像 [Barricade.java](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/%E6%9D%80%E6%88%AE%E5%B0%96%E5%A1%94%E5%8E%9F%E7%A0%81/cards/red/Barricade.java)。固定提交为 `fc379c875c11e008e9c10548ac8e394c301c532f`；Git blob `9ea02e89cce3dec5a3c37e3608272eeda6fe43fa`，原字节 SHA256 `fd0d75660eebf157a7d54d0bb4acae0005d6110f7341cf0a8ef4cd327a86e15a`。本轮重读并核对这两种哈希；不将第三方源码复制进项目。

该文件的 use 方法在玩家已持有 Barricade 时不再排入 ApplyPower；构造费用为3，升级费用为2。这是社区方法体证据，不是官方开源、正版PC构建认证或本轮原游戏观察。原30牌审计的来源认证不足仍保留。

实现仅调整 `abyss_effects.lua` 的 gainStatus：玩家、barricade、请求1层、现有1层，且定义为table、stack为none时，不执行冗余施加。Combat 的付费、能力牌离开战斗牌堆、后续效果和失败回滚不变。不改卡牌数据、Actor共享API、状态数值或UI；不全局过滤零值，也不扩展效果协议。

严格匹配请求1层和既有1层，故显式0、非数字、NaN、无穷、负值、非整数、int32越界、旧层数溢出及缺失定义仍进入原校验路径。仅在前述条件精确匹配后检查定义容器：非table容器、非table定义或非none定义均走原Actor路径，不提前索引坏容器或新增通用定义校验；其他操作、敌人来源及状态保留原合同。

## 本地验证（2026-10-24）

基线为 `6293d117766e56c073d7c0ad97982eeb3c3b301f`；1032个仓库输入逐Git blob核验，包含PR176地图更新及PR177的Guardian、空牌组和药水修复。没有改写这些并行功能或原历史诊断JSON。

- 新增 `tests/lua/barricade_repeat.lua` 20组：最初17组在原实现11过6败、初修17过；集成复核发现“定义存在”门槛会吞掉数字定义错误，并错误跳过可叠加或字符串定义的旧行为。补3组差分回归后初修17过3败；收窄为table且stack=none后20过。旧冻结及失败证据保留，不把初审通过当成覆盖了此边界。
- 专项覆盖基础/升级四种先后组合、真实费用和能力牌去向、首次状态事件、真实轮次格挡保留、失败原地引用/能量/牌/事件恢复，以及零值、Artifact和通用Actor边界。定义差分额外验证合法intensity及受控add保留加层/事件、数字0仍抛原错误、字符串仍保留原加层行为。同组再加入非table容器，先证19过1败，再修为20过并保留原Actor错误文字与位置。
- 使用实际生成布局驱动生产Feedback：首次仍有＋1和状态音效；重复仍播放出牌流程，但没有＋0和额外状态音效。此为离线适配器测试，不是千星画面或声音实测。
- 初修时去掉金额门槛、已有能力门槛、定义门槛三个负变异分别被4、8、1组定向断言检出；这不覆盖随后才发现的定义类型边界。
- 原三条 `scripts/diagnose-card-sequences.lua` 诊断重新执行：Shockwave基础/升级仍为 `strictExpectedMatch=false`，事件顺序差异未修；Barricade-repeat由 `false`（`player:barricade:0`）变为 `true`（空状态事件列表）。诊断进程退出0不等于三条全过。
- 原生Lua 5.4 helper执行全部167个Lua fixture文件，均exit0；battle_ui使用真正battleLayout注入，其他界面使用build:ui生成布局。含Artifact、Flex、NoDraw、signed status、atomic_play、Guardian、空牌组、药水和地图回归。
- 独立纯Node子集59文件／1008测试通过；JS语法、data、Backlog只读校验通过；Python呈现测试17通过。

Node子集明确排除直接或间接依赖缺失Fengari的文件。早先带这些wrapper的目标运行有6条缺依赖失败，扩大子集时另有3条间接wrapper缺依赖失败，均保留为环境失败，未安装依赖、替换runner或包装成全量通过。一次npm test中途停止，亦不计入通过。原生Lua结果不替代Fengari／当前SHA的CI。

没有运行完整npm check、官方编译、存档导出、官方导入、实机试玩或发布。独立审查与远端CI由集成流程另行记录；本记录不提前宣称通过。

## 最新主线接合复核

基线dc487e63（PR178合入，tree852d3960）保留PR177清单与PR176/179界面。Effects旧blob仍423b400，最终修复blob0c498b3。独立以最新布局/主题重新验证4条真实GameUI重复牌流程、4条晚失败回滚、4项定义边界，14个相关Lua文件229组及内容校验通过。仅原生离线执行，不代表Fengari、官方导入或原神/手机实测。首发清单仅移除已修的barricade顺序阻塞项，所有逐项验收标记不变，Shockwave两条失败及历史诊断原样保留。
