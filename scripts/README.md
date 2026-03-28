# Scripts 目录

这里将存放交付过程需要的脚本。

后续预计包括：

- `install.sh`
- `update-stack.sh`
- `preflight-check.sh`
- `fetch-wordpress-assets.sh`
- `init-wordpress.sh`
- `setup-https.sh`
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
