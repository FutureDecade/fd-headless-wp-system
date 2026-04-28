#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/.env}"

# shellcheck source=/dev/null
source "${ROOT_DIR}/scripts/common.sh"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing .env file. Run: cp .env.example .env"
  exit 0
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is not available. Skipping deployment status report."
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is not available. Skipping deployment status report."
  exit 0
fi

load_env_file "${ENV_FILE}"

if [[ -z "${FD_STACK_DEPLOYMENT_ID:-}" || -z "${FD_STACK_STATUS_REPORT_URL:-}" || -z "${FD_STACK_STATUS_REPORT_TOKEN:-}" ]]; then
  echo "FD Stack deployment reporting is not configured. Skipping status report."
  exit 0
fi

payload="$(
  jq -n \
    --arg deploymentId "${FD_STACK_DEPLOYMENT_ID}" \
    --arg token "${FD_STACK_STATUS_REPORT_TOKEN}" \
    --arg currentFrontendImage "${FRONTEND_IMAGE:-}" \
    --arg currentWebsocketImage "${WEBSOCKET_IMAGE:-}" \
    --arg availableFrontendImage "${AVAILABLE_FRONTEND_IMAGE:-}" \
    --arg availableWebsocketImage "${AVAILABLE_WEBSOCKET_IMAGE:-}" \
    --arg runtimeOfferedAt "${LAST_RUNTIME_IMAGE_OFFERED_AT:-}" \
    --arg runtimeAppliedAt "${LAST_RUNTIME_IMAGE_APPLIED_AT:-}" \
    --arg fdTheme "${FD_THEME_RELEASE_TAG:-}" \
    --arg fdPageComposer "${FD_PAGE_COMPOSER_RELEASE_TAG:-}" \
    --arg fdAdminUi "${FD_ADMIN_UI_RELEASE_TAG:-}" \
    --arg fdMember "${FD_MEMBER_RELEASE_TAG:-}" \
    --arg fdPayment "${FD_PAYMENT_RELEASE_TAG:-}" \
    --arg fdCommerce "${FD_COMMERCE_RELEASE_TAG:-}" \
    --arg fdContentTypes "${FD_CONTENT_TYPES_RELEASE_TAG:-}" \
    --arg fdForms "${FD_FORMS_RELEASE_TAG:-}" \
    --arg fdAiRouter "${FD_AI_ROUTER_RELEASE_TAG:-}" \
    --arg fdWebsocketPush "${FD_WEBSOCKET_PUSH_RELEASE_TAG:-}" \
    --arg wpgraphql "${WPGRAPHQL_RELEASE_TAG:-}" \
    --arg wpgraphqlJwt "${WPGRAPHQL_JWT_AUTH_RELEASE_TAG:-}" \
    --arg wpgraphqlTax "${WPGRAPHQL_TAX_QUERY_REF:-}" \
    --arg availableFdTheme "${AVAILABLE_FD_THEME_RELEASE_TAG:-}" \
    --arg availableFdPageComposer "${AVAILABLE_FD_PAGE_COMPOSER_RELEASE_TAG:-}" \
    --arg availableFdAdminUi "${AVAILABLE_FD_ADMIN_UI_RELEASE_TAG:-}" \
    --arg availableFdMember "${AVAILABLE_FD_MEMBER_RELEASE_TAG:-}" \
    --arg availableFdPayment "${AVAILABLE_FD_PAYMENT_RELEASE_TAG:-}" \
    --arg availableFdCommerce "${AVAILABLE_FD_COMMERCE_RELEASE_TAG:-}" \
    --arg availableFdContentTypes "${AVAILABLE_FD_CONTENT_TYPES_RELEASE_TAG:-}" \
    --arg availableFdForms "${AVAILABLE_FD_FORMS_RELEASE_TAG:-}" \
    --arg availableFdAiRouter "${AVAILABLE_FD_AI_ROUTER_RELEASE_TAG:-}" \
    --arg availableFdWebsocketPush "${AVAILABLE_FD_WEBSOCKET_PUSH_RELEASE_TAG:-}" \
    --arg availableWpgraphql "${AVAILABLE_WPGRAPHQL_RELEASE_TAG:-}" \
    --arg availableWpgraphqlJwt "${AVAILABLE_WPGRAPHQL_JWT_AUTH_RELEASE_TAG:-}" \
    --arg availableWpgraphqlTax "${AVAILABLE_WPGRAPHQL_TAX_QUERY_REF:-}" \
    --arg wordpressOfferedAt "${LAST_WORDPRESS_ASSET_UPDATE_OFFERED_AT:-}" \
    --arg wordpressAppliedAt "${LAST_WORDPRESS_ASSET_UPDATE_APPLIED_AT:-}" \
    '
    def optional($value):
      if ($value | length) > 0 then $value else null end;

    {
      deploymentId: $deploymentId,
      token: $token,
      runtimeImages: {
        currentFrontendImage: optional($currentFrontendImage),
        currentWebsocketImage: optional($currentWebsocketImage),
        availableFrontendImage: optional($availableFrontendImage),
        availableWebsocketImage: optional($availableWebsocketImage),
        offeredAt: optional($runtimeOfferedAt),
        appliedAt: optional($runtimeAppliedAt)
      },
      wordpressAssets: {
        current: {
          FD_THEME_RELEASE_TAG: optional($fdTheme),
          FD_PAGE_COMPOSER_RELEASE_TAG: optional($fdPageComposer),
          FD_ADMIN_UI_RELEASE_TAG: optional($fdAdminUi),
          FD_MEMBER_RELEASE_TAG: optional($fdMember),
          FD_PAYMENT_RELEASE_TAG: optional($fdPayment),
          FD_COMMERCE_RELEASE_TAG: optional($fdCommerce),
          FD_CONTENT_TYPES_RELEASE_TAG: optional($fdContentTypes),
          FD_FORMS_RELEASE_TAG: optional($fdForms),
          FD_AI_ROUTER_RELEASE_TAG: optional($fdAiRouter),
          FD_WEBSOCKET_PUSH_RELEASE_TAG: optional($fdWebsocketPush),
          WPGRAPHQL_RELEASE_TAG: optional($wpgraphql),
          WPGRAPHQL_JWT_AUTH_RELEASE_TAG: optional($wpgraphqlJwt),
          WPGRAPHQL_TAX_QUERY_REF: optional($wpgraphqlTax)
        },
        available: {
          AVAILABLE_FD_THEME_RELEASE_TAG: optional($availableFdTheme),
          AVAILABLE_FD_PAGE_COMPOSER_RELEASE_TAG: optional($availableFdPageComposer),
          AVAILABLE_FD_ADMIN_UI_RELEASE_TAG: optional($availableFdAdminUi),
          AVAILABLE_FD_MEMBER_RELEASE_TAG: optional($availableFdMember),
          AVAILABLE_FD_PAYMENT_RELEASE_TAG: optional($availableFdPayment),
          AVAILABLE_FD_COMMERCE_RELEASE_TAG: optional($availableFdCommerce),
          AVAILABLE_FD_CONTENT_TYPES_RELEASE_TAG: optional($availableFdContentTypes),
          AVAILABLE_FD_FORMS_RELEASE_TAG: optional($availableFdForms),
          AVAILABLE_FD_AI_ROUTER_RELEASE_TAG: optional($availableFdAiRouter),
          AVAILABLE_FD_WEBSOCKET_PUSH_RELEASE_TAG: optional($availableFdWebsocketPush),
          AVAILABLE_WPGRAPHQL_RELEASE_TAG: optional($availableWpgraphql),
          AVAILABLE_WPGRAPHQL_JWT_AUTH_RELEASE_TAG: optional($availableWpgraphqlJwt),
          AVAILABLE_WPGRAPHQL_TAX_QUERY_REF: optional($availableWpgraphqlTax)
        },
        offeredAt: optional($wordpressOfferedAt),
        appliedAt: optional($wordpressAppliedAt)
      }
    }
    '
)"

if curl -fsSL -X POST "${FD_STACK_STATUS_REPORT_URL}" \
  -H 'content-type: application/json' \
  -d "${payload}" >/dev/null; then
  echo "Reported deployment status to FD Stack."
else
  echo "Failed to report deployment status to FD Stack. Continuing."
fi
