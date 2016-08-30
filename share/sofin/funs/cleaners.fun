clean_purge () {
    if [ -d "${CACHE_DIR}" ]; then
        debug "Purging all caches from: $(distn "${CACHE_DIR}")"
        try "${RM_BIN} -rf ${CACHE_DIR}"
    fi
}


clean_logs () {
    if [ -d "${LOGS_DIR}" ]; then
        debug "Removing build logs from: $(distn "${LOGS_DIR}")"
        try "${RM_BIN} -rf ${LOGS_DIR}"
    fi
}


clean_filecache () {
    if [ -d "${FILE_CACHE_DIR}" ]; then
        debug "Removing file-caches from: $(distn "${FILE_CACHE_DIR}")"
        try "${RM_BIN} -rf ${FILE_CACHE_DIR}"
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
            num="$(${PRINTF_BIN} '%s\n' "${_cf_files}" | eval "${FILES_COUNT_GUARD}")"
            if [ -n "${num}" ]; then
                _cf_number="${_cf_number} + ${num} - 1"
            fi
            for i in ${_cf_files}; do
                debug "Removing cache directory: ${i}"
                try "${RM_BIN} -rf ${i}"
            done
            _cf_result="$(${PRINTF_BIN} '%s\n' "${_cf_number}" | ${BC_BIN} 2>/dev/null)"
            note "$(distn "${_cf_result}") directories cleaned."
        fi
    fi
    unset _cf_number _cf_files _cf_result
}


perform_clean () {
    fail_any_bg_jobs
    case "${1}" in
        purge) # purge
            clean_purge
            ;;

        dist) # distclean
            note "Dist cleaning.."
            clean_logs
            clean_filecache
            clean_failbuilds
            ;;

        *) # clean
            clean_failbuilds
            ;;
    esac
}


finalize () {
    restore_security_state
    finalize_afterbuild
    destroy_locks
    finalize_shell_reload
}


finalize_shell_reload () {
    update_shell_vars
    reload_zsh_shells
    finalize_onquit
}


finalize_onquit () {
    untrap_signals
    summary
    # Bring back echo
    ${STTY_BIN} echo
}


# NOTE: C-c is handled differently, not full finalize is running. f.e. build dir isn't wiped out
finalize_interrupt () {
    destroy_locks
    finalize_onquit
}


finalize_afterbuild () {
    _bund_name="${1}"
    # Cleanup build dir if DEVEL unset:
    if [ -z "${DEVEL}" ]; then
        try_destroy_binbuild
    else
        # TODO: dump srcdir? here?
        debug "No-Op - not yet implemented"
    fi
    # Destroy lock of just built bundle:
    if [ -n "${_bund_name}" ]; then
        destroy_locks "${_bund_name}"
    fi
}


remove_useless () {
    _rufiles=${@}
    if [ -n "${_rufiles}" ]; then
        try "${RM_BIN} -rf ${_rufiles}" && \
            return 0
        debug "Failed to remove useless files: '$(distd "${_rufiles}")'"
    fi
    return 1
}
