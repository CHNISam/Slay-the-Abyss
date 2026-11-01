# 草史莱姆测试原型 r02（来源与初次接入记录）

> 下述单池/额外同类回退描述是初次接入历史，不是当前运行时。当前显式 monster-enabled 候选按 actor.id 独立绘制所有实例，详见 `docs/art/MULTI_MONSTER_DRAWINGS.md`；默认五类美术开关均关闭。

这是源图衍生的**可用性测试原型**，不是精修终稿，也不代表42种新画怪物全部完成。按既有原生编辑器导出JSON/Lua，以597个基础图形（534三角形、63椭圆）接入真实战斗头像；不把PNG上传或原图库换绑冒充新图。

- 本PR同时纳入已审阅的四项源图归档；源图与完整提示词原先发布于[源图归档PR355](https://github.com/CHNISam/Slay-the-Abyss/pull/355)，固定Git ref `58d7046a99a30d8b04894f87040ea62e6f465ed3`、路径 `art/monster-benchmarks/genshin-v1/dendro-slime/`；不假定独立归档PR已合入develop；合并后仍仅在上述单一路径保存源PNG，不建立第二份副本。精确源图/提示词及原生文件SHA见 `provenance.json`。怪物开关启用时仅依赖本PR内原生JSON/Lua及注册表，不下载或读取归档PNG/提示词。
- `data/presentation/native-monster-art.json` 是逐属性原生槽位注册表，106×106；XYZ旋转、RGBA、顺序保持导出值。`IMAGE_TYPES`省略时沿用固定编辑器的`stretch`默认值。
- 显式怪物构建生成并部署含图元的 `abyss_monster_art_data`（默认关闭只生成空桩）；启用时仅一个控件池，在已有、无蒙版且位于敌人之前的`topBar`容器内，不增加满额的战斗stage直接子控件。597图形+10组+2容器=609新增控件；减去宿主局部原点以保留战斗坐标。敌人的命中、护盾、浮字和信息仍在新图上方。
- 首个**当前可见**`acid_slime_m`（任意显示槽）替换图库头像；额外同类实例仍显示原图库，不声称全副本替换。没有该敌人、原生API不支持、写入失败、隐藏/结束/重启时恢复或保留图库。
- 使用既有CardDisplay原生写入，战斗反馈同步呼吸/攻击/受击/死亡的位移、缩放、闪色及透明度；不改命中框、HP、状态、意图、AI或RNG。
- 当前生成配置/美术回执为 `schemaVersion=2`，严格五键；旧四键 `schemaVersion=1` 只由对应历史源码解释，当前入口拒绝并全关闭，不冒称回执兼容。
- 沿用候选开发开关 `monsters` / `--art-monsters=true|false`，默认 false；全关闭构建不加载草史莱姆数据或预分配绘制池。此轮新画候选必须显式 `--art-monsters=true`，其余四类保持 false。开关开启不授予发布权限；原型仍需原生与设备验收。

`authoring-report.json`保留制作完成时的待审状态；后续审阅与Owner候选接受以`provenance.json`及registry为准。

源图Owner已接受；r02由集成人审为可辨识且允许单个测试原型。叶片平面与身体光照明显简化；Owner于2026-10-30 03:22:27 UTC明确接受r02视觉测试候选；**不等于精修终稿或实机批准**，`nativeFinalApproved=false`。真实官方导入、PC/实体安卓、性能和同候选RC容量均未验证；不得据此发布或批量放行。

纯图形独立Lua导出含固定Primitive的MIT/LiuL基础运行时，沿用[许可原文](../../../cards/shared/licenses/PRIMITIVE-SHAPE-MIT.txt)及仓库第三方声明；游戏只消费静态槽位，不挂载导出脚本或其实例化生命周期。

身份为既有原神草史莱姆，不宣称完整自有IP或第三方IP再许可。平台项目用途与商用许可分开。失败的571控件历史草稿没有接入。
