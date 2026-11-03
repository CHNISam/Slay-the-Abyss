# PR477：Windows CRLF 负控锚点修复

基线提交 `b7a4857aa7f990fde144fb2cda062b4548ee993d`。原托管 Windows rules11/13 作业 `125634902915` 为245/246通过，唯一失败是 `retained nested promise after throw` 负控多行锚匹配0而断言2；其余六项意图测试通过。完整失败日志由主控保存在 `/workspace/shared/intent-geometry-review/monitor/job125634902915.log`，不是基础设施豁免。

## 变更

仅 `tests/intent-geometry-cache.test.mjs`：多行regex的两个 `\n` 改为 `\r?\n`。五个原负控分别以 LF、CRLF 源文本执行，不改写磁盘生产文件；原先两处精确匹配、Lua非零、指定失败消息及源文件未变断言全部保留。其他四个锚不跨行；文件中的其余换行是变异替换文本或临时Lua入口内容，不承担源锚匹配。

## RED → GREEN

命令均为 `node --test --test-concurrency=1 tests/intent-geometry-cache.test.mjs`：

- 先新增双格式场景但保留旧regex：11/12通过，唯一失败是CRLF的原负控，仍为 `0 !== 2`，见 `red.log`。
- 修复后12/12通过：两个原正控和五负控×两格式，见 `green.log`。
- `node --check tests/intent-geometry-cache.test.mjs`、`git diff --check`通过。
- 生产 `abyss_battle_render_actors.lua` 无diff，SHA256仍为 `f535f2d14b15e8af3fe49bf3e3af45900b4cae4fcc8f8ccb29a407cf6fdcc6d9`；其他测试/玩法/配置/阈值/超时均未改。

日志只规范化行尾空白。没有重跑旧CI、没有宣称Windows托管新SHA已绿；这里只是本地Fengari对真实LF/CRLF源文本的验证。未推送，交主控独审并更新原PR后验证新的精确SHA完整CI。此次不更改Backlog或手机验收状态。
