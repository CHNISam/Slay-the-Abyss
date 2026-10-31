# 本轮M3模拟器截图来源登记

本记录补齐八张已提交PNG的资产清单身份，沿用`assets.json` schemaVersion 1及PR436已登记的`m3-static-simulator-evidence`分类。没有修改图片、许可门禁或docs目录扫描范围；这不是新授予的素材许可。

## 生成来源

- `m3-visual-20261031`五张PNG：本项目生产GameUI源码`e8eb72360d1a1e9eef015948e3b63bf09661f372`经Fengari原生合同fixture执行，`docs/evidence/m3-visual-20261031/capture.lua`/`capture.mjs`导出真实控件树，项目`experiments/ui-polish-sim/sim.mjs`转换为去除脚本的静态save，再由`beyond-simulator-mcp@0.5.2`实际Host输出。对应scene的`.tree.json`、`.sim.save.json`、`.sim.receipt.json`、metadata和README完整保留，最初纳入提交`af81787d40c993fba60b9416294c400c1c2289f7`。
- `m3-relic-name-20261031/before.sim.png`：逐字复制上述`owned-relic-detail.sim.png`，SHA及字节数相同，保留适配修前状态。
- 同目录`after.sim.png`：生产源码不变，修正捕获/转换中autoSize字段丢失后重新运行的Host静帧。`isolated.sim.png`：从原解析树只恢复遗物名称autoSize字段的受控诊断重绘。生成入口、两份树/save/回执、worker哈希、单字段语义差异及metadata见该目录README；适配与证据原始提交`93b9b5361ae3c18870e3c749121464b5004afdac`。
- 画面为本项目UI布局、文字和模拟器栅格输出，含游戏/平台名称及图库资源ID引用。回执明确记录纹理请求`fetch failed`，原网络日志保留403 Forbidden及raw gzip。没有以这些失败请求捏造已取得外部纹理的许可，也不声称最终图标或全部美术已正确装配。

## 已有权利边界

沿用[LICENSE-SCOPE](../../LICENSE-SCOPE.md)、[第三方声明](../../THIRD_PARTY_NOTICES.md)和[许可审计](LICENSE_AUDIT.md)：项目原创代码的PolyForm Noncommercial 1.0.0不扩展为对所有截图、名称、文案或画面内容的独立素材许可。项目原创布局/呈现贡献保留其现有权利；HoYoverse、Mega Crit及其他权利人的IP不由本仓库转授。八张PNG仅作为当前平台项目的开发证据保留，不授予平台外素材复用或商用清权。

模拟器为生成工具，GPL-3.0工具及项目适配代码的许可边界保持既有审计结论；本次没有复制模拟器bundle或将其作为运行时嵌入PNG，也不推断工具许可证自动成为全部图像内容的许可。所有未明的第三方内容权利继续保持原有限制。截图不代表官方导入、ready、设备、交互或发布验收。

## 精确文件身份

SHA256按原始PNG二进制字节计算；`bytes`为真实文件长度。相同图像的副本也按各自路径登记，没有LFS指针或新压缩编码。

| 文件 | bytes | SHA256 |
| --- | ---: | --- |
| `docs/evidence/m3-relic-name-20261031/after.sim.png` | 67110 | `ddfc21478fdad264c1cb39c037bde651eaf507a78bb3c141b12be897d13a20b5` |
| `docs/evidence/m3-relic-name-20261031/before.sim.png` | 64141 | `c98a85566a97b5935d147e309aaa63472f56b1b9e204a6e484dd48164fa55749` |
| `docs/evidence/m3-relic-name-20261031/isolated.sim.png` | 67110 | `ddfc21478fdad264c1cb39c037bde651eaf507a78bb3c141b12be897d13a20b5` |
| `docs/evidence/m3-visual-20261031/card-detail.sim.png` | 91277 | `3ca7045112330c2bf06681e3ba71191594d415172061cc93b2e861c12ef9bf1a` |
| `docs/evidence/m3-visual-20261031/exit-confirmation.sim.png` | 95861 | `a1d4dd5f165ba46396167175ef85846ad27ba1001d8e75bb45284fc103aed007` |
| `docs/evidence/m3-visual-20261031/owned-relic-detail.sim.png` | 64141 | `c98a85566a97b5935d147e309aaa63472f56b1b9e204a6e484dd48164fa55749` |
| `docs/evidence/m3-visual-20261031/select-deck.sim.png` | 103965 | `ed5ea1cd9f11bd4542ab68039d536eda1217f53242c453e925c1ee20ef521dff` |
| `docs/evidence/m3-visual-20261031/select.sim.png` | 79052 | `ab9a74902486fc4eab0c9aae01141d113e16988b379314a985e9039a748f970e` |
