---
id: TASK-33
title: M4 可选：双人合作联机可行性 Spike
status: To Do
assignee: []
created_date: '2026-10-23 07:34'
labels:
  - P2 optional coop
milestone: m-5
dependencies:
  - TASK-3
references:
  - docs/SCOPE.md
  - docs/TOOLCHAIN.md
priority: medium
type: spike
ordinal: 45000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
官方多人房间、玩家分组、客户端Lua与服务器节点图通信仅为能力线索，不等于卡牌联机已实现。借鉴Slay the Spire 2合作体验，调查成熟方案的来源、许可与适配性。仅有限技术验证，执行前确定时间盒和退出条件，到期如实给出NO-GO或证据不足，不开发完整联机。仅资源允许时开展，不阻塞M1～M5必要交付、M4关口及投稿；M1保持唯一主冲刺，2026-10-30内部硬线不变。不提前改正式单人Lua架构或STS1核心数值规则；实验代码和存档隔离，MILIASTRA_ALLOW_LIVE_WRITE=0，不修改正式存档。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 隔离副本中两个真实玩家/客户端共同进入并分别操作同一场战斗，保留两端录像、日志、服务器记录、候选版本/hash及复现步骤；仅入房或模拟双端不能算通过
- [ ] #2 验证客户端命令、服务器权威结算、双方状态同步及去重，覆盖重复/过期/乱序消息、同时输入和网络延迟，记录一致性及平台限制
- [ ] #3 形成并实测双方卡组、手牌、能量、血量及共享敌人、地图、随机数的归属/可见性矩阵，验证回合协调与一致结果
- [ ] #4 真实双端验证掉线/退出、继续或终止策略及UI恢复，明确重连支持边界，不宣称未验证能力
- [ ] #5 交付GO/NO-GO、真实双人证据、成熟方案可复用性、单人Lua必要改造量、分项工时与风险；证据不足不得GO。实验不进入正式存档或提前修改单人架构/STS1规则，不成为M4及投稿前置
<!-- AC:END -->
