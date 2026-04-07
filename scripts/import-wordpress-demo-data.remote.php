<?php
/**
 * Import the packaged demo data into WordPress.
 */

declare(strict_types=1);

if (!defined('ABSPATH')) {
    $wpLoad = dirname(__DIR__, 2) . '/wp-load.php';

    if (!is_file($wpLoad)) {
        fwrite(STDERR, "Unable to locate wp-load.php\n");
        exit(1);
    }

    require_once $wpLoad;
}

require_once ABSPATH . 'wp-admin/includes/image.php';
require_once ABSPATH . 'wp-admin/includes/file.php';
require_once ABSPATH . 'wp-admin/includes/media.php';

function fd_demo_out(string $message): void
{
    fwrite(STDOUT, $message . PHP_EOL);
}

function fd_demo_fail(string $message, int $code = 1): void
{
    fwrite(STDERR, $message . PHP_EOL);
    exit($code);
}

function fd_demo_frontend_base_url(): string
{
    $base = defined('FD_FRONTEND_URL') ? (string) constant('FD_FRONTEND_URL') : home_url('/');

    return rtrim($base, '/');
}

function fd_demo_join_url(string $base, string $path = ''): string
{
    if ($path === '' || $path === '/') {
        return $base . '/';
    }

    return $base . '/' . ltrim($path, '/');
}

function fd_demo_replace_demo_urls($value)
{
    $frontendBase = fd_demo_frontend_base_url();
    $replacements = [
        'https://demo.futuredecade.local' => $frontendBase,
        'http://demo.futuredecade.local' => $frontendBase,
    ];

    if (is_array($value)) {
        foreach ($value as $key => $item) {
            $value[$key] = fd_demo_replace_demo_urls($item);
        }

        return $value;
    }

    if (!is_string($value)) {
        return $value;
    }

    return strtr($value, $replacements);
}

function fd_demo_parse_args(): array
{
    $argv = $_SERVER['argv'] ?? [];

    array_shift($argv);

    $jsonPath = '';
    $force = false;

    foreach ($argv as $arg) {
        if ($arg === '--force') {
            $force = true;
            continue;
        }

        if ($jsonPath === '') {
            $jsonPath = $arg;
        }
    }

    if ($jsonPath === '') {
        fd_demo_fail('Usage: php import-wordpress-demo-data.remote.php <demo-data.json> [--force]');
    }

    return [$jsonPath, $force];
}

function fd_demo_load_package(string $jsonPath): array
{
    if (!is_file($jsonPath)) {
        fd_demo_fail(sprintf('Demo data file does not exist: %s', $jsonPath));
    }

    $json = file_get_contents($jsonPath);

    if ($json === false) {
        fd_demo_fail(sprintf('Unable to read demo data file: %s', $jsonPath));
    }

    $package = json_decode($json, true);

    if (!is_array($package)) {
        fd_demo_fail(sprintf('Demo data JSON is invalid: %s', $jsonPath));
    }

    return $package;
}

function fd_demo_package_signature(string $jsonPath): string
{
    $hash = sha1_file($jsonPath);

    if ($hash === false) {
        fd_demo_fail(sprintf('Unable to hash demo data file: %s', $jsonPath));
    }

    return basename($jsonPath) . ':' . $hash;
}

function fd_demo_pick_author_id(): int
{
    $adminIds = get_users([
        'role' => 'administrator',
        'number' => 1,
        'fields' => 'ids',
        'orderby' => 'ID',
        'order' => 'ASC',
    ]);

    if (!empty($adminIds)) {
        return (int) $adminIds[0];
    }

    $userIds = get_users([
        'number' => 1,
        'fields' => 'ids',
        'orderby' => 'ID',
        'order' => 'ASC',
    ]);

    if (!empty($userIds)) {
        return (int) $userIds[0];
    }

    return 1;
}

