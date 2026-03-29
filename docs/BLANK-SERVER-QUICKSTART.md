# 空白服务器快速安装

这份是短版入口。

如果你想看更完整、更接近正式交付的版本，先看：

- `docs/ONE-CLICK-DEPLOY.md`

如果你现在只想马上在空白机上开始，就照这份走。

## 先准备好 4 样东西

1. 一台空白 Debian 12 服务器
2. 3 个已经解析到这台服务器的子域名
3. 阿里云 ACR 账号和密码
4. GitHub token

推荐域名这样分：

- 前台：`www.你的域名`
- 后台：`admin.你的域名`
- 推送：`ws.你的域名`

## 第 1 步：在 GitHub 先做一次基础镜像同步

进入 `fd-headless-wp-system` 仓库的 GitHub Actions，手动运行一次 `Sync Base Images`。

这一步的作用很直接：

- 把 `mariadb`、`redis`、`wordpress`、`wpcli`、`nginx`、`certbot` 同步到你自己的 ACR
- 避免空白服务器第一次安装时再去直接拉 Docker Hub

这一步每次新装服务器前都不用重复做。

## 第 2 步：登录服务器，拉交付仓库

现在这个交付仓库已经公开。

所以最省事的首装命令就是这一条：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/FutureDecade/fd-headless-wp-system/main/scripts/remote-install.sh)
```

这条命令会自动做这些事：

- 安装最基础的 `git`、`curl`、`ca-certificates`
- 把交付仓库拉到 `/opt/fd-headless-wp-system`
- 安装 Docker、Docker Compose、GitHub CLI
- 进入配置向导
- 收集首次安装需要的 ACR / GitHub 凭据
- 调用已经验证通过的首装流程

如果你想分步手工做，再继续看下面。

如果你还是想手工拉仓库：

```bash
apt update
apt install -y git curl ca-certificates
git clone https://github.com/FutureDecade/fd-headless-wp-system.git /opt/fd-headless-wp-system
cd /opt/fd-headless-wp-system
```

如果以后为了商业授权又改回私有，可以改成下面这套拉取方式：

```bash
apt update
apt install -y git curl ca-certificates
type -p curl >/dev/null || apt install -y curl
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list
apt update
apt install -y gh
gh auth login
gh repo clone FutureDecade/fd-headless-wp-system /opt/fd-headless-wp-system
cd /opt/fd-headless-wp-system
```

## 第 3 步：安装服务器基础环境

```bash
bash scripts/prepare-server.sh
```

这一步只安装这些东西：

- Docker
- Docker Compose
- GitHub CLI
- 常用系统工具

它不会启动你的项目服务。

## 第 4 步：生成 `.env`

```bash
bash scripts/configure-env.sh
```

这个脚本会按顺序问你这些值：

- 主域名
- 前台域名
- 后台域名
- 推送域名
- 前端镜像完整地址
- 推送镜像完整地址
- 证书通知邮箱
- 是否自动拉 WordPress 的主题和插件
- 是否自动完成首次 WordPress 安装

建议第一次就这样选：

- 自动拉 WordPress 主题和插件：`y`
- 自动完成首次 WordPress 安装：`y`

## 第 5 步：第一次安装

如果你已经使用上面那条 `remote-install.sh` 一条命令入口，这一步已经会自动带你走完。

如果你是手工分步操作，再执行下面这条：

```bash
ACR_USERNAME=你的阿里云账号 \
ACR_PASSWORD=你的ACR密码 \
GH_TOKEN=你的GitHubToken \
bash scripts/install.sh
```

这一步已经在真实空白服务器上跑通过。

它会按比较稳妥的顺序做这些事：

- 先检查配置有没有明显错误
- 拉取需要的镜像
- 拉取 WordPress 主题和插件 release
- 启动数据库、Redis、WordPress、前端、推送、Nginx
- 如果你在 `.env` 里打开了首次安装，就自动初始化 WordPress
- 做基础健康检查

## 第 6 步：先验收 HTTP

第一次不要急着切 HTTPS，先看最基本的联通是否正常。

先检查这 4 个地址：

- `http://www.你的域名`
- `http://admin.你的域名`
- `http://ws.你的域名/health`
- `http://admin.你的域名/graphql`

