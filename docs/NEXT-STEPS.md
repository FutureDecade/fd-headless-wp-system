# 下一步执行顺序

这是当前最合理的推进顺序。

## 1. 固定策略

已完成：

- 建立交付仓库
- 建立顶层编排骨架
- 建立基础 CI

## 2. 优先治理 WebSocket 来源

已完成：

- `fd-websocket` 已整理为独立仓库
- 已补基础文档
- 已补基础 CI

接下来目标：

- 为 `fd-websocket` 补镜像发布能力
- 让交付层引用明确的镜像来源

## 3. 梳理 WordPress 可交付资产

已完成的前置工作：

- `fd-theme` 已独立成仓库
- `fd-member` 已独立成仓库
- `fd-payment` 已独立成仓库
- `fd-commerce` 已独立成仓库

重点不是整个 `wp-content` 打包，而是先区分：

- 必须进入交付版的
- 只是线上运行痕迹的
- 可选功能的

重点优先级：

1. `fd-theme`
2. `fd-member`
3. `fd-payment`
4. `fd-commerce`
5. 其余关键 `fd-*`
6. ACF 配置

## 4. 设计 staging 运行方式

需要先明确：

- staging 是否使用真实域名子域
- 是否先只用 HTTP
- 是否先不接支付和第三方服务

原则：

- staging 先追求可复现
- 不先追求完整生产能力

## 5. 再做第二版 compose

第二版 compose 的目标不是更复杂，
而是更贴近现有组件真实来源。

## 6. 最后才做 install.sh 增强

第一版脚本只是骨架。

真正的安装脚本要等：

- 组件来源稳定
- WordPress 资产稳定
- staging 跑通

之后再补。
