# 迦智（Jiazhi）— 钉钉 / Teambition 记录习惯

> 公司专属，仅用于迦智工作系统；不要复用到其他公司。
> 换公司时新建 `work/<company-slug>/`，本文件的任务 ID、链接、字段 ID、凭证都不迁移。

## 1. 系统入口

- **钉钉文档**：`alidocs.dingtalk.com`；本机通过 `dingtalk-doc` MCP 读取（Cookie 文件，只读）。
- **Teambition**：任务系统；通过官方 HTTP MCP `teambition`（OAuth）读写任务。
- **GitLab**：`server01.jz`；`flash-agv` 等仓库与 CI（`build-verify`）。
- **`dws` CLI**：已安装，但组织未开通 CLI 数据访问权限，当前不可用；等管理员放行。

## 2. 任务记录风格

参考任务：`6adf0e8fc54cf79de8ebdcfb`（停障忽略区域接入）。

- **需求描述**：一段话说明来源/问题/范围，再列 3 条左右工作项；**工时写在条目里**，同类任务合计不超过 2.5。
- **交付事项**：一句话，写清交付物 + 版本号/自测报告。
- **验收事项**：一句话，列测试/AC + 证据。
- **备注**：只放进度、阻塞、上机状态；不要把长需求描述塞进备注。

## 3. 操作流程

1. 先读当前 `note` 和三个 rtf 字段，确认原文。
2. 追加/改写，不覆盖历史。
3. 用 `teambition_task_customfield-rtf-update` 写 `需求描述` / `交付事项` / `验收事项`。
4. 用 `teambition_task_update` 写 `note`。
5. 更新后回读校验。

## 4. 本次任务记录（2026-11-21 / 11-23）

- 任务：`6afd7d914380d7d24e1a18f6`《【遥控】网页遥控驱动改造》。
- 代码：`flash-agv` 分支 `feat/remote-control-web` @ `1f808aaa`；单 commit；tag `1.2611.1+remote-control` @ `1f808aaa`。
- CI：branch `#163776`、tag `#163777` 均 Passed（1d 前）。
- 本机：协议 182、WS 83、ASan/UBSan 通过。
- ABI：driver 14 / event plugin 20。
- 上机：暂缓（机器未就绪）；剩余真实 DSO/上机 AC、RCS 参数槽位。

## 5. 公司边界

- 本文件所有任务 ID、文档链接、字段 ID、CI 结果只属于迦智。
- 新公司：新建 `work/<company-slug>/`，重新记录其钉钉/项目管理/代码平台习惯。
- 不复用本文件的 Cookie、token、MCP 配置或任务链接。
