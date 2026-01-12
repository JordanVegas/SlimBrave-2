#!/usr/bin/env bash
set -euo pipefail

POLICY_DIR="/etc/brave/policies/managed"
POLICY_FILE="${POLICY_DIR}/slimbrave.json"
SANITIZED_CONFIG=""
TMP_POLICY=""

usage() {
  cat <<'USAGE'
SlimBrave (Linux)

Usage:
  ./SlimBrave.sh --import <path> [--policy-file <path>] [--doh-templates <template>]
  ./SlimBrave.sh --export <path> [--policy-file <path>]
  ./SlimBrave.sh --reset [--policy-file <path>]
  ./SlimBrave.sh --interactive [--policy-file <path>] [--doh-templates <template>]

Options:
  --import <path>        Import a SlimBrave JSON config (from the PowerShell version) and apply it.
  --export <path>        Export a SlimBrave JSON config based on the current policy file.
  --reset                Remove SlimBrave's managed policy file.
  --interactive          Run an interactive terminal setup to select SlimBrave settings.
  --policy-file <path>   Override the policy file path (default: /etc/brave/policies/managed/slimbrave.json).
  --doh-templates <url>  Set DnsOverHttpsTemplates when DnsMode is "custom".
  -h, --help             Show this help.
USAGE
}

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "This script must be run as root (use sudo)." >&2
    exit 1
  fi
}

require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required but not installed. Please install jq and retry." >&2
    exit 1
  fi
}

sanitize_config() {
  local input_path="$1"
  local output_path="$2"

  if command -v python3 >/dev/null 2>&1; then
    python3 - "$input_path" "$output_path" <<'PY'
import sys

input_path = sys.argv[1]
output_path = sys.argv[2]

with open(input_path, "rb") as fh:
    data = fh.read()

if data.startswith(b"\xff\xfe"):
    text = data[2:].decode("utf-16-le", errors="strict")
elif data.startswith(b"\xfe\xff"):
    text = data[2:].decode("utf-16-be", errors="strict")
elif data.startswith(b"\xef\xbb\xbf"):
    text = data[3:].decode("utf-8", errors="strict")
else:
    try:
        text = data.decode("utf-8", errors="strict")
    except UnicodeDecodeError:
        try:
            text = data.decode("utf-16-le", errors="strict")
        except UnicodeDecodeError:
            text = data.decode("utf-16-be", errors="strict")

text = text.replace("\x00", "")

with open(output_path, "w", encoding="utf-8") as fh:
    fh.write(text)
PY
  else
    LC_ALL=C tr -d '\000' <"$input_path" | sed $'1s/^\\xEF\\xBB\\xBF//' >"$output_path"
  fi
}

add_policy_entry() {
  local key="$1"
  local json_value="$2"
  jq -n --arg key "$key" --argjson value "$json_value" '{($key): $value}' >>"$TMP_POLICY"
}

