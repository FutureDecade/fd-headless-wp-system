<?php
require '/var/www/html/wp-load.php';

function fd_demo_array_get($array, $key, $default = null) {
    return array_key_exists($key, $array) ? $array[$key] : $default;
}

function fd_demo_trim_text($value) {
    if (!is_string($value)) {
        return '';
    }

    return trim(wp_strip_all_tags($value));
}

function fd_demo_excerpt($post) {
    $excerpt = fd_demo_trim_text($post->post_excerpt);
    if ($excerpt !== '') {
        return $excerpt;
    }

    return wp_trim_words(fd_demo_trim_text($post->post_content), 40, '...');
}

function fd_demo_is_noise($post) {
    $haystack = mb_strtolower(
        implode(
            "\n",
            array(
                (string) $post->post_title,
                (string) $post->post_name,
                mb_substr((string) $post->post_excerpt, 0, 240),
                mb_substr((string) $post->post_content, 0, 240),
            )
        )
    );

    return (bool) preg_match(
        '/(测试|哈哈|呵呵|嘎嘎|auto-draft|hehe|hahah|deedeeee|adaja|cshi|试试)/iu',
        $haystack
    );
}

function fd_demo_split_lines($value) {
    if (!is_string($value) || trim($value) === '') {
        return array();
    }

    $lines = preg_split('/\r\n|\r|\n/', $value);
    $lines = array_map('trim', $lines);
    $lines = array_values(array_filter($lines, static function ($line) {
        return $line !== '';
    }));

    return $lines;
}

function fd_demo_attachment_url($attachment_id) {
    $attachment_id = (int) $attachment_id;
    if ($attachment_id <= 0) {
        return null;
    }

    $url = wp_get_attachment_url($attachment_id);
    return $url ? $url : null;
}

function fd_demo_collect_post_terms($post_id) {
    $post = get_post($post_id);
    if (!$post) {
        return array();
    }

    $result = array();
    $taxonomies = get_object_taxonomies($post->post_type, 'names');

    foreach ($taxonomies as $taxonomy) {
        if (!taxonomy_exists($taxonomy)) {
            continue;
        }

        $terms = wp_get_object_terms($post_id, $taxonomy, array('fields' => 'all'));
        if (is_wp_error($terms) || empty($terms)) {
            continue;
        }

        $result[$taxonomy] = array_map(static function ($term) {
            return array(
                'name' => $term->name,
                'slug' => $term->slug,
            );
        }, $terms);
    }

    return $result;
}

function fd_demo_collect_term_index(&$term_index, $terms_by_taxonomy) {
    foreach ($terms_by_taxonomy as $taxonomy => $terms) {
        foreach ($terms as $term_stub) {
            $term = get_term_by('slug', $term_stub['slug'], $taxonomy);
            if (!$term || is_wp_error($term)) {
                continue;
            }

            $key = $taxonomy . ':' . $term->slug;
            if (isset($term_index[$key])) {
                continue;
            }

            $parent_slug = null;
            if (!empty($term->parent)) {
                $parent = get_term($term->parent, $taxonomy);
                if ($parent && !is_wp_error($parent)) {
                    $parent_slug = $parent->slug;
                }
            }

            $term_index[$key] = array(
                'taxonomy' => $taxonomy,
                'name' => $term->name,
                'slug' => $term->slug,
                'description' => $term->description,
                'parent_slug' => $parent_slug,
            );
        }
    }
}

function fd_demo_base_item($post) {
    $thumbnail_id = get_post_thumbnail_id($post->ID);

    return array(
        'title' => $post->post_title,
        'slug' => $post->post_name,
        'status' => $post->post_status,
        'date' => mysql2date('c', $post->post_date_gmt ?: $post->post_date, false),
        'excerpt' => fd_demo_excerpt($post),
        'content' => $post->post_content,
        'featured_media' => array(
            'attachment_id' => $thumbnail_id ? (int) $thumbnail_id : null,
            'url' => $thumbnail_id ? fd_demo_attachment_url($thumbnail_id) : null,
        ),
        'taxonomies' => fd_demo_collect_post_terms($post->ID),
    );
}