function fd_demo_normalize_post_dates(?string $rawDate): array
{
    if ($rawDate === null || trim($rawDate) === '') {
        return [
            'post_date' => current_time('mysql'),
            'post_date_gmt' => current_time('mysql', true),
        ];
    }

    try {
        $date = new DateTimeImmutable($rawDate);
    } catch (Throwable $throwable) {
        $timestamp = strtotime($rawDate);

        if ($timestamp === false) {
            return [
                'post_date' => current_time('mysql'),
                'post_date_gmt' => current_time('mysql', true),
            ];
        }

        $date = (new DateTimeImmutable('@' . $timestamp))->setTimezone(wp_timezone());
    }

    return [
        'post_date' => $date->format('Y-m-d H:i:s'),
        'post_date_gmt' => $date->setTimezone(new DateTimeZone('UTC'))->format('Y-m-d H:i:s'),
    ];
}

function fd_demo_find_post_id(string $postType, string $slug): int
{
    $posts = get_posts([
        'post_type' => $postType,
        'name' => $slug,
        'post_status' => ['publish', 'draft', 'pending', 'future', 'private'],
        'posts_per_page' => 1,
        'fields' => 'ids',
        'orderby' => 'ID',
        'order' => 'ASC',
        'suppress_filters' => false,
    ]);

    return isset($posts[0]) ? (int) $posts[0] : 0;
}

function fd_demo_term_id($term)
{
    if (is_array($term)) {
        return isset($term['term_id']) ? (int) $term['term_id'] : 0;
    }

    return is_numeric($term) ? (int) $term : 0;
}

function fd_demo_ensure_term(array $term, array &$state): int
{
    $taxonomy = (string) ($term['taxonomy'] ?? '');
    $slug = (string) ($term['slug'] ?? '');

    if ($taxonomy === '' || $slug === '') {
        return 0;
    }

    if (!taxonomy_exists($taxonomy)) {
        fd_demo_out(sprintf('Skipping unknown taxonomy: %s', $taxonomy));
        return 0;
    }

    $existing = term_exists($slug, $taxonomy);
    $termId = fd_demo_term_id($existing);

    $args = [
        'slug' => $slug,
        'description' => (string) ($term['description'] ?? ''),
    ];

    if ($termId > 0) {
        $updated = wp_update_term($termId, $taxonomy, $args);

        if (is_wp_error($updated)) {
            fd_demo_fail(sprintf('Failed to update term %s:%s: %s', $taxonomy, $slug, $updated->get_error_message()));
        }

        $termId = fd_demo_term_id($updated);
    } else {
        $created = wp_insert_term((string) ($term['name'] ?? $slug), $taxonomy, $args);

        if (is_wp_error($created)) {
            fd_demo_fail(sprintf('Failed to create term %s:%s: %s', $taxonomy, $slug, $created->get_error_message()));
        }

        $termId = fd_demo_term_id($created);
    }

    $state['terms'][$taxonomy][$slug] = $termId;

    return $termId;
}

function fd_demo_import_terms(array $terms, array &$state): void
{
    foreach ($terms as $term) {
        if (!is_array($term)) {
            continue;
        }

        fd_demo_ensure_term($term, $state);
    }

    foreach ($terms as $term) {
        if (!is_array($term)) {
            continue;
        }

        $taxonomy = (string) ($term['taxonomy'] ?? '');
        $slug = (string) ($term['slug'] ?? '');
        $parentSlug = (string) ($term['parent_slug'] ?? '');

        if ($taxonomy === '' || $slug === '' || $parentSlug === '') {
            continue;
        }

        $termId = (int) ($state['terms'][$taxonomy][$slug] ?? 0);
        $parentId = (int) ($state['terms'][$taxonomy][$parentSlug] ?? 0);

        if ($termId < 1 || $parentId < 1) {
            continue;
        }

        $updated = wp_update_term($termId, $taxonomy, ['parent' => $parentId]);

        if (is_wp_error($updated)) {
            fd_demo_fail(sprintf('Failed to set parent for term %s:%s: %s', $taxonomy, $slug, $updated->get_error_message()));
        }
    }
}

