clean_purge () {
    if [ -d "${CACHE_DIR}" ]; then
        note "Purging all caches from: $(distinct n ${CACHE_DIR})"
        ${FIND_BIN} "${CACHE_DIR}" -delete 2>/dev/null
    fi
}


clean_logs () {
    if [ -d "${LOGS_DIR}" ]; then
        note "Removing build logs from: $(distinct n ${LOGS_DIR})"
        ${FIND_BIN} "${LOGS_DIR}" -delete 2>/dev/null
    fi
}


clean_binbuilds () {
    if [ -d "${BINBUILDS_CACHE_DIR}" ]; then
        note "Removing binary builds from: $(distinct n ${BINBUILDS_CACHE_DIR})"
        ${FIND_BIN} "${BINBUILDS_CACHE_DIR}" -delete 2>/dev/null
    fi
}


clean_failbuilds () {
    if [ -d "${CACHE_DIR}cache" ]; then
        number="0"
        files=$(${FIND_BIN} "${CACHE_DIR}cache" -maxdepth 2 -mindepth 1 -type d 2>/dev/null)
        num="$(echo "${files}" | eval ${FILES_COUNT_GUARD})"
        if [ ! -z "${num}" ]; then
            number="${number} + ${num} - 1"
        fi
        for i in ${files}; do
            debug "Removing directory: ${i}"
            ${FIND_BIN} "${i}" -delete 2>/dev/null
        done
        result="$(echo "${number}" | ${BC_BIN} 2>/dev/null)"
        note "$(distinct n ${result}) directories cleaned."
    fi
}


perform_clean () {
    fail_on_any_background_jobs
    case "$1" in
        purge) # purge
            clean_purge
            ;;

        dist) # distclean
            note "Dist cleaning.."
            clean_logs
            clean_binbuilds
            clean_failbuilds
            ;;

        *) # clean
            clean_failbuilds
            ;;
    esac
    create_cache_directories
}