function fd_demo_pick_values($post_id, $keys) {
    $meta = array();
    foreach ($keys as $key) {
        $value = get_post_meta($post_id, $key, true);
        if ($value === '' || $value === array() || $value === null) {
            continue;
        }
        $meta[$key] = maybe_unserialize($value);
    }

    return $meta;
}

function fd_demo_parse_counted_group($post_id, $prefix, $shape) {
    $count = (int) get_post_meta($post_id, $prefix, true);
    if ($count <= 0) {
        return array();
    }

    $rows = array();

    for ($index = 0; $index < $count; $index++) {
        $row = array();
        foreach ($shape as $field => $meta_suffix) {
            $meta_key = $prefix . '_' . $index . '_' . $meta_suffix;
            $value = get_post_meta($post_id, $meta_key, true);
            if ($value === '' || $value === null) {
                continue;
            }
            $row[$field] = maybe_unserialize($value);
        }

        if (!empty($row)) {
            $rows[] = $row;
        }
    }

    return $rows;
}

function fd_demo_parse_nested_counted_group($post_id, $prefix, $outer_name, $inner_name, $outer_shape, $inner_shape) {
    $outer_count = (int) get_post_meta($post_id, $prefix, true);
    if ($outer_count <= 0) {
        return array();
    }

    $rows = array();

    for ($outer_index = 0; $outer_index < $outer_count; $outer_index++) {
        $row = array();

        foreach ($outer_shape as $field => $meta_suffix) {
            $meta_key = $prefix . '_' . $outer_index . '_' . $meta_suffix;
            $value = get_post_meta($post_id, $meta_key, true);
            if ($value === '' || $value === null) {
                continue;
            }
            $row[$field] = maybe_unserialize($value);
        }

        $inner_count_key = $prefix . '_' . $outer_index . '_' . $inner_name;
        $inner_count = (int) get_post_meta($post_id, $inner_count_key, true);
        $inner_rows = array();

        for ($inner_index = 0; $inner_index < $inner_count; $inner_index++) {
            $inner_row = array();
            foreach ($inner_shape as $field => $meta_suffix) {
                $meta_key = $prefix . '_' . $outer_index . '_' . $inner_name . '_' . $inner_index . '_' . $meta_suffix;
                $value = get_post_meta($post_id, $meta_key, true);
                if ($value === '' || $value === null) {
                    continue;
                }
                $inner_row[$field] = maybe_unserialize($value);
            }

            if (!empty($inner_row)) {
                $inner_rows[] = $inner_row;
            }
        }

        if (!empty($inner_rows)) {
            $row[$outer_name] = $inner_rows;
        }

        if (!empty($row)) {
            $rows[] = $row;
        }
    }

    return $rows;
}

function fd_demo_export_page($post) {
    $item = fd_demo_base_item($post);
    $item['template'] = get_post_meta($post->ID, '_wp_page_template', true) ?: 'default';

    return $item;
}

function fd_demo_export_post($post) {
    $item = fd_demo_base_item($post);
    $item['meta'] = fd_demo_pick_values($post->ID, array(
        'template_type',
        'subtitle',
        'article_author',
        'article_translator',
        'article_editor',
        'custom_editor',
        'copyright_type',
    ));

    return $item;
}

function fd_demo_export_note($post) {
    $item = fd_demo_base_item($post);
    $item['meta'] = fd_demo_pick_values($post->ID, array(
        'note_source',
    ));

    return $item;
}

function fd_demo_export_book($post) {
    $item = fd_demo_base_item($post);
    $item['meta'] = fd_demo_pick_values($post->ID, array(
        'book_subtitle',
        'book_original_title',
        'book_authors',
        'book_translators',
        'book_publisher',
        'book_series',
        'book_publish_date',
        'book_edition',
        'book_pages',
        'book_binding',
        'book_price',
        'book_isbn',
        'book_language',
        'book_status',
    ));

    return $item;
}

