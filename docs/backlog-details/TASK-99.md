# TASK-99：重跑继承作业的收据识别

## 触发与范围

基线为 develop `67493f1a707dd5332788b4081adb3c3ce6e46761`。本任务接续 #501 暴露的收据兼容缺陷，不接管 TASK-98 的规则设置、其他 PR 或发布。

[Quality run 41759592870](https://github.com/CHNISam/Slay-the-Abyss/actions/runs/41759592870) 仅重跑失败作业后，`rules (1/13)` 从 job `126344253028` / attempt 1 复制为 job `126356479470` / attempt 2。执行起止、runner、labels 和完整 30 个 steps 相同；复制记录的 created_at 晚于 completed_at，runner_group_id 从 0 变为 null。原始 checkout artifact 仍为 `13291078495` / `quality-41759592870-1-check`。

当前 collector 及 #502 新增的 Full 发布器均直接绑定最新记录的 attempt，导致合法继承被拒绝。不能通过随意寻找旧成功收据解决。

## 修复合同

- 仅对 created_at 晚于执行结束的首分片记录解析继承；逐个相邻 attempt 回溯，不越过缺失、失败或不同执行。
- 每段要求唯一记录、不同 job ID、相同 run/head、递增创建时间，以及相同有效执行时间、runner、labels 和完整 steps。
- 普通执行与历史稀疏证据仍用自己的 attempt；真实重跑必须用新的收据。不会改写原始 GitHub jobs 或 checkout。
- collector 与 publisher 共用收据关联校验；各自仍检查完整作业、最新失败优先、run/currentRun、SHA/base/tested/parents 和 artifact 身份。
- publisher 的 allowRunningAggregate 保持原窄边界：仅允许当前 check 作业正在发布 Full 状态；正式交付判断仍要求全部完成。
- 缺少继承信息、未知时间格式、labels 顺序变化或历史缺页保守拒绝。该校验基于可信 GitHub 响应，不为任意手写 JSON 提供来源认证。

## 本轮验证

Node v24.22.1，`node --test tests/delivery.test.mjs tests/full-quality.test.mjs tests/auto-merge.test.mjs`：81/81 通过。

`backlog doctor`、`npm run verify:backlog`、`npm run check:guidance` 与 `git diff --check` 均通过。任务创建与认领使用 Backlog CLI，task:pick 返回 ALLOW；未接管仍在进行的 TASK-98。

新增正反例覆盖 schema 2/3、PR/push、多层继承、缺失/歧义/变化历史、真实重跑、最新失败及错误身份。实际 main → collector → publisher 的本地模拟通路覆盖继承成功，以及缺前序记录时不下载、不发布 success。原版 3df397a 配相同新增测试有 4 项失败；修复后 delivery/full-quality 两组 51/51 通过。

对上述 #501 原始完整 GitHub 快照回放，补丁版 collector 与 verifier 均为 merged_passed，保留 run attempt 2、receipt attempt 1 和 54 条原始作业。最新失败、缺旧执行、step 变化、错误 SHA、错误父提交、末次 run attempt 变化六项负对照均为 merged_pending。原始输入逐文件摘要未改写。下载的 ZIP SHA256 为 `4da5f153be6f8c048214e7787f222c61ecfc71fda62cd122227130eafb2a9261`。

独立只读复审覆盖继承链、publisher 调用边界及正反例，无阻断发现；独立运行两组 51/51。吸收到本基线后增加 auto-merge 回归，总计 81 项。

以上是本地补丁验证，不代表当前远端主线已经通过该继承场景，也不是整库 Quality 结果。当前精确 HEAD 的完整 CI 由本 PR 统一运行；任务在实际合后 squash SHA、父提交、源码树及其独立 push Quality 验证完成前保持 In Progress。
