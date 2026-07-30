#!/usr/bin/env bash
set -e

mageops::get_ec2_tag_value() {
    local region=$1
    local instance_id=$2
    local tag_name=$3

    aws ec2 describe-tags --region "${region}" \
        --filters "Name=resource-id,Values=${instance_id}" \
        "Name=key,Values=${tag_name}" | jq -r '.Tags[].Value' || return 1
}

mageops::get_tag_value() {
    local tag_name=$1

    local instance_id
    local found_value
    local region
    region="$(aws::get_current_region)"
    instance_id="$(aws::current_instance_id)"
    found_value="$(mageops::get_ec2_tag_value "$region" \
        "$instance_id" "$tag_name")"

    echo "$found_value"
}

mageops::is_tag_exists() {
    local tag_name=$1

    local instance_id
    local found_value
    local region
    region="$(aws::get_current_region)"
    instance_id="$(aws::current_instance_id)"
    found_value="$(mageops::get_ec2_tag_value "$region" \
        "$instance_id" "$tag_name")"

    if [ -n "$found_value" ];then
        return 0
    fi
    return 1
}

mageops::assert_tag_value() {
    local tag_name=$1
    local tag_value=$2

    local instance_id
    local found_value
    local region
    region="$(aws::get_current_region)"
    instance_id="$(aws::current_instance_id)"
    found_value="$(mageops::get_ec2_tag_value "$region" \
        "$instance_id" "$tag_name")"

    if [ "$tag_value" = "$found_value" ];then
        return 0
    fi
    return 1
}

mageops::read_s3_file() {
    local url=$1

    aws s3 cp "$url" -
}

mageops::update_s3_file() {
    local url=$1
    local content=$2

    echo "$content" | aws s3 cp - "$url"
}

mageops::set_security_updates_scope() {
    local state=$1
    local scope=$2

    if [ "$scope" = all ] || [ "$scope" = app ];then
        features::update_feature_flag security_updates_app "$state"
    fi

    if [ "$scope" = all ] || [ "$scope" = varnish ];then
        features::update_feature_flag security_updates_varnish "$state"
    fi

    if [ "$scope" = all ] || [ "$scope" = persistent ];then
        features::update_feature_flag security_updates_persistent "$state"
    fi

    case "$scope" in
    all|app|varnish|persistent)
        return 0
    ;;
    *)
        return 2
    ;;
    esac
}

mageops::security_updates_log() {
    local message="$1"
    local log_identifier="${LOG_IDENTIFIER:-security-updates}"

    logger -t "$log_identifier" -- "$message"
    printf '%s\n' "$message"
}

mageops::json_escape() {
    local value="$1"

    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//$'\r'/}"
    value="${value//$'\n'/\\n}"

    printf '%s' "$value"
}

mageops::security_updates_slack_payload() {
    local message="$1"
    local channel="${SLACK_CHANNEL:-}"
    local channel_json=""

    message="$(mageops::json_escape "$message")"
    channel="$(mageops::json_escape "$channel")"

    if [[ -n "$channel" ]]; then
        channel_json=",\"channel\":\"${channel}\""
    fi

    printf '{"text":"%s"%s}' "$message" "$channel_json"
}

mageops::security_updates_notify_slack_bot() {
    local message="$1"
    local slack_bot_token="${SLACK_BOT_TOKEN:-}"
    local response

    response="$(curl --silent --show-error --fail --max-time 10 \
        --header "Authorization: Bearer ${slack_bot_token}" \
        --header 'Content-Type: application/json; charset=utf-8' \
        --data "$(mageops::security_updates_slack_payload "$message")" \
        https://slack.com/api/chat.postMessage)" || {
        mageops::security_updates_log "Failed to send security update notification to Slack bot API."
        return 1
    }

    if ! printf '%s' "$response" | grep -q '"ok"[[:space:]]*:[[:space:]]*true'; then
        mageops::security_updates_log "Failed to send security update notification to Slack bot API: ${response}"
        return 1
    fi

    return 0
}

