# Release 与版本规则

这份文档只解决一个问题：

- 交付系统后续到底引用什么版本标识

## 当前规则

- Git tag 统一使用：`vMAJOR.MINOR.PATCH`
- WordPress 主题/插件源码内部版本继续使用：`MAJOR.MINOR.PATCH`
- 每个正式交付版本都必须有 GitHub Release
- Release 必须附带可下载的 zip 制品

## 当前已落地的首个版本

- `fd-theme`：`v1.0.0`
- `fd-member`：`v1.0.0`
- `fd-payment`：`v1.0.0`
- `fd-commerce`：`v1.0.0`
- `fd-content-types`：`v0.4.0`
- `fd-ai-router`：`v2.2`

## 当前推荐默认版本

- `fd-theme`：`v1.0.11`
- `fd-member`：`v1.0.5`
- `fd-payment`：`v1.0.2`
- `fd-commerce`：`v1.0.0`
- `fd-content-types`：`v0.4.4`
- `fd-ai-router`：`v2.2.4`

对应 release asset：

- `fd-theme.zip`
- `fd-member.zip`
- `fd-payment.zip`
- `fd-commerce.zip`
- `fd-content-types.zip`
- `fd-ai-router.zip`

## 推荐发布顺序

1. 业务代码进入 `main`
2. `CI` 通过
3. 创建对应 tag，例如 `v1.0.1`
4. 发布 GitHub Release
5. 由 `Package Artifact` workflow 自动上传 zip asset
6. 交付仓库再引用这个固定版本

## 对交付仓库的含义

从现在开始，交付仓库不应该再把这四个组件当成“浮动源码来源”。

应该把它们当成：

- 有版本号的 release 制品来源
- 后续可被 staging / install 流程固定引用的输入
