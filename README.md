# FD Headless WP System

这个仓库不是前端仓库，也不是 WordPress 运行目录。

它只负责一件事：

- 把 `fd-frontend`、`fd-websocket`、WordPress、数据库、Redis、反向代理编排成一套可交付系统

## 仓库职责

这里未来只放这些内容：

- 顶层 `docker-compose.yml`
- `.env.example`
- Nginx / 反向代理模板
- 安装脚本
- 健康检查与备份脚本
- 交付文档
- 发布说明

这里明确不放这些内容：

- `fd-frontend` 的完整业务源码副本
- `fd-theme` 的长期开发副本
- WordPress 插件的长期开发副本
- 线上数据库文件
- `wp-content/uploads`
- 生产 `.env`

## 管理方式

采用“多仓库 + 一个交付仓库”的方式：

- `fd-frontend`
- `fd-websocket`
- `fd-theme`
- `fd-member`
- `fd-payment`
- `fd-commerce`
- `fd-headless-wp-system`

前面这些仓库负责业务代码本身。

`fd-headless-wp-system` 负责：

- 服务编排
- 环境变量规范
- 部署入口
- 交付文档
- 基础校验

## 当前阶段目标

第一阶段只做三件事：

1. 统一编排
2. 统一配置
3. 建立交付骨架

先不做这些高风险动作：

- 大规模代码搬家
- 线上迁移
- 正式环境自动发布
- 一步到位重构

## 目录说明

- `docs/`
  - 策略、管理规则、路线图
- `compose/`
  - 未来的扩展编排文件
- `nginx/`
  - 反向代理模板
- `scripts/`
  - 环境生成、安装、检查脚本

## 当前仓库状态

这还是第一版骨架。

它当前提供：

- 一份顶层 `docker-compose.yml`
- 一份 `.env.example`
- 一份可参数化的 Nginx 模板
- 基础脚本
- 基础 CI 校验

它当前还不提供：

- 可直接用于生产的一键安装
- 完整的 TLS/证书自动化
- 自定义 WordPress 镜像
- 主题/插件打包产物

## 快速开始

```bash
cp .env.example .env
bash scripts/bootstrap-env.sh
bash scripts/preflight-check.sh
docker compose --env-file .env config
```

注意：

- 当前 `FRONTEND_IMAGE` 可以直接替换成真实前端镜像
- 当前 `WEBSOCKET_IMAGE` 还是占位设计，后续需要补正式镜像发布
- 这版仓库的目标是先固定系统边界，不是立即完成生产可用的一键部署

## 下一步路线

1. 用当前骨架固定系统边界
2. 明确每个组件未来从哪里来
3. 再逐步做 staging 部署
4. 最后才做正式的一键安装与迁移