你至少应该确认：

- 前台能打开
- 后台能打开
- `/health` 能返回 `{"status":"ok"...}`
- `/graphql` 能正常响应

如果你保留了初始化示例页面，还可以再打开：

- `http://www.你的域名/sample-page`

## 第 7 步：再切 HTTPS

这一步前，先确认三件事已经成立：

1. `www`、`admin`、`ws` 三个域名都已经解析到这台服务器
2. HTTP 版本已经跑通
3. 前端镜像里写入的公开地址已经改成正式 HTTPS 地址

第 3 点很重要，因为前端镜像里有一部分公开地址是在构建镜像时写进去的。

也就是说，你要先在 `fd-frontend` 仓库重新构建一版正式镜像，构建参数至少要改成：

- `site_url=https://www.你的域名`
- `wordpress_url=https://admin.你的域名`
- `wordpress_api_url=https://admin.你的域名/graphql`
- `websocket_url=wss://ws.你的域名`

然后把新的前端镜像地址写回这台服务器的 `.env`。

如果你想继续用更少命令，也可以直接执行：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/FutureDecade/fd-headless-wp-system/main/scripts/remote-setup-https.sh)
```

这条命令会自动：

- 更新本机的交付仓库
- 进入 HTTPS 切换入口
- 收集这一步需要的 ACR / GitHub 凭据
- 调用 `setup-https.sh`

如果你想手工执行，再用下面这条：

确认无误后，再执行：

```bash
ACR_USERNAME=你的阿里云账号 \
ACR_PASSWORD=你的ACR密码 \
GH_TOKEN=你的GitHubToken \
bash scripts/setup-https.sh
```

这个脚本会：

- 先确认 HTTP 版本还正常
- 申请 Let’s Encrypt 证书
- 自动把 `.env` 改成 `https` 和 `wss`
- 重新启动整套服务

## 第 8 步：验收 HTTPS

切完以后检查：

- `https://www.你的域名`
- `https://admin.你的域名`
- `https://ws.你的域名/health`
- `https://www.你的域名/sample-page`

## 第 9 步：以后怎么更新

以后不要上去手工改容器，也不要直接在服务器改源码。

最稳妥的做法只有一句话：

- 改 `.env` 里的镜像 tag 或 release tag，然后执行 `bash scripts/update-stack.sh`

常见更新有两种。

前端或推送更新：

```bash
ACR_USERNAME=你的阿里云账号 \
ACR_PASSWORD=你的ACR密码 \
GH_TOKEN=你的GitHubToken \
bash scripts/update-stack.sh
```

WordPress 主题或插件更新：

1. 先把 `.env` 里的 tag 改成新版本
2. 再执行：

```bash
ACR_USERNAME=你的阿里云账号 \
ACR_PASSWORD=你的ACR密码 \
GH_TOKEN=你的GitHubToken \
bash scripts/update-stack.sh
```

## 当前已经确认的真实状态

截至 `2026-03-29`，下面这套链路已经在空白 Debian 12 服务器 `144.48.8.218` 上跑通并验收过：

- 首次安装
- WordPress 自动初始化
- `fd-websocket-push`
- `wp-graphql-jwt-authentication`
- `wp-graphql-tax-query-develop`
- `redis-cache`
- GraphQL 可用
- 示例页面可访问
- HTTPS 证书申请
- 前台、后台、推送三个域名联通

当前已经确认正常的正式地址：

- `https://www.futuredecade.com`
- `https://admin.futuredecade.com`
- `https://ws.futuredecade.com/health`

## 还没到“完全交付最终版”的地方

现在已经不是“架构方向不行”，而是还剩最后几项交付收尾：

- ACF 还没正式并入这条 release 交付链
- 付费授权链路还没有接上你未来的授权中台
- 还没有做成最终的客户授权安装器

如果你要看更完整的说明，再看：

- `docs/INSTALL-AND-UPDATE.md`