apply_from_config() {
  local config_path="$1"
  local dns_templates="$2"

  if [[ ! -f "$config_path" ]]; then
    echo "Config file not found: $config_path" >&2
    exit 1
  fi

  local features
  local dns_mode
  cleanup() {
    [[ -n "${SANITIZED_CONFIG:-}" ]] && rm -f "$SANITIZED_CONFIG"
    [[ -n "${TMP_POLICY:-}" ]] && rm -f "$TMP_POLICY"
  }
  trap cleanup EXIT

  SANITIZED_CONFIG=$(mktemp)
  sanitize_config "$config_path" "$SANITIZED_CONFIG"
  mapfile -t features < <(jq -r '.Features[]?' "$SANITIZED_CONFIG")
  dns_mode=$(jq -r '.DnsMode // empty' "$SANITIZED_CONFIG")

  TMP_POLICY=$(mktemp)

  for feature in "${features[@]:-}"; do
    if [[ -z "$feature" ]]; then
      continue
    fi
    case "$feature" in
      MetricsReportingEnabled) add_policy_entry "$feature" "false" ;;
      SafeBrowsingExtendedReportingEnabled) add_policy_entry "$feature" "false" ;;
      UrlKeyedAnonymizedDataCollectionEnabled) add_policy_entry "$feature" "false" ;;
      FeedbackSurveysEnabled) add_policy_entry "$feature" "false" ;;
      SafeBrowsingProtectionLevel) add_policy_entry "$feature" "0" ;;
      AutofillAddressEnabled) add_policy_entry "$feature" "false" ;;
      AutofillCreditCardEnabled) add_policy_entry "$feature" "false" ;;
      PasswordManagerEnabled) add_policy_entry "$feature" "false" ;;
      BrowserSignin) add_policy_entry "$feature" "0" ;;
      WebRtcIPHandling) add_policy_entry "$feature" '"disable_non_proxied_udp"' ;;
      QuicAllowed) add_policy_entry "$feature" "false" ;;
      BlockThirdPartyCookies) add_policy_entry "$feature" "true" ;;
      ForceGoogleSafeSearch) add_policy_entry "$feature" "true" ;;
      IncognitoModeAvailability) add_policy_entry "$feature" "1" ;;
      IncognitoModeAvailabilityForce) add_policy_entry "IncognitoModeAvailability" "2" ;;
      BraveRewardsDisabled) add_policy_entry "$feature" "true" ;;
      BraveWalletDisabled) add_policy_entry "$feature" "true" ;;
      BraveVPNDisabled) add_policy_entry "$feature" "true" ;;
      BraveAIChatEnabled) add_policy_entry "$feature" "false" ;;
      BraveShieldsDisabledForUrls) add_policy_entry "$feature" '["https://*", "http://*"]' ;;
      TorDisabled) add_policy_entry "$feature" "true" ;;
      SyncDisabled) add_policy_entry "$feature" "true" ;;
      BackgroundModeEnabled) add_policy_entry "$feature" "false" ;;
      MediaRecommendationsEnabled) add_policy_entry "$feature" "false" ;;
      ShoppingListEnabled) add_policy_entry "$feature" "false" ;;
      AlwaysOpenPdfExternally) add_policy_entry "$feature" "true" ;;
      TranslateEnabled) add_policy_entry "$feature" "false" ;;
      SpellcheckEnabled) add_policy_entry "$feature" "false" ;;
      PromotionsEnabled) add_policy_entry "$feature" "false" ;;
      SearchSuggestEnabled) add_policy_entry "$feature" "false" ;;
      PrintingEnabled) add_policy_entry "$feature" "false" ;;
      DefaultBrowserSettingEnabled) add_policy_entry "$feature" "false" ;;
      *)
        echo "Warning: unsupported feature key '$feature' in config." >&2
        ;;
    esac
  done

  if [[ -n "$dns_mode" ]]; then
    local policy_dns_mode="$dns_mode"
    if [[ "$dns_mode" == "custom" ]]; then
      policy_dns_mode="secure"
    fi
    add_policy_entry "DnsOverHttpsMode" "\"$policy_dns_mode\""
    if [[ "$dns_mode" == "custom" ]]; then
      if [[ -n "$dns_templates" ]]; then
        add_policy_entry "DnsOverHttpsTemplates" "\"$dns_templates\""
      else
        echo "Warning: DnsMode is 'custom' but no --doh-templates provided." >&2
      fi
    fi
  fi

  mkdir -p "$POLICY_DIR"
  if [[ ! -s "$TMP_POLICY" ]]; then
    echo "No supported features were found in the config; no policy file was written." >&2
    exit 1
  fi

  jq -s 'add' "$TMP_POLICY" >"$POLICY_FILE"
  echo "SlimBrave policies applied to $POLICY_FILE"
}