mageops::security_updates_notify() {
    local message="$1"
    local slack_bot_token="${SLACK_BOT_TOKEN:-}"
    local slack_channel="${SLACK_CHANNEL:-}"

    mageops::security_updates_log "$message"

    if [ "${SLACK_ENABLED:-true}" != true ]; then
        mageops::security_updates_log "Security update Slack notification skipped: SLACK_ENABLED is not true."
        return 0
    fi

    if [[ -z "$slack_bot_token" ]]; then
        mageops::security_updates_log "Security update Slack notification skipped: SLACK_BOT_TOKEN is empty."
        return 0
    fi

    if [[ -z "$slack_channel" ]]; then
        mageops::security_updates_log "Security update Slack notification skipped: SLACK_CHANNEL is empty."
        return 0
    fi

    mageops::security_updates_notify_slack_bot "$message" || true
}

mageops::security_updates_check_kill_switch_url() {
    local label="$1"
    local url="$2"
    local value

    if [[ -z "$url" ]]; then
        return 0
    fi

    value="$(curl --silent --show-error --fail --max-time 10 "$url" 2>/dev/null)" || {
        mageops::security_updates_log "Security updates ${label} kill switch could not be read; continuing."
        return 0
    }

    if [ "$value" = true ]; then
        mageops::security_updates_notify "Security updates blocked on $(hostname -f): ${label} kill switch is active."
        return 1
    fi

    return 0
}

mageops::security_updates_check() {
    local node_role="${SECURITY_UPDATES_NODE_ROLE:-generic}"
    local feature_value

    mageops::security_updates_check_kill_switch_url "global" "${GLOBAL_KILL_SWITCH_URL:-}" || return 1

    case "$node_role" in
    app|varnish|persistent)
        feature_value="$(features::read_feature_flag "security_updates_${node_role}" "true")"
        if [ "$feature_value" = true ];then
            return 0
        fi

        mageops::security_updates_log "Security updates skipped: features.json disabled security_updates_${node_role}."
        return 1
    ;;
    *)
        return 0
    ;;
    esac
}

mageops::security_updates_print_status() {
    local config_path="${SECURITY_UPDATES_CONFIG_PATH:-/etc/dnf/security-updates.conf}"
    local node_role="${SECURITY_UPDATES_NODE_ROLE:-generic}"
    local download_timer_name="dnf-automatic-download.timer"
    local install_timer_name="dnf-automatic-install.timer"
    local value

    printf 'Security updates setup\n'
    printf '  config: %s\n' "$config_path"
    printf '  node_role: %s\n' "$node_role"

    printf 'Features\n'
    case "$node_role" in
    app|varnish|persistent)
        value="$(features::read_feature_flag "security_updates_${node_role}" "true")"
        printf '  security_updates_%s: %s\n' "$node_role" "$value"
    ;;
    *)
        printf '  security_updates: not scoped for node role\n'
    ;;
    esac

    printf 'Systemd\n'
    if command -v systemctl >/dev/null 2>&1;then
        printf '  download_timer: %s\n' "$download_timer_name"
        value="$(systemctl is-enabled "$download_timer_name" 2>/dev/null || true)"
        printf '  download_timer_enabled: %s\n' "${value:-unknown}"
        value="$(systemctl is-active "$download_timer_name" 2>/dev/null || true)"
        printf '  download_timer_active: %s\n' "${value:-unknown}"
        printf '  install_timer: %s\n' "$install_timer_name"
        value="$(systemctl is-enabled "$install_timer_name" 2>/dev/null || true)"
        printf '  install_timer_enabled: %s\n' "${value:-unknown}"
        value="$(systemctl is-active "$install_timer_name" 2>/dev/null || true)"
        printf '  install_timer_active: %s\n' "${value:-unknown}"
    else
        printf '  download_timer: %s\n' "$download_timer_name"
        printf '  download_timer_enabled: unknown\n'
        printf '  download_timer_active: unknown\n'
        printf '  install_timer: %s\n' "$install_timer_name"
        printf '  install_timer_enabled: unknown\n'
        printf '  install_timer_active: unknown\n'
    fi
}