function fd_demo_export_app($post) {
    $item = fd_demo_base_item($post);
    $item['meta'] = fd_demo_pick_values($post->ID, array(
        'app_short_description',
        'app_description',
        'app_developer',
        'app_version',
        'app_update_date',
        'app_size',
        'app_price',
        'app_rating',
        'app_platforms',
        'app_download_links',
        'app_website',
        'app_features',
        'app_system_requirements',
        'app_languages',
        'app_privacy_policy',
        'app_terms_of_service',
        'app_notes',
        'app_purchase_type',
        'app_usage_instructions',
        'app_trial_days',
    ));

    $icon_id = (int) get_post_meta($post->ID, 'app_icon', true);
    $screenshots = maybe_unserialize(get_post_meta($post->ID, 'app_screenshots', true));
    $screenshots = is_array($screenshots) ? $screenshots : array_filter(array_map('trim', explode(',', (string) $screenshots)));

    $item['media'] = array(
        'icon' => array(
            'attachment_id' => $icon_id > 0 ? $icon_id : null,
            'url' => $icon_id > 0 ? fd_demo_attachment_url($icon_id) : null,
        ),
        'screenshots' => array_values(array_filter(array_map(static function ($attachment_id) {
            $url = fd_demo_attachment_url($attachment_id);
            return $url ? array(
                'attachment_id' => (int) $attachment_id,
                'url' => $url,
            ) : null;
        }, $screenshots))),
    );

    return $item;
}

function fd_demo_export_event($post) {
    $item = fd_demo_base_item($post);
    $item['meta'] = fd_demo_pick_values($post->ID, array(
        'event_short_description',
        'event_description',
        'event_organizer',
        'event_co_organizers',
        'event_start_date',
        'event_end_date',
        'event_registration_deadline',
        'event_venue_name',
        'event_venue_address',
        'event_location_coordinates',
        'event_is_online',
        'event_online_platform',
        'event_online_link',
        'event_price',
        'event_status',
        'event_category',
        'event_tags',
        'event_speakers',
        'event_agenda',
        'event_highlights',
        'event_registration_link',
        'event_sponsors',
        'event_partners',
        'event_faq',
        'event_terms',
    ));

    $banner_id = (int) get_post_meta($post->ID, 'event_banner', true);
    $logo_id = (int) get_post_meta($post->ID, 'event_logo', true);
    $photo_ids = maybe_unserialize(get_post_meta($post->ID, 'event_photos', true));
    $photo_ids = is_array($photo_ids) ? $photo_ids : array();

    $item['media'] = array(
        'banner' => array(
            'attachment_id' => $banner_id > 0 ? $banner_id : null,
            'url' => $banner_id > 0 ? fd_demo_attachment_url($banner_id) : null,
        ),
        'logo' => array(
            'attachment_id' => $logo_id > 0 ? $logo_id : null,
            'url' => $logo_id > 0 ? fd_demo_attachment_url($logo_id) : null,
        ),
        'photos' => array_values(array_filter(array_map(static function ($attachment_id) {
            $url = fd_demo_attachment_url($attachment_id);
            return $url ? array(
                'attachment_id' => (int) $attachment_id,
                'url' => $url,
            ) : null;
        }, $photo_ids))),
    );

    $item['tickets'] = fd_demo_parse_counted_group($post->ID, 'event_tickets', array(
        'name' => 'ticket_name',
        'price' => 'ticket_price',
        'quantity' => 'ticket_quantity',
        'sold' => 'ticket_sold',
        'status' => 'ticket_status',
        'description' => 'ticket_description',
        'sale_start' => 'ticket_sale_start',
        'sale_end' => 'ticket_sale_end',
    ));

    return $item;
}

