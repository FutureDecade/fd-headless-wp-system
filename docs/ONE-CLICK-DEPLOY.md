# 一键部署说明

这份文档只讲一件事：

- 一台空白 Debian 12 服务器，怎样用最少命令把这套系统跑起来

这里说的“一键”，目前准确来说是：

- 一条首装命令
- 然后按提示输入必要配置和凭据

它还不是完全零输入的商业安装器，但已经是当前这套系统最稳、最短、最接近正式交付的入口。

## 当前真实状态

截至 `2026-03-29`，下面这条链路已经在空白 Debian 12 服务器 `144.48.8.218` 上完整验证通过：

- 服务器基础环境安装
- 交付仓库拉取
- `.env` 向导生成
- 基础镜像从阿里云 ACR 拉取
- WordPress 主题和插件从 GitHub Release 自动拉取
- WordPress 自动初始化
- Redis Object Cache 自动启用
- 前端、后台、推送服务启动并通过健康检查
- `https://www.futuredecade.com`
- `https://admin.futuredecade.com`
- `https://ws.futuredecade.com/health`
- `https://admin.futuredecade.com/graphql`

当前自动纳入交付链的 WordPress 关键组件包括：

- `fd-theme`
- `fd-admin-ui`
- `fd-member`
- `fd-payment`
- `fd-commerce`
- `fd-content-types`
- `fd-websocket-push`
- `wp-graphql`
- `wp-graphql-jwt-authentication`
- `wp-graphql-tax-query-develop`
- `redis-cache`
- `classic-editor`

## 你要先准备什么

至少准备这 5 样东西：

1. 一台空白 Debian 12 服务器
2. 3 个已经解析到这台服务器公网 IP 的域名
3. 阿里云 ACR 用户名和密码
4. GitHub token
5. 已经构建好的前端镜像和 WebSocket 镜像

推荐域名分法：

- 前台：`www.你的域名`
- 后台：`admin.你的域名`
- 推送：`ws.你的域名`

## 先做一次 GitHub 动作

在 `fd-headless-wp-system` 仓库的 GitHub Actions 里，先手工运行一次 `Sync Base Images`。

这一步的作用是：

- 把 `mariadb`、`redis`、`wordpress`、`wpcli`、`nginx`、`certbot` 这些基础镜像同步到你自己的 ACR
- 避免空白服务器首次安装时直接依赖 Docker Hub

这一步不是每次部署都要跑。

通常只有第一次搭交付体系时跑一次，后面基础镜像有调整时再跑。

## 最短安装命令

空白服务器上，直接执行：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/FutureDecade/fd-headless-wp-system/main/scripts/remote-install.sh)
```

这条命令会自动做这些事：

- 安装最基础的系统包：`git`、`curl`、`ca-certificates`
- 拉取交付仓库到 `/opt/fd-headless-wp-system`
- 安装 Docker、Docker Compose、GitHub CLI
- 进入 `.env` 配置向导
- 收集这次首装需要的 ACR / GitHub 凭据
- 调用已经验证过的首装流程

## 安装过程中你会被问到什么

`remote-install.sh` 最后会进入 `scripts/quick-install.sh`，它会按顺序问你：

- 主域名
- 前台域名
- 后台域名
- 推送域名
- 前端镜像完整地址
- 推送镜像完整地址
- 证书通知邮箱
- 是否自动拉 WordPress release 资产
- 是否自动完成 WordPress 首次安装
- 阿里云 ACR 用户名
- 阿里云 ACR 密码
- GitHub token

推荐第一次就这样选：

- 自动拉 WordPress 资产：`y`
- 自动完成 WordPress 首次安装：`y`

## 第一次建议怎么填

第一次部署，不要急着直接切 HTTPS。

最稳的方式是先把 HTTP 跑通：

- `PUBLIC_SCHEME=http`
- `WEBSOCKET_PUBLIC_SCHEME=ws`
- `HTTPS_ENABLED=false`

这样做的好处是：

- 问题容易定位
- 能先确认前端、后台、推送、GraphQL、WordPress 初始化都正常
- 不会把证书、反代、前端构建地址三个问题混在一起

## 需要特别注意的两点

### 1. GitHub token 不是可有可无

如果你打开了：

- `WORDPRESS_FETCH_RELEASE_ASSETS=true`

那就需要 GitHub token。

因为这套交付链会自动拉这些 release / archive：

- `fd-theme`
- `fd-admin-ui`
- `fd-member`
- `fd-payment`
- `fd-commerce`
- `fd-content-types`
- `fd-websocket-push`
- `wp-graphql-jwt-authentication`
- `wp-graphql-tax-query`

### 2. 前端镜像必须提前准备好

交付仓库不会帮你现场构建前端源码。

它要的是：

- 一个已经构建好的 `fd-frontend` 镜像
- 一个已经构建好的 `fd-websocket` 镜像

也就是说，空白服务器部署时，真正被拉起来的是镜像，不是源码。

## 首装完成后先检查什么

首装结束后，先检查这 4 个地址：

- `http://www.你的域名`
- `http://admin.你的域名`
- `http://ws.你的域名/health`
- `http://admin.你的域名/graphql`

