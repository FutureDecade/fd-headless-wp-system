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
- WordPress release zip 接入骨架
- WordPress 初始化脚手架
- 可选 HTTPS 证书脚本

它当前还不提供：

- 可直接用于生产的一键安装
- 自定义 WordPress 镜像
- 最终的客户交付分发方案

## 快速开始

```bash
cp .env.example .env
bash scripts/bootstrap-env.sh
bash scripts/preflight-check.sh
# 如果需要 WordPress release 资产，先把 .env 里的 WORDPRESS_FETCH_RELEASE_ASSETS 改成 true
# 如果需要自动完成首次安装，先把 .env 里的 WORDPRESS_RUN_INIT 改成 true
bash scripts/fetch-wordpress-assets.sh
bash scripts/update-stack.sh
docker compose --env-file .env config
```

如果你想从更简单的入口开始，也可以直接运行：

```bash
bash scripts/install.sh
```

如果 `.env` 还不存在，这个脚本会先帮你生成一份，然后停下来提醒你把关键配置改掉，再重新执行。

如果你面对的是一台刚装好的 Debian / Ubuntu 服务器，也可以先运行：

```bash
bash scripts/prepare-server.sh
```

这个脚本只负责安装系统依赖、Docker、Docker Compose、GitHub CLI，不会启动项目服务。

如果你已经有 `.env`，或者不想手改一堆配置项，也可以运行：

```bash
bash scripts/configure-env.sh
```

这个脚本会按顺序询问域名、镜像、证书邮箱、WordPress 初始化等核心配置，然后写入 `.env`。

注意：

- 先在 GitHub Actions 里手动运行一次 `Sync Base Images`，把 `mariadb`、`redis`、`wordpress`、`wpcli`、`nginx`、`certbot` 同步到自己的 ACR
- 交付时优先使用阿里云 ACR 镜像
- 最稳妥的方式是给 `FRONTEND_IMAGE` 和 `WEBSOCKET_IMAGE` 都写入固定 tag，不要直接依赖 `latest`
- 空白服务器首次启动，建议先使用 `PUBLIC_SCHEME=http` 和 `WEBSOCKET_PUBLIC_SCHEME=ws`，先把整套服务跑通
- 真正切到 HTTPS 前，要先重新构建一版前端交付镜像，把 `site_url` 改成 `https://...`，把 `websocket_url` 改成 `wss://...`
- `scripts/setup-https.sh` 现在会自动申请证书，并把 `.env` 里的 `HTTPS_ENABLED`、`HTTPS_PORT`、`PUBLIC_SCHEME`、`WEBSOCKET_PUBLIC_SCHEME` 一起改到正确值
- `WORDPRESS_RUN_INIT=true` 时，会自动完成 WordPress 首次安装，并安装激活 `WPGraphQL`
- 初始化还会自动设置 `WORDPRESS_PERMALINK_STRUCTURE`，确保 `/graphql` 这种地址能直接使用
- 如果服务器不能直接从 WordPress 官方源下载插件，可以把 `WORDPRESS_WPGRAPHQL_SOURCE` 改成你自己的 zip 地址
- 如果要在测试服务器拉取私有 WordPress release 资产，需要把 `WORDPRESS_FETCH_RELEASE_ASSETS=true`
- 如果 WordPress 资产版本没有变化，`scripts/update-stack.sh` 会自动跳过重复下载；只有需要强制重拉时，才把 `FORCE_WORDPRESS_ASSET_FETCH=true`
- 测试服务器更新建议直接运行 `bash scripts/update-stack.sh`
- `scripts/install.sh` 现在会先做预检查，再直接复用 `scripts/update-stack.sh` 的安全更新流程，避免维护两套部署逻辑
- 如果 `fd-headless-wp-system` 仓库保持私有，空白服务器不能直接匿名 `git clone`；要么先 `gh auth login` 后用 `gh repo clone`，要么把交付仓库改成公开
- 如果前端或推送服务镜像在阿里云 ACR 私有仓库，第一次更新时可这样运行：`ACR_USERNAME=你的账号 ACR_PASSWORD=你的密码 bash scripts/update-stack.sh`
- 如果已经换成正式域名并准备启用 HTTPS，可以运行 `ACR_USERNAME=你的账号 ACR_PASSWORD=你的密码 bash scripts/setup-https.sh`
- 后续证书续期可以运行 `ACR_USERNAME=你的账号 ACR_PASSWORD=你的密码 bash scripts/renew-https.sh`
- 如果只想更新 `fd-theme`、`fd-member`、`fd-payment`、`fd-commerce` 的 release tag，可以运行 `FD_THEME_RELEASE_TAG=v1.0.3 bash scripts/update-wordpress-release-tags.sh`
- GitHub Actions 里的 `Deploy Test Server` 现在支持手动填写这些 release tag，服务器会先改 `.env`，再自动重拉并更新
- 截至 `2026-03-28`，测试机 `144.48.8.218` 已经完成 `www.futuredecade.com`、`admin.futuredecade.com`、`ws.futuredecade.com` 的正式 HTTPS 验证
- 这版仓库的目标是先固定系统边界，不是立即完成生产可用的一键部署

## 下一步路线

1. 用当前骨架固定系统边界
2. 明确每个组件未来从哪里来
3. 再逐步做测试服务器部署
4. 最后才做正式的一键安装与迁移

## 关键文档

- `docs/PROJECT-MANAGEMENT.md`
- `docs/MINIMAL-INTEGRATION-STRATEGY.md`
- `docs/COMPONENT-SOURCES.md`
- `docs/INSTALL-AND-UPDATE.md`
- `docs/NEXT-STEPS.md`
- `docs/COMPOSE-V2-PLAN.md`
- `docs/WORDPRESS-ASSET-INTEGRATION.md`