function fd_demo_export_product($post) {
    $item = fd_demo_base_item($post);
    $item['meta'] = fd_demo_pick_values($post->ID, array(
        'product_subtitle',
        'product_short_description',
        'product_brand',
        'product_model',
        'product_type',
        'product_original_price',
        'product_sale_price',
        'product_member_price',
        'product_price_note',
        'product_stock_status',
        'product_video',
        'product_shipping_info',
        'product_delivery_time',
        'product_shipping_fee',
        'product_return_policy',
        'product_service_notes',
        'product_status',
        'product_sale_start',
        'product_sale_end',
        'product_rating',
        'product_review_summary',
    ));

    $featured_image_url = get_post_meta($post->ID, '_featured_image_url', true);
    if ($featured_image_url) {
        $item['featured_media'] = array(
            'attachment_id' => null,
            'url' => $featured_image_url,
        );
    }

    $item['highlights'] = fd_demo_parse_counted_group($post->ID, 'product_highlights', array(
        'icon' => 'highlight_icon',
        'title' => 'highlight_title',
        'description' => 'highlight_description',
    ));

    $item['attributes'] = fd_demo_parse_counted_group($post->ID, 'product_attributes', array(
        'name' => 'attr_name',
        'value' => 'attr_value',
    ));

    $item['specifications'] = fd_demo_parse_nested_counted_group(
        $post->ID,
        'product_specifications',
        'options',
        'spec_options',
        array(
            'name' => 'spec_name',
        ),
        array(
            'value' => 'option_value',
            'price_adjust' => 'option_price_adjust',
            'stock' => 'option_stock',
            'image' => 'option_image',
        )
    );

    $item['media'] = array(
        'gallery' => fd_demo_split_lines((string) get_post_meta($post->ID, 'product_gallery', true)),
        'detail_images' => fd_demo_split_lines((string) get_post_meta($post->ID, 'product_detail_images', true)),
    );

    $badges = maybe_unserialize(get_post_meta($post->ID, 'product_badges', true));
    $item['badges'] = is_array($badges) ? array_values($badges) : fd_demo_split_lines((string) $badges);

    return $item;
}

function fd_demo_pick_posts($post_type, $limit, $exporter, $require_featured_image = false) {
    $posts = get_posts(array(
        'post_type' => $post_type,
        'post_status' => 'publish',
        'posts_per_page' => -1,
        'orderby' => 'date',
        'order' => 'DESC',
    ));

    $items = array();
    foreach ($posts as $post) {
        if (fd_demo_is_noise($post)) {
            continue;
        }

        if ($require_featured_image && empty(fd_demo_base_item($post)['featured_media']['url'])) {
            continue;
        }

        $items[] = $exporter($post);
        if (count($items) >= $limit) {
            break;
        }
    }

    return $items;
}

$page_allowlist = array(
    'about-us',
    'contact-us',
    'communication-terms',
    'privacy',
    'copyright-claim',
    'terms',
);

$pages = array();
foreach ($page_allowlist as $slug) {
    $page = get_page_by_path($slug, OBJECT, 'page');
    if ($page && $page->post_status === 'publish') {
        $pages[] = fd_demo_export_page($page);
    }
}

$posts = fd_demo_pick_posts('post', 24, 'fd_demo_export_post', true);
$notes = fd_demo_pick_posts('note', 20, 'fd_demo_export_note', false);

$books = array_map('fd_demo_export_book', get_posts(array(
    'post_type' => 'book',
    'post_status' => 'publish',
    'posts_per_page' => -1,
    'orderby' => 'date',
    'order' => 'DESC',
)));

$apps = array_map('fd_demo_export_app', get_posts(array(
    'post_type' => 'app',
    'post_status' => 'publish',
    'posts_per_page' => -1,
    'orderby' => 'date',
    'order' => 'DESC',
)));

$events = array_map('fd_demo_export_event', get_posts(array(
    'post_type' => 'event',
    'post_status' => 'publish',
    'posts_per_page' => -1,
    'orderby' => 'date',
    'order' => 'DESC',
)));

$products = array_map('fd_demo_export_product', get_posts(array(
    'post_type' => 'product',
    'post_status' => 'publish',
    'posts_per_page' => -1,
    'orderby' => 'date',
    'order' => 'DESC',
)));

$term_index = array();
foreach (array($pages, $posts, $notes, $books, $apps, $events, $products) as $collection) {
    foreach ($collection as $item) {
        fd_demo_collect_term_index($term_index, fd_demo_array_get($item, 'taxonomies', array()));
    }
}

