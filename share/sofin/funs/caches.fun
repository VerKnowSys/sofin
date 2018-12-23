
less_logs () {
    ${LESS_BIN} ${DEFAULT_LESS_OPTIONS} ${LOGS_DIR}/${SOFIN_NAME}-*${1}* 2>/dev/null
    return 0
}


show_logs () {
    _logf_pattern="${1:-+}"
    debug "Show logs pattern: '$(distd "${_logf_pattern}")'"
    touch_logsdir_and_logfile
    if [ "-" = "${_logf_pattern}" ] \
    || [ "${SOFIN_NAME}" = "${_logf_pattern}" ]; then
        ${TAIL_BIN} -n "${LOG_LINES_AMOUNT}" "${LOG}"

    elif [ "@" = "${_logf_pattern}" ]; then
        unset _all_files
        for _mr in $(${FIND_BIN} "${LOGS_DIR%/}" -name "${SOFIN_NAME}*" -not -name "*.log" -not -name "*.help" -not -name "*.strip" -type f 2>/dev/null); do
            _all_files="${_mr} ${_all_files}"
        done
        eval "${TAIL_BIN} -n1 -F ${_all_files}"

    elif [ "+" = "${_logf_pattern}" ]; then
        unset _all_files
        for _mr in $(find_most_recent "${LOGS_DIR%/}" "${SOFIN_NAME}*" | ${HEAD_BIN} -n "${LOG_LAST_FILES}" 2>/dev/null); do
            _all_files="${_mr} ${_all_files}"
        done
        eval "${TAIL_BIN} -n ${LOG_LINES_AMOUNT} -F ${_all_files}"

    else
        unset _all_files
        for _mr in $(${FIND_BIN} "${LOGS_DIR%/}" -name "${SOFIN_NAME}*${_logf_pattern}*" -not -name "*.log" -not -name "*.help" -not -name "*.strip" -type f 2>/dev/null); do
            _all_files="${_mr} ${_all_files}"
        done
        if [ -n "${_all_files}" ]; then
            _2x_more_lines=$(( ${LOG_LINES_AMOUNT} * 2 ))
            eval "${TAIL_BIN} -F -n ${_2x_more_lines} ${_all_files}"
        else
            return 1
        fi
    fi
    unset _files_x_min _logf_minutes _logf_pattern _files_list _files_count _files_blist _mod_f_names _all_count
}


pretouch_logs () {
    _params="${*}"
    if [ -z "${CAP_SYS_PRODUCTION}" ]; then
        debug "Calling log-pretouch for: $(distd "$(printf "%b\n" "${_params}" | ${WC_BIN} -w 2>/dev/null)") files…"
        unset _pret_list
        for _app in $(to_iter "${_params}"); do
            if [ -z "${_app}" ]; then
                debug "Empty app given out of params: $(distd "${_params}")?"
            else
                if [ -z "${_pret_list}" ]; then
                    _pret_list="${LOGS_DIR}${SOFIN_NAME}-${_app}"
                else
                    _pret_list="${LOGS_DIR}${SOFIN_NAME}-${_app} ${_pret_list}"
                fi
            fi
        done
        ${TOUCH_BIN} ${LOGS_DIR}${SOFIN_NAME} ${_pret_list} >/dev/null 2>&1
        unset _app _params
    fi
}


show_log_if_available () {
    if [ -f "${LOG}" ]; then
        note "$(fill)"
        ${TAIL_BIN} -n "${LOG_LINES_AMOUNT_ON_ERR}" "${LOG}" 2>/dev/null
    else
        debug "No log available to attach tail to.."
    fi
}


touch_logsdir_and_logfile () {
    ${MKDIR_BIN} -p "${LOGS_DIR}" >/dev/null 2>&1
    ${TOUCH_BIN} "${LOG}" >/dev/null 2>&1
}


checksum_filecache_element () {
    _file_to_checksum="${1}"
    if [ -z "${_file_to_checksum}" ]; then
        error "First argument with $(diste "file-name-to-chksum") is required!"
    fi
    _file_chksum="$(file_checksum "${FILE_CACHE_DIR}${_file_to_checksum}")"
    if [ -z "${_file_chksum}" ]; then
        error "Empty checksum of file: $(diste "${FILE_CACHE_DIR}${_file_to_checksum}")"
    elif [ ! -f "${FILE_CACHE_DIR}${_file_to_checksum}" ]; then
        error "No such file found in file-cache: $(diste "${FILE_CACHE_DIR}${_file_to_checksum}")"
    else
        _chksum_file="${FILE_CACHE_DIR}${_file_to_checksum}${DEFAULT_CHKSUM_EXT}"
        printf "%b\n" "${_file_chksum}" > "${_chksum_file}" \
            && debug "Stored chksum: $(distd "${_file_chksum}") of file: $(distd "${_file_to_checksum}") in path: $(distd "${FILE_CACHE_DIR}${_file_to_checksum}")"
    fi
    unset _file_chksum _file_to_checksum _chksum_file
}


dump_software_build_configuration_options () {
    _config_log="${1}"
    if [ ! -f "${_config_log}" ]; then
        # Store all options per definition from configure scripts
        ${MKDIR_BIN} -p "$(${DIRNAME_BIN} "${_config_log}" 2>/dev/null)"
        # Copy whole configuration block from stdout but additionally redirect stderr to stdout:
        try "${DEF_CONFIGURE_METHOD} -h 2>&1 | ${TEE_BIN} '${_config_log}' 2>/dev/null" \
            && debug "Configuration options dump has been written to: $(distd "${_config_log}")"

        printf "%b ----Build--Configuration--Options----> \n%b %b\n" \
                "${ColorBlue}" \
                "$(${CAT_BIN} "${_config_log}" | ${GREP_BIN} -E '\-\-\s*' 2>&1)" \
                "${ColorReset}"
    fi
    _configuration_opts_only="${ColorBlue}$(${CAT_BIN} "${_config_log}")${ColorReset}"
    if [ -n "${DEBUG}" ] \
    || [ "YES" = "${CAP_SYS_BUILDHOST}" ]; then
        note "Available configuration options available in file: '$(distd "${_config_log}" "${ColorExample}")'"
        debug "Available configuration options in details: '$(distd "${_configuration_opts_only}" "${ColorBlue}")'"
    else
        note "Available configuration options available in file: '$(distd "${_config_log}" "${ColorExample}")'"
    fi
    return 0
}
