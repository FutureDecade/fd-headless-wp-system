# GitHub 需要你做的事

你现在只需要做下面 4 件事。

## 1. 创建一个新的私有仓库

建议仓库名：

- `fd-headless-wp-system`

建议位置：

- 和 `FD-headless-wordpress` 同一个 GitHub 账号或组织下

创建时：

- 选 `Private`
- 默认分支用 `main`
- 不要勾选初始化 README
- 不要自动添加 `.gitignore`
- 不要自动添加 license

原因：

- 我会直接在本地把仓库骨架整理好，再推上去

## 2. 开启 GitHub Actions

仓库创建后确认：

- `Settings > Actions > General`
- 允许 Actions 运行

目前先不用配复杂权限。

## 3. 先不要急着配 Secrets

现在先不配服务器和生产密钥。

第一阶段我们先做：

- 仓库骨架
- 目录结构
- 顶层 compose
- 示例环境变量
- 校验型 CI

等这些稳定后，再补：

- `SERVER_HOST`
- `SERVER_USER`
- `SERVER_SSH_KEY`
- 镜像仓库账号密码
- 其他部署密钥

## 4. 创建好后，把仓库地址发给我

例如：

- `git@github.com:你的组织/fd-headless-wp-system.git`

或者：

- `https://github.com/你的组织/fd-headless-wp-system`

然后我来做：

- 本地初始化
- 目录骨架
- 第一版交付文档
- 顶层编排结构
- 第一版 CI
