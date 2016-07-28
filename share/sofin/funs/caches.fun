create_dirs () {
    # special threatment for LOGS_DIR
    if [ ! -d "${LOGS_DIR}" ]; then
        debug "LOGS_DIR: $(distinct d "${LOGS_DIR}")"
        try "${MKDIR_BIN} -p ${LOGS_DIR}"
    fi

    # check for regular cache dirs for existence:
    if [ ! -d "${CACHE_DIR}" -o \
         ! -d "${FILE_CACHE_DIR}" -o \
         ! -d "${LOCKS_DIR}" ]; then
         for dir in "${FILE_CACHE_DIR}" "${CACHE_DIR}" "${LOCKS_DIR}"; do
            try "${MKDIR_BIN} -p ${dir}"
         done
    fi
    if [ ! -d "${DEFINITIONS_DIR}" -o \
         ! -f "${DEFINITIONS_DEFAULTS}" ]; then
        debug "No valid definitions cache found in: $(distinct d "${DEFINITIONS_DIR}"). Creating one."
        clean_purge
        update_defs
    fi
}


log_helper () {
    _log_h_pattern="$1"
    create_dirs
    if [ -z "${_log_h_pattern}" ]; then
        _log_files="$(find_all "${LOGS_DIR}" "${DEFAULT_NAME}*")"
    else
        _log_files="$(find_all "${LOGS_DIR}" "${DEFAULT_NAME}*${_log_h_pattern}*")"
    fi
    _lognum_f="$(echo "${_log_files}" | eval ${FILES_COUNT_GUARD})"
    if [ -z "${_lognum_f}" ]; then
        _lognum_f="0"
    fi
    debug "Log helper, files found: $(distinct d "${_lognum_f}")"
    if [ -z "${_log_files}" ]; then
        ${SLEEP_BIN} 2
        log_helper ${_log_h_pattern}
    else
        case ${_lognum_f} in
            0)
                ${SLEEP_BIN} 2
                log_helper ${_log_h_pattern}
                ;;

            1)
                note "Found $(distinct n ${_lognum_f}) log file, that matches _log_h_pattern: $(distinct n ${_log_h_pattern}). Attaching tail.."
                ${TAIL_BIN} -n ${LOG_LINES_AMOUNT} -F $(echo "${_log_files}" | eval ${NEWLINES_TO_SPACES_GUARD})
                ;;

            *)
                note "Found $(distinct n ${_lognum_f}) log files, that match pattern: $(distinct n ${_log_h_pattern}). Attaching to all available files.."
                ${TAIL_BIN} -F $(echo "${_log_files}" | eval "${NEWLINES_TO_SPACES_GUARD}")
                ;;
        esac
    fi
    unset _log_h_pattern _log_files _lognum_f
}


