# Runtime Assets

这个目录不存长期源码。

它只用于 staging / install 过程中放置临时拉取下来的 WordPress 制品，例如：

- `runtime/wp-content/themes/fd-theme`
- `runtime/wp-content/plugins/fd-admin-ui`
- `runtime/wp-content/plugins/fd-member`
- `runtime/wp-content/plugins/fd-payment`
- `runtime/wp-content/plugins/fd-commerce`
- `runtime/wp-content/plugins/fd-content-types`
- `runtime/wp-content/plugins/fd-ai-router`
- `runtime/wp-content/plugins/fd-websocket-push`
- `runtime/wp-content/plugins/wp-graphql-jwt-authentication`
- `runtime/wp-content/plugins/wp-graphql-tax-query-develop`

这些内容由 `scripts/fetch-wordpress-assets.sh` 生成。

如果启用了 HTTPS，这里还会出现：

- `runtime/certbot/www`
- `runtime/letsencrypt`
