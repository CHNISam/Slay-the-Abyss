# TASK-89：黄色占位图回退策略短修

基线：`origin/develop@7adc71b6a7eaff42f30f09862e4cdf54fd956dbc`。

2026-10-31 离线确证：`abyss_battle_unit_view.portraitVisible` 隐藏主题中 `status=placeholder` 的玩家图像，但 GameUI 随后的肖像 `sync`/`tick` 会在未 ready、暂停或失败时把同一 fallback 控件重新显示。新增回归在未修源码上失败于 `building refresh restored the yellow placeholder`。这证明黄色占位图的可见性策略冲突，不能证明 Owner 报告约90%的正式资源丢失根因。

修复只在启用战斗肖像时读取主题玩家图像身份。肖像普通刷新及 ready setter 重入后的恢复均遵循同一策略：正式图库图像保留回退，明确的玩家 placeholder 保持隐藏。选角、卡牌扇和背景的禁用路径不新增主题读取。

## 本轮验证

- `npm run build:theme`：通过，生成本树主题。
- `npm run check:architecture`：通过，316模块、1817依赖边、0错误；本树报告 `build/architecture.json`。
- `node --test --experimental-test-isolation=none tests/official-portraits-lifecycle.test.mjs tests/official-portraits-flags.test.mjs tests/official-portraits-equivalence.test.mjs tests/selection-portrait-preload.test.mjs tests/lowpoly-select-flags.test.mjs`：33/33通过，27.34秒；结果见本树 `build/portrait-fallback-tests.tap`。
- 负控使用当前主题玩家 metadata，覆盖 building、ready、map 暂停、返回战斗、失败及 ready setter 内 release 重入。正控使用主题官方图库数字ID，确保正常 fallback 仍恢复。
- 真实生成肖像夹具补充 runtimeV2/cache 离开和返回战斗后的 `visible`/`active` 与 placeholder 最终可见性断言；原有逐属性及setter顺序等价、默认关闭和单独开启旗标继续验证。

首次普通 Node test worker 和 Python 子进程在沙箱中报 EPERM；无隔离模式运行 Fengari，获自动审核许可后仅为生成夹具运行 Python。新树最初缺 luaparse，复用已安装依赖，无安装。组合回归首次发现顶层读取主题破坏 cards-only/menu-only 测试，已改为战斗旗标内延迟读取；另为既有 palette 用例生成其要求的主题后重跑。

## 尚未验证

未执行全CI、候选写入/读回、官方导入、真实 ready、PC或手机实测。缓存夹具不模拟原生引擎跨场景资源回收，未独立复现用户原90%资源丢失率。TASK-89两项验收继续未完成。
