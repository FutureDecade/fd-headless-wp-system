# WordPress 资产接入策略

现在最关键的问题不是 WordPress 能不能跑，
而是：

- `fd-theme`
- `fd-admin-ui`
- `fd-member`
- `fd-payment`
- `fd-commerce`
- `fd-websocket-push`
- `wp-graphql-jwt-authentication`
- `wp-graphql-tax-query`

这些已经独立成仓库的资产，未来如何进入交付系统。

## 当前结论

现在不要直接在交付仓库里这样做：

- 复制插件源码
- 复制主题源码
- 用本地相对路径硬绑所有业务目录

这样会让交付仓库退化成大杂烩。

## 推荐分阶段策略

## 阶段 1：来源独立

已完成：

- 核心主题和插件已经独立成仓库

## 阶段 2：制品策略

这一步已经开始落地。

现在应该坚持的不是“把源码塞进交付仓库”，
而是“生成可交付制品，并固定后续引用方式”。

可选方式：

### 方案 A：Zip 制品

- `fd-theme.zip`
- `fd-admin-ui.zip`
- `fd-member.zip`
- `fd-payment.zip`
- `fd-commerce.zip`
- `fd-websocket-push.zip`

当前状态：

- 自有插件和主题已经具备 GitHub Actions 打包流程
- push 到 `main` 会生成对应 zip workflow artifact
- 发布 GitHub Release 时可以自动上传对应 zip asset
- `fd-websocket-push` 也已经纳入这条 release zip 路径
- 交付仓库已具备内部 staging 资产拉取脚本：`scripts/fetch-wordpress-assets.sh`
- 交付仓库已具备对应挂载文件：`compose/wordpress-assets.override.yml`
- 交付仓库已具备 WordPress 初始化脚本：`scripts/init-wordpress.sh`
- `wp-graphql-jwt-authentication` 走官方 release zip
- `wp-graphql-tax-query` 因为官方 release 没有 zip asset，所以暂时走官方仓库 archive
- `redis-cache` 目前不进 release 资产目录，首次安装时由 `wp-cli` 直接安装

优点：

- 符合 WordPress 习惯
- 易理解

缺点：

- 自动化安装时还要解压和拷贝

### 方案 B：自定义 WordPress 镜像

在镜像构建阶段把主题和插件打进去。

优点：

- 更接近一键部署
- 更适合正式交付

缺点：

- 需要更完整的版本和构建流程

## 当前最稳建议

当前最稳的是：

- 短期先用 zip 制品把 WordPress 资产来源固定住
- 当前内部 staging 路径：GitHub Release zip -> `runtime/wp-content` -> compose override bind mount
- 当前初始化路径：core services -> `wp-cli` -> `core install` / 安装 `WPGraphQL` / theme activate / plugin activate
- 中期再决定交付仓库到底是“下载 zip 安装”还是“构建自定义 WordPress 镜像”
- 长期再把 WordPress runtime 做成正式交付镜像

因为现在还缺：

- ACF 导出治理
- 个别外部插件的完全离线安装治理
- WordPress 初始化治理

## 当前阶段目标

当前阶段只需要先达成：

- 核心主题/插件来源独立
- 核心主题/插件具备基础 zip 打包能力
- 核心主题/插件具备首个正式 release
- 交付仓库文档明确下一步接入方向
- 交付仓库具备 staging 级别的 release zip 消费能力
- 交付仓库具备 staging 级别的 WordPress 初始化能力

之后再做：

- 在真实 Docker 环境完成首次安装验证
- WordPress 自定义镜像
- 自动安装
