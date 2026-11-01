# 本地卡图打包入口

## 当前75张接入

Owner后续明确要求仅有源图的卡也全部接入。普通 `npm run build:native -- <base.gil> <new-output-directory>` 现在使用75张动态卡图路径，具体预算与待验范围见[当前美术接入](READY_ASSET_INTEGRATION.md)。`--native-card-art-count=0` 或 `--no-ready-card-art` 显式关闭卡图；背景/角色图仍按各自绑定处理。

PR356的两卡单静态池仍可明确选择：追加 `--native-card-art-registry=art/cards/traveler-geo/native-runtime-registry.json --native-card-art-count=1`。该路径不扩为75张，也不与动态池叠加。原registry与SHA保持不变。

## PR356历史有限接入记录（默认值已被上文替代）

2026-10-30：按 Owner“已有成果先用起来，自己本地打包”指令，正常入口已默认启用已离线审阅的 `cleave`（星陨剑）和 `heavy_blade`（重剑斩）原生精修图：

```powershell
npm run build:native -- <base.gil> <new-output-directory>
```

**只启用战斗手牌第 1 个静态槽 `battlePanel/card1`。** 只有这两张卡通过正常奖励/商店等获得并恰好出现在该槽时显示精修图；同一张卡在其他手牌槽、奖励、商店、牌库仍使用原占位/类型图标。其他卡始终回退原类型图标。未修改初始牌组、抽牌顺序、卡池或任何规则；不声称全手牌/全卡池完成。

一池最大 2657 图元，加 45 分组和宿主共 **2703 个额外控件**。不默认复制 5/10 池，不向无限牌库模板加池。开关仅供本地测试准备，官方导入、PC、实体安卓、反复进退及性能仍未测，不把离线视觉批准当作运行/容量验收。

恢复原无池构建：

```powershell
npm run build:native -- <base.gil> <new-output-directory> --native-card-art-count=0
```

已有显式 registry + count/host 参数现在也能穿过音频包装入口，供已有容量方案使用；没有本轮测量不建议扩池。底层 `build-native-candidate.mjs` 和普通 `build:ui` 的无参数行为保持不变。原生绘制失败/无图、换卡和清槽继续使用既有 `CardDisplay` 回退/清理，不在本切片新造渲染器。

## 冻结来源与复现

`art/cards/traveler-geo/native-source-registry.json` 固定两张既有 JSON/Lua 的 SHA256。`native-runtime-registry.json` 是固定官方编辑器 `1475505/Miliastra-image-editor-webui@103025f9095d8089e3f9bf097f4d0c5fe039d546` 的 `lua_scene.read_drawing` 解析真实 Lua literal 后导出的 schema 2 表；未信任编辑器快照、未执行 standalone 生命周期、未重绘源图。生成使用真实 Git checkout（最小 sparse `backend/app`、`backend/vendor`），不是给源码缓存伪造 Git 身份。

```sh
python scripts/art/assemble-native-card-samples.py --editor <pinned-git-checkout> \
  --candidate-registry art/cards/traveler-geo/native-source-registry.json \
  --candidate-output <temporary-runtime-registry.json>
```

入库表仅将 `sourceInputs[].path` 转为仓库相对路径，并紧凑序列化，消除生成机器绝对路径；所有 slot 数值和冻结源 hash 原样保留。本次最小 Git pack 约 276 KiB，正式本地打包不联网下载编辑器。运行构建逐一重验 JSON/Lua hash、生成 presentation/layout 的消费及最终音频收据，失败拒绝打包，不静默忽略损坏来源。`native-card-art-source-equivalence` 现默认运行两张真实素材的每个原生 API 属性对照及旋转负控，不再因缺少本地环境变量跳过。

armaments、新 PNG 卡源、怪物、未通过画像和启动背景不在本 registry；各自仍缺已批准的原生消费/组件注册等接线，不因为已有 PNG 或离线导出就自动启用。资产清单中的历史 `unbound`/未验字段保留当时审计事实，以本页与当前构建收据说明这次有限接线，不改写旧验收。