function fd_demo_find_attachment_by_key(string $assetKey): int
{
    $posts = get_posts([
        'post_type' => 'attachment',
        'post_status' => 'inherit',
        'posts_per_page' => 1,
        'fields' => 'ids',
        'meta_key' => '_fd_demo_asset_key',
        'meta_value' => $assetKey,
        'orderby' => 'ID',
        'order' => 'ASC',
        'suppress_filters' => false,
    ]);

    return isset($posts[0]) ? (int) $posts[0] : 0;
}

function fd_demo_ensure_asset(array $asset, array &$state): int
{
    $key = (string) ($asset['key'] ?? '');
    $sourceType = (string) ($asset['source_type'] ?? '');
    $filename = (string) ($asset['filename'] ?? '');

    if ($key === '' || $sourceType !== 'inline_svg' || $filename === '') {
        return 0;
    }

    $uploads = wp_upload_dir();

    if (!empty($uploads['error'])) {
        fd_demo_fail('WordPress uploads directory is unavailable: ' . $uploads['error']);
    }

    $relativePath = 'fd-demo-assets/' . ltrim($filename, '/');
    $absolutePath = trailingslashit($uploads['basedir']) . $relativePath;
    $directory = dirname($absolutePath);

    if (!wp_mkdir_p($directory)) {
        fd_demo_fail(sprintf('Unable to create asset directory: %s', $directory));
    }

    $svg = (string) ($asset['svg'] ?? '');

    if ($svg === '' || file_put_contents($absolutePath, $svg) === false) {
        fd_demo_fail(sprintf('Unable to write demo asset: %s', $absolutePath));
    }

    $attachmentId = fd_demo_find_attachment_by_key($key);
    $attachment = [
        'post_mime_type' => (string) ($asset['mime_type'] ?? 'image/svg+xml'),
        'post_title' => (string) ($asset['title'] ?? $key),
        'post_content' => '',
        'post_excerpt' => '',
        'post_status' => 'inherit',
        'guid' => trailingslashit($uploads['baseurl']) . $relativePath,
    ];

    if ($attachmentId > 0) {
        $attachment['ID'] = $attachmentId;
        wp_update_post(wp_slash($attachment));
    } else {
        $attachmentId = wp_insert_attachment(wp_slash($attachment), $absolutePath, 0, true);

        if (is_wp_error($attachmentId)) {
            fd_demo_fail(sprintf('Failed to create attachment for %s: %s', $key, $attachmentId->get_error_message()));
        }
    }

    update_post_meta($attachmentId, '_fd_demo_asset_key', $key);
    update_post_meta($attachmentId, '_wp_attached_file', $relativePath);
    update_post_meta($attachmentId, '_wp_attachment_image_alt', (string) ($asset['title'] ?? ''));
    update_post_meta($attachmentId, '_fd_demo_asset_width', (int) ($asset['width'] ?? 0));
    update_post_meta($attachmentId, '_fd_demo_asset_height', (int) ($asset['height'] ?? 0));

    $state['attachments'][$key] = (int) $attachmentId;

    return (int) $attachmentId;
}

function fd_demo_import_assets(array $assets, array &$state): void
{
    foreach ($assets as $asset) {
        if (!is_array($asset)) {
            continue;
        }

        fd_demo_ensure_asset($asset, $state);
    }
}

function fd_demo_attachment_id_from_ref($ref, array &$state): int
{
    if (!is_array($ref)) {
        return 0;
    }

    $assetKey = (string) ($ref['asset_key'] ?? '');

    if ($assetKey === '') {
        return 0;
    }

    $attachmentId = (int) ($state['attachments'][$assetKey] ?? 0);

    if ($attachmentId < 1) {
        return 0;
    }

    $alt = (string) ($ref['alt'] ?? '');

    if ($alt !== '') {
        update_post_meta($attachmentId, '_wp_attachment_image_alt', $alt);
    }

    return $attachmentId;
}

function fd_demo_attachment_ids_from_refs($refs, array &$state): array
{
    if (!is_array($refs)) {
        return [];
    }

    $ids = [];

    foreach ($refs as $ref) {
        $attachmentId = fd_demo_attachment_id_from_ref($ref, $state);

        if ($attachmentId > 0) {
            $ids[] = $attachmentId;
        }
    }

    return array_values(array_unique($ids));
}

