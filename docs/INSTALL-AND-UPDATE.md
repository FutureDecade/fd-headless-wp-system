# 安装与更新说明

这份说明只讲三件事：

1. 一台空白 Debian 12 服务器，怎么从 0 装起来
2. 现在这套系统已经验证到什么程度
3. 后续代码更新后，怎么稳妥更新到别的机器

## 1. 当前验证状态

截至 2026-03-28，这套交付骨架已经在测试服务器 `144.48.8.218` 跑通，并完成了正式域名的 HTTPS 验证。

当前测试域名：

- 前台：`https://www.futuredecade.com`
- 后台：`https://admin.futuredecade.com`
- 推送：`wss://ws.futuredecade.com`

当前已验证通过：

- `http://www.futuredecade.com` 会自动跳转到 `https://www.futuredecade.com`
- `https://www.futuredecade.com` 可正常返回 `200`
- `https://admin.futuredecade.com` 可正常返回 `200`
- `https://ws.futuredecade.com/health` 可正常返回健康状态
- 前端容器可正常启动，并通过健康检查
- WebSocket 容器可正常启动，并通过 `/health`
- Nginx 反向代理可把三个域名分别转发到前端、WordPress、推送服务
- WordPress 可正常启动
- `fd-theme` 已作为 release 资产挂载并启用
- `wp-graphql` 已安装并启用
- `fd-member` 已启用
- `fd-payment` 已启用
- `fd-commerce` 已启用
- `/graphql` 路由可正常返回 `slugMappingTable`
- 前台首页和示例页面可正常访问
- 前端主要旧域名硬编码已经去掉，页面源码里不再残留 `sslip.io`、`http://admin.futuredecade.com`、`ws://ws.futuredecade.com`
- 基础镜像已经切到你自己的 ACR，不再依赖 Docker Hub 拉 `nginx` 和 `wordpress`
- `GraphQL generalSettings.url` 现在已经是 `https://admin.futuredecade.com`
- Let’s Encrypt 正式证书已经申请成功

当前测试机使用的关键版本：

- `fd-theme`: `v1.0.4`
- `fd-frontend`: `crpi-8y82lbqoc1haiday.cn-beijing.personal.cr.aliyuncs.com/futuredecade/fd-frontend:futuredecade-https-8862356`
- `fd-websocket`: `crpi-8y82lbqoc1haiday.cn-beijing.personal.cr.aliyuncs.com/futuredecade/fd-websocket:248efba2800ce856e043d673233bc5f5205e2a40`

当前关于 HTTPS 的状态：

- HTTPS 脚本、compose 配置、CI 校验已经补上
- 已经在正式域名下真实申请到 Let’s Encrypt 证书
- 当前测试机已经切到 `https/wss`
- 当前证书有效期到 `2026-06-26`

## 2. 一台空白服务器怎么装

### 第一步：准备系统环境

建议系统：

- Debian 12

先安装基础命令：

```bash
apt update
apt install -y git curl unzip openssl perl ca-certificates
```

再安装 Docker 和 Docker Compose。

如果服务器需要自动从 GitHub release 拉 WordPress 主题/插件，还需要安装 GitHub CLI：

```bash
type -p curl >/dev/null || apt install -y curl
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list
apt update
apt install -y gh
```

### 第二步：准备域名

你需要准备 3 个域名，都解析到同一台服务器公网 IP：

- 前台域名，例如 `www.xxx.com`
- 后台域名，例如 `admin.xxx.com`
- 推送域名，例如 `ws.xxx.com`

如果只是临时测试，也可以先用 `sslip.io` 或者临时子域名，等前后端联通后再换正式域名。

### 第三步：拉交付仓库

```bash
git clone https://github.com/FutureDecade/fd-headless-wp-system.git /opt/fd-headless-wp-system
cd /opt/fd-headless-wp-system
```

### 第四步：先把基础镜像同步到你自己的 ACR

这一步只需要在 GitHub 上做，不需要在服务器上做。

在 `fd-headless-wp-system` 仓库里手动运行一次 `Sync Base Images`。

它会把下面这些基础镜像推到你自己的 ACR：

- `mariadb:10.11`
- `redis:7`
- `wordpress:6.8.3-php8.2-apache`
- `wordpress:cli-2.12.0`
- `nginx:1.27-alpine`
- `certbot/certbot:latest`

