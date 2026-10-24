# TASK-4.1 开发附件

任务首页只保留好理解的目标。下面保存原始技术要求、执行方案和已有证据；这些要求继续有效，开发时须一并遵守。


## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
PR117格挡徽标静态留白正确，但原反馈动画横向放大会再次压到生命条。真实Defend播放路径在5ms步进下复现负间距；只修动态边界，不改布局方向、数值或其他特效。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 玩家、普通敌人各列宽及Boss的格挡动画全过程不覆盖生命条，显示值继续读取真实格挡。
- [ ] #2 保留纵向反馈和其他特效；取消、完成及仅点击兼容宿主恢复正常状态。
- [ ] #3 增加真实控制器播放先红后绿回归并独立复审，当前head CI通过；不将坐标测试冒充实机视觉验收。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 用原Defend播放路径复现动画重叠。2. 最小限制格挡徽标横向缩放。3. 覆盖多敌人布局、动画清理与宿主回归，独立评审后提交PR。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
固定源cf5f03009真实Defend播放负控在hero/blockEdge与生命条产生重叠；最小修复只将格挡徽标横向scale固定1，纵向pop保留。候选Native Lua战斗50/50、Node布局/主题11/11、Python16/16通过，覆盖玩家、1至5敌人、Boss、嵌入与独立宿主、点击/拖动、吸收及取消清理。独立复审进行中；未执行本地npm全检或平台视觉验收。
<!-- SECTION:NOTES:END -->