export_to_config() {
  local output_path="$1"
  if [[ ! -f "$POLICY_FILE" ]]; then
    echo "Policy file not found: $POLICY_FILE" >&2
    exit 1
  fi

  local features=()
  local policy="$POLICY_FILE"

  if jq -e '.MetricsReportingEnabled == false' "$policy" >/dev/null; then features+=("MetricsReportingEnabled"); fi
  if jq -e '.SafeBrowsingExtendedReportingEnabled == false' "$policy" >/dev/null; then features+=("SafeBrowsingExtendedReportingEnabled"); fi
  if jq -e '.UrlKeyedAnonymizedDataCollectionEnabled == false' "$policy" >/dev/null; then features+=("UrlKeyedAnonymizedDataCollectionEnabled"); fi
  if jq -e '.FeedbackSurveysEnabled == false' "$policy" >/dev/null; then features+=("FeedbackSurveysEnabled"); fi
  if jq -e '.SafeBrowsingProtectionLevel == 0' "$policy" >/dev/null; then features+=("SafeBrowsingProtectionLevel"); fi
  if jq -e '.AutofillAddressEnabled == false' "$policy" >/dev/null; then features+=("AutofillAddressEnabled"); fi
  if jq -e '.AutofillCreditCardEnabled == false' "$policy" >/dev/null; then features+=("AutofillCreditCardEnabled"); fi
  if jq -e '.PasswordManagerEnabled == false' "$policy" >/dev/null; then features+=("PasswordManagerEnabled"); fi
  if jq -e '.BrowserSignin == 0' "$policy" >/dev/null; then features+=("BrowserSignin"); fi
  if jq -e '.WebRtcIPHandling == "disable_non_proxied_udp"' "$policy" >/dev/null; then features+=("WebRtcIPHandling"); fi
  if jq -e '.QuicAllowed == false' "$policy" >/dev/null; then features+=("QuicAllowed"); fi
  if jq -e '.BlockThirdPartyCookies == true' "$policy" >/dev/null; then features+=("BlockThirdPartyCookies"); fi
  if jq -e '.ForceGoogleSafeSearch == true' "$policy" >/dev/null; then features+=("ForceGoogleSafeSearch"); fi
  if jq -e '.IncognitoModeAvailability == 1' "$policy" >/dev/null; then features+=("IncognitoModeAvailability"); fi
  if jq -e '.IncognitoModeAvailability == 2' "$policy" >/dev/null; then features+=("IncognitoModeAvailabilityForce"); fi
  if jq -e '.BraveRewardsDisabled == true' "$policy" >/dev/null; then features+=("BraveRewardsDisabled"); fi
  if jq -e '.BraveWalletDisabled == true' "$policy" >/dev/null; then features+=("BraveWalletDisabled"); fi
  if jq -e '.BraveVPNDisabled == true' "$policy" >/dev/null; then features+=("BraveVPNDisabled"); fi
  if jq -e '.BraveAIChatEnabled == false' "$policy" >/dev/null; then features+=("BraveAIChatEnabled"); fi
  if jq -e '.BraveShieldsDisabledForUrls == ["https://*", "http://*"]' "$policy" >/dev/null; then features+=("BraveShieldsDisabledForUrls"); fi
  if jq -e '.TorDisabled == true' "$policy" >/dev/null; then features+=("TorDisabled"); fi
  if jq -e '.SyncDisabled == true' "$policy" >/dev/null; then features+=("SyncDisabled"); fi
  if jq -e '.BackgroundModeEnabled == false' "$policy" >/dev/null; then features+=("BackgroundModeEnabled"); fi
  if jq -e '.MediaRecommendationsEnabled == false' "$policy" >/dev/null; then features+=("MediaRecommendationsEnabled"); fi
  if jq -e '.ShoppingListEnabled == false' "$policy" >/dev/null; then features+=("ShoppingListEnabled"); fi
  if jq -e '.AlwaysOpenPdfExternally == true' "$policy" >/dev/null; then features+=("AlwaysOpenPdfExternally"); fi
  if jq -e '.TranslateEnabled == false' "$policy" >/dev/null; then features+=("TranslateEnabled"); fi
  if jq -e '.SpellcheckEnabled == false' "$policy" >/dev/null; then features+=("SpellcheckEnabled"); fi
  if jq -e '.PromotionsEnabled == false' "$policy" >/dev/null; then features+=("PromotionsEnabled"); fi
  if jq -e '.SearchSuggestEnabled == false' "$policy" >/dev/null; then features+=("SearchSuggestEnabled"); fi
  if jq -e '.PrintingEnabled == false' "$policy" >/dev/null; then features+=("PrintingEnabled"); fi
  if jq -e '.DefaultBrowserSettingEnabled == false' "$policy" >/dev/null; then features+=("DefaultBrowserSettingEnabled"); fi

  local dns_mode
  local dns_templates
  dns_mode=$(jq -r '.DnsOverHttpsMode // empty' "$policy")
  dns_templates=$(jq -r '.DnsOverHttpsTemplates // empty' "$policy")
  if [[ "$dns_mode" == "secure" && -n "$dns_templates" ]]; then
    dns_mode="custom"
  fi

  jq -n --argjson features "$(printf '%s\n' "${features[@]}" | jq -R . | jq -s .)" \
    --arg dnsmode "$dns_mode" \
    '{Features: $features, DnsMode: ($dnsmode | if length > 0 then . else null end)}' >"$output_path"

  echo "SlimBrave settings exported to $output_path"
}

