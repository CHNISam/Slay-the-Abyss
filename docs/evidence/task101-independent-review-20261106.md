# TASK-101 独立代码复审

结论：本次复审范围通过，首轮提出的五项阻断均已关闭。此结论不替代仓库必要 CI、Full 或合并准入。

## 冻结文件

复审与定向测试前后 SHA256 一致：

- scripts/repository-costs.mjs：54a9fdebd2c56055368af44875fce48bed6130334d1ab4213234acc2a8b3f5dc
- tests/repository-costs.test.mjs：36ed434dcac3d79162648d47c0ee8a7555b138ff48a4f004dc6169d02b2383ce

## 阻断复验

1. LFS 字节口径：已分离 logicalCheckoutPayloadBytes 与 verifiedWorktreeBytes；未下载指针不再被称为已 materialize。
2. 空结果误绿：七个必要输出必须存在且非空；退出零但无产物的负例失败，不生成成功耗时汇总。
3. 输出目录链接：measureBuilds 在写入前检查 build 路径祖先；CLI 同样检查报告路径。现存 symlink 不会被直接用作输出目的地。
4. Windows 文件名：tab 文件名仅用于非 Windows fixture，Windows 使用普通空格；fixture 固定 core.autocrlf=false。
5. LFS 父目录链接：fileState 检查完整祖先链，替换为 symlink 的文件或父目录不会被读取并计为 verified。

补充确认：Git cat-file 使用二进制 Buffer 按对象长度解析；Git blob 和 LFS payload 分别按各自 OID 去重。构建失败、冷暖输出漂移、构建期间源码变化均返回失败且不生成成功汇总。inputDigestScope 已明确排除 ignored 依赖及外部链接目标。

## 独立定向测试

仅执行一次 `node --test tests/repository-costs.test.mjs`：15/15 通过，0 失败、0 跳过，约 2.56 秒。执行环境 Linux；本轮未运行真实构建或 Full。

## 实际报告核对

报告 SHA256：131f11dbaa1524d889f1ab99cc4a9718a4626e316595bdd1d5e3ee7547b15ea7。统计提交：7f11f4bfa994c4d3fa8ad7b677bf7aba4359bbf2。

独立 Python 程序读取 git ls-tree 与 git cat-file，没有调用被审脚本统计函数。与报告一致：7,138 个 blob 路径、7,038 个唯一 blob；路径字节236,778,859，唯一字节226,921,854；140 个 LFS 指针/唯一对象；指针18,453 B；唯一及全部逻辑 payload216,647,536 B；全部展开的逻辑checkout453,407,942 B。verifiedWorktreeBytes 与 readableUniqueBytes 均为0，不是已下载证明。

报告三组默认构建通过，源树前后摘要相同，各组冷暖输出清单一致。独立读取保留的63条 warm 输出文件，大小和SHA256均匹配。真实构建由实现者运行，本复审没有重复执行。冷P50/P95为729.10/768.52ms，暖为765.07/797.82ms；三次小样本不支持暖构建加速，未清空OS页缓存，也不声称应用缓存命中。

## 未验范围与限制

- 未实跑 Windows/macOS；Windows junction/reparse-point 行为仍需平台CI验证。
- 路径检查是预先检查，不是抵抗并发恶意替换路径的安全沙箱。
- 输入摘要不验证node_modules、Python依赖或外部链接目标。
- 未测美术开启的原生候选、网络传输、官方导入、游戏GUI或官方包体。
- 未重复Full，未触发CI，未修改被审文件。
- 本审查不涉及Backlog CLI全库既有重复ID，未声称已修复。