mageops::security_updates_download() {
    local report

    report="$(cat)"
    if [[ -z "$report" ]]; then
        return 0
    fi

    mkdir -p /run/security-updates
    touch /run/security-updates/dnf-automatic-emitted
    mageops::security_updates_notify "dnf-automatic report on $(hostname -f):
${report}"
}

mageops::security_updates_install() {
    local tracer_rc
    local restart_commands
    local restart_rc=0
    local reboot_exit_code="${SECURITY_UPDATES_REBOOT_EXIT_CODE:-1}"

    set +e
    tracer -va
    tracer_rc=$?
    set -e

    if [[ "$tracer_rc" -eq 0 ]]; then
        return 0
    fi

    if [[ "$tracer_rc" -lt 100 ]]; then
        mageops::security_updates_notify "Tracer failed after security updates on $(hostname -f) with exit code ${tracer_rc}."
        return "$tracer_rc"
    fi

    if [[ "$tracer_rc" -eq 102 ]]; then
        set +e
        restart_commands="$(tracer --daemons-only | tail -n +3 | sed '/^[[:space:]]*$/d')"
        set -e
        if [[ -n "$restart_commands" ]]; then
            mageops::security_updates_notify "Restarting services affected by security updates on $(hostname -f):
${restart_commands}"
            while IFS= read -r restart_command; do
                if ! bash -c "$restart_command"; then
                    restart_rc=1
                fi
            done <<< "$restart_commands"
        fi
        if [[ "$restart_rc" -ne 0 ]]; then
            mageops::security_updates_notify "One or more service restarts failed after security updates on $(hostname -f)."
        fi
        return "$restart_rc"
    fi

    if [[ "$tracer_rc" -eq 104 ]]; then
        mageops::security_updates_notify "Rebooting $(hostname -f) after security updates; tracer reported exit code ${tracer_rc}."
        /usr/bin/systemctl reboot
        exit "$reboot_exit_code"
    fi

    mageops::security_updates_notify "Security updates on $(hostname -f) left tracer advisory code ${tracer_rc}; no automatic host reboot performed."
    return 0
}

mageops::security_updates_install_if_downloaded() {
    if [[ ! -e /run/security-updates/dnf-automatic-emitted ]]; then
        return 0
    fi

    rm -f /run/security-updates/dnf-automatic-emitted
    mageops::security_updates_install
}

mageops::security_updates_startup_install() {
    local report
    local dnf_rc

    if ! mageops::security_updates_check;then
        mageops::security_updates_log "Security update startup install skipped on $(hostname -f): eligibility check blocked the run."
        return 0
    fi

    if ! command -v dnf >/dev/null 2>&1;then
        mageops::security_updates_notify "Security update startup install failed on $(hostname -f): dnf is not installed."
        return 127
    fi

    set +e
    report="$(dnf -y --security update 2>&1)"
    dnf_rc=$?
    set -e

    if [[ "$dnf_rc" -ne 0 ]];then
        mageops::security_updates_notify "Security update startup install failed on $(hostname -f) with exit code ${dnf_rc}:
${report}"
        return "$dnf_rc"
    fi

    if [[ "$report" =~ (Nothing[[:space:]]+to[[:space:]]+do|No[[:space:]]+security[[:space:]]+updates[[:space:]]+needed) ]];then
        mageops::security_updates_log "Security update startup install completed on $(hostname -f): no security updates to apply."
        return 0
    fi

    mageops::security_updates_notify "Security update startup install completed on $(hostname -f):
${report}"
    SECURITY_UPDATES_REBOOT_EXIT_CODE=194 mageops::security_updates_install
}


mageops::clear_php_opcache() {
    for dir in "${config__opcache_file_paths[@]}";do
        echo "Clearing opcache $dir..."
        rm -rf "$dir"
    done
    systemctl reload php-fpm
}
