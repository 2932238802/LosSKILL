# 迦智（Jiazhi）工作习惯

> 公司专属；不要复用到其他公司。

- **系统**：DingTalk 文档（`alidocs.dingtalk.com`）、Teambition 任务、GitLab `server01.jz`、CI `build-verify`。
- **任务记录**：参考任务 `6adf0e8fc54cf79de8ebdcfb`。
  - 需求描述：一段话 + 3 条左右工作项，工时写在条目里，同类任务合计 ≤2.5。
  - 交付事项 / 验收事项：各一句话。
  - 备注：只放进度、阻塞、上机状态。
- **MCP**：Teambition 官方 HTTP MCP（OAuth）读写任务；`dingtalk-doc` Cookie 只读；`dws` 组织 CLI 权限未开通。
- **项目口径**：车端参数统一用 `flash-agv-parameters`；App 遥控 WS 协议 V1.0；设计文档与协议冲突时以协议为准。
- **Git/CI**：`flash-agv` 分支/ tag；一单一个 commit；tag `1.2611.1+remote-control`。旧基线 `1f808aaa` 的 branch `#163776`、tag `#163777` 均 Passed；2026-11-23 嫁接后分支 `feat/remote-control-web` @ `da2ae3e1` 已推送，tag 是否跟随待定。
- **公司边界**：任务 ID、链接、字段 ID、凭证、MCP 配置只在本目录使用。
- **文档归档**：Doc Agent 开发文档 → `docs/archive/<YYYYMMDD>/N-<主题>-开发文档.md`，同日放 `README.md` 子索引（状态总览 + 待决事项）；角色执行报告 → `docs/reports/`；两者都登记 `WORKLOG.md`。
- **配置改动留痕**：修改 `flash-agv/config/*.json` 时，必须在 Teambition 单备注：①改了哪个 JSON、为什么；②日后需同步到车型参数（`flash-agv-parameters` proto）；③对应 JSON 变更的 commit 哈希（未提交时先记「待提交后补哈希」）。项目组后续统一迁移 JSON→车型参数时，以该哈希对应的 JSON 为准。
- **单子备注格式**：进度写进任务「备注」字段（`note`），不是评论；**一条 = 一个时间 + 一件事，只追加不覆盖**（各时间块各自保留，不合并/不改写）；只写产出与结果，不写过程、不写「待确认/阻塞/剩余」；结果用**人话**说明哪些测试通过、覆盖什么，不堆裸数字；时间到分钟，短句分行；提交后补录哈希。
- **临时目录**：脚本、构建目录、测试临时文件统一放 `D:\Temp`（WSL `/mnt/d/Temp`），不放 `/tmp`、CWD 或仓库目录，也不写 C 盘默认临时目录；测试代码尊重 `TMPDIR`/`*_TEST_TMPDIR`，本地运行时设 `TMPDIR=/mnt/d/Temp`。
- **人工文档审阅清单**：`JZ/docs/人工文档审阅清单.md` 只列**必要审阅**（需求/G1/开发文档/材料/自测交付/关键评审结论）；持续变动或过程性文件（STATUS、WORKLOG、README 索引、清单本身、脚本、存档 patch、逐次返工报告）不列入；「完成」= 审阅发生在文件最后修改之后，文件再改则运行 `docs/scripts/doc_review_sync.py` 自动取消勾选。
