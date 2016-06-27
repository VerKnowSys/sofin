create_cache_directories () {
    # special threatment for LOGS_DIR
    if [ ! -d "${LOGS_DIR}" ]; then
        debug "LOGS_DIR: $(distinct d "${LOGS_DIR}")"
        ${MKDIR_BIN} -p "${LOGS_DIR}" >/dev/null 2>&1
    fi

    # check for regular cache dirs for existence:
    if [ ! -d "${CACHE_DIR}" -o \
         ! -d "${BINBUILDS_CACHE_DIR}" -o \
         ! -d "${LOCKS_DIR}" ]; then
         for dir in "${CACHE_DIR}" "${BINBUILDS_CACHE_DIR}" "${LOCKS_DIR}"; do
            ${MKDIR_BIN} -p "${dir}" >/dev/null 2>&1
         done
    fi
    if [ ! -d "${DEFINITIONS_DIR}" -o \
         ! -f "${DEFAULTS}" ]; then
        debug "No valid definitions cache found in: $(distinct d "${DEFINITIONS_DIR}"). Creating one."
        clean_purge
        update_definitions
    fi
}


log_helper () {
    _pattern="$1"
    create_cache_directories
    if [ -z "${_pattern}" ]; then
        _files="$(find_all "${LOGS_DIR}" "sofin*")"
    else
        _files="$(find_all "${LOGS_DIR}" "sofin*${_pattern}*")"
    fi
    _num="$(echo "${_files}" | eval ${FILES_COUNT_GUARD})"
    if [ -z "${_num}" ]; then
        _num="0"
    fi
    debug "Log helper, files found: $(distinct d "${_num}")"
    if [ -z "${_files}" ]; then
        ${SLEEP_BIN} 2
        log_helper ${_pattern}
    else
        case ${_num} in
            0)
                ${SLEEP_BIN} 2
                log_helper ${_pattern}
                ;;

            1)
                note "Found $(distinct n ${_num}) log file, that matches _pattern: $(distinct n ${_pattern}). Attaching tail.."
                ${TAIL_BIN} -n ${LOG_LINES_AMOUNT} -F $(echo "${_files}" | eval ${NEWLINES_TO_SPACES_GUARD})
                ;;

            *)
                note "Found $(distinct n ${_num}) log files, that match pattern: $(distinct n ${pattern}). Attaching to all available files.."
                ${TAIL_BIN} -F $(echo "${_files}" | eval "${NEWLINES_TO_SPACES_GUARD}")
                ;;
        esac
    fi

}


show_logs () {
    create_cache_directories
    shift
    _pattern="$*"
    debug "show_logs() pattern: $(distinct d "${_pattern}")"
    _minutes="${LOG_LAST_ACCESS_OR_MOD_MINUTES}"
    _files=$(${FIND_BIN} "${LOGS_DIR}" -maxdepth 1 -mindepth 1 -mmin -${_minutes} -amin -${_minutes} -iname "sofin*${_pattern}*" -print 2>/dev/null)
    ${TOUCH_BIN} ${LOG} >/dev/null 2>&1
    if [ "-" = "${_pattern}" -o \
         "sofin" = "${_pattern}" ]; then
        ${TAIL_BIN} -n ${LOG_LINES_AMOUNT} "${LOG}" 2>&1

    elif [ "+" = "${_pattern}" ]; then
        if [ -d "${LOGS_DIR}" ]; then
            debug "LOGS_DIR: $(distinct d ${LOGS_DIR})"
            _files_list="$(find_most_recent "${LOGS_DIR}" "sofin*")"
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

    elif [ -z "${_pattern}" ]; then
        note "No pattern specified, setting tail on all logs accessed or modified in last ${_minutes} minutes.."
        if [ -z "${_files}" ]; then
            note "No log files updated or accessed in last ${_minutes} minutes to show. Specify '+' as param, to attach a tail to all logs."
        else
            debug "show_logs(), files: $(distinct d "$(echo "${_files}" | eval ${FILES_COUNT_GUARD})")"
            ${TAIL_BIN} -n ${LOG_LINES_AMOUNT} $(echo "${_files}" | eval ${NEWLINES_TO_SPACES_GUARD})
        fi
    else
        note "Seeking for log files.."
        log_helper ${_params}
    fi
    unset _files _minutes _pattern _files_list _files_count _files_blist _mod_f_names
}


pretouch_logs () {
    _params="$*"
    create_cache_directories
    debug "Logs pretouch called with params: $(distinct d ${_params})"
    ${TOUCH_BIN} ${LOGS_DIR}sofin >/dev/null 2>&1
    for _app in ${_params}; do
        if [ -z "${_app}" ]; then
            debug "Empty app given out of params: $(distinct d "${_params}")?"
        else
            _lapp="$(lowercase ${_app})"
            debug "pretouch_logs(): $(distinct d "${_lapp}")"
            ${TOUCH_BIN} "${LOGS_DIR}sofin-${_lapp}" >/dev/null 2>&1
        fi
    done
    unset _app _params _lapp
}
