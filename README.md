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

## 产品交付声明

仓库根目录包含：

- `fd-delivery.manifest.json`

这个文件用于让 `fd-core-stack` 自动识别当前产品的部署合同，包括：

- 安装器入口
- 仓库与分支
- 域名槽位
- 用户需要填写的字段
- 高级预设字段

目标是让控制平面只渲染当前产品真正需要的字段，而不是给所有产品展示一套固定的大表单。

## 产品交付声明

仓库根目录包含：

- `fd-delivery.manifest.json`

这个文件用于让 `fd-core-stack` 自动识别当前产品的部署合同，包括：

- 安装器入口
- 仓库与分支
- 域名槽位
- 用户需要填写的字段
- 高级预设字段

目标是让控制平面只渲染当前产品真正需要的字段，而不是给所有产品展示一套固定的大表单。

## 管理方式

采用“多仓库 + 一个交付仓库”的方式：

- `fd-frontend`
- `fd-websocket`
- `fd-theme`
- `fd-admin-ui`
- `fd-member`
- `fd-payment`
- `fd-commerce`
- `fd-content-types`
- `fd-ai-router`
- `fd-websocket-push`
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

如果你现在最关心的是：

- 一台空白服务器怎么从 0 装起来
- 需要准备什么
- 先跑 HTTP，再切 HTTPS 的顺序怎么走

先看这份更短的入口文档：

- `docs/BLANK-SERVER-QUICKSTART.md`

如果你要的是当前最完整的“空白主机一键部署说明”，直接看：

- `docs/ONE-CLICK-DEPLOY.md`