$terms = array_values($term_index);
usort($terms, static function ($left, $right) {
    $left_key = $left['taxonomy'] . ':' . $left['slug'];
    $right_key = $right['taxonomy'] . ':' . $right['slug'];
    return strcmp($left_key, $right_key);
});

$export = array(
    'manifest' => array(
        'schema_version' => 1,
        'exported_at' => gmdate('c'),
        'source' => array(
            'site_url' => home_url('/'),
            'theme' => get_option('stylesheet'),
            'uploads_baseurl' => fd_demo_array_get(wp_get_upload_dir(), 'baseurl'),
        ),
        'selection' => array(
            'page_allowlist' => $page_allowlist,
            'post_limit' => 24,
            'note_limit' => 20,
            'noise_filter' => 'Exclude obvious test content by title/slug/content pattern.',
            'media_strategy' => 'Keep remote media URLs instead of copying binaries into the package.',
        ),
    ),
    'site' => array(
        'show_on_front' => get_option('show_on_front'),
        'page_on_front' => (int) get_option('page_on_front'),
        'page_for_posts' => (int) get_option('page_for_posts'),
        'stylesheet' => get_option('stylesheet'),
        'template' => get_option('template'),
        'nav_menu_locations' => get_theme_mod('nav_menu_locations'),
    ),
    'menus' => array(
        'primary' => array(
            'location' => 'primary-menu',
            'label' => '顶部菜单',
            'items' => array(
                array('title' => '首页', 'kind' => 'custom_path', 'path' => '/', 'parent' => null, 'order' => 1),
                array('title' => '分类', 'kind' => 'custom_path', 'path' => '/intelligence', 'parent' => null, 'order' => 2),
                array('title' => '自定义分类法1', 'kind' => 'custom_path', 'path' => '/company', 'parent' => '分类', 'order' => 3),
                array('title' => '自定义分类法2', 'kind' => 'custom_path', 'path' => '/industry', 'parent' => '分类', 'order' => 4),
                array('title' => '自定义分类法3', 'kind' => 'custom_path', 'path' => '/region', 'parent' => '分类', 'order' => 5),
                array('title' => '标签', 'kind' => 'custom_path', 'path' => '/innovation', 'parent' => null, 'order' => 6),
                array('title' => '笔记', 'kind' => 'custom_path', 'path' => '/note', 'parent' => null, 'order' => 7),
                array('title' => '商品', 'kind' => 'custom_path', 'path' => '/product', 'parent' => '笔记', 'order' => 8),
                array('title' => '活动', 'kind' => 'custom_path', 'path' => '/event', 'parent' => '笔记', 'order' => 9),
                array('title' => '应用', 'kind' => 'custom_path', 'path' => '/app', 'parent' => '笔记', 'order' => 10),
            ),
        ),
        'footer' => array(
            'location' => 'footer-menu',
            'label' => '底部菜单',
            'items' => array(
                array('title' => '关于我们', 'kind' => 'page_ref', 'page_slug' => 'about-us', 'parent' => null, 'order' => 1),
                array('title' => '联系我们', 'kind' => 'page_ref', 'page_slug' => 'contact-us', 'parent' => null, 'order' => 2),
                array('title' => '隐私条款', 'kind' => 'page_ref', 'page_slug' => 'privacy', 'parent' => null, 'order' => 3),
                array('title' => '版权声明', 'kind' => 'page_ref', 'page_slug' => 'copyright-claim', 'parent' => null, 'order' => 4),
            ),
        ),
    ),
    'terms' => $terms,
    'content' => array(
        'pages' => $pages,
        'posts' => $posts,
        'notes' => $notes,
        'books' => $books,
        'apps' => $apps,
        'events' => $events,
        'products' => $products,
    ),
    'counts' => array(
        'pages' => count($pages),
        'posts' => count($posts),
        'notes' => count($notes),
        'books' => count($books),
        'apps' => count($apps),
        'events' => count($events),
        'products' => count($products),
        'terms' => count($terms),
    ),
);

echo json_encode($export, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) . PHP_EOL;
