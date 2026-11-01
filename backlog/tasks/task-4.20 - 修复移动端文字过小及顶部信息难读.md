---
id: TASK-4.20
title: 修复移动端文字过小及顶部信息难读
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-31 23:38'
updated_date: '2026-11-01 00:16'
labels: []
milestone: m-5
dependencies: []
references:
  - >-
    https://gameaccessibilityguidelines.com/use-an-easily-readable-default-font-size/
  - 'https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html'
  - docs/backlog-details/TASK-4.20.md
  - docs/evidence/mobile-readability-20261101/
parent_task_id: TASK-4
priority: high
type: bug
ordinal: 135000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
用户转述真实玩家反馈：手机文字很小，尤其顶部一行，十六七岁玩家也看得费劲。默认阅读体验必须按游戏无障碍原则改善，不能以年龄、视力或手机配置解释问题。现已确认14–18设计单位字体、自动缩小至14、顶栏窄框及卡组计数20×14的根因。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 记录字号从主题、原生文本到移动端画布缩放的完整路径，区分设计单位与实际pt/dp。
- [ ] #2 增大默认关键文字，顶部生命、金币、楼层及卡组/遗物数量清楚可读；最长合法数字和窄屏下不靠缩小到旧字号掩盖空间不足。
- [x] #3 菜单、提示和正文保持清晰层次及足够行高，重要普通文本前景与确定背景的对比度达到4.5:1；小卡面与完整阅读入口分别核验。
- [x] #4 新增回归覆盖字体回退、顶栏重排及长文字，不损失状态信息、触屏入口或原有点击安全规则。
- [ ] #5 同候选实体手机和PC核验实际字号、阅读距离、裁切及可放大阅读；官方及设备证据未取得时不宣称已达完整无障碍标准。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 固定当前字体链与真实失败断言。2. 在现有主题内提高默认关键字号并重排顶栏和菜单，保留背景与卡牌规则。3. 核对重要文字对比度和完整阅读入口，补相关回归及离线预览。4. 独立复审和精确提交完整CI后正常合入develop；实际设备验收单列。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-11-01 源码切片04e3a75e：正文24、标签22、提示20、关键HUD28、完整阅读28设计单位；面板标题34、Main主视觉44。关键文字min保持所选字号，顶栏/药水/遗物4项分页/长文及底部文字框同步重排。Root相关9文件53/53、末尾奖励标题修复后4文件22/22（有重叠复跑）与原实际文字碰撞守卫通过，工程/原生替身合同通过；独立296组不透明按钮文字对比均>=4.5。九场景Host+浏览器预览无裁切，非官方或实体手机证据。AC2只覆盖999/999、99999、三位牌堆/卡组压力，尚未证明所有两幕自然可达数值极限，因此整条不勾；AC5官方字体、设备pt/dp、阅读距离、200%文字放大及完整AA仍未验。背景/美术数据/音效/动效/游戏规则不变。
<!-- SECTION:NOTES:END -->
