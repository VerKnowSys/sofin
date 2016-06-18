create_cache_directories () {
    # check for regular cache dirs for existence:
    if [ ! -d "${CACHE_DIR}" -o \
         ! -d "${BINBUILDS_CACHE_DIR}" -o \
         ! -d "${LOCKS_DIR}" -o \
         ! -d "${LOGS_DIR}" ]; then
         ${MKDIR_BIN} -p "${CACHE_DIR}" "${BINBUILDS_CACHE_DIR}" "${LOGS_DIR}" "${LOCKS_DIR}"
    fi
    if [ ! -d "${DEFINITIONS_DIR}" -o \
         ! -f "${DEFAULTS}" ]; then
        note "No valid definitions cache found. Creating one."
        clean_purge
        update_definitions
    fi
}


log_helper () {
    if [ -z "${pattern}" ]; then
        files=$(${FIND_BIN} ${CACHE_DIR}logs/ -maxdepth 1 -mindepth 1 -type f -iname "sofin*" -print 2>/dev/null)
    else
        files=$(${FIND_BIN} ${CACHE_DIR}logs/ -maxdepth 1 -mindepth 1 -type f -iname "sofin*${pattern}*" -print 2>/dev/null)
    fi
    num="$(echo "${files}" | eval ${FILES_COUNT_GUARD})"
    if [ -z "${num}" ]; then
        num="0"
    fi
    debug "Log helper, files found: $(distinct d "${num}")"
    if [ -z "${files}" ]; then
        ${SLEEP_BIN} 2
        log_helper
    else
        case ${num} in
            0)
                ${SLEEP_BIN} 2
                log_helper
                ;;

            1)
                note "Found $(distinct n ${num}) log file, that matches pattern: $(distinct n ${pattern}). Attaching tail.."
                ${TAIL_BIN} -n ${LOG_LINES_AMOUNT} -F $(echo "${files}" | ${TR_BIN} '\n' ' ' 2>/dev/null)
                ;;

            *)
                note "Found $(distinct n ${num}) log files, that match pattern: $(distinct n ${pattern}). Attaching to all available files.."
                ${TAIL_BIN} -F $(echo "${files}" | ${TR_BIN} '\n' ' ' 2>/dev/null)
                ;;
        esac
    fi
}


show_logs () {
    create_cache_directories
    shift
    pattern="$*"
    minutes="${LOG_LAST_ACCESS_OR_MOD_MINUTES}"
    files=$(${FIND_BIN} ${CACHE_DIR}logs/ -maxdepth 1 -mindepth 1 -mmin -${minutes} -amin -${minutes} -iname "sofin*${pattern}*" -print 2>/dev/null)
    ${TOUCH_BIN} ${LOG} >> ${LOG} 2>> ${LOG} # Make sure that main log always exists
    if [ "-" = "${pattern}" -o \
         "sofin" = "${pattern}" ]; then
        ${TAIL_BIN} -n ${LOG_LINES_AMOUNT} ${LOG}

    elif [ "+" = "${pattern}" ]; then
        note "Setting tail on all logs available.."
        ${TAIL_BIN} -F ${LOG}*

    elif [ -z "${pattern}" ]; then
        note "No pattern specified, setting tail on all logs accessed or modified in last ${minutes} minutes.."
        if [ -z "${files}" ]; then
            note "No log files updated or accessed in last ${minutes} minutes to show. Specify '+' as param, to attach a tail to all logs."
        else
            debug "show_logs(), files: $(distinct d "$(echo "${files}" | eval ${FILES_COUNT_GUARD})")"
            ${TAIL_BIN} -n ${LOG_LINES_AMOUNT} $(echo "${files}" | ${TR_BIN} '\n' ' ' 2>/dev/null)
        fi

    else
        note "Seeking log files.."
        log_helper
    fi
}


pretouch_logs () {
    debug "Logs pretouch for: $*"
    ${MKDIR_BIN} -p ${CACHE_DIR}logs >> ${LOG} 2>> ${LOG}
    ${TOUCH_BIN} ${CACHE_DIR}logs/sofin >> ${LOG} 2>> ${LOG}
    for app in $*; do
        if [ -z "${app}" ]; then
            debug "Empty app?"
        else
            lapp="$(lowercase $app)"
            ${TOUCH_BIN} ${CACHE_DIR}logs/sofin-${lapp} >> ${LOG} 2>> ${LOG}
            unset lapp
        fi
    done
    unset app
}