做完这一步之后，空白服务器首次安装就不再依赖 Docker Hub。

### 第五步：生成 `.env`

```bash
cp .env.example .env
bash scripts/bootstrap-env.sh
```

然后手工修改 `.env`。至少要改这些：

- `FRONTEND_DOMAIN`
- `ADMIN_DOMAIN`
- `WS_DOMAIN`
- `PUBLIC_SCHEME`
- `WEBSOCKET_PUBLIC_SCHEME`
- `FRONTEND_IMAGE`
- `WEBSOCKET_IMAGE`
- `MYSQL_PASSWORD`
- `MYSQL_ROOT_PASSWORD`
- `JWT_SECRET`
- `PUSH_SECRET`
- `REVALIDATE_SECRET`
- `WORDPRESS_ADMIN_PASSWORD`
- `WORDPRESS_ADMIN_EMAIL`
- `LETSENCRYPT_EMAIL`

首次启动建议这样填：

- `PUBLIC_SCHEME=http`
- `WEBSOCKET_PUBLIC_SCHEME=ws`
- `HTTPS_ENABLED=false`
- `HTTPS_PORT=443`

原因很简单：

- 先用最朴素的 `http/ws` 把整套服务跑通
- 确认前台、后台、推送都正常以后
- 再切 `https/wss`

如果这台机器要自动拉 GitHub release 里的主题和插件，还要确认这些：

- `WORDPRESS_FETCH_RELEASE_ASSETS=true`
- `FD_THEME_RELEASE_TAG=v1.0.4`
- `FD_MEMBER_RELEASE_TAG=...`
- `FD_PAYMENT_RELEASE_TAG=...`
- `FD_COMMERCE_RELEASE_TAG=...`

如果这台机器要自动完成首次 WordPress 安装，还要确认这些：

- `WORDPRESS_RUN_INIT=true`
- `WORDPRESS_TITLE=你的站点名`
- `WORDPRESS_ADMIN_USER=你的后台管理员用户名`
- `WORDPRESS_ADMIN_PASSWORD=你的后台管理员密码`
- `WORDPRESS_ADMIN_EMAIL=你的后台管理员邮箱`

### 第六步：登录 ACR

因为前端和 WebSocket 镜像都在阿里云 ACR 私有仓库，所以第一次部署前要登录：

```bash
docker login --username=你的阿里云账号 crpi-8y82lbqoc1haiday.cn-beijing.personal.cr.aliyuncs.com
```

或者直接在执行更新脚本时把账号密码临时带进去：

```bash
ACR_USERNAME=你的阿里云账号 ACR_PASSWORD=你的ACR密码 bash scripts/update-stack.sh
```

### 第七步：如果要拉 GitHub release 资产，先登录 GitHub CLI

```bash
gh auth login
```

或者直接导出 token：

```bash
export GH_TOKEN=你的GitHubToken
```

### 第八步：预检查

```bash
bash scripts/preflight-check.sh
```

### 第九步：正式启动

最稳妥的方式是直接跑统一更新脚本：

```bash
ACR_USERNAME=你的阿里云账号 ACR_PASSWORD=你的ACR密码 GH_TOKEN=你的GitHubToken bash scripts/update-stack.sh
```

如果你是第一次安装，也可以用：

```bash
ACR_USERNAME=你的阿里云账号 ACR_PASSWORD=你的ACR密码 GH_TOKEN=你的GitHubToken bash scripts/install.sh
```

当前更推荐 `update-stack.sh`，因为它已经带了：

- 预检查
- 基础镜像拉取
- WordPress release 资产同步
- 安全顺序更新
- 容器健康检查
- 前台 / 推送 / GraphQL 的基本验收

### 第十步：如果你要切正式 HTTPS

先说明一件事：

前端交付镜像里有一部分公开地址是在构建镜像时写进去的。

所以你准备切到正式 HTTPS 时，顺序要这样走：

1. 先确认 3 个正式域名已经全部解析到这台服务器
2. 先在前端仓库重新构建一版正式交付镜像
3. 构建参数里把：
   - `wordpress_api_url` 改成 `https://你的后台域名/graphql`
   - `wordpress_url` 改成 `https://你的后台域名`
   - `site_url` 改成 `https://你的前台域名`
   - `websocket_url` 改成 `wss://你的推送域名`
