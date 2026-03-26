# Compose 第二版设计

这份文档定义第二版 compose 的目标。

## 第二版不是最终版

第二版的目标不是直接做生产一键部署。

第二版的目标是：

- 让交付仓库真实反映当前组件来源
- 让服务边界更清晰
- 为 staging 验证做准备

## 第二版的核心变化

### 1. 从“占位式系统图”变成“真实来源系统图”

当前系统已经具备这些独立来源：

- `fd-frontend`
- `fd-websocket`
- `fd-theme`
- `fd-member`
- `fd-payment`
- `fd-commerce`

所以第二版 compose 不再只是一个抽象示意图，
而是明确：

- 哪些服务当前靠镜像
- 哪些资产未来通过 WordPress 制品进入系统

### 2. 网络分层

第二版采用两层网络：

- `core`
  - `db`
  - `redis`
  - `wordpress`
- `edge`
  - `wordpress`
  - `frontend`
  - `websocket`
  - `nginx`

这样表达更接近真实运行结构。

### 3. WebSocket 接入方式升级

第二版 compose 明确为 `websocket` 注入：

- `PUSH_SECRET`
- `JWT_SECRET`
- `ALLOWED_ORIGINS`

这和现在独立出来的 `fd-websocket` 仓库结构一致。

### 4. WordPress 仍保持保守策略

第二版仍然不直接绑定：

- `fd-theme`
- `fd-member`
- `fd-payment`
- `fd-commerce`

的源码目录。

原因：

- 交付仓库不是业务代码总仓
- 现在还没完成 WordPress 制品策略

因此第二版只先把：

- WordPress runtime
- 数据层
- 前端
- websocket
- reverse proxy

组织清楚。

## 第二版明确不做

- 不把本地业务源码直接 bind mount 进交付仓库
- 不在交付仓库复制主题和插件源码
- 不直接做生产迁移
- 不直接做自动证书签发

## 第二版完成标准

- `docker-compose.yml` 的结构更贴近真实组件来源
- WebSocket 环境变量与现有独立仓库一致
- 文档明确下一步要做 WordPress 制品接入

## 第二版之后的顺序

1. 为 `fd-websocket` 增加镜像发布
2. 设计 WordPress 主题/插件进入交付系统的制品方式
3. 设计 staging 验证方案
4. 再做第三版 compose
