# Claude ↔ LosSKILL 同步规则

用户要求：**凡是更新到 Claude 的工作习惯、个人习惯记录，都要同步更新到 LosSKILL。**

## 分类

- **个人**：身份、通用偏好、代码/写作/工具习惯 → `personal/`
- **工作**：公司系统、项目流程、任务记录习惯 → `work/<company>/`
  - 当前公司：`jiazhi/`
- **公司之间严格隔离**：任务 ID、文档链接、字段 ID、凭证、MCP 配置不跨公司复用。

## 时机

- 每次在 Claude memory（`user` / `feedback` / `project` / `reference`）中新增或修改后，同一轮写入对应 LosSKILL 文件。
- Claude memory 仍是工作副本；LosSKILL 是持久归档。
- 不写 token / Cookie / 私钥；只记“怎么获取、怎么用”。

## 结构

```
LosSKILL/
├─ SYNC.md
├─ personal/
│  └─ habits.md
└─ work/
   ├─ README.md
   └─ jiazhi/
      ├─ habits.md
      └─ dingtalk-teambition.md
```
