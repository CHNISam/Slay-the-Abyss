# M3 整批离线实现与验证记录

任务范围是Backlog m-4的18项。生产范围仅岩系旅行者第一、二幕，背景策略保持；未发布、未创建版本Tag。本目录保存对应真实日志和独立复审，不替代任务AC或官方设备验收。

| 证据 | 实际结果与边界 |
| --- | --- |
| `combined-acceptance.log.gz` | 初始完整M3组合27/27：55事件四片、真实Host历史、33药水商店/普通奖励、独立同局药水链、UI来源等；为整合PR435前的源版本，最终CI另验 |
| `combined-engineering.log.gz` | 初始M3组合架构、质量、固定Luacheck、四变异杀死、原生合同通过 |
| `combined-focused.log.gz` | 原输入/来源专项13/14；唯一失败为严格中文测试读了原始“化学物X”，后643c3c0改为检查实际中文名称解析值；原失败保留 |
| `map-properties-10000.json` / `.log.gz` | 0–9999全10,000种子结构不变量通过、0错误；不冒充golden/祖先配额或平台证据 |
| `final-engineering.log.gz` | PR435与全部M3源码合成后完整工程门禁通过，固定Luacheck零新增、原四变异均被杀死、原生合同4/4 |
| `final-combination-focused.log.gz` | 最终组合首轮28/29，唯一旧帮助入口合同不符批准的隐藏规则；明确保留原失败，后续专项复验独立记录 |
| `final-normal-campaign.log.gz` | 精确干净源码243ae1b下seed2正常双幕胜利、seed3与42正常战败；三局均完成且无driver阻塞 |

[正常规则逐动作轨迹](../m3-normal-campaign-20261031/summary.json)记录源码身份、driver与三个策略的SHA256、UID、牌组、资源和随机流。三局只观察到75牌中的21张自然取得、18张实际打出，不能认定全75牌自然验收。旧源码0d8a9fe的胜利与真实driver失败保留在同目录的`source-0d8a9fe/`，不改写历史。

`m3-review-*-full.json`是各领域独立审查，UI最初两个Important问题在后续4304194/85db83e后解除；`m3-review-campaign-final.json`是必选遗物模态窄审，所提新增helper指纹已在243ae1b补全；`m3-review-ci-fixes-final.json`审查435的12文件修复；`m3-review-integrated-final.json`绑定243ae1b整合源码。审查结论仅覆盖各自明确的commit和范围，不能代替最终HEAD的完整CI。

[五场景实际模拟器静帧](../m3-visual-20261031/README.md)保留纹理OSS 403及assetWarnings，不能据此判最终美术或官方PC/手机通过。当前云环境没有本轮GIL候选、官方导入/ready、实体手机或官方容量读数；相关要求仍未验收。普通代码PR按原精确HEAD CI与交付验证器集成，发布仍由既有正式候选合同约束。
