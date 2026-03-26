# Runtime Assets

这个目录不存长期源码。

它只用于 staging / install 过程中放置临时拉取下来的 WordPress 制品，例如：

- `runtime/wp-content/themes/fd-theme`
- `runtime/wp-content/plugins/fd-member`
- `runtime/wp-content/plugins/fd-payment`
- `runtime/wp-content/plugins/fd-commerce`

这些内容由 `scripts/fetch-wordpress-assets.sh` 生成。
