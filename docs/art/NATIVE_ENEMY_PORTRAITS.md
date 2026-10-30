# 两幕42种敌人的原生图库接线

2026-10-30：23个既有定义、第一幕2个追加Boss、第二幕17个定义（含召唤物）全部直接绑定 `icon.enemy` 数字图库ID。共复用26张图库图片，**不是42个独立物种或42张新画**。现有 `abyss_battle_render_actors.enemyPortraitIcon` → `host.unit` → `UIImage:SetImage("static", id)` 不变；不增加控件、上传图片、在线查询、渲染器、动画或特效，不改名字、AI、数值、布局、Boss逻辑。未知敌人保留原有按层级节点图标回退。

## 来源与边界

SDK固定提交 `eb05fd35075b2635e851a2f58b202ac2eadd187b` 的图库目录，照片标注采集于2026-10-13：

- [src/scene/image-library/index.json](https://github.com/8itlab/genshin-miliastra-mcp/blob/eb05fd35075b2635e851a2f58b202ac2eadd187b/src/scene/image-library/index.json)
- [src/scene/image-library/creature_00.jpg](https://github.com/8itlab/genshin-miliastra-mcp/blob/eb05fd35075b2635e851a2f58b202ac2eadd187b/src/scene/image-library/creature_00.jpg)
- [src/scene/image-library/creature_01.jpg](https://github.com/8itlab/genshin-miliastra-mcp/blob/eb05fd35075b2635e851a2f58b202ac2eadd187b/src/scene/image-library/creature_01.jpg)

照片SHA-256：

- `native-monster-creature-01.jpg`：`7536986fc79248ab60703ea94ed5edf512360b2eb58046bb93019a6b94c25cb4`
- `native-monster-creature-00.jpg`：`b3dec8311cd262c3eee9f84196e4619348d4d7e3e00de397acc6620067cdf1b3`

图库照片确认这些编号存在及可见外形；实际官方客户端/设备渲染仍待用户本地打包验证，`verify: true` 保留。旧2026-10-02模拟目录只到112042，不覆盖较新的112077目录。OSS元数据请求返回403后未重试或绕过；本次证据来自独立公开SDK照片。照片只作参考，未复制入仓库；图库及角色的第三方权利不由项目源码许可覆盖。

表中是游戏机械角色与图库的适配，不把原版《杀戮尖塔》身份宣称成原神官方物种。五种普通小魔均用深渊法师，丘丘督军用丘丘岩盔王；蕈甲兽暂用炽热骗骗花等植物外形，**不是已确认的蕈兽**。部分保留资产的精确物种未核，按照片外形记录，不编造官方名字。PR355的未绑定PNG仍仅是未来源稿基准，不参与本次运行时。

## 实际绑定

| 敌人ID | 游戏名（未改） | 图库ID | 照片外形/适配 |
|---|---|---:|---|
| `looter` | 窃金客 | 112030 | 盗宝团人形（精确职业未核） |
| `guardian` | 深渊守卫 | 112046 | 深渊系高瘦重甲造物（精确物种未核） |
| `cultist` | 祈火徒 | 112022 | 火深渊法师 |
| `jaw_worm` | 石颚兽 | 112038 | 野猪 |
| `red_louse` | 赤甲虫 | 112013 | 岩史莱姆 |
| `green_louse` | 青甲虫 | 112014 | 大型岩史莱姆 |
| `acid_slime_s` | 小型酸液团 | 112009 | 草史莱姆 |
| `acid_slime_m` | 中型酸液团 | 112009 | 草史莱姆 |
| `acid_slime_l` | 大型酸液团 | 112010 | 大型草史莱姆 |
| `spike_slime_s` | 小型棘刺团 | 112007 | 雷史莱姆 |
| `spike_slime_m` | 中型棘刺团 | 112007 | 雷史莱姆 |
| `spike_slime_l` | 大型棘刺团 | 112008 | 大型雷史莱姆 |
| `blue_slaver` | 蓝衣束缚者 | 112031 | 盗宝团人形（精确职业未核） |
| `red_slaver` | 赤衣束缚者 | 112050 | 戴斗笠人形（精确物种未核） |
| `fungi_beast` | 蕈甲兽 | 112033 | 炽热骗骗花 |
| `mad_gremlin` | 狂怒小魔 | 112022 | 火深渊法师 |
| `sneaky_gremlin` | 潜行小魔 | 112025 | 冰深渊法师 |
| `fat_gremlin` | 迟缓小魔 | 112023 | 水深渊法师 |
| `wizard_gremlin` | 蓄能小魔 | 112024 | 雷深渊法师 |
| `shield_gremlin` | 护盾小魔 | 112025 | 冰深渊法师 |
| `gremlin_nob` | 怒焰巨魔 | 112037 | 岩甲造物（精确物种未核） |
| `lagavulin` | 沉眠遗卫 | 112026 | 古代机关（精确型号未核） |
| `sentry` | 符文哨卫 | 112027 | 古代机关（精确型号未核） |
| `hexaghost` | 六焰幽核 | 112022 | 火深渊法师 |
| `slime_boss` | 巨型凝胶君王 | 112004 | 大型水史莱姆 |
| `spheric_guardian` | 磐核守卫 | 112026 | 古代机关（精确型号未核） |
| `centurion` | 岩卫统领 | 112017 | 丘丘暴徒 |
| `mystic` | 祈岩医者 | 112021 | 水丘丘萨满 |
| `taskmaster` | 缚役监军 | 112031 | 盗宝团人形（精确职业未核） |
| `book_of_stabbing` | 刺棘秘典 | 112024 | 雷深渊法师 |
| `snake_plant` | 噬岩藤 | 112033 | 炽热骗骗花 |
| `chosen` | 蚀咒使徒 | 112025 | 冰深渊法师 |
| `shelled_parasite` | 岩甲寄生兽 | 112014 | 大型岩史莱姆 |
| `byrd` | 巡风隼 | 112065 | 白鹤 |
| `snecko` | 惑心蜥 | 112037 | 岩甲造物（精确物种未核） |
| `mugger` | 荒野劫匪 | 112030 | 盗宝团人形（精确职业未核） |
| `gremlin_leader` | 丘丘督军 | 112020 | 丘丘岩盔王 |
| `torch_head` | 炬火侍从 | 112016 | 冲锋丘丘人 |
| `collector` | 聚烬领主 | 112022 | 火深渊法师 |
| `automaton` | 青铜机枢 | 112027 | 古代机关（精确型号未核） |
| `bronze_orb` | 青铜浮核 | 112026 | 古代机关（精确型号未核） |
| `champ` | 磐岩斗魁 | 112018 | 丘丘雷兜王 |

## 可重复验证

`tests/native-enemy-portraits.test.mjs` 执行真实生成UI夹具，核对生产定义集合正好42项及每项数字ID，再批量进入正式战斗渲染并检查原生 `SetImage` 调用结果。另走生产召唤路径检查炬火侍从、青铜浮核与小魔，以及未知普通/精英/Boss的原有回退。通过此测试只能证明源码接线，不代表官方导入、截图观感或手机性能验收。
