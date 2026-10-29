---
id: TASK-53
title: 查清离开后丢进度并核实恢复能力
status: Blocked
assignee:
  - '@Furinya'
created_date: '2026-10-24 15:48'
updated_date: '2026-10-28 14:46'
labels:
  - post-release
  - platform-capability
  - competition-deferred
  - persistence-dependent
dependencies: []
references:
  - docs/TOOLCHAIN.md
  - src/lua/abyss_ui.lua
  - src/lua/abyss_game_ui.lua
  - 'https://act.mihoyo.com/ys/ugc/tutorial/detail/mhzcw29qjjma'
priority: medium
type: feature
ordinal: 91000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
用户2026-10-28确认当前无奇匠Lv.4能力，本次比赛不做任何依赖持久Save的恢复、跨局进度、解锁、历史资格、Neow上局条件及A Note For Yourself跨局留卡。不升级账号、不增加服务器/存储后端或其他绕过方案；保留未来候选及原问题证据，不设新日期。短暂重连与离开重进分清，同局内存状态/回滚不在削减范围。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 核对并记录官方断线重连、局内存档能力及账号实际权限，区分短暂重连和离开后重进；现有资料所述Lv.4仍需官方复核。
- [ ] #2 能力可用时补齐恢复，并以同一候选实测断网后关键进度一致；不可用时记录限制和依据，不能把完成记录当作恢复功能通过。
- [ ] #3 不为本项升级账号，不阻塞10月30日首投，不改现有必过里程碑。
- [ ] #4 未来另行授权后核对Boss已见历史、跨局Boss资格和历史provider；比赛当前策略须明确，不能声称平台已经全解锁或要求持久化后端。
- [ ] #5 未来能力具备并另获授权后，再评估跨局留卡、Neow上局历史、胜利资格/解锁和恢复；当前不伪造provider、默认历史或存储，不作为比赛必做。
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-27队列复核：补齐有效负责人Furinya；Low候选仍不占当前冲刺，不因指定负责人自动启动新功能。

2026-10-28用户确认范围变更：当前比赛只覆盖第一幕、第二幕，优先前10分钟体验；第三幕/隐藏第四幕/真结局及依赖退出续玩、跨局进度、历史解锁或跨局留卡的内容退出比赛必做，保留为无新截止日的未来候选。四职业及已批准原创角色要求不变。同局跨房间、第一幕到第二幕的资源与随机流、内存快照/回滚和本局结算保留；源码/候选/平台/实机仍分层，未完成状态不因范围调整改变。

PR #304记录退出丢进度风险；跨局持久恢复仍为未来事项，同实例恢复问题不得忽略。

PR #304：手机试玩短暂离开后丢进度，是否同实例、重建或断线未知；源码缺持久恢复，PC具体表现未测。分别记录同实例恢复与跨局恢复。
<!-- SECTION:NOTES:END -->