最少确认这几件事：

- 前台能打开
- WordPress 后台能打开
- `/health` 返回正常
- `/graphql` 能正常响应

如果保留了默认演示数据，还可以再确认：

- `http://www.你的域名/about-us`

## 再切 HTTPS

HTTP 验收通过后，再执行 HTTPS 切换入口：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/FutureDecade/fd-headless-wp-system/main/scripts/remote-setup-https.sh)
```

这条命令会：

- 更新服务器上的交付仓库
- 进入 HTTPS 切换入口
- 收集这一步需要的凭据
- 调用 `scripts/setup-https.sh`

这里有一个前提不能省：

- 你的前端镜像里写入的公开地址，必须已经是正式 HTTPS 地址

也就是说，在切 HTTPS 前，你要先重新构建前端镜像，至少保证这些构建参数是正式值：

- `site_url=https://www.你的域名`
- `wordpress_url=https://admin.你的域名`
- `wordpress_api_url=https://admin.你的域名/graphql`
- `websocket_url=wss://ws.你的域名`

## 如果你不想走一条命令

也可以分步执行：

```bash
apt update
apt install -y git curl ca-certificates
git clone https://github.com/FutureDecade/fd-headless-wp-system.git /opt/fd-headless-wp-system
cd /opt/fd-headless-wp-system
bash scripts/prepare-server.sh
bash scripts/quick-install.sh
```

这和 `remote-install.sh` 本质上是同一条链路，只是拆开给你看。

## 首装失败时先看哪几个点

最常见的检查点就是这几个：

- 三个域名是否都已经解析到这台机器
- ACR 用户名密码是否正确
- GitHub token 是否有效
- `FRONTEND_IMAGE` 和 `WEBSOCKET_IMAGE` 是否是完整镜像地址
- GitHub Actions 里的 `Sync Base Images` 是否已经跑过
- 前端镜像里的公开地址是否和当前部署域名一致

## 后续怎么更新

这套系统后续更新，不是重新装一遍。

最稳的方式是：

- 改镜像 tag 或 release tag
- 然后执行 `bash scripts/update-stack.sh`

常用命令：

```bash
cd /opt/fd-headless-wp-system
ACR_USERNAME=你的阿里云账号 \
ACR_PASSWORD=你的ACR密码 \
GH_TOKEN=你的GitHubToken \
bash scripts/update-stack.sh
```

如果只是更新 WordPress 资产版本，也可以先改 tag：

```bash
cd /opt/fd-headless-wp-system
FD_THEME_RELEASE_TAG=v1.0.7 \
FD_ADMIN_UI_RELEASE_TAG=v1.3.1 \
FD_MEMBER_RELEASE_TAG=v1.0.1 \
FD_PAYMENT_RELEASE_TAG=v1.0.0 \
FD_COMMERCE_RELEASE_TAG=v1.0.0 \
FD_WEBSOCKET_PUSH_RELEASE_TAG=v1.0.0 \
WPGRAPHQL_JWT_AUTH_RELEASE_TAG=v0.7.2 \
WPGRAPHQL_TAX_QUERY_REF=v0.2.0 \
bash scripts/update-wordpress-release-tags.sh
```

然后再跑：

```bash
ACR_USERNAME=你的阿里云账号 \
ACR_PASSWORD=你的ACR密码 \
GH_TOKEN=你的GitHubToken \
bash scripts/update-stack.sh
```

## 这份文档和其它文档的关系

如果你现在只关心空白主机怎么装，这一份就够了。

其它文档可以按下面理解：

- `docs/BLANK-SERVER-QUICKSTART.md`
  - 更短的速查版
- `docs/INSTALL-AND-UPDATE.md`
  - 更完整的安装和更新说明
- `README.md`
  - 仓库总入口
