# Demo Data

`demo-cpt-content.v1.json` is the primary demo package for one-click deployment.

It contains:

- public pages and demo posts for the base site shell
- the current CPT set only: `note`, `app`, `event`, `product`
- 3 demo items per CPT
- footer and primary menu definitions
- taxonomy terms required by those CPTs
- inline SVG assets, so the package does not depend on legacy media or remote URLs

Generate it with:

```bash
php scripts/generate-demo-cpt-data.php
```

Notes:

- media-related fields use `asset_key` references instead of WordPress attachment IDs
- complex product fields such as badges and attributes stay structured in JSON, so the later importer can map them into the plugin's storage format
- import it during init with `WORDPRESS_IMPORT_DEMO_DATA=true` and `WORDPRESS_DEMO_DATA_FILE=demo-data/demo-cpt-content.v1.json`
- `legacy-site-demo-content.v1.json` is kept only as an archival reference from the earlier legacy-site exploration and is no longer the recommended import source
