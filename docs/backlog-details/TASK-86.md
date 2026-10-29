# 回归合同的排版耦合治理

## 真实失败与边界

- PR336 首次失败源码为 `4da5c49c301f00f533382153eef7770c4dfb23ec`，Quality [40863783913](https://github.com/CHNISam/Slay-the-Abyss/actions/runs/40863783913)。读取 `gh run view 40863783913 --log-failed`，不是推测当前头失败。
- 当前 PR336 头 `df163bc6222ba9c8a66226bb02bd54d38a8ab08c` 的 Quality 40871514608 在取证时仍运行；不能复用首头结论，也不能将其列为已通过。
- Windows 和 POSIX 都出现 `unreviewed mobile QA replay source`，涉及 `config/architecture.json`、主题、Node UI；PR323、Task77、Run/Nodes/MaxHP 等逆层随之拒绝新完整身份。首头架构的实际哈希 `e6f839c55cd050a7a53fc6069db8700da8308c5a2531bed91516378aa4322ae3` 与 mobile-QA 预期 `6e4375b9bd66868cd6ab8ac6fd5a1eef9d48573fac8e2bf2f6b6dfd8d3a9eafe` 不同。这是历史源身份不匹配，单凭该信息不能判定玩法回归。
- `tests/game-ui.test.mjs:12` 的根控件清单多出 `relicBar` 和 `relicPanel`。这是当前界面树合同与新面板的集成差异；仍须保留隐藏状态、可交互性及当前行为验证，不能删除整个清单断言。
- roster admission 的负例出现 `Expected actual to be strictly unequal`；P0 主题负例出现 `negative control must change actual current source`。说明替换未改变测试输入；它们没有证明安全性或产品错误，必须修正负例的适用输入，不能删断言。
- 其余历史 trace、冻结原体、room port、主题效果集合失败属于历史回放/快照消费链；需结合对应当前行为测试判断，不能将全部失败一概标作误报。此次没有替 PR336 修改其产品源码或源身份逆层。

PR336 当前头加入了完整 relic-view 逆层及夹具；本任务没有重做该修复，也不通过更新 golden/hash、放宽模块白名单来接纳其语义变化。

## 可证明等价的最小切片

调查历史架构合同时，额外实际复现：将当前 `config/architecture.json` 只改为单行 JSON，生产 `JSON.parse` 得到完全相同策略，`requirePr323Source` 却以 `b3df22e9...` 对 `1b0a5505...` 拒绝。它是单独复现的排版耦合，**不是 PR336 首头的原始根因**。

在 PR323 历史入口中只为该路径恢复标准缩进，然后仍要求原完整 `afterSha256`。转换前后去除字符串外 JSON 空白的 token 序列必须相同，因此不会利用 JSON.parse 隐去重复键、改写字符串内部空白、转义或数字表达。数组和对象键的顺序也没有放宽。无法证明等价时保留输入原文，由原严格守卫拒绝。

全部旧 accepted/original 原文、完整 SHA、压缩归档和 golden 保持原字节。此适配仅影响测试用历史投影；候选构建与审计的实际字节哈希不变。原来已有 CRLF→LF 规范继续使用。

## 验证

- 修改前真实 RED：同对象单行 JSON 无法通过 `requirePr323Source`。
- 专用正反例与旧 PR323：5/5 通过，Node v22.22.1。
- 九份历史/架构集成文件：30/30 通过，16260.9ms。覆盖原历史原文、完整 identity、缺文件/跨路径/未知字段/错误分类、重复/缺失/移动 hunk 等负例。
- 专用负例另覆盖数组换序、重复同值键、字符串内部空白、等价转义改写、非法语法和其他路径；这些均不得获得排版许可。
- 独立工作树将磁盘配置实际改为单行后，相同九文件仍30/30通过，15477.3ms；finally恢复原始字节。不是只对函数传入模拟字符串。
- 精确 PR 头 CI 待。完整跨平台门禁未实证之前，TASK86 保持未完成。

未运行官方客户端、未占键鼠；没有新的平台、自然通关或 UI 验收证据。