show_logs () {
    create_dirs
    _logf_pattern="${*}"
    _logf_minutes="${LOG_LAST_ACCESS_OR_MOD_MINUTES}"
    debug "show_logs(): _logf_minutes: $(distinct d ${_logf_minutes}), pattern: $(distinct d "${_logf_pattern}")"
    _files_x_min=$(${FIND_BIN} "${LOGS_DIR}" -maxdepth 1 -mindepth 1 -mmin -${_logf_minutes} -amin -${_logf_minutes} -iname "${DEFAULT_NAME}*${_logf_pattern}*" -print 2>/dev/null)
    touch_logsdir_and_logfile
    if [ "-" = "${_logf_pattern}" -o \
         "${DEFAULT_NAME}" = "${_logf_pattern}" ]; then
        ${TAIL_BIN} -n ${LOG_LINES_AMOUNT} "${LOG}" 2>&1

    elif [ "+" = "${_logf_pattern}" ]; then
        if [ -d "${LOGS_DIR}" ]; then
            debug "LOGS_DIR: $(distinct d ${LOGS_DIR})"
            if [ "${SYSTEM_NAME}" = "Linux" ]; then
                _files_list="$(find_all "${LOGS_DIR}" "${DEFAULT_NAME}*")"
            else
                _files_list="$(find_most_recent "${LOGS_DIR}" "${DEFAULT_NAME}*")"
            fi
            debug "_files_list: ${_files_list}"
            _files_abspaths="$(${PRINTF_BIN} "${_files_list}" | eval "${NEWLINES_TO_SPACES_GUARD}")"
            _files_count="$(${PRINTF_BIN} "${_files_list}" | eval "${FILES_COUNT_GUARD}")"
            _files_blist="" # build file list without full path to each one
            for _fl in ${_files_list}; do
                _base_fl="$(${BASENAME_BIN} "${_fl}" 2>/dev/null)"
                if [ -z "${_base_fl}" ]; then
                    debug "Got an empty element basename: _base_fl=$(distinct d "${_base_fl}") of _fl=$(distinct d "${_fl}")"
                else
                    if [ -z "${_files_blist}" ]; then
                        _files_blist="${_base_fl}"
                    else
                        _files_blist="${_files_blist} ${_base_fl}"
                    fi
                fi
            done
            if [ "0" = "${_files_count}" ]; then
                note "Attaching tail only to internal log: [$(distinct n "${_files_blist}")]"
            else
                note "Attaching tail to $(distinct n "${_files_count}") most recently modified log files (exact order): [$(distinct n "${_files_blist}")]"
            fi
            debug "_files_abspaths: $(distinct d ${_files_abspaths})"
            ${TAIL_BIN} -n0 -F ${_files_abspaths} 2>/dev/null
        else
            note "No logs to attach to. LOGS_DIR=($(distinct n "${LOGS_DIR}")) contain no log files?"
        fi

    elif [ -z "${_logf_pattern}" ]; then
        note "No pattern specified, setting tail on all logs accessed or modified in last ${_logf_minutes} minutes.."
        if [ -z "${_files_x_min}" ]; then
            note "No log files updated or accessed in last ${_logf_minutes} minutes to show. Specify '+' as param, to attach a tail to all logs."
        else
            debug "show_logs(), files: $(distinct d "$(echo "${_files_x_min}" | eval ${FILES_COUNT_GUARD})")"
            ${TAIL_BIN} -n ${LOG_LINES_AMOUNT} $(echo "${_files_x_min}" | eval ${NEWLINES_TO_SPACES_GUARD})
        fi
    else
        note "Seeking for log files.."
        log_helper "${_logf_pattern}"
    fi
    unset _files_x_min _logf_minutes _logf_pattern _files_list _files_count _files_blist _mod_f_names
}


pretouch_logs () {
    _params="${*}"
    create_dirs
    debug "Logs pretouch called with params: $(distinct d ${_params})"
    try "${TOUCH_BIN} ${LOGS_DIR}${DEFAULT_NAME}"
    _pret_list=""
    for _app in ${_params}; do
        if [ -z "${_app}" ]; then
            debug "Empty app given out of params: $(distinct d "${_params}")?"
        else
            _lapp="$(lowercase ${_app})"
            if [ -z "${_pret_list}" ]; then
                _pret_list="${LOGS_DIR}${DEFAULT_NAME}-${_lapp}"
            else
                _pret_list="${LOGS_DIR}${DEFAULT_NAME}-${_lapp} ${_pret_list}"
            fi
        fi
    done
    debug "pretouch_logs(): $(distinct d "${_pret_list}")"
    try "${TOUCH_BIN} ${_pret_list}"
    unset _app _params _lapp _pret_list
}


show_log_if_available () {
    if [ -f "${LOG}" ]; then
        note $(fill)
        ${TAIL_BIN} -n${LOG_LINES_AMOUNT_ON_ERR} "${LOG}" 2>/dev/null
    else
        debug "No log available to attach tail to.."
    fi
}


touch_logsdir_and_logfile () {
    ${MKDIR_BIN} -p "${LOGS_DIR}" >/dev/null 2>&1
    ${TOUCH_BIN} "${LOG}" >/dev/null 2>&1
}
