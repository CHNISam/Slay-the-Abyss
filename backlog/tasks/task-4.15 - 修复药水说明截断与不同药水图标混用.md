---
id: TASK-4.15
title: 修复药水说明截断与不同药水图标混用
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-30 21:58'
updated_date: '2026-10-31 15:48'
labels:
  - playtest-20261030
  - p1
  - grok
milestone: m-5
dependencies: []
references:
  - docs/backlog-details/PLAYTEST-20261030.md
  - docs/backlog-details/MOBILE-QA-20261029.md
parent_task_id: TASK-4
priority: medium
type: bug
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Owner截图：肌肉药水描述末尾在「人工」附近截断；两种不同药水在顶部槽位几乎相同图标，容易误用；开局另有HP显示成80/8的裁剪疑点。须区分素材区分度、源字符串、文本布局和实际状态，无需提前规定实现步骤。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 肌肉药水及其余长描述均完整显示，文本真实含义和使用/丢弃控件不被裁剪。
- [ ] #2 不同药水可通过正确的图形/语义可靠区分，保持原有效果和点击确认规则。
- [ ] #3 顶部生命等数值完整显示；裁剪问题与真实数值异常作出区分。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
本轮仅针对截图HP裁剪增加map/node数值框横向余量，保留字号/autoSize/数值规则与战斗框；先核对真实GIL旗标，再验证最终布局邻距及真实宿主字符串，实机待复测不Done。

2026-10-31：从7adc71b6独立短修，先以实际生成字号/换行容量和药水重复视觉证红；仅修药水弹层与区分语义，不改HP、药水规则或美术开关；定向回归并交主线程独审，设备验收保持未完成。

2026-10-31 接续PR433全池辨识：复用既有每槽label，固定唯一双字中文短名竖排与瓶图左右并列，保留圆壳/tint和五物理槽点击。严格检查药水主目录与职业可得池短名无碰撞，瓶/标签矩形无交叠、原生子控件数量不增加、槽交换/空槽及旧tap行为。独立树pc-potion-identity，仍需同候选设备可读性复验。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
原生截图80/8裁剪继续按真实问题处理；Simulator同源码80/80完整不能冒充设备通过。已只读回读ba2c实际GIL：battle/player、map/resources/hp、node/hp均autoSize=true、font18/min14，重复启用无效。本轮仅nativeNode.topBar.hp由[-540,316,64,40]改[-536,316,80,40]，供map/node同源复用，保留原生autoSize/字号/HP规则和战斗68宽。最终布局左右与生命/金币图标留4/5间隔，真实宿主80/80及88/88字符串不变。2项定向通过；此为截图裁剪针对性余量修复，未宣称官方原生已修或药水其它项完成，AC不勾。

2026-10-31 独立药水切片：真实Host红例确认肌肉药水弹层40高标题框侵入仅20高标题区。按实际文字框预留标题/操作高度，正文增加一行末尾余量；恢复现有Theme.icon.potionTint读取，不更改主题配色、HP或药水规则。新增全部药水说明、5物理槽边界、人工制品末尾完整性和同形strength/fire配色断言。定向药水8/8通过；扩展全部药水边界1/1通过。初次两项测试错误（主题颜色已为table、换行分隔文本）已修，保留红例事实。PC/手机真实文字渲染和同形同色flex/strength等仍未验，AC1/2/3保持未勾，不宣称设备裁切彻底解决。

2026-10-31 PR433后补全同形同色辨识：保留瓶图/tint，复用已有label显示唯一双字中文短名（力量/肌肉、敏捷/速度），槽内竖排与瓶图左右分离，原生控件数不增加。42种定义和ironclad/silent/defect/watcher/shared五套来源池无碰撞；五槽全部normal/hover/pressed/disabled状态、满名弹层、空槽、槽替换旧触点均覆盖。2ed旧渲染器副本运行新增测试按预期失败在caption visibility；当前药水组合Node10/10及临时能力2、发现/自动药水6、持续效果3组Lua通过，完整效果断言保留。药水专属图形不足由可读短名补足，仍未候选写入/官方导入/真实ready或PC手机设备验收，不勾AC。

306976b4双字竖排方案在独审时发现不符合原生每行40高预算，已撤回该显示方案。接续改唯一单字徽记，保留双字短名与弹层全名；42显示徽记无碰撞（能/量、钢/甲明确分开），每槽一行14x40，瓶图矩形和五槽热区不变。重建UI后全池2/2、三套完整说明2+6+3通过；设备仍未验。
<!-- SECTION:NOTES:END -->