run_interactive() {
  local dns_templates="$1"
  local dns_mode=""
  local temp_config=""
  local -A selected=()
  local -a features=()
  temp_config=$(mktemp)
  trap 'rm -f "$temp_config"' EXIT

  local -a telemetry_labels=(
    "Disable Metrics Reporting"
    "Disable Safe Browsing Reporting"
    "Disable URL Data Collection"
    "Disable Feedback Surveys"
  )
  local -a telemetry_keys=(
    "MetricsReportingEnabled"
    "SafeBrowsingExtendedReportingEnabled"
    "UrlKeyedAnonymizedDataCollectionEnabled"
    "FeedbackSurveysEnabled"
  )

  local -a privacy_labels=(
    "Disable Safe Browsing"
    "Disable Autofill (Addresses)"
    "Disable Autofill (Credit Cards)"
    "Disable Password Manager"
    "Disable Browser Sign-in"
    "Disable WebRTC IP Leak"
    "Disable QUIC Protocol"
    "Block Third Party Cookies"
    "Force Google SafeSearch"
    "Disable Incognito Mode"
    "Force Incognito Mode"
  )
  local -a privacy_keys=(
    "SafeBrowsingProtectionLevel"
    "AutofillAddressEnabled"
    "AutofillCreditCardEnabled"
    "PasswordManagerEnabled"
    "BrowserSignin"
    "WebRtcIPHandling"
    "QuicAllowed"
    "BlockThirdPartyCookies"
    "ForceGoogleSafeSearch"
    "IncognitoModeAvailability"
    "IncognitoModeAvailabilityForce"
  )

  local -a brave_labels=(
    "Disable Brave Rewards"
    "Disable Brave Wallet"
    "Disable Brave VPN"
    "Disable Brave AI Chat"
    "Disable Brave Shields"
    "Disable Tor"
    "Disable Sync"
  )
  local -a brave_keys=(
    "BraveRewardsDisabled"
    "BraveWalletDisabled"
    "BraveVPNDisabled"
    "BraveAIChatEnabled"
    "BraveShieldsDisabledForUrls"
    "TorDisabled"
    "SyncDisabled"
  )

  local -a perf_labels=(
    "Disable Background Mode"
    "Disable Media Recommendations"
    "Disable Shopping List"
    "Always Open PDF Externally"
    "Disable Translate"
    "Disable Spellcheck"
    "Disable Promotions"
    "Disable Search Suggestions"
    "Disable Printing"
    "Disable Default Browser Prompt"
  )
  local -a perf_keys=(
    "BackgroundModeEnabled"
    "MediaRecommendationsEnabled"
    "ShoppingListEnabled"
    "AlwaysOpenPdfExternally"
    "TranslateEnabled"
    "SpellcheckEnabled"
    "PromotionsEnabled"
    "SearchSuggestEnabled"
    "PrintingEnabled"
    "DefaultBrowserSettingEnabled"
  )

  toggle_feature() {
    local key="$1"
    if [[ -n "${selected[$key]:-}" ]]; then
      unset "selected[$key]"
    else
      selected["$key"]=1
    fi
  }

  render_category() {
    local title="$1"
    local labels_name="$2"
    local keys_name="$3"
    local page="$4"
    local -n labels_ref="$labels_name"
    local -n keys_ref="$keys_name"
    local page_size=9
    local start=$((page * page_size))
    local end=$((start + page_size))

    printf '\033c'
    echo "SlimBrave Interactive Setup"
    echo "Category: $title"
    echo

    local i
    for ((i=start; i<end && i<${#labels_ref[@]}; i++)); do
      local index=$((i - start + 1))
      local key="${keys_ref[$i]}"
      local status="[ ]"
      if [[ -n "${selected[$key]:-}" ]]; then
        status="[x]"
      fi
      printf " %d) %s %s\n" "$index" "$status" "${labels_ref[$i]}"
    done

    echo
    echo "Press number to toggle, n/p to navigate pages, b to go back."
  }

  category_menu() {
    local title="$1"
    local labels_name="$2"
    local keys_name="$3"
    local -n labels_ref="$labels_name"
    local -n keys_ref="$keys_name"
    local page=0
    local page_size=9
    local max_page=$(( (${#labels_ref[@]} + page_size - 1) / page_size - 1 ))

    while true; do
      render_category "$title" "$labels_name" "$keys_name" "$page"
      read -rsn1 keypress
      case "$keypress" in
        b|B) return ;;
        n|N) if (( page < max_page )); then page=$((page + 1)); fi ;;
        p|P) if (( page > 0 )); then page=$((page - 1)); fi ;;
        [1-9])
          local idx=$((page * page_size + keypress - 1))
          if (( idx >= 0 && idx < ${#keys_ref[@]} )); then
            toggle_feature "${keys_ref[$idx]}"
          fi
          ;;
      esac
    done
  }

  dns_menu() {
    while true; do
      printf '\033c'
      echo "SlimBrave Interactive Setup"
      echo "DNS Over HTTPS Mode"
      echo
      echo " 1) automatic"
      echo " 2) off"
      echo " 3) custom"
      echo " 4) skip"
      echo
      echo "Press a number to choose."
      read -rsn1 keypress
      case "$keypress" in
        1) dns_mode="automatic"; return ;;
        2) dns_mode="off"; return ;;
        3) dns_mode="custom"; return ;;
        4) dns_mode=""; return ;;
      esac
    done
  }

  main_menu() {
    while true; do
      printf '\033c'
      echo "SlimBrave Interactive Setup"
      echo
      echo " 1) Telemetry & Reporting"
      echo " 2) Privacy & Security"
      echo " 3) Brave Features"
      echo " 4) Performance & Bloat"
      echo " 5) DNS Over HTTPS Mode"
      echo " a) Apply settings"
      echo " q) Quit"
      echo
      echo "Press a key to continue."
      read -rsn1 keypress
      case "$keypress" in
        1) category_menu "Telemetry & Reporting" telemetry_labels telemetry_keys ;;
        2) category_menu "Privacy & Security" privacy_labels privacy_keys ;;
        3) category_menu "Brave Features" brave_labels brave_keys ;;
        4) category_menu "Performance & Bloat" perf_labels perf_keys ;;
        5) dns_menu ;;
        a|A) return ;;
        q|Q) exit 0 ;;
      esac
    done
  }

  while true; do
    main_menu

    local -a all_keys=(
      "${telemetry_keys[@]}"
      "${privacy_keys[@]}"
      "${brave_keys[@]}"
      "${perf_keys[@]}"
    )
    local key
    features=()
    for key in "${all_keys[@]}"; do
      if [[ -n "$key" && -n "${selected[$key]:-}" ]]; then
        features+=("$key")
      fi
    done

    if [[ ${#features[@]} -eq 0 && -z "$dns_mode" ]]; then
      echo "No settings selected. Press any key to return to the menu."
      read -rsn1
      continue
    fi

    if [[ "$dns_mode" == "custom" && -z "$dns_templates" ]]; then
      read -r -p "Enter DoH template URL (required for custom mode): " dns_templates
    fi

    break
  done

  local features_json="[]"
  if [[ ${#features[@]} -gt 0 ]]; then
    features_json=$(printf '%s\n' "${features[@]}" | awk 'NF' | jq -R . | jq -s .)
  fi

  jq -n --argjson features "$features_json" \
    --arg dnsmode "$dns_mode" \
    '{Features: $features, DnsMode: ($dnsmode | if length > 0 then . else null end)}' >"$temp_config"

  apply_from_config "$temp_config" "$dns_templates"
}

reset_policies() {
  if [[ -f "$POLICY_FILE" ]]; then
    rm -f "$POLICY_FILE"
    echo "Removed $POLICY_FILE"
  else
    echo "No policy file found at $POLICY_FILE"
  fi
}

main() {
  local import_path=""
  local export_path=""
  local reset_requested="false"
  local dns_templates=""
  local interactive_requested="false"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --import)
        import_path="$2"
        shift 2
        ;;
      --export)
        export_path="$2"
        shift 2
        ;;
      --reset)
        reset_requested="true"
        shift
        ;;
      --interactive)
        interactive_requested="true"
        shift
        ;;
      --policy-file)
        POLICY_FILE="$2"
        POLICY_DIR=$(dirname "$POLICY_FILE")
        shift 2
        ;;
      --doh-templates)
        dns_templates="$2"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown option: $1" >&2
        usage
        exit 1
        ;;
    esac
  done

  if [[ -z "$import_path" && -z "$export_path" && "$reset_requested" != "true" && "$interactive_requested" != "true" ]]; then
    usage
    exit 1
  fi

  require_root
  require_jq

  if [[ "$reset_requested" == "true" ]]; then
    reset_policies
  fi

  if [[ "$interactive_requested" == "true" ]]; then
    run_interactive "$dns_templates"
  fi

  if [[ -n "$import_path" ]]; then
    apply_from_config "$import_path" "$dns_templates"
  fi

  if [[ -n "$export_path" ]]; then
    export_to_config "$export_path"
  fi
}

main "$@"
