# Compose 目录

这里将存放顶层编排文件。

规划中的核心文件：

- `docker-compose.yml`
- `docker-compose.override.yml`
- `docker-compose.staging.yml`

第一阶段目标：

- 用一个顶层 compose 编排现有前端、websocket、wordpress、db、redis、reverse-proxy

第一阶段原则：

- 尽量复用现有服务定义
- 不先重写业务代码
- 不直接动生产配置
