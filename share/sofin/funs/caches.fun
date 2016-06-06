create_cache_directories () {
    # check for regular cache dirs for existence:
    if [ ! -d "${CACHE_DIR}" -o \
         ! -d "${BINBUILDS_CACHE_DIR}" -o \
         ! -d "${LOGS_DIR}" ]; then
         ${MKDIR_BIN} -p "${CACHE_DIR}" "${BINBUILDS_CACHE_DIR}" "${LOGS_DIR}"
    fi
    if [ ! -d "${DEFINITIONS_DIR}" -o \
         ! -f "${DEFAULTS}" ]; then
        note "No valid definitions cache found. Purging leftovers from: $(distinct n ${CACHE_DIR})"
        clean_purge
        update_definitions
    fi
}


log_helper () {
    files=$(${FIND_BIN} ${CACHE_DIR}logs -type f -iname "sofin*${pattern}*" 2>/dev/null)
    num="$(echo "${files}" | eval ${FILES_COUNT_GUARD})"
    if [ -z "${num}" ]; then
        num="0"
    fi
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
                ${TAIL_BIN} -n ${LOG_LINES_AMOUNT} -F ${files}
                ;;

            *)
                note "Found $(distinct n ${num}) log files, that match pattern: $(distinct n ${pattern}). Attaching to all available files.."
                ${TAIL_BIN} -F ${files}
                ;;
        esac
    fi
}


show_logs () {
    create_cache_directories
    shift
    pattern="$*"
    if [ "${pattern}" = "-" -o "${pattern}" = "sofin" ]; then
        ${TAIL_BIN} -n ${LOG_LINES_AMOUNT} -F ${LOG}
    elif [ "${pattern}" = "" ]; then
        ${TAIL_BIN} -n ${LOG_LINES_AMOUNT} -F ${LOG}*
    else
        note "Seeking log files.."
        log_helper
    fi
    exit
}
