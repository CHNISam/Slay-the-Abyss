# TASK-81：按平台汇总 Fast 预算

2026-10-29，基线 `a5da67aaaf018bfd6d92e32af5c7bcd9a0866a59`。

只修正影响计划的估算聚合：两台平台 VM 各自串行执行完整选集，取 Windows 总和、Linux 总和的较大值。旧算法把每份文件较慢的平台耗时相加，可能构造出不存在的平台临界路径。选测依赖图、完整 JS/Lua 集合、Lua 共用权重、未知文件权重、180000ms 回退阈值和初始化余量全部沿用。超预算 Full 也输出双平台估算，便于判断瓶颈。

合成边界证明：两份 JS 在 Windows 分别耗时120000/10000ms，在 Linux 分别10000/120000ms，另有50000ms Lua。旧估计290000ms，改后两平台各180000ms，完整两份 JS 与 Lua 全部保留。任一平台增加1ms仍必须 Full；混入未知输入或核心 combat 输入仍 Full。实际Required Check的Bash对失败、取消、跳过、缺失执行与影响计划全部拒绝。

## 真实回退核查

从 GitHub 下载本次原始 `ci-impact` artifact，核对 run SHA、attempt 和事件；没有从任务旧报告推断。

| run | head SHA | attempt | 结论 | 原始回退原因 | 本次是否改变 |
| --- | --- | --- | --- | --- | --- |
| [40866923323](https://github.com/CHNISam/Slay-the-Abyss/actions/runs/40866923323) | 1cdee208d40c163871c5c4c07fdd420b6cbf2336 | 2 | success | 未建模的Backlog归档/资料/证据输入 | 否，继续Full |
| [40861929035](https://github.com/CHNISam/Slay-the-Abyss/actions/runs/40861929035) | 841a5740be793e3c7ccfb7eeb405ef08541654c8 | 1 | success | combat/run高风险核心输入 | 否，继续Full |

两份artifact的`sha`分别为合成merge SHA `3cd0a6682727ba8243b542118e7615809836c05a`、`be978b2e76bc3ee3876b0a81db1ab894387bb021`，不混同head SHA。原始下载与聚焦日志保存在本工作树 `.artifacts/impact-40866923323`、`.artifacts/impact-40861929035`、`.artifacts/ci-impact-focused.tap`。

当前基线的单独 `tests/ci-impact.test.mjs` 改动仍选出73 JS+1 Lua；旧估算772805ms，双平台估算771466/617863ms，继续Full。未删去动态发现测试以制造Fast。两个历史样本均没有因本修正转Fast，不能声称已取得实际耗时改善。

本轮Fast自然PR样本数0；P50≤5分钟/P90≤10分钟仍未验收。上述Full历史不同attempt与排队不能作为当前修正的性能样本；不据此判断完整回归≤30分钟达标。TASK-81保持In Progress，性能AC不勾选。
