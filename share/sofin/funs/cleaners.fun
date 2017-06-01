clean_purge () {
    ${RM_BIN} -rf "${CACHE_DIR}"
}


clean_logs () {
    ${RM_BIN} -rf "${LOGS_DIR}"
}


clean_filecache () {
    ${RM_BIN} -rf "${FILE_CACHE_DIR}"
}


clean_all_bdirs_leftovers () {
    env_forgivable
    if [ "YES" = "${CAP_SYS_ZFS}" ]; then
        for i in $(${ZFS_BIN} list -H -o name -t filesystem 2>/dev/null | ${EGREP_BIN} "${DEFAULT_SRC_EXT}" 2>/dev/null); do
            try "${ZFS_BIN} destroy -vfR '${i}'" && \
                debug "Dataset destroyed: $(distd "${i}")"
        done
    else
        for i in $(${FIND_BIN} "${SOFTWARE_DIR}" -mindepth 2 -maxdepth 2 -name "${DEFAULT_SRC_EXT}*" -type d 2>/dev/null); do
            try "${RM_BIN} -vf '${i}'" && \
                debug "Empty dir removed using <slow-file-IO>: $(distd "${i}")"
        done
        debug "Done cleaning of build-dir leftovers."
    fi
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
            clean_all_bdirs_leftovers
            ;;

        *) # clean
            clean_all_bdirs_leftovers
            ;;
    esac
    create_dirs
}


finalize () {
    # restore_security_state
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
    # summary
    if [ "${TTY}" = "YES" ]; then
        # Bring back echo
        ${STTY_BIN} echo
    fi
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
        try_destroy_binbuild "${_bund_name}"
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
    _rufiles="${@}"
    env_forgivable
    if [ -n "${_rufiles}" ]; then
        try "${RM_BIN} -rf ${_rufiles}" && \
            debug "Useless files wiped out: $(distd "${_rufiles}")" && \
                return 0
    fi
    debug "Failure removing useless files: '$(distd "${_rufiles}")'"
    return 1
}
