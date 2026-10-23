# Backlog task ID migrations · PR #114

The GUI branch and develop independently allocated the same IDs. After merging
develop `7f12445359a15c90eb747518c97b0b7ec4158166`, the native
`backlog doctor --fix --yes` repaired both remaining duplicate groups. Task
content, status, assignee, acceptance criteria, and history were preserved; only
the duplicate filenames and frontmatter IDs changed.

| Historical context | Current ID | Task |
|---|---|---|
| TASK-38 in PR #110 and its discussion | TASK-41 | 防止中断触摸误用药水 |
| TASK-38 on the GUI branch | TASK-38 | 手机触屏游玩适配与完整流程验收（优先排期） |
| TASK-39 in PR #111 | TASK-39 | 拒绝空文件或目录冒充验收截图 |
| TASK-39 on the GUI branch | TASK-42 | 电脑鼠标键盘游玩适配与完整流程验收（优先排期） |
| TASK-40 in PR #112 and its discussion | TASK-43 | 防止过期触摸结束回合或跳过奖励 |
| TASK-40 on the GUI branch | TASK-40 | 手柄游玩支持（后续适配，待设备验证） |

The doctor chooses the retained task deterministically; it retained the
controller task as TASK-40 and moved the battle action task to TASK-43. Historical
PR text is interpreted using the context above, rather than the old number alone.
The doctor found no textual references to duplicate IDs in Backlog Markdown;
the repository documentation search found no affected TASK-38/39/40 references.
A second `backlog doctor` found no duplicate IDs, self dependencies, or cycles.

This is an identity repair only. It does not complete any acceptance criteria or
claim platform import, UI acceptance, or game playtest success.
