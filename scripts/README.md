# Scripts 目录

这里将存放交付过程需要的脚本。

后续预计包括：

- `install.sh`
- `quick-install.sh`
- `remote-install.sh`
- `configure-env.sh`
- `prepare-server.sh`
- `update-stack.sh`
- `preflight-check.sh`
- `fetch-wordpress-assets.sh`
- `init-wordpress.sh`
- `setup-https.sh`
- `quick-setup-https.sh`
- `remote-setup-https.sh`
- `renew-https.sh`
- `health-check.sh`
- `backup.sh`
- `restore.sh`

第一阶段不会直接写生产安装脚本，
而是先补：

- 环境检查
- 配置生成
- 编排验证
- 测试服务器所需的 WordPress 制品拉取
- 测试服务器所需的 WordPress 初始化
- 测试服务器安全更新脚本
- 可选 HTTPS 证书申请与续期

目前 `install.sh` 已经改成一个更稳妥的首装入口：

- 如果 `.env` 不存在，会先自动生成
- 然后提醒你修改关键配置
- 真正执行安装时，会直接复用 `update-stack.sh`

目前 `quick-install.sh` 负责再往前收一层：

- 调用 `configure-env.sh`
- 按需收集 ACR / GitHub 凭据
- 再调用 `install.sh`

目前 `remote-install.sh` 负责最外层的一条命令首装：

- 在空白 Debian / Ubuntu 机器上安装最基础的拉仓库能力
- 拉取或更新交付仓库
- 调用 `prepare-server.sh`
- 再进入 `quick-install.sh`

目前 `configure-env.sh` 负责：

- 按顺序询问核心配置
- 自动写入 `.env`
- 尽量复用已有值
- 不启动任何服务

目前 `prepare-server.sh` 负责另一件事：

- 在干净的 Debian / Ubuntu 机器上安装基础命令
- 安装 Docker Engine 和 Docker Compose
- 安装 GitHub CLI
- 不碰项目容器，不启动业务服务

目前 `quick-setup-https.sh` 负责：

- 按需收集 ACR / GitHub 凭据
- 再调用 `setup-https.sh`

目前 `remote-setup-https.sh` 负责：

- 拉取或更新交付仓库
- 进入 `quick-setup-https.sh`
