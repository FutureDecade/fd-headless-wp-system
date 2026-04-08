#!/usr/bin/env python3
import json
import os
import re
import subprocess
import sys
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parent.parent
MANIFEST_FILE = ROOT_DIR / "fd-delivery.manifest.json"
ENV_EXAMPLE_FILE = ROOT_DIR / ".env.example"
README_FILE = ROOT_DIR / "README.md"
RELEASE_DOC_FILE = ROOT_DIR / "docs" / "RELEASE-AND-VERSIONING.md"
INSTALL_DOC_FILE = ROOT_DIR / "docs" / "INSTALL-AND-UPDATE.md"
FETCH_SCRIPT_FILE = ROOT_DIR / "scripts" / "fetch-wordpress-assets.sh"
CONFIGURE_SCRIPT_FILE = ROOT_DIR / "scripts" / "configure-env.sh"
PREFLIGHT_SCRIPT_FILE = ROOT_DIR / "scripts" / "preflight-check.sh"
UPDATE_STACK_FILE = ROOT_DIR / "scripts" / "update-stack.sh"

TAG_REPOS = {
    "FD_THEME_RELEASE_TAG": "FutureDecade/fd-theme",
    "FD_ADMIN_UI_RELEASE_TAG": "FutureDecade/fd-admin-ui",
    "FD_MEMBER_RELEASE_TAG": "FutureDecade/fd-member",
    "FD_PAYMENT_RELEASE_TAG": "FutureDecade/fd-payment",
    "FD_COMMERCE_RELEASE_TAG": "FutureDecade/fd-commerce",
    "FD_CONTENT_TYPES_RELEASE_TAG": "FutureDecade/fd-content-types",
    "FD_AI_ROUTER_RELEASE_TAG": "FutureDecade/fd-ai-router",
    "FD_WEBSOCKET_PUSH_RELEASE_TAG": "FutureDecade/fd-websocket-push",
    "WPGRAPHQL_JWT_AUTH_RELEASE_TAG": "wp-graphql/wp-graphql-jwt-authentication",
    "WPGRAPHQL_TAX_QUERY_REF": "wp-graphql/wp-graphql-tax-query",
}

CONFIGURE_DEFAULTS = {
    "fd_theme_release_tag_default": "FD_THEME_RELEASE_TAG",
    "fd_admin_ui_release_tag_default": "FD_ADMIN_UI_RELEASE_TAG",
    "fd_member_release_tag_default": "FD_MEMBER_RELEASE_TAG",
    "fd_payment_release_tag_default": "FD_PAYMENT_RELEASE_TAG",
    "fd_commerce_release_tag_default": "FD_COMMERCE_RELEASE_TAG",
    "fd_content_types_release_tag_default": "FD_CONTENT_TYPES_RELEASE_TAG",
    "fd_ai_router_release_tag_default": "FD_AI_ROUTER_RELEASE_TAG",
    "fd_websocket_push_release_tag_default": "FD_WEBSOCKET_PUSH_RELEASE_TAG",
    "wpgraphql_jwt_auth_release_tag_default": "WPGRAPHQL_JWT_AUTH_RELEASE_TAG",
    "wpgraphql_tax_query_ref_default": "WPGRAPHQL_TAX_QUERY_REF",
}

UPDATE_STACK_KEYS = {
    "fd-theme": "FD_THEME_RELEASE_TAG",
    "fd-admin-ui": "FD_ADMIN_UI_RELEASE_TAG",
    "fd-member": "FD_MEMBER_RELEASE_TAG",
    "fd-payment": "FD_PAYMENT_RELEASE_TAG",
    "fd-commerce": "FD_COMMERCE_RELEASE_TAG",
    "fd-content-types": "FD_CONTENT_TYPES_RELEASE_TAG",
    "fd-ai-router": "FD_AI_ROUTER_RELEASE_TAG",
    "fd-websocket-push": "FD_WEBSOCKET_PUSH_RELEASE_TAG",
    "wp-graphql-jwt-authentication": "WPGRAPHQL_JWT_AUTH_RELEASE_TAG",
    "wp-graphql-tax-query-develop": "WPGRAPHQL_TAX_QUERY_REF",
}

DOC_SLUG_KEYS = {
    "fd-theme": "FD_THEME_RELEASE_TAG",
    "fd-admin-ui": "FD_ADMIN_UI_RELEASE_TAG",
    "fd-member": "FD_MEMBER_RELEASE_TAG",
    "fd-payment": "FD_PAYMENT_RELEASE_TAG",
    "fd-commerce": "FD_COMMERCE_RELEASE_TAG",
    "fd-content-types": "FD_CONTENT_TYPES_RELEASE_TAG",
    "fd-ai-router": "FD_AI_ROUTER_RELEASE_TAG",
    "fd-websocket-push": "FD_WEBSOCKET_PUSH_RELEASE_TAG",
}


def run(command: list[str]) -> str:
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip() or f"Command failed: {' '.join(command)}")
    return result.stdout.strip()


def fetch_latest_tags() -> dict[str, str]:
    tags: dict[str, str] = {}

    for key, repo in TAG_REPOS.items():
        tag_name = run(["gh", "api", f"repos/{repo}/releases/latest", "--jq", ".tag_name"])
        if not tag_name:
            raise RuntimeError(f"Missing latest release tag for {repo}")
        tags[key] = tag_name

    return tags


def replace_required(text: str, pattern: str, replacement: str, file_path: Path) -> str:
    next_text, count = re.subn(pattern, replacement, text, flags=re.MULTILINE)
    if count == 0:
        raise RuntimeError(f"Pattern not found in {file_path}: {pattern}")
    return next_text


