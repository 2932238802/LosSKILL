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
