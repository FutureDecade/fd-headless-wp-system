# Scripts 目录

这里将存放交付过程需要的脚本。

后续预计包括：

- `install.sh`
- `preflight-check.sh`
- `fetch-wordpress-assets.sh`
- `init-wordpress.sh`
- `health-check.sh`
- `backup.sh`
- `restore.sh`

第一阶段不会直接写生产安装脚本，
而是先补：

- 环境检查
- 配置生成
- 编排验证
- staging 所需的 WordPress 制品拉取
- staging 所需的 WordPress 初始化
