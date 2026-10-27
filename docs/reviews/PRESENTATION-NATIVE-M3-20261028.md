# M3 有序原生写入契约迁移

本次只迁移已确认的呈现轨迹，不改生产 Lua、严格控件 mock、recorder、文字内容、输入归属断言或测试时限。

## 独立配对捕获

| 冻结源 | 完整条目数 | 原 rolling hash | 原断言结果 | 实际耗时 |
| --- | ---: | ---: | --- | ---: |
| e0fad45c74ed574bc4cfb8a4c9ad71424a13c386 | 72915 | 148113441 | PASS | 14.952 秒 |
| c5e768807081d1c62750174998367f1565274ee5 | 77278 | 1948853637 | RED：旧有序轨迹断言 | 15.798 秒 |

两棵独立工作树各自离线安装相同锁文件依赖、生成自身 data/UI，并执行完全相同的原 `presentation_responsibilities_trace.lua`。原 fixture 的字节 SHA-256 都是 `6078d7df871c878a15e2645097debcb825f6f38e6abb66c1b35f0e05e2497d8b`。临时捕获驱动只观察原 `Trace.serialize` 的最外层返回值，原 add/hash/严格 native 字段代理继续执行；原断言保留，以 pcall 记录上述真实通过或失败。两次都保留原 30 秒预算。完整原有序字符串、来源头、结果、输出和耗时以两个 gzip JSON 保存，不使用采样或重新构造的假轨迹。

机械比对结果：**全部 72,915 条旧写入在当前 77,278 条中逐字、逐序完整保留；零删除、零替换。** 仅增加 4,363 条，恰好 324 种唯一字符串。既有动作顺序、文字与所有旧写入仍由旧 count/hash 及完整序列检查保护。

## 所有新增写入

| 分类 | 条数 | 真实来源与原因 |
| --- | ---: | --- |
| 奖励框、边框、底板、标题和副标题几何 | 812 | RewardLayout 每次28轮 render 重申原普通奖励几何，便于独立多奖励时切换扩展布局。当前场景仍是640×516，原字段写入不删改。 |
| 药水奖励说明几何 | 196 | 同28轮 render，说明文字重申位置(0,-264)和大小1040×64，避免扩展布局残留。 |
| 独立绿钥匙按钮 | 308 | 同28轮 render，新按钮保持隐藏、不可交互，文案为“领取绿钥匙”；复用现有 preset 状态和主题色。 |
| 地图说明几何 | 77 | 11轮地图 render，每轮7个方法/属性写，重申原说明位置(0,-324)和1160×28大小。 |
| 地图图标位置 | 1782 | 594次实际可见节点 render，每次3条方法/坐标写，把未标记节点图标复位至(0,0)。 |
| 绿钥匙节点标签显隐 | 1188 | 同594次 render，新标签每次 SetVisible(false)和visible=false。 |

本场景没有已解锁历史或绿钥匙奖励，新增按钮/标签处于关闭状态；不能把该轨迹当作燃烧精英、六奖励扩展排版或真结局本身的交互验收。这些由专用M3回归负责。本片只证明旧呈现没有丢写或重排及新增基础几何/关闭状态合法。

全部精确路径、字段、参数、颜色、文案、次数、源码位置在 [review.json](presentation-native-m3-20261028/review.json) 的324项 writes中登记；每次插入在当前序列中的索引和此前旧条目数一起形成独立SHA-256。完整 [baseline](presentation-native-m3-20261028/baseline.json.gz) 与 [current](presentation-native-m3-20261028/current.json.gz) 可直接解压读回核对。归档继承 `docs/reviews/** -text`，gzip和JSON均保留Git blob字节；源码/fixture身份统一先将CRLF转为LF再计算SHA，不改变源码内容。

## 机器保护及最后实测

`tests/presentation-native-m3-contract.test.mjs` 固定证据归档/清单SHA，独立重算两个旧式hash，断言全部旧行完整有序、每次插入的精确位置/内容、全部324类具体值/次数与六类总数；并绑定本轮三个直接写入源、主题/布局、原scenario和两个严格fixture/recorder，不冻结无关核心源码。删除、改值、重排旧写，额外插入，将已审插入移位，以及更换recorder身份均有实际拒绝负例。没有通用路径或字段allowlist。

当前 Lua raw 轨迹仍是严格的77278/1948853637断言；旧72915/148113441和全部原始序列在上述独立Node守卫中保留并继续断言，避免Lua重复遍历整段旧hash导致预算压力。原文字361/1837256485、UI退出/反馈清理/战斗状态不变以及 `assertNativeInteraction` 全部保留；原 `presentation_trace_native.lua` 的 CursorArea非法字段、只读activeInHierarchy、preset双门和P0逆映射检查未改。

最终实际串行命令 `node --test --test-concurrency=1 tests/presentation-native-m3-contract.test.mjs tests/presentation-responsibilities.test.mjs`：5/5 GREEN，18.213秒；其中原文字1.196秒、原trace15.359秒、原严格recorder0.547秒。所有Lua仍使用默认30秒。未启动游戏、导入、实机或发布。