如果你想直接用更少命令开始，空白 Debian 12 服务器现在可以先这样做：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/FutureDecade/fd-headless-wp-system/main/scripts/remote-install.sh)
```

确认 HTTP 正常后，再切 HTTPS：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/FutureDecade/fd-headless-wp-system/main/scripts/remote-setup-https.sh)
```

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
- `WORDPRESS_RUN_INIT=true` 时，会自动完成 WordPress 首次安装，并安装激活 `WPGraphQL`、`redis-cache`、`Classic Editor`，同时启用交付链里挂载的核心插件；全新安装还会把 `WPGraphQL` 与 `Classic Editor` 对齐到旧站默认配置，并保持 `Redis Cache` 的 object cache 启用状态与旧站一致
- `fd-ai-router` 现在也作为核心插件纳入交付链，会跟其他私有插件一起挂载并自动启用
- 默认还会导入 `WORDPRESS_DEMO_DATA_FILE` 指向的演示数据包；如果不想导入，把 `WORDPRESS_IMPORT_DEMO_DATA=false`
- 默认交付链路不再安装 `ACF` 或 `WPGraphQL for ACF`，当前内容模型默认按纯代码插件运行
- 初始化还会自动设置 `WORDPRESS_PERMALINK_STRUCTURE`，确保 `/graphql` 这种地址能直接使用
- 如果需要在已有站点上强制重导演示数据，可以把 `WORDPRESS_FORCE_DEMO_DATA_IMPORT=true`
- 如果服务器不能直接从 WordPress 官方源下载插件，可以把 `WORDPRESS_WPGRAPHQL_SOURCE`、`WORDPRESS_CLASSIC_EDITOR_SOURCE` 改成你自己的 zip 地址
- 如果要在测试服务器拉取私有 WordPress release 资产，需要把 `WORDPRESS_FETCH_RELEASE_ASSETS=true`
- 如果 WordPress 资产版本没有变化，`scripts/update-stack.sh` 会自动跳过重复下载；只有需要强制重拉时，才把 `FORCE_WORDPRESS_ASSET_FETCH=true`
- 测试服务器更新建议直接运行 `bash scripts/update-stack.sh`
- `FD_RUNTIME_IMAGE_UPDATE_POLICY` 用来控制收到新运行时镜像后的行为：`manual` 只记录 `AVAILABLE_FRONTEND_IMAGE` / `AVAILABLE_WEBSOCKET_IMAGE`，`auto` 才会直接切换当前镜像
- 当策略是 `manual` 时，可以先查看 `.env` 里记录的 `AVAILABLE_*`，再运行 `bash scripts/apply-available-runtime-images.sh`，最后执行 `bash scripts/update-stack.sh`
- 服务器上不要直接手写裸 `docker compose up/run` 来操作 WordPress 相关容器，应该统一走仓库脚本；否则可能遗漏 `wordpress-assets` 挂载
- `scripts/install.sh` 现在会先做预检查，再直接复用 `scripts/update-stack.sh` 的安全更新流程，避免维护两套部署逻辑
- `scripts/quick-install.sh` 会把“配置 + 收集凭据 + 首次安装”收成一个入口
- `scripts/remote-install.sh` 支持空白 Debian 12 服务器一条命令拉起首装入口
- `scripts/quick-setup-https.sh` 会把“收集凭据 + 切 HTTPS”收成一个入口
- `scripts/remote-setup-https.sh` 支持一条命令触发 HTTPS 切换入口
- `fd-headless-wp-system` 现在已经是公开交付仓库，空白服务器可以直接 `git clone`
- 如果前端或推送服务镜像在阿里云 ACR 私有仓库，第一次更新时可这样运行：`ACR_USERNAME=你的账号 ACR_PASSWORD=你的密码 bash scripts/update-stack.sh`
- 如果已经换成正式域名并准备启用 HTTPS，可以运行 `ACR_USERNAME=你的账号 ACR_PASSWORD=你的密码 bash scripts/setup-https.sh`
- 后续证书续期可以运行 `ACR_USERNAME=你的账号 ACR_PASSWORD=你的密码 bash scripts/renew-https.sh`
- 如果只想更新 WordPress 交付资产版本，可以运行 `FD_THEME_RELEASE_TAG=v1.1.0 FD_CONTENT_TYPES_RELEASE_TAG=v0.4.4 FD_AI_ROUTER_RELEASE_TAG=v2.2.4 FD_WEBSOCKET_PUSH_RELEASE_TAG=v1.0.2 WPGRAPHQL_JWT_AUTH_RELEASE_TAG=v0.7.2 WPGRAPHQL_TAX_QUERY_REF=v0.2.0 bash scripts/update-wordpress-release-tags.sh`
- GitHub Actions 里的 `Sync WordPress Release Tags` 现在会每 6 小时自动检查一次 latest release；必要时也可以手动触发，自动回写 manifest 与默认脚本版本
- GitHub Actions 里的 `Deploy Test Server` 现在既支持手动填写 release tag，也支持被 `repository_dispatch` 传入新的 `FRONTEND_IMAGE` / `WEBSOCKET_IMAGE`；是否立即更新由服务器 `.env` 里的 `FD_RUNTIME_IMAGE_UPDATE_POLICY` 决定
- 截至 `2026-03-28`，测试机 `144.48.8.218` 已经完成 `www.futuredecade.com`、`admin.futuredecade.com`、`ws.futuredecade.com` 的正式 HTTPS 验证
- 这版仓库的目标是先固定系统边界，不是立即完成生产可用的一键部署

## 下一步路线

1. 用当前骨架固定系统边界
2. 明确每个组件未来从哪里来
3. 再逐步做测试服务器部署
4. 最后才做正式的一键安装与迁移

## 关键文档

- `docs/BLANK-SERVER-QUICKSTART.md`
- `docs/ONE-CLICK-DEPLOY.md`
- `docs/PROJECT-MANAGEMENT.md`
- `docs/MINIMAL-INTEGRATION-STRATEGY.md`
- `docs/COMPONENT-SOURCES.md`
- `docs/INSTALL-AND-UPDATE.md`
- `docs/NEXT-STEPS.md`
- `docs/COMPOSE-V2-PLAN.md`
- `docs/WORDPRESS-ASSET-INTEGRATION.md`