4. 把新的前端镜像 tag 写进这台服务器的 `.env`
5. 再运行：

```bash
ACR_USERNAME=你的阿里云账号 ACR_PASSWORD=你的ACR密码 bash scripts/setup-https.sh
```

如果这台机器本来就依赖 `GH_TOKEN` 拉私有主题和插件，就把 `GH_TOKEN` 一起带上。

这个脚本会做 5 件事：

- 先确保当前 HTTP 栈正常
- 申请 Let’s Encrypt 证书
- 自动把 `.env` 改成 `HTTPS_ENABLED=true`
- 自动把 `HTTPS_PORT` 补成 `443`
- 自动把 `PUBLIC_SCHEME` 改成 `https`，把 `WEBSOCKET_PUBLIC_SCHEME` 改成 `wss`

后续证书续期直接运行：

```bash
ACR_USERNAME=你的阿里云账号 ACR_PASSWORD=你的ACR密码 bash scripts/renew-https.sh
```

## 3. 域名和访问逻辑

外部访问路径是这样：

- 用户访问前台域名
- 外层 Nginx 按域名转发
- 前台域名转给 `frontend`
- 后台域名转给 `wordpress`
- 推送域名转给 `websocket`

所以这里是“双层 Web 服务”结构：

- WordPress 容器内部用 Apache
- 对外统一入口用 Nginx

这不是冲突，而是现在这套架构本来就这样设计的。

## 4. 现在功能是否完全正常

就“基础交付链路”来说，当前测试机已经可用，而且现在验证的是正式域名下的 HTTPS 访问，不再是临时测试域名。

已经确认正常：

- 前台首页能打开
- `/sample-page` 能打开
- WebSocket `/health` 正常
- GraphQL 路由正常
- WordPress 主题和核心插件都处于启用状态

但目前还不能说“已经完全最终版可商用交付”，因为还剩这些收尾项：

- ACF 还没并入当前 release 交付链路
- 一些次级页面的 SEO 文案、Twitter 元信息里还残留旧品牌文字
- 联系方式这类前端公开信息，后面还要整理成更清晰的交付参数
- 还没有做真正的客户级一键安装脚本

## 5. 不同服务器以后怎么更新

### 前端或 WebSocket 有新镜像

修改 `.env` 里的镜像 tag，然后更新：

```bash
FRONTEND_IMAGE=新的前端镜像 WEBSOCKET_IMAGE=新的推送镜像 bash scripts/update-runtime-images.sh
ACR_USERNAME=你的阿里云账号 ACR_PASSWORD=你的ACR密码 GH_TOKEN=你的GitHubToken bash scripts/update-stack.sh
```

### WordPress 主题或插件有新 release

修改 `.env` 里的 release tag：

```bash
FD_THEME_RELEASE_TAG=v1.0.4 bash scripts/update-wordpress-release-tags.sh
```

然后执行更新：

```bash
ACR_USERNAME=你的阿里云账号 ACR_PASSWORD=你的ACR密码 GH_TOKEN=你的GitHubToken bash scripts/update-stack.sh
```

### 最推荐的更新顺序

最稳妥的做法永远是：

1. 先出新的前端镜像
2. 再出新的主题 / 插件 release
3. 最后在目标服务器只改 `.env` 里的 tag
4. 再跑一次 `update-stack.sh`

这样更新是可追踪、可回滚、风险最小的。

## 6. 回滚怎么做

如果某次更新有问题，不要改代码，先回滚 tag：

- 把 `.env` 的 `FRONTEND_IMAGE` 改回上一个稳定 tag
- 把 `.env` 的 `FD_THEME_RELEASE_TAG` 改回上一个稳定 tag
- 再跑一次 `bash scripts/update-stack.sh`

这就是现在这套“镜像 + release tag”方案最大的价值。

## 7. 当前结论

现在这套项目已经从“只能你自己本机/现有服务器跑”推进到：

- 可以明确版本
- 可以从空白机器部署
- 可以按镜像 tag / release tag 更新
- 已经在测试机完成正式域名 Let’s Encrypt HTTPS 验证
- 可以不动线上旧系统，先在新机器验证

离真正“商业化一键交付”的差距，已经不是架构方向问题了，主要是最后一层工程封装和交付细节。