def replace_optional(text: str, pattern: str, replacement: str) -> str:
    next_text, _ = re.subn(pattern, replacement, text, flags=re.MULTILINE)
    return next_text


def update_manifest(tags: dict[str, str]) -> None:
    data = json.loads(MANIFEST_FILE.read_text(encoding="utf-8"))
    touched = set()

    for field in data.get("envFields", []):
        key = field.get("key")
        if key in tags:
            field["defaultValue"] = tags[key]
            touched.add(key)

    missing = sorted(set(tags) - touched)
    if missing:
        raise RuntimeError(f"Missing manifest env fields: {', '.join(missing)}")

    MANIFEST_FILE.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def update_env_example(tags: dict[str, str]) -> None:
    text = ENV_EXAMPLE_FILE.read_text(encoding="utf-8")

    for key, value in tags.items():
        text = replace_required(text, rf"^{re.escape(key)}=.*$", f"{key}={value}", ENV_EXAMPLE_FILE)

    ENV_EXAMPLE_FILE.write_text(text, encoding="utf-8")


def update_fetch_defaults(tags: dict[str, str], file_path: Path) -> None:
    text = file_path.read_text(encoding="utf-8")

    for key, value in tags.items():
        pattern = rf'^{re.escape(key)}="\$\{{{re.escape(key)}:-[^"]+\}}"$'
        replacement = f'{key}="${{{key}:-{value}}}"'
        text = replace_required(text, pattern, replacement, file_path)

    file_path.write_text(text, encoding="utf-8")


def update_configure_defaults(tags: dict[str, str]) -> None:
    text = CONFIGURE_SCRIPT_FILE.read_text(encoding="utf-8")

    for local_key, env_key in CONFIGURE_DEFAULTS.items():
        value = tags[env_key]
        pattern = rf'^{re.escape(local_key)}="\$\{{{re.escape(env_key)}:-[^"]+\}}"$'
        replacement = f'{local_key}="${{{env_key}:-{value}}}"'
        text = replace_required(text, pattern, replacement, CONFIGURE_SCRIPT_FILE)

    CONFIGURE_SCRIPT_FILE.write_text(text, encoding="utf-8")


def update_stack_defaults(tags: dict[str, str]) -> None:
    text = UPDATE_STACK_FILE.read_text(encoding="utf-8")

    for slug, env_key in UPDATE_STACK_KEYS.items():
        value = tags[env_key]
        pattern = rf"^{re.escape(slug)}=\$\{{{re.escape(env_key)}:-[^}}]+\}}$"
        replacement = f"{slug}=${{{env_key}:-{value}}}"
        text = replace_required(text, pattern, replacement, UPDATE_STACK_FILE)

    UPDATE_STACK_FILE.write_text(text, encoding="utf-8")


def update_readme(tags: dict[str, str]) -> None:
    text = README_FILE.read_text(encoding="utf-8")

    for key, value in tags.items():
        text = replace_optional(text, rf"{re.escape(key)}=[^ `]+", f"{key}={value}")

    README_FILE.write_text(text, encoding="utf-8")


def update_markdown_version_bullets(text: str, tags: dict[str, str]) -> str:
    next_text = text

    for slug, env_key in DOC_SLUG_KEYS.items():
        value = tags[env_key]
        pattern = rf"(- `{re.escape(slug)}`[：:]\s*`)[^`]+(`)"
        replacement = rf"\g<1>{value}\2"
        next_text = replace_optional(next_text, pattern, replacement)

    return next_text


def update_release_doc(tags: dict[str, str]) -> None:
    text = RELEASE_DOC_FILE.read_text(encoding="utf-8")
    pattern = r"(## 当前推荐默认版本\s+)(.*?)(\n对应 release asset：)"
    match = re.search(pattern, text, flags=re.DOTALL)
    if not match:
        raise RuntimeError(f"Unable to find recommended release section in {RELEASE_DOC_FILE}")

    updated_section = update_markdown_version_bullets(match.group(2), tags)
    text = text[: match.start(2)] + updated_section + text[match.end(2) :]
    RELEASE_DOC_FILE.write_text(text, encoding="utf-8")


def update_install_doc(tags: dict[str, str]) -> None:
    text = INSTALL_DOC_FILE.read_text(encoding="utf-8")
    text = update_markdown_version_bullets(text, tags)
    INSTALL_DOC_FILE.write_text(text, encoding="utf-8")


def write_summary(tags: dict[str, str]) -> None:
    summary_file = os.getenv("GITHUB_STEP_SUMMARY")
    if not summary_file:
        return

    lines = ["## Synced WordPress release tags", ""]
    for key, value in tags.items():
        lines.append(f"- `{key}` -> `{value}`")

    Path(summary_file).write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    if not os.getenv("GH_TOKEN") and not os.getenv("GITHUB_TOKEN"):
        print("GH_TOKEN or GITHUB_TOKEN is required.", file=sys.stderr)
        return 1

    tags = fetch_latest_tags()

    print("Resolved latest release tags:")
    for key, value in tags.items():
        print(f"- {key}={value}")

    update_manifest(tags)
    update_env_example(tags)
    update_fetch_defaults(tags, FETCH_SCRIPT_FILE)
    update_fetch_defaults(tags, PREFLIGHT_SCRIPT_FILE)
    update_configure_defaults(tags)
    update_stack_defaults(tags)
    update_readme(tags)
    update_release_doc(tags)
    update_install_doc(tags)
    write_summary(tags)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
