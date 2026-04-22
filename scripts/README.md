# Scripts 目录

这里将存放交付过程需要的脚本。

后续预计包括：

- `install.sh`
- `quick-install.sh`
- `remote-install.sh`
- `configure-env.sh`
- `prepare-server.sh`
- `update-stack.sh`
- `record-available-runtime-images.sh`
- `apply-available-runtime-images.sh`
- `update-runtime-services.sh`
- `record-available-wordpress-release-tags.sh`
- `apply-available-wordpress-release-tags.sh`
- `report-deployment-status.sh`
- `run-pending-deployment-action.sh`
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

目前运行时镜像更新还新增了两条辅助脚本：

- `record-available-runtime-images.sh`
  - 把新的 `FRONTEND_IMAGE` / `WEBSOCKET_IMAGE` 记录成 `AVAILABLE_*`
  - 适合 `FD_RUNTIME_IMAGE_UPDATE_POLICY=manual` 的部署
- `apply-available-runtime-images.sh`
  - 把 `AVAILABLE_*` 提升为当前 `FRONTEND_IMAGE` / `WEBSOCKET_IMAGE`
  - 提升后仍需要再执行一次 `update-stack.sh` 才会真正拉镜像并重建容器
- `update-runtime-services.sh`
  - 只拉取并重建 `frontend`、`websocket`、`nginx`
  - 不触发 `wordpress`、`db`、`redis` 的受控更新流程
  - 适合前端镜像 tag 的独立更新
- `record-available-wordpress-release-tags.sh`
  - 把新的主题/插件/GraphQL release tag 记录成 `AVAILABLE_*_RELEASE_TAG`
  - 适合手动确认后再更新的部署
- `apply-available-wordpress-release-tags.sh`
  - 把 `AVAILABLE_*_RELEASE_TAG` 提升为当前 release tag
  - 提升后仍需要再执行一次 `update-stack.sh` 才会真正拉取资产并更新容器
- `report-deployment-status.sh`
  - 把当前/可用 runtime image 与 WordPress release 状态回报给 `fd-core-stack`
  - 依赖 bootstrap 下发的 `FD_STACK_DEPLOYMENT_ID`、`FD_STACK_STATUS_REPORT_URL`、`FD_STACK_STATUS_REPORT_TOKEN`
- `run-pending-deployment-action.sh`
  - 从 `fd-core-stack` 拉取待执行的 deployment 更新动作
  - 命中后自动执行“应用前端更新”或“应用 WP 资产更新”
  - 执行完会回报动作完成状态

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
