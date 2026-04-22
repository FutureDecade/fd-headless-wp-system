# Demo Data

`demo-cpt-content.v1.json` is the primary demo package for one-click deployment.

It contains:

- public pages, page composer showcase pages, and demo posts for the base site shell
- demo content for `post`, `page`, `note`, `app`, `event`, `product`, and `fd_form`
- editorial and generic page composer layouts aligned with current frontend support
- footer and primary menu definitions
- taxonomy terms required by those CPTs
- custom taxonomies, member levels, and demo comments used by the current stack
- inline SVG assets, so the package does not depend on legacy media or remote URLs

Generate it with:

```bash
php scripts/generate-demo-cpt-data.php
```

Notes:

- media-related fields use `asset_key` references instead of WordPress attachment IDs
- complex product fields such as badges and attributes stay structured in JSON, so the later importer can map them into the plugin's storage format
- page composer layouts may include stable post/category/taxonomy references that the importer resolves to runtime IDs during install
- import it during init with `WORDPRESS_IMPORT_DEMO_DATA=true` and `WORDPRESS_DEMO_DATA_FILE=demo-data/demo-cpt-content.v1.json`
- `legacy-site-demo-content.v1.json` is kept only as an archival reference from the earlier legacy-site exploration and is no longer the recommended import source
