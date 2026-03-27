# 组件来源说明

这个文件用于固定系统层面的边界。

## 当前组件来源

### 前端

- 组件名：`fd-frontend`
- 当前来源：独立 Git 仓库
- 当前状态：已工程化，已有 CI/CD
- 未来在交付仓库中的引用方式：
  - 优先使用版本化镜像

### WebSocket

- 组件名：`fd-websocket`
- 当前来源：独立 Git 仓库
- 当前仓库：`https://github.com/FutureDecade/fd-websocket`
- 当前状态：已独立入 Git，并具备基础 CI 与 GHCR 镜像发布
- 未来在交付仓库中的引用方式：
  - 短期直接引用 GHCR 镜像
  - 中期补版本标签治理
  - 当前镜像：`ghcr.io/futuredecade/fd-websocket:latest`

### WordPress

- 组件名：WordPress Runtime
- 当前来源：官方镜像 + 服务器内 `wp-content`
- 当前状态：运行正常，但未产品化
- 未来在交付仓库中的引用方式：
  - 短期先保留官方镜像
  - 中期补自定义主题/插件打包
  - 长期考虑自定义 WordPress 镜像

### Theme / Plugins

- `fd-theme`
- `fd-member`
- `fd-payment`
- `fd-commerce`
- 其他 `fd-*` 插件

当前状态：

- 已有独立 Git 仓库来源：
  - `https://github.com/FutureDecade/fd-theme`
  - `https://github.com/FutureDecade/fd-member`
  - `https://github.com/FutureDecade/fd-payment`
  - `https://github.com/FutureDecade/fd-commerce`
- 四个核心仓库都已具备基础 PHP CI
- 四个核心仓库都已具备 zip 打包 workflow artifact
- 四个核心仓库都已具备首个正式 release `v1.0.0`
- 交付仓库已可消费这些 release zip 做内部 staging
- 交付仓库已可用 `wp-cli` 做首次安装与启用
- 线上也有运行中的副本
- 其余 `fd-*` 组件仍未完全独立治理
- 还没有完成正式安装链路验证

未来方向：

- 每个核心插件/主题有独立版本来源
- 交付仓库只引用版本和制品

## 当前交付仓库原则

这个仓库不直接承载长期业务开发。

它只负责：

- 规定组件之间如何连接
- 规定每个组件需要哪些变量
- 规定安装和部署入口