function fd_demo_should_delete_meta($value): bool
{
    return $value === null || $value === '' || (is_array($value) && $value === []);
}

function fd_demo_upsert_meta(int $postId, string $key, $value): void
{
    if (fd_demo_should_delete_meta($value)) {
        delete_post_meta($postId, $key);
        return;
    }

    if (is_bool($value)) {
        update_post_meta($postId, $key, $value ? '1' : '0');
        return;
    }

    update_post_meta($postId, $key, $value);
}

function fd_demo_set_featured_media(int $postId, $ref, array &$state): void
{
    $attachmentId = fd_demo_attachment_id_from_ref($ref, $state);

    if ($attachmentId > 0) {
        set_post_thumbnail($postId, $attachmentId);
        return;
    }

    delete_post_thumbnail($postId);
}

function fd_demo_set_taxonomies(int $postId, array $taxonomies, array &$state): void
{
    foreach ($taxonomies as $taxonomy => $terms) {
        if (!taxonomy_exists($taxonomy) || !is_array($terms)) {
            continue;
        }

        $termIds = [];

        foreach ($terms as $term) {
            if (!is_array($term)) {
                continue;
            }

            $slug = (string) ($term['slug'] ?? '');

            if ($slug === '') {
                continue;
            }

            $termId = (int) ($state['terms'][$taxonomy][$slug] ?? 0);

            if ($termId < 1) {
                $termId = fd_demo_ensure_term([
                    'taxonomy' => $taxonomy,
                    'slug' => $slug,
                    'name' => (string) ($term['name'] ?? $slug),
                    'description' => (string) ($term['description'] ?? ''),
                    'parent_slug' => $term['parent_slug'] ?? null,
                ], $state);
            }

            if ($termId > 0) {
                $termIds[] = $termId;
            }
        }

        wp_set_object_terms($postId, array_values(array_unique($termIds)), $taxonomy, false);
    }
}

function fd_demo_map_post_meta(array $item, array &$state): array
{
    $meta = fd_demo_replace_demo_urls($item['meta'] ?? []);

    if (!is_array($meta)) {
        return [];
    }

    if (isset($meta['additional_images'])) {
        $meta['additional_images'] = fd_demo_attachment_ids_from_refs($meta['additional_images'], $state);
    }

    return $meta;
}

function fd_demo_map_note_meta(array $item, array &$state): array
{
    $meta = fd_demo_replace_demo_urls($item['meta'] ?? []);

    return is_array($meta) ? $meta : [];
}

function fd_demo_map_app_meta(array $item, array &$state): array
{
    $meta = fd_demo_replace_demo_urls($item['meta'] ?? []);
    $media = $item['media'] ?? [];

    if (!is_array($meta)) {
        $meta = [];
    }

    if (is_array($media)) {
        $meta['app_icon'] = fd_demo_attachment_id_from_ref($media['icon'] ?? null, $state);
        $meta['app_screenshots'] = fd_demo_attachment_ids_from_refs($media['screenshots'] ?? [], $state);
    }

    return $meta;
}

function fd_demo_map_event_speakers(array $speakers, array &$state): array
{
    $clean = [];

    foreach ($speakers as $speaker) {
        if (!is_array($speaker)) {
            continue;
        }

        $speaker = fd_demo_replace_demo_urls($speaker);
        $speaker['speaker_avatar'] = fd_demo_attachment_id_from_ref($speaker['speaker_avatar'] ?? null, $state);
        $clean[] = $speaker;
    }

    return $clean;
}

function fd_demo_map_event_meta(array $item, array &$state): array
{
    $meta = fd_demo_replace_demo_urls($item['meta'] ?? []);
    $media = $item['media'] ?? [];

    if (!is_array($meta)) {
        $meta = [];
    }

    if (is_array($media)) {
        $meta['event_banner'] = fd_demo_attachment_id_from_ref($media['banner'] ?? null, $state);
        $meta['event_logo'] = fd_demo_attachment_id_from_ref($media['logo'] ?? null, $state);
        $meta['event_organizer_logo'] = fd_demo_attachment_id_from_ref($media['organizer_logo'] ?? null, $state);
        $meta['event_photos'] = fd_demo_attachment_ids_from_refs($media['photos'] ?? [], $state);
    }

    $meta['event_speakers'] = fd_demo_map_event_speakers($meta['event_speakers'] ?? [], $state);

    return $meta;
}

