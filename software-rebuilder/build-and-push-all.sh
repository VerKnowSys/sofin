#!/usr/bin/env sh


SOFIN_ROOT="${SOFIN_ROOT:-/Software/Sofin}"
. "${SOFIN_ROOT}/share/loader"


# Notifications:
_slack_channel="#development"
_slack_webhook="$(${CAT_BIN} "${HOME}/.sofin.notification.webhook" 2>/dev/null)"
if [ -z "${_slack_webhook}" ]; then
    error "Please write your full Slack WebHook URL to file: $(diste "${HOME}/.sofin/.notification.webhook")"
fi

# Curl binary utlility:
_curl="${SERVICES_DIR}/Sofin/exports/curl"
if [ ! -L "${_curl}" ]; then
    error "Please install Curl-minimal as an utility, by calling: $(diste "s util Curl-minimal") first."
fi

# Host identification quadruple:
_host_quad="${HOST}: ${SYSTEM_NAME}-${SYSTEM_VERSION}-${SYSTEM_ARCH})"


# Example: $ slack_notification "ERROR" "some message!"
slack_notification () {
    _type="${1}"
    shift
    _message="${_type}: ${*}"
    case "${_type}" in
        FAIL|FAILURE|ERROR)
            _emoji=':dragon:'
            ;;
        *)
            _emoji=':bird:'
            ;;
    esac
    __slack_channel="${_slack_channel}"
    _slack_webhook_url="${_slack_webhook}"
    _payload="payload={\"channel\": \"${_channel//\"/\\\"}\", \"username\": \"${SofinCI//\"/\\\"}\", \"text\": \"${_message//\"/\\\"}\", \"icon_emoji\": \"${_emoji}\"}"
    "${_curl}" -m 5 \
        --data-urlencode "${_payload}" \
        "${_slack_webhook_url}" \
        -A 'SofinCI' \
            >> "${LOG}" 2>> "${LOG}"
}


permnote "Checking remote machine connection (shouldn't take more than a second).."
run "${SSH_BIN} sofin@software.verknowsys.com uname -a" \
    && slack_notification "INFO" "[${_host_quad}] Connection test passed${CHAR_DOTS} Ok!"

set +e

unset USE_NO_TEST

_working_state_file="/tmp/software.list.processing"
if [ ! -f "${_working_state_file}" ]; then
    permnote "Creating new work-state file: $(distn "${_working_state_file}")"
    run "${CP_BIN} -v software.list ${_working_state_file}"
    slack_notification "INFO" "[${_host_quad}] Starting new build iteration${CHAR_DOTS}"
    TIME_START_S="$(${DATE_BIN} +%s 2>/dev/null)"
fi

for _software in $(${CAT_BIN} ${_working_state_file} 2>/dev/null); do
    if [ "${_software}" = "------" ]; then
        permnote "All tasks finished!"
        TIME_END_S="$(${DATE_BIN} +%s 2>/dev/null)"
        ELAPSED_S=$(( ${TIME_END_S} - ${TIME_START_S} ))
        slack_notification "INFO" "[${_host_quad}] All tasks finished! Iteration took: ${ELAPSED_S} seconds."
        exit
    fi
    permnote "________________________________"

    _indicator="/Software/${_software}/$(lowercase "${_software}")${DEFAULT_INST_MARK_EXT}"
    if [ -d "/Software/${_software}" ] && [ -f "${_indicator}" ]; then
        warn "Found already prebuilt version of software: $(distw "${_software}"). Leaving untouched with version: $(distw "$(${CAT_BIN} "${_indicator}" 2>/dev/null)")"
        ${SED_BIN} -i '' -e "/${_software}/d" ${_working_state_file}
    else

        destroy_software_and_datadirs () {
            try "${SOFIN_BIN} rm ${_software}"
            try "${ZFS_BIN} destroy -fr ${DEFAULT_ZPOOL}${SOFTWARE_DIR}/root/${_software}"
            try "${ZFS_BIN} destroy -fr ${DEFAULT_ZPOOL}${SERVICES_DIR}/root/${_software}"
            try "${RM_BIN} -rf ${HOME}/.sofin/file-cache/$(capitalize_abs "${_software}")* '${SOFTWARE_DIR}/${_software}' '${SERVICES_DIR}/${_software}'"
        }

        permnote "Removing software: $(distn "${_software}")"
        try "${SOFIN_BIN} rm ${_software}"
        destroy_software_and_datadirs

        _bundle_time_start_s="$(${DATE_BIN} +%s 2>/dev/null)"
        permnote "Deploying software: $(distn "${_software}")"
        slack_notification "INFO" "[${_host_quad}] Deploying software bundle: ${_software}${CHAR_DOTS}"

        remove_from_list_and_destroy () {
            try "${SED_BIN} -i '' -e \"/${_software}/d\" ${_working_state_file}"
            destroy_software_and_datadirs
        }

        complete_subtask () {
            _bundle_time_finish_s="$(${DATE_BIN} +%s 2>/dev/null)"
            _bundle_time_total_s=$(( ${_bundle_time_finish_s} - ${_bundle_time_start_s} ))
            slack_notification "INFO" "[${_host_quad}] Successfully deployed bundle: ${_software} (took: ${_bundle_time_total_s} seconds)."
        }

        ${SOFIN_BIN} deploy "${_software}" \
            && complete_subtask \
            && remove_from_list_and_destroy \
            && continue

        slack_notification "FAILURE" "[${_host_quad}] Task: ('${SOFIN_BIN} deploy ${_software}') has crashed!"
        remove_from_list_and_destroy
    fi
    permnote "--------------------------------"
done
