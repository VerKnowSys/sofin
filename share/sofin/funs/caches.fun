
less_logs () {
    ${LESS_BIN} ${DEFAULT_LESS_OPTIONS} ${LOGS_DIR}/${SOFIN_NAME}-*${1}* 2>/dev/null
    return 0
}


show_logs () {
    clear
    _logf_pattern="${1:-+}"
    touch_logsdir_and_logfile
    if [ "-" = "${_logf_pattern}" ] || \
       [ "${SOFIN_NAME}" = "${_logf_pattern}" ]; then
        ${TAIL_BIN} -n "${LOG_LINES_AMOUNT}" "${LOG}" 2>&1

    elif [ "@" = "${_logf_pattern}" ]; then
        if [ -d "${LOGS_DIR}" ]; then
            unset _all_files
            for _mr in $(${FIND_BIN} "${LOGS_DIR%/}" -name "${SOFIN_NAME}*" -not -name "*.log" -not -name "*.help" -not -name "*.strip" -type f 2>/dev/null); do
                _all_files="${_mr} ${_all_files}"
            done
            _all_count="$(echo "${_all_files}" | env "${WORDS_COUNT_GUARD}")"
            debug "@ Loading tail of $(distd "${_all_count}") log files"
            eval "${TAIL_BIN} -F ${_all_files}" 2>&1
        else
            note "@ No logs to attach to. LOGS_DIR='$(distn "${LOGS_DIR}")' contain no log files?"
        fi

    elif [ "+" = "${_logf_pattern}" ]; then
        if [ -d "${LOGS_DIR}" ]; then
            unset _all_files
            for _mr in $(find_most_recent "${LOGS_DIR%/}" "${SOFIN_NAME}*" | ${HEAD_BIN} -n "${LOG_LAST_FILES}" 2>/dev/null); do
                _all_files="${_mr} ${_all_files}"
            done
            _all_count="$(echo "${_all_files}" | env "${WORDS_COUNT_GUARD}")"
            debug "+ Loading tail of $(distd "${_all_count}") log files"
            eval "${TAIL_BIN} -n ${LOG_LINES_AMOUNT} -F ${_all_files}" 2>&1
        else
            note "+ No logs to attach to. LOGS_DIR='$(distn "${LOGS_DIR}")' contain no log files?"
        fi

    else
        if [ -d "${LOGS_DIR}" ]; then
            _patie="${LOGS_DIR}${SOFIN_NAME}-${_logf_pattern}"
            note "Show long tail with file pattern: '$(distd "${_patie}")'"
            ${TAIL_BIN} -F -n "$(calculate_bc "50 + ${LOG_LINES_AMOUNT}")" ${_patie}* 2>&1
        else
            note "No log match='$(distn "${_logf_pattern}")' contains no pattern or name."
        fi
    fi
    unset _files_x_min _logf_minutes _logf_pattern _files_list _files_count _files_blist _mod_f_names _all_count
}


pretouch_logs () {
    _params="${*}"
    if [ -z "${CAP_SYS_PRODUCTION}" ]; then
        debug "Logs pretouch called with params: $(distd "${_params}")"
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
        try "${TOUCH_BIN} ${LOGS_DIR}${SOFIN_NAME} ${_pret_list}"
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
        ${PRINTF_BIN} '%s' "${_file_chksum}" > "${_chksum_file}" && \
            debug "Stored chksum: $(distd "${_file_chksum}") of file: $(distd "${_file_to_checksum}") in path: $(distd "${FILE_CACHE_DIR}${_file_to_checksum}")"
    fi
    unset _file_chksum _file_to_checksum _chksum_file
}


cache_conf_scrpt_hlp_opts () {
    _config_log="${1}"
    if [ ! -f "${_config_log}" ]; then
        # Store all options per definition from configure scripts
        try "${MKDIR_BIN} -p \"$(${DIRNAME_BIN} "${_config_log}" 2>/dev/null)\" 2>/dev/null" \
            && try "${DEF_CONFIGURE_METHOD} -h | ${GREP_BIN} -E '\-\-\s*' 2>/dev/null > \"${_config_log}\""
    fi
    debug "Configure options: $(distd "$(${CAT_BIN} "${_config_log}" 2>/dev/null)" "${ColorExample}")"
    return 0
}