function fd_demo_map_product_meta(array $item, array &$state): array
{
    $meta = fd_demo_replace_demo_urls($item['meta'] ?? []);
    $media = $item['media'] ?? [];

    if (!is_array($meta)) {
        $meta = [];
    }

    $galleryIds = [];

    if (is_array($media)) {
        $galleryIds = fd_demo_attachment_ids_from_refs($media['gallery'] ?? [], $state);
    }

    $meta['_fd_product_gallery'] = wp_json_encode($galleryIds);
    $meta['_fd_product_badges'] = wp_json_encode(array_values((array) ($meta['_fd_product_badges'] ?? [])));
    $meta['_fd_product_attributes'] = wp_json_encode(array_values((array) ($meta['_fd_product_attributes'] ?? [])));
    $meta['_fd_product_related'] = wp_json_encode(array_values((array) ($meta['_fd_product_related'] ?? [])));

    return $meta;
}

function fd_demo_import_content_items(
    array $items,
    string $label,
    string $postType,
    array &$state,
    callable $metaMapper
): void {
    if (!post_type_exists($postType) && !in_array($postType, ['post', 'page'], true)) {
        fd_demo_out(sprintf('Skipping content import for unknown post type: %s', $postType));
        return;
    }

    foreach ($items as $item) {
        if (!is_array($item)) {
            continue;
        }

        $slug = (string) ($item['slug'] ?? '');

        if ($slug === '') {
            continue;
        }

        $postDates = fd_demo_normalize_post_dates($item['date'] ?? null);
        $existingId = fd_demo_find_post_id($postType, $slug);

        $postarr = [
            'post_type' => $postType,
            'post_status' => (string) ($item['status'] ?? 'publish'),
            'post_title' => (string) ($item['title'] ?? $slug),
            'post_name' => $slug,
            'post_content' => (string) fd_demo_replace_demo_urls($item['content'] ?? ''),
            'post_excerpt' => (string) fd_demo_replace_demo_urls($item['excerpt'] ?? ''),
            'post_author' => (int) $state['author_id'],
            'post_date' => $postDates['post_date'],
            'post_date_gmt' => $postDates['post_date_gmt'],
        ];

        if ($existingId > 0) {
            $postarr['ID'] = $existingId;
        }

        $postId = wp_insert_post(wp_slash($postarr), true);

        if (is_wp_error($postId)) {
            fd_demo_fail(sprintf('Failed to import %s "%s": %s', $label, $slug, $postId->get_error_message()));
        }

        $postId = (int) $postId;

        fd_demo_set_featured_media($postId, $item['featured_media'] ?? null, $state);
        fd_demo_set_taxonomies($postId, (array) ($item['taxonomies'] ?? []), $state);

        if ($postType === 'page') {
            $template = (string) ($item['template'] ?? 'default');

            if ($template !== '' && $template !== 'default') {
                fd_demo_upsert_meta($postId, '_wp_page_template', $template);
            } else {
                delete_post_meta($postId, '_wp_page_template');
            }

            $state['pages'][$slug] = $postId;
        }

        $meta = $metaMapper($item, $state);

        if (is_array($meta)) {
            foreach ($meta as $metaKey => $metaValue) {
                fd_demo_upsert_meta($postId, (string) $metaKey, $metaValue);
            }
        }
    }

    $state['summary'][$label] = count($items);
}

function fd_demo_resolve_page_option($value, array $state): int
{
    if (is_numeric($value)) {
        return max(0, (int) $value);
    }

    if (is_string($value) && $value !== '') {
        return (int) ($state['pages'][$value] ?? 0);
    }

    if (is_array($value)) {
        $slug = (string) ($value['page_slug'] ?? '');

        if ($slug !== '') {
            return (int) ($state['pages'][$slug] ?? 0);
        }
    }

    return 0;
}

