clean_purge () {
    if [ -d "${CACHE_DIR}" ]; then
        note "Purging all caches from: $(distinct n ${CACHE_DIR})"
        if [ ! -f "${LOG}" ]; then
            LOG="/dev/null"
        fi
        ${RM_BIN} -rf "${CACHE_DIR}" >> ${LOG} 2>> ${LOG}
    fi
}


clean_logs () {
    if [ -d "${LOGS_DIR}" ]; then
        note "Removing build logs from: $(distinct n ${LOGS_DIR})"
        if [ ! -f "${LOG}" ]; then
            LOG="/dev/null"
        fi
        ${RM_BIN} -rf "${LOGS_DIR}" >> ${LOG} 2>> ${LOG}
    fi
}


clean_binbuilds () {
    if [ -d "${BINBUILDS_CACHE_DIR}" ]; then
        note "Removing binary builds from: $(distinct n ${BINBUILDS_CACHE_DIR})"
        if [ ! -f "${LOG}" ]; then
            LOG="/dev/null"
        fi
        ${RM_BIN} -rf "${BINBUILDS_CACHE_DIR}" >> ${LOG} 2>> ${LOG}
    fi
}


clean_failbuilds () {
    if [ -n ${BUILD_DIR} -a \
         -d "${BUILD_DIR}" ]; then
        _cf_number="0"
        _cf_files=$(${FIND_BIN} "${BUILD_DIR}" -maxdepth 2 -mindepth 1 -type d 2>/dev/null)
        if [ -z "${_cf_files}" ]; then
            debug "No cache dirs. Skipped"
        else
            num="$(echo "${_cf_files}" | eval ${FILES_COUNT_GUARD})"
            if [ -n "${num}" ]; then
                _cf_number="${_cf_number} + ${num} - 1"
            fi
            for i in ${_cf_files}; do
                if [ ! -f "${LOG}" ]; then
                    LOG="/dev/null"
                fi
                debug "Removing cache directory: ${i}"
                ${RM_BIN} -rf "${i}" >> ${LOG} 2>> ${LOG}
            done
            _cf_result="$(echo "${_cf_number}" | ${BC_BIN} 2>/dev/null)"
            note "$(distinct n ${_cf_result}) directories cleaned."
        fi
    fi
    unset _cf_number _cf_files _cf_result
}


perform_clean () {
    fail_any_bg_jobs
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
}


finalize () {
    debug "finalize()"
    restore_security_state
    update_shell_vars
    reload_zsh_shells
    destroy_locks
}
