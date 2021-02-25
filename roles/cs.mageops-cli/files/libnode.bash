#!/usr/bin/env bash

set -euo pipefail

node::log() {
    echo "$@"
}

node::loge() {
    echo "Error: $@" >&2
}

node::logw() {
    echo "Warning: $@" >&2
}

node::logf() {
    echo "Fatal: $@" >&2
}

node::logv() {
    [ ! -z "${MAGEOPS_VERBOSE:-}" ] || return 0

    echo "Info: $@" >&2
}

node::is_a_tty() {
    [ -t 1 ]
}

node::is_interactive() {
    node::is_a_tty \
        && [[ "$-" == *i* ]]
}

node::is_ansi_color_enabled() {
    node::is_a_tty \
        && [ -z "${MAGEOPS_NO_COLOR:-}" ] \
        && [ -z "${NO_COLOR:-}" ]
}

. "$config__sysconfig_path"

if [ ! -f "${config__sysconfig_path:=/etc/sysconfig/mageops}" ] ; then
    node::logf "Could not find MageOps sysconfig file: $config__sysconfig_path"
    return 99
fi

# Variables for caching dynamic data within the scope of a single command run
__node_instance_id=
__node_instance_data=

node::jq() {     
    [ ! -z "${JQ_FORCE_COLOR:-}" ] || export JQ_NO_COLOR=1

    local jqOpts=( "-L${MAGEOPS_CLI_LIB_PATH:-/var/lib/mageops}" )
    jqOpts+=( ${JQ_OPTS[@]:-} )
    
    command jq "${jqOpts[@]}" "$@"; ret=$?
    
    if [ $ret -gt 0 ]; then
        node::logw "Warning: [$ret] Could not execute node::jq query: $@"
        return $ret
    fi
}

node::format_output() {
    case "$outputMode" in
        json) node::jq -r ;;
        text) node::jq -r ;;
        env) node::jq -r ;;
        *) cat ;;
    esac
}

node::list_functions() {
    local prefix="${1:-}"
    compgen -A function | grep -E '^'"$prefix"'[^_]+' | sed -e 's/^'"$prefix"'//g'
}

node::get_instance_id() {
    echo "${__node_instance_id:="$(aws::get_current_instance_id)"}"
}

node::describe_instances() {
    local project="${1:-${MAGEOPS_PROJECT:-}}"; shift || true
    local env="${1:-${MAGEOPS_ENVIRONMENT:-}}"; shift || true
    local states="${1:-pending,running,stopped}"; shift || true
    local roles="${1:-"*"}"; shift || true
    
    aws ec2 describe-instances \
        --filters \
            Name=instance-state-name,Values="$states" \
            Name=tag:Environment,Values=${env} \
            Name=tag:Project,Values=${project} \
            Name=tag:Role,Values=${roles} \
                | node::jq 'import "aws" as aws; aws::reservations_to_instances'
}

node::describe_instance() {
    local instanceId="${1:-"$(node::get_instance_id)"}"; shift || true

    aws ec2 describe-instances \
        --instance-ids "$instanceId" "$@" \
            | node::jq 'import "aws" as aws; aws::reservations_to_instances | first'
}

node::get_instance_data() {
    echo "${__node_instance_data:="$(node::describe_instance | node::jq 'import "aws" as aws; aws::instance_data')"}"
}

node::get_instance_data_field() {
    local fieldName="${1:-}"

    echo "$(node::get_instance_data)" | node::jq -r ".${fieldName}"
}

node::get_instance_state() {
    node::get_instance_data_field 'state'
}

node::get_instance_lifecycle_state() {
    local instanceId="${1:-"$(node::get_instance_id)"}"
    # We're interested in two statuses:
    # - Pending - instance is being started up
    # - InService - instance is fully started and Healthcheck Grace Period has passed
     aws autoscaling describe-auto-scaling-instances \
        --instance-ids "$instanceId" \
            | node::jq -r '.AutoScalingInstances | first | .LifecycleState'
}