function fd_demo_configure_site(array $site, array $state): void
{
    $showOnFront = (string) ($site['show_on_front'] ?? 'posts');
    $pageOnFront = fd_demo_resolve_page_option($site['page_on_front'] ?? 0, $state);
    $pageForPosts = fd_demo_resolve_page_option($site['page_for_posts'] ?? 0, $state);

    update_option('show_on_front', $showOnFront === 'page' ? 'page' : 'posts');
    update_option('page_on_front', $showOnFront === 'page' ? $pageOnFront : 0);
    update_option('page_for_posts', $pageForPosts);
}

function fd_demo_menu_item_url(array $item, array $state): string
{
    $frontendBase = fd_demo_frontend_base_url();
    $kind = (string) ($item['kind'] ?? 'custom_path');

    if ($kind === 'custom_path') {
        return fd_demo_join_url($frontendBase, (string) ($item['path'] ?? '/'));
    }

    if ($kind === 'page_ref') {
        $pageSlug = (string) ($item['page_slug'] ?? '');

        if ($pageSlug === '') {
            return $frontendBase . '/';
        }

        return fd_demo_join_url($frontendBase, $pageSlug);
    }

    if ($kind === 'custom_url') {
        return (string) fd_demo_replace_demo_urls($item['url'] ?? $frontendBase . '/');
    }

    return $frontendBase . '/';
}

function fd_demo_reset_menu_items(int $menuId): void
{
    $items = wp_get_nav_menu_items($menuId, [
        'post_status' => 'any',
    ]);

    if (!is_array($items)) {
        return;
    }

    foreach ($items as $item) {
        wp_delete_post((int) $item->ID, true);
    }
}

function fd_demo_import_menus(array $menus, array $state): void
{
    $locations = get_theme_mod('nav_menu_locations', []);

    if (!is_array($locations)) {
        $locations = [];
    }

    foreach ($menus as $menuKey => $menuDefinition) {
        if (!is_array($menuDefinition)) {
            continue;
        }

        $label = (string) ($menuDefinition['label'] ?? $menuKey);
        $menuObject = wp_get_nav_menu_object($label);

        if (!$menuObject) {
            $menuId = wp_create_nav_menu($label);

            if (is_wp_error($menuId)) {
                fd_demo_fail(sprintf('Failed to create nav menu "%s": %s', $label, $menuId->get_error_message()));
            }

            $menuObject = wp_get_nav_menu_object((int) $menuId);
        }

        if (!$menuObject) {
            fd_demo_fail(sprintf('Unable to load nav menu "%s"', $label));
        }

        $menuId = (int) $menuObject->term_id;

        fd_demo_reset_menu_items($menuId);

        $items = (array) ($menuDefinition['items'] ?? []);

        usort($items, static function ($left, $right) {
            return ((int) ($left['order'] ?? 0)) <=> ((int) ($right['order'] ?? 0));
        });

        $createdItems = [];

        foreach ($items as $item) {
            if (!is_array($item)) {
                continue;
            }

            $title = (string) ($item['title'] ?? '');

            if ($title === '') {
                continue;
            }

            $parentKey = (string) ($item['parent'] ?? '');
            $parentId = $parentKey !== '' ? (int) ($createdItems[$parentKey] ?? 0) : 0;
            $menuItemId = wp_update_nav_menu_item($menuId, 0, [
                'menu-item-title' => $title,
                'menu-item-url' => fd_demo_menu_item_url($item, $state),
                'menu-item-status' => 'publish',
                'menu-item-type' => 'custom',
                'menu-item-parent-id' => $parentId,
                'menu-item-position' => (int) ($item['order'] ?? 0),
            ]);

            if (is_wp_error($menuItemId)) {
                fd_demo_fail(sprintf('Failed to create nav menu item "%s": %s', $title, $menuItemId->get_error_message()));
            }

            $createdItems[$title] = (int) $menuItemId;
        }

        $location = (string) ($menuDefinition['location'] ?? '');

        if ($location !== '') {
            $locations[$location] = $menuId;
        }
    }

    set_theme_mod('nav_menu_locations', $locations);
}

