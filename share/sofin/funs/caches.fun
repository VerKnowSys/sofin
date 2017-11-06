
log_helper () {
    _log_h_pattern="${1}"
    if [ -z "${_log_h_pattern}" ]; then
        _log_files="$(find_most_recent "${LOGS_DIR}" "${SOFIN_NAME}*")"
    else
        _log_files="$(find_most_recent "${LOGS_DIR}" "${SOFIN_NAME}*${_log_h_pattern}*")"
    fi
    _lognum_f="$(${PRINTF_BIN} '%s\n' "${_log_files}" | eval "${FILES_COUNT_GUARD}")"
    if [ -z "${_lognum_f}" ]; then
        _lognum_f="0"
    else
        debug "Found: $(distd "${_lognum_f}") recent log files matching pattern: $(distd "${_log_h_pattern}")"
    fi

    _log_h_pattern="$(echo "${_log_h_pattern}" | ${CUT_BIN} -f1-${LOG_LAST_FILES} -d' ' 2>/dev/null)"
    case ${_lognum_f} in
        0)
            ${TAIL_BIN} -n ${LOG_LINES_AMOUNT} ${LOGS_DIR}${SOFIN_NAME}-* 2>/dev/null
            ;;

        1)
            ${LESS_BIN} ${DEFAULT_LESS_OPTIONS} ${LOGS_DIR}/${SOFIN_NAME}-*${_log_h_pattern}* 2>/dev/null
            ;;

        *)
            note "Found $(distn "${_lognum_f}") log files, that match pattern: $(distn "${_log_h_pattern}"). Attaching to all available files.."
            ${TAIL_BIN} -n "${LOG_LINES_AMOUNT}" -F ${LOGS_DIR}${SOFIN_NAME}-*${_log_h_pattern}* 2>/dev/null
            ;;
    esac
    unset _log_h_pattern _log_files _lognum_f
}


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
            _all_files=""
            for _mr in $(${FIND_BIN} "${LOGS_DIR%/}" -name "${SOFIN_NAME}*" -type f 2>/dev/null); do
                _all_files="${_mr} ${_all_files}"
            done
            debug "Tail of logs: $(distd "${_all_files}")"
            eval "${TAIL_BIN} -F ${_all_files}" 2>&1
        else
            note "No logs to attach to. LOGS_DIR=($(distn "${LOGS_DIR}")) contain no log files?"
        fi

    elif [ "+" = "${_logf_pattern}" ]; then
        if [ -d "${LOGS_DIR}" ]; then
            _all_files=""
            for _mr in $(find_most_recent "${LOGS_DIR%/}" "${SOFIN_NAME}*" | ${HEAD_BIN} -n "${LOG_LAST_FILES}" 2>/dev/null); do
                _all_files="${_mr} ${_all_files}"
            done
            debug "Tail of logs: $(distd "${_all_files}")"
            eval "${TAIL_BIN} -n ${LOG_LINES_AMOUNT} -F ${_all_files}" 2>&1
        else
            note "No logs to attach to. LOGS_DIR=($(distn "${LOGS_DIR}")) contain no log files?"
        fi

    else
        debug "Seeking log files that match pattern: '$(distd "${_logf_pattern}")' (check intervals: $(distn "${LOG_CHECK_INTERVAL:-1}")s)" && \
            note "Waiting for logs"
        ${SLEEP_BIN} "${LOG_CHECK_INTERVAL:-1}" 2>/dev/null
        log_helper "${_logf_pattern}"
    fi
    unset _files_x_min _logf_minutes _logf_pattern _files_list _files_count _files_blist _mod_f_names
}


pretouch_logs () {
    _params="${@}"
    try "${TOUCH_BIN} ${LOGS_DIR}${SOFIN_NAME}"
    if [ -z "${CAP_SYS_PRODUCTION}" ]; then
        debug "Logs pretouch called with params: $(distd "${_params}")"
        _pret_list=""
        for _app in $(echo "${_params}" | ${TR_BIN} ' ' '\n' 2>/dev/null); do
            if [ -z "${_app}" ]; then
                debug "Empty app given out of params: $(distd "${_params}")?"
            else
                _lapp="$(lowercase "${_app}")"
                if [ -z "${_pret_list}" ]; then
                    _pret_list="${LOGS_DIR}${SOFIN_NAME}-${_lapp}"
                else
                    _pret_list="${LOGS_DIR}${SOFIN_NAME}-${_lapp} ${_pret_list}"
                fi
            fi
        done
        try "${TOUCH_BIN} ${_pret_list}" && \
            debug "Logs pre-touch-ed for: $(distd "${_pret_list}")!"
        unset _app _params _lapp _pret_list
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
