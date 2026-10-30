# 草史莱姆单池测试原型 r02

这是源图衍生的**可用性测试原型**，不是精修终稿，也不代表42种新画怪物全部完成。按既有原生编辑器导出JSON/Lua，以597个基础图形（534三角形、63椭圆）接入真实战斗头像；不把PNG上传或原图库换绑冒充新图。

- 本PR同时纳入已审阅的四项源图归档；源图与完整提示词原先发布于[源图归档PR355](https://github.com/CHNISam/Slay-the-Abyss/pull/355)，固定Git ref `58d7046a99a30d8b04894f87040ea62e6f465ed3`、路径 `art/monster-benchmarks/genshin-v1/dendro-slime/`；不假定独立归档PR已合入develop；合并后仍仅在上述单一路径保存源PNG，不建立第二份副本。精确源图/提示词及原生文件SHA见 `provenance.json`。正常构建仅依赖本PR内原生JSON/Lua及注册表，不下载或读取归档PNG/提示词。
- `data/presentation/native-monster-art.json` 是逐属性原生槽位注册表，106×106；XYZ旋转、RGBA、顺序保持导出值。`IMAGE_TYPES`省略时沿用固定编辑器的`stretch`默认值。
- 普通构建自动生成并部署 `abyss_monster_art_data`；仅一个控件池，在已有、无蒙版且位于敌人之前的`topBar`容器内，不增加满额的战斗stage直接子控件。597图形+10组+2容器=609新增控件；减去宿主局部原点以保留战斗坐标。敌人的命中、护盾、浮字和信息仍在新图上方。
- 首个**当前可见**`acid_slime_m`（任意显示槽）替换图库头像；额外同类实例仍显示原图库，不声称全副本替换。没有该敌人、原生API不支持、写入失败、隐藏/结束/重启时恢复或保留图库。
- 使用既有CardDisplay原生写入，战斗反馈同步呼吸/攻击/受击/死亡的位移、缩放、闪色及透明度；不改命中框、HP、状态、意图、AI或RNG。
- 编辑器脚本布尔参数`nativeMonsterArtEnabled=false`是关闭回退开关；默认true仅表示该测试原型可用，不授予发布权限；运行时关闭仍保留预分配池，不能冒充静态负载减少。

`authoring-report.json`保留制作完成时的待审状态；后续审阅与Owner候选接受以`provenance.json`及registry为准。

源图Owner已接受；r02由集成人审为可辨识且允许单个测试原型。叶片平面与身体光照明显简化；Owner于2026-10-30 03:22:27 UTC明确接受r02视觉测试候选；**不等于精修终稿或实机批准**，`nativeFinalApproved=false`。真实官方导入、PC/实体安卓、性能和同候选RC容量均未验证；不得据此发布或批量放行。

纯图形独立Lua导出含固定Primitive的MIT/LiuL基础运行时，沿用[许可原文](../../../cards/shared/licenses/PRIMITIVE-SHAPE-MIT.txt)及仓库第三方声明；游戏只消费静态槽位，不挂载导出脚本或其实例化生命周期。

身份为既有原神草史莱姆，不宣称完整自有IP或第三方IP再许可。平台项目用途与商用许可分开。失败的571控件历史草稿没有接入。

默认构建关闭此测试原型（data/presentation/native-monster-art.json 的 enabled=false），保持已有默认关闭美术与无绘图源依赖合同。只有显式将该构建配置开启并重建同 SHA 候选后才装配597图元；运行时 nativeMonsterArtEnabled 仍可关闭。独立主机测试使用隔离的显式开启配置，默认关闭分支仅检验空模块回退。未取得官方容量与设备通过证据前不默认启用。