function fd_demo_configure_frontend_options(array $package): void
{
    $frontendPostTypes = ['note', 'app', 'event', 'product'];
    $frontendTaxonomies = [];

    foreach ((array) ($package['terms'] ?? []) as $term) {
        if (!is_array($term)) {
            continue;
        }

        $taxonomy = (string) ($term['taxonomy'] ?? '');

        if ($taxonomy !== '' && taxonomy_exists($taxonomy)) {
            $frontendTaxonomies[] = $taxonomy;
        }
    }

    $frontendTaxonomies = array_values(array_unique($frontendTaxonomies));

    update_option('fd_frontend_post_types', $frontendPostTypes);
    update_option('fd_frontend_taxonomies', $frontendTaxonomies);
    update_option('fd_custom_type_views', [
        'note' => 'notes',
        'app' => 'software',
        'event' => 'events',
        'product' => 'products',
    ]);
}

[$jsonPath, $forceImport] = fd_demo_parse_args();

$package = fd_demo_load_package($jsonPath);
$signature = fd_demo_package_signature($jsonPath);
$existingSignature = (string) get_option('fd_demo_data_version', '');

if (!$forceImport && $existingSignature === $signature) {
    fd_demo_out(sprintf('Demo data already imported: %s', $signature));
    exit(0);
}

$state = [
    'author_id' => fd_demo_pick_author_id(),
    'terms' => [],
    'attachments' => [],
    'pages' => [],
    'summary' => [],
];

$oldDeferTermCounting = wp_defer_term_counting(true);
$oldDeferCommentCounting = wp_defer_comment_counting(true);

try {
    fd_demo_out(sprintf('Importing demo data package: %s', basename($jsonPath)));

    fd_demo_import_terms((array) ($package['terms'] ?? []), $state);
    fd_demo_import_assets((array) ($package['assets'] ?? []), $state);

    fd_demo_import_content_items((array) ($package['pages'] ?? []), 'pages', 'page', $state, 'fd_demo_map_note_meta');
    fd_demo_import_content_items((array) ($package['posts'] ?? []), 'posts', 'post', $state, 'fd_demo_map_post_meta');
    fd_demo_import_content_items((array) ($package['notes'] ?? []), 'notes', 'note', $state, 'fd_demo_map_note_meta');
    fd_demo_import_content_items((array) ($package['apps'] ?? []), 'apps', 'app', $state, 'fd_demo_map_app_meta');
    fd_demo_import_content_items((array) ($package['events'] ?? []), 'events', 'event', $state, 'fd_demo_map_event_meta');
    fd_demo_import_content_items((array) ($package['products'] ?? []), 'products', 'product', $state, 'fd_demo_map_product_meta');

    fd_demo_configure_frontend_options($package);
    fd_demo_configure_site((array) ($package['site'] ?? []), $state);
    fd_demo_import_menus((array) ($package['menus'] ?? []), $state);

    if (function_exists('fd_rebuild_slug_mapping_table')) {
        fd_rebuild_slug_mapping_table();
    }

    update_option('fd_demo_data_version', $signature);
    update_option('fd_demo_data_manifest', [
        'file' => basename($jsonPath),
        'imported_at' => current_time('mysql'),
        'signature' => $signature,
        'schema_version' => (int) (($package['manifest']['schema_version'] ?? 0)),
    ]);

    $state['summary']['terms'] = count((array) ($package['terms'] ?? []));
    $state['summary']['assets'] = count((array) ($package['assets'] ?? []));

    fd_demo_out('Demo data import completed.');
    fd_demo_out(wp_json_encode($state['summary'], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES));
} catch (Throwable $throwable) {
    fd_demo_fail('Demo data import failed: ' . $throwable->getMessage());
} finally {
    wp_defer_term_counting($oldDeferTermCounting);
    wp_defer_comment_counting($oldDeferCommentCounting);
}
