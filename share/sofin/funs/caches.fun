
log_helper () {
    _log_h_pattern="${1}"
    if [ -z "${_log_h_pattern}" ]; then
        _log_files="$(find_all "${LOGS_DIR}" "${SOFIN_NAME}*")"
    else
        _log_files="$(find_all "${LOGS_DIR}" "${SOFIN_NAME}*${_log_h_pattern}*")"
    fi
    _lognum_f="$(${PRINTF_BIN} '%s\n' "${_log_files}" | eval "${FILES_COUNT_GUARD}")"
    if [ -z "${_lognum_f}" ]; then
        _lognum_f="0"
    fi
    debug "Log helper, files found: $(distd "${_lognum_f}")"
    if [ -z "${_log_files}" ]; then
        log_helper "${_log_h_pattern}"
    else
        case ${_lognum_f} in
            0)
                log_helper "${_log_h_pattern}"
                ;;

            1)
                note "Found $(distn "${_lognum_f}") log file, that matches _log_h_pattern: $(distn "${_log_h_pattern}"). Attaching tail.."
                ${TAIL_BIN} -n "${LOG_LINES_AMOUNT}" -F $(${PRINTF_BIN} '%s\n' "${_log_files}" | eval "${NEWLINES_TO_SPACES_GUARD}")
                ;;

            *)
                note "Found $(distn "${_lognum_f}") log files, that match pattern: $(distn "${_log_h_pattern}"). Attaching to all available files.."
                ${TAIL_BIN} -F $(${PRINTF_BIN} '%s\n' "${_log_files}" | eval "${NEWLINES_TO_SPACES_GUARD}")
                ;;
        esac
    fi
    unset _log_h_pattern _log_files _lognum_f
}


less_logs () {
    # XXX: show only single log
    ${LESS_BIN} ${DEFAULT_LESS_OPTIONS} ${LOGS_DIR}/sofin*${1}* 2>/dev/null
}


show_logs () {
    clear
    _logf_pattern="${1:-+}"
    _logf_minutes="${LOG_LAST_ACCESS_OR_MOD_MINUTES}"
    debug "_logf_minutes: $(distd "${_logf_minutes}"), pattern: $(distd "${_logf_pattern}")"
    _files_x_min=$(${FIND_BIN} "${LOGS_DIR}" -maxdepth 1 -mindepth 1 -mmin -${_logf_minutes} -amin -${_logf_minutes} -iname "${SOFIN_NAME}*${_logf_pattern}*" -print 2>/dev/null)
    touch_logsdir_and_logfile
    if [ "-" = "${_logf_pattern}" ] || \
       [ "${SOFIN_NAME}" = "${_logf_pattern}" ]; then
        ${TAIL_BIN} -n "${LOG_LINES_AMOUNT}" "${LOG}" 2>&1

    elif [ "+" = "${_logf_pattern}" ]; then
        if [ -d "${LOGS_DIR}" ]; then
            if [ "${SYSTEM_NAME}" = "Linux" ]; then
                _files_list="$(find_all "${LOGS_DIR}" "${SOFIN_NAME}*")"
            else
                _files_list="$(find_most_recent "${LOGS_DIR}" "${SOFIN_NAME}*")"
            fi
            _files_abspaths="$(${PRINTF_BIN} '%s\n' "${_files_list}" | eval "${NEWLINES_TO_SPACES_GUARD}")"
            _files_count="$(${PRINTF_BIN} '%s\n' "${_files_list}" | eval "${FILES_COUNT_GUARD}")"
            _files_blist="" # build file list without full path to each one
            for _fl in ${_files_list}; do
                _base_fl="${_fl##*/}"
                if [ -z "${_base_fl}" ]; then
                    debug "Got an empty element basename: _base_fl=$(distd "${_base_fl}") of _fl=$(distd "${_fl}")"
                else
                    if [ -z "${_files_blist}" ]; then
                        _files_blist="${_base_fl}"
                    else
                        _files_blist="${_files_blist} ${_base_fl}"
                    fi
                fi
            done
            if [ "0" = "${_files_count}" ]; then
                note "Attaching tail only to internal log: [$(distn "${_files_blist}")]"
            else
                note "Attaching tail to $(distn "${_files_count}") most recently modified log files (exact order): [$(distn "${_files_blist}")]"
            fi
            # debug "_files_abspaths: $(distd "${_files_abspaths}")"
            ${TAIL_BIN} -n0 -F ${_files_abspaths} 2>/dev/null
        else
            note "No logs to attach to. LOGS_DIR=($(distn "${LOGS_DIR}")) contain no log files?"
        fi

    # elif [ -z "${_logf_pattern}" ]; then
    #     note "No pattern specified, setting tail on all logs accessed or modified in last $(distn "${_logf_minutes}") minutes.."
    #     if [ -z "${_files_x_min}" ]; then
    #         note "No log files updated or accessed in last $(distn "${_logf_minutes}") minutes to show. Specify '$(distn "+")' as param, to attach a tail to all logs."
    #     else
    #         debug "show_log files: $(distd "$(${PRINTF_BIN} '%s\n' "${_files_x_min}" | eval "${FILES_COUNT_GUARD}")")"
    #         ${TAIL_BIN} -n ${LOG_LINES_AMOUNT} $(${PRINTF_BIN} '%s\n' "${_files_x_min}" | eval "${NEWLINES_TO_SPACES_GUARD}")
    #     fi
    else
        note "Seeking log files that match pattern: '$(distn "${_logf_pattern}")' (check intervals: $(distn "${LOG_CHECK_INTERVAL:-3}")s)"
        ${SLEEP_BIN} "${LOG_CHECK_INTERVAL:-3}" 2>/dev/null
        log_helper "${_logf_pattern}"
    fi
    unset _files_x_min _logf_minutes _logf_pattern _files_list _files_count _files_blist _mod_f_names
}


pretouch_logs () {
    _params=${*}
    debug "Logs pretouch called with params: $(distd "${_params}")"
    try "${TOUCH_BIN} ${LOGS_DIR}${SOFIN_NAME}"
    _pret_list=""
    for _app in ${_params}; do
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
        debug "Logs pre-touch-ed!"
    unset _app _params _lapp _pret_list
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
    if [ -f "${_config_log}" ]; then
        debug "[C] Configure script options:\n$(distd "$(${CAT_BIN} "${_config_log}" 2>/dev/null)")"
    else
        # Store all options per definition from configure scripts
        ${MKDIR_BIN} -p "$(${DIRNAME_BIN} "${_config_log}")" 2>/dev/null && \
            ${DEF_CONFIGURE_METHOD} -h > "${_config_log}" 2>/dev/null && \
            debug "[N] Configure script options:\n$(distd "$(${CAT_BIN} "${_config_log}" 2>/dev/null)")"
    fi
}