node::is_being_launched() {
    [[ "$(node::get_instance_lifecycle_state)" == "Pending" ]]
}

node::is_warming_up() {
    [[ $(node::get_instance_tag "AppWarmupState") == "is-warming-up" ]]
}

node::is_warmed_up() {
    [[ $(node::get_instance_tag "AppWarmupState") == "warmed-up" ]]
}

node::get_instance_tags() {
    local instanceId="${1:-"$(node::get_instance_id)"}"; shift || true

    aws ec2 describe-tags \
        --filters Name=resource-id,Values="$instanceId" \
                  Name=resource-type,Values=instance \
                  "$@" \
            | node::jq -r '.Tags'
}

node::get_instance_tag() {
    local tagName="${1:-}"
    local instanceId="${2:-"$(node::get_instance_id)"}"
    
    node::get_instance_tags "$instanceId" \
        Name=tag:"$tagName",Values='*' \
            | node::jq -r --arg "tagName" "$tagName" 'import "aws" as aws; aws::find_tag_value($tagName)'
}

node::get_instance_group_name() {
    node::get_instance_tag "aws:autoscaling:groupName"
}

node::in_in_group() {
    [ ! -z "$(node::get_instance_group_name)" ]
}

node::get_instance_nr_in_group() {
    # Return a number that indentifies this node uniquely in the scope
    # of current autoscaling group. We use last IPv4 component as all our
    # VPCs use /24 block.
    ( node::get_instance_data_field private_ip || hostname -i ) | cut -d. -f4
}

node::get_app_release_info() {
    if [ ! -f "${MAGEOPS_APP_RELEASE_JSON:-}" ] ; then
        if [ -z "${MAGEOPS_APP_RELEASE_JSON:-}" ] ; then
            node::loge "Could not get app release info: The variable MAGEOPS_APP_RELEASE_JSON is not set."
        else
            node::loge "Could not get app release info: The file ${MAGEOPS_APP_RELEASE_JSON:-} is missing."
        fi

        return 8
    fi

    local key="${1:-}"

    cat "${MAGEOPS_APP_RELEASE_JSON}" | node::jq -r ".${key}"
}

node::is_set_unhealthy_permitted() {
    [[ "$(node::get_instance_lifecycle_state)" != "InService" ]]
}

node::mark_instance_as_warmed_up() {
    local instanceId="${1:-"$(node::get_instance_id)"}"

    # Mark the instance as healthy as soon as the app warmup was completed
    # in order to sepped up the ASG instance refresh - and whole deploy.
    # Note: When setting healthy we ignore the grace period because we know
    # the instance is ready and shall be used at once.
    aws autoscaling set-instance-health \
        --instance-id "$instanceId" \
        --health-status Healthy \
        --no-should-respect-grace-period

    node::logv "Updated instance $instanceId autoscaling group health status to: Healthy"

    node::set_instance_tag "AppWarmupState" "warmed-up"

    node::logv "Marked instance $instanceId as warmed-up"
}

node::mark_instance_as_warming_up() {
    local instanceId="${1:-"$(node::get_instance_id)"}"

    if node::is_warming_up ; then
        node::logw "Will not mark instance $instanceId as warming-up: Instance is already marked as warming-up (in progress)."
        return 9
    fi

    if node::is_warmed_up ; then
        node::logw "Will not mark instance $instanceId as warming-up: Instance is marked as successfully warmed-up (completed)."
        return 9
    fi

    node::set_instance_tag "AppWarmupState" "is-warming-up"

    # Mark the instance as Unhealthy so ASG group still waits for it, before
    # replacing the next one during rolling refresh.
    # Note: When setting unhealthy respect the grace period, cause we do not
    # want the instance to be terminated before it had chance to start
    if ! node::in_in_group ; then
        node::loge "Will not mark instance $instanceId as warming-up: Instance is not a member of an autoscaling group."
        return 9
    else
        if node::is_set_unhealthy_permitted ; then
            aws autoscaling set-instance-health \
                --instance-id "$instanceId" \
                --health-status Unhealthy \
                --should-respect-grace-period

            node::logv "Updated instance $instanceId autoscaling group health status to: Unealthy"
        else 
            node::logw "Refusing to mark instance $instanceId as unhealthy as part of warming-up status: Instance is past the grace period."
            return 99
        fi
    fi
}

