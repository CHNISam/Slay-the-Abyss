# Snecko Eye / Preserved Insect 独立向量续办

基线 `ca838ef`，独立工作树 `/workspace/m3-relic-vector-followup`，2026-10-31。主 PR436 候选与旧 golden 不变；本续办包含一项真实生产边界修复和两项独立来源向量。没有调整平衡、池、概率、预算、Backlog 或远端。

## 原版依据与真正的 RED

从 `https://codeload.github.com/aeubanks/sts/zip/319009d5df0a82d9fb0f23cc22322286c6a87ec0` 读取固定镜像，核对 `SneckoEye`、`ConfusionPower`、`PreservedInsect`、`DrawCardAction`、`AbstractPlayer.draw`。五份文件的原始 SHA256 记录在新 fixture；不把镜像源码认证说成原版 PC 二进制认证，Java 方法体不入仓。

昆虫标本源操作次序是先把整数最大 HP 转成 binary32，再乘 binary32 的 `1-.25`，结果转整数；仅在 eliteTrigger 且当前 HP 更高时设置当前 HP，最大 HP 不变，也没有最小 1 HP 钳制。生产原先只在乘法后转 binary32，漏掉输入转换。公开 `Run.obtainRelic` + `Run.startCombat` 的受控合法目录 HP `16777217` 给出 `12582913`，独立 Python `struct.pack/unpack` 源模型给出 `12582912`。标准新 wrapper 的精确测试先失败，日志 `/workspace/cloud-reports/m3-insect-vector-red.log`。`validate-data.mjs` 敌人 HP 仅要求正整数，HP range 接受至 2147483647；公开生产战斗也实际接受该输入。该边界不是当前默认敌人的实际 HP。

最小修复只在 `abyss_relic_hooks.lua` 原乘法输入增加 `S.float32(enemy.maxHp)`，完整保留原乘法、截断、资格与当前 HP 条件。不是用修后生产函数生成预期。

## 新证据覆盖

`tools/oracles/sts1_snecko_insect.py` 只用既有独立 Python XS128、Java48 shuffle 模型、固定原版注册成本与 Python IEEE binary32。预期不调用生产 RNG clone、生产 float32 或本地牌定义。完整注册、两个独立模型及新生成器的原始字节 hash 入 fixture，并用精确 LF 属性保护。新增真实 Git `core.autocrlf=true/core.eol=crlf` clone 验证：未固定对照文件确实转 CRLF，认证模型/输入字节不变，原 `--check` 成功。

- Snecko：种子 `0/1/3/42`，真实取得遗物/Swift Potion，公开开始战斗首抽 7 张，再公开用瓶后续抽 3 张。独立全牌组 shuffle 确定身份；每次 Confusion 的 bound=3、返回值、两个64位 word 及 counter 前后完整比较。完整核每张牌的持续战斗成本、临时本回合成本、是否修改与 freeToPlayOnce；X费和不可打出牌不消费随机。后续抽牌的预置临时零费/free-once 是明确受控输入，真实抽牌仍由公开用瓶触发；种子3的 Defend 同值 roll 保留本回合0费，负费保留 free-once，非负费清除 free-once。没有声称自然取得或自然产生这些预置临时费用。
- 昆虫标本：11个最大 HP（1/2/3/5/50/101/16777215/16777216/16777217/16777219/2147483647），各核 normal/elite/boss、显式 eliteTrigger=false 与 normal+eliteTrigger=true；额外真实取得 Neow's Lament 的当前 HP1 场景，核不抬升低 HP 及最大 HP1 可变0，无虚构下限。共57个公开战斗入口，按最大 HP 切成11个默认30秒短 fixture。
- 旧 `common_relic_final.lua` 11项通过（2466ms），含原小 HP 昆虫标本；旧断言与 golden 全保留。

公开 explicit-ID 开发战斗有明确入口边界：cardRandomRng 使用 raw run seed，shuffle 使用 seed+floor1；模型按该公开路径建表，不外推正式 source-room 种子传播。早期新测试的错误药水 ID 和 shuffle seed 预期已定位为 fixture 错误，不记成生产 RED。

## 复现与状态

```sh
npm run build:data
npm run build:ui
node --test --test-concurrency=1 tests/snecko-insect-vectors.test.mjs
node scripts/test-lua.mjs tests/lua/common_relic_final.lua
```

状态：Snecko 独立验证 `TEST_ADDED`；昆虫标本输入 binary32 边界 `PRODUCTION_FIXED`，有源依据的公开 RED→GREEN。最终标准测试17/17通过（42059ms合计，各Lua约1.3–4秒，默认30秒不变），含真实CRLF checkout。JS语法、Python编译、`check-syntax`、`git diff --check`通过。完整标准向量日志 `/workspace/cloud-reports/m3-snecko-insect-green.log`。这不是自然长跑、官方 LuaHost 或 PC/手机证据，不关闭全部153遗物效果与全组合 AC。
