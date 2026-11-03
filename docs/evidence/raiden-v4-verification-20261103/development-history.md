# 开发期原始失败与纠正

cwd：`F:\New folder\.worktrees\raiden-v4-verification-20261103`；Node `v22.22.1`。

## 依赖与准备

- `node --version` → `v22.22.1`；`npm --version` → `10.9.4`。
- `require.resolve('fengari')` → `F:\New folder\node_modules\fengari\src\fengari.js`。
- 早期同一依赖探针还查询了项目不依赖的 `fengari-interop`，输出 `MODULE_NOT_FOUND`，探针 exit 1；实际执行入口只需已存在的 `fengari-node-cli`。没有安装依赖。
- `npm run build:data && npm run build:ui` 初次成功，未单独计时；收据重放中的对应实际脚本分别130/894ms。

## 第一次新增测试：测试预期错误

命令：`node --test --test-concurrency=1 tests/raiden-v4-verification.test.mjs`

```text
public_commands: not ok, duration_ms 10652.0459
  TRACE cap R=2 gain=2 eye=2 hp=487 energy=0 block=2 replay=unchanged
  PASS paid commands cap resolve at two; eye establishment, refresh and replay are physical-play bounded
  raiden_v4_public_commands.lua:5: value: expected 2 got 1
  raiden_v4_public_commands.lua:98: in local 'fn'
rollback: not ok, duration_ms 6121.0187
  PASS Q late refuse restores complete graph/resources/ledgers; same-ID retry then replay
  PASS Q late throw restores complete graph/resources/ledgers; same-ID retry then replay
  raiden_v4_public_commands.lua:5: value: expected 2 got 1
  raiden_v4_public_commands.lua:61: in function readyNormal
tests 2, pass 0, fail 2, skipped 0, duration_ms 16987.4198; exit 1
```

假设：第二次和第三次E刷新雷眼时旧眼依然有效，刷新后各触发一次追击；Q随后再消耗一次，因此Q后应为1而非2。若Q前后探针不符合2→1，则不能采用这个修正。

最小探针加载测试夹具 `loadfile('tests/lua/raiden_v4_public_commands.lua')('fixture')`，依次执行 `readyQ()`、公开 `play(Q)`、`Run.endTurn()`，实际输出：

```text
before Q  3  2  2     # resolve, eye.uses, eye.ends
after Q   0  1  2  3  # resolve, eye.uses, eye.ends, musou.uses
after end 1  1  3     # eye.uses, eye.ends, musou.uses
```

与冻结RD2-003“不追击自身新建时的命中”（非已有眼刷新豁免）、RD2-004“真实伤害后的雷眼追击”一致。修正独立测试算术：Q后眼1，下一回合两普攻11+9=20；完全格挡分支保留眼1。能量拒绝标记按已有公开合同使用 `insufficient_energy`。生产文件未改。

探针最初一次 PowerShell 命令使用错误的 `\"` 转义，Shell ParserError、Lua未执行；随后用单引号变量和独立Lua参数成功运行。此Shell调用错误不计为产品红例。

## 修正后新增测试

同一精确Node测试命令：

```text
public_commands: ok, duration_ms 10277.8911
rollback: ok, duration_ms 10143.8414
tests 2, pass 2, fail 0, skipped 0, duration_ms 20588.0679; exit 0
```

此后增加公开路径的跨回合R=4/6/6上限断言、成功诊断输出，由 `results-initial.json` 重新验证（2 pass，28378ms墙钟）；末次回滚夹具加强及最终验证见文末。

## 首次完整收据：负对照诊断匹配错误

命令：`node docs/evidence/raiden-v4-verification-20261103/replay.mjs`。

- 2次构建、新增2个Node测试及7个已有Lua入口全部 exit 0。
- 不清零每回合愿力计数的退化确已exit 1，但更早在公开累积上限组报 `expected 4 got 2`。重放器错误地寻找较晚的 `expected 0 got 2`，因此标 `FAIL` 并整体exit 1。该首轮耗时88.361秒，收据原样保留在 `results-initial.json`。
- 同轮预览偷扣眼和回滚残留愿力负对照均命中指定断言，耗时4603/1942ms；愿力重置负对照耗时2382ms。
- 只修正取证脚本寻找的诊断至实际更早的独立断言；没有改变测试断言。
- 新增 `--negative-only`：先验证原收据普通命令全PASS、源SHA与所有已记录测试/生产输入SHA一致，然后只重跑3个负对照。3/3 `EXPECTED_RED`，2339/5195/1994ms；整体9.573秒、exit 0，见 `negative-controls.json`。

以上两类初始失败属于测试算术和证据诊断匹配，不是已确认的生产缺陷；真正的三项退化在独立子进程被有效杀死。未删断言、跳过用例、放宽阈值或重写冻结输入。

## 末次走查：加强雷眼已经消耗后的晚失败回滚

原晚失败边界把敌人HP置1，主伤害会直接击杀；此时无存活目标，雷眼不消耗。因此原测试虽验证整个Run图，但未证明“已经消耗的雷眼次数”也能还原。

将受控致死HP分别设为Q=18、强化普攻=11。冻结主伤害16/9留下2HP，真实雷眼追击扣2并完成击杀；故障钩子在真实奖励后额外断言眼次数分别为1/0，再拒绝或抛异常。回滚必须恢复原眼2/1，且所有其他原图边/账本也保持。未改生产文件。

命令：`node docs/evidence/raiden-v4-verification-20261103/replay.mjs --focused`

- 新增Node测试最终2 pass / 0 fail / 0 skip，墙钟21853ms（Lua公开组10672.6492ms，回滚组10958.6708ms）。
- 三负对照均 `EXPECTED_RED`，2459/5816/1965ms。
- 总32.131秒，exit 0；最终当前测试SHA与完整输出见 `results.json`。
- 7个既有入口及生产源码未变，引用初轮收据，不重复整套测试。