# Human-readable node name unique in the project-env scope
node::get_name() {
    local nodeName="$(node::get_instance_group_name || get_instance_data_field name || true)"
    local releaseNr="$(node::get_app_release_info nr || true)" 
    local instanceNr="$(node::get_instance_nr_in_group || true)"

    [ ! -z "$nodeName" ] || nodeName="${MAGEOPS_APP_NAME:-}"

    if [ -z "$nodeName" ] ; then
        loge "Cannot determine base node name"
        return 9
    fi

    [ -z "$releaseNr" ] || nodeName="${nodeName}-release-${releaseNr}"
    [ -z "$instanceNr" ] || nodeName="${nodeName}-node-${instanceNr}"

    echo "$nodeName"
}

node::get_inventory_hostname() {
    local publicIp="$(aws::get_current_instance_public_ip || node::get_instance_data_field public_ip || hostname -i || true)"

    [ ! -z "$publicIp" ] || return 8
        
    echo "$(node::get_name)-$publicIp"
}

node::set_instance_tag() {
    local key="$1"
    local value="$2"
    local instanceId="${3:-"$(node::get_instance_id)"}"

    aws ec2 create-tags \
        --resources "$instanceId" \
        --tags Key="$key",Value="$value"

    node::logv "Updated instance $instanceId tag: $key=$value"
}

node::set_node_name_instance_tag() {  
    local nodeName="$(node::get_name || true)"

    if [ -z "$nodeName" ] ; then
        loge "Could set node name tag: Failed to compute node name."
        return 8
    fi

    node::set_instance_tag "Name" "$nodeName"
}

node::set_inventory_hostname_instance_tag() {  
    local inventoryHostname="$(node::get_inventory_hostname || true)"

    if [ -z "$inventoryHostname" ] ; then
        loge "Could set inventory hostname name tag: Failed to compute hostname."
        return 8
    fi

    node::set_instance_tag "InventoryHostname" "$inventoryHostname"
}

node::has_app_release() {
    node::get_app_release_info >/dev/null
}

node::set_app_release_tags() {
    if ! node::has_app_release ; then
        loge "Cannot set app release tags: Could not read release info, is this an app node?."
        return 9
    fi

    local releaseNr="$(node::get_app_release_info nr || true)" 
    local releaseTimestamp="$(node::get_app_release_info timestamp || true)" 
    local releaseDate=

    if ! node::get_app_release_info nr >/dev/null ; then
        loge "Refusing to set app release tags: Could not read release number."
        return 8
    fi

    [ -z "$releaseTimestamp" ]  || releaseDate="$(printf "%(%FT%TZ)T" "$(( $releaseTimestamp / 1000 ))" || true)"
    [ ! -z "$releaseDate" ]     || releaseDate="$(node::get_app_release_info date || true)" 

    [ -z "$releaseNr" ]         || node::set_instance_tag "AppReleaseNr"         "$releaseNr"
    [ -z "$releaseTimestamp" ]  || node::set_instance_tag "AppReleaseTimestamp"  "$releaseTimestamp"
    [ -z "$releaseDate" ]       || node::set_instance_tag "AppReleaseDate"       "$releaseDate"
}

node::set_instance_tags() {   
    node::set_node_name_instance_tag
    node::set_app_release_tags
    node::set_inventory_hostname_instance_tag
}


