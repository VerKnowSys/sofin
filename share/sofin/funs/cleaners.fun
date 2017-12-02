clean_purge () {
    try "${RM_BIN} -rf \"${CACHE_DIR}\""
}


clean_logs () {
    try "${RM_BIN} -rf \"${LOGS_DIR}\""
}


clean_filecache () {
    try "${RM_BIN} -rf \"${FILE_CACHE_DIR}\""
}


clean_all_bdirs_leftovers () {
    if [ "YES" = "${CAP_SYS_ZFS}" ]; then
        for i in $(${ZFS_BIN} list -H -o name -t filesystem 2>/dev/null | ${EGREP_BIN} "${DEFAULT_SRC_EXT}" 2>/dev/null); do
            try "${ZFS_BIN} destroy -fR '${i}'" && \
                debug "Dataset destroyed: $(distd "${i}")"
        done
    else
        for i in $(${FIND_BIN} "${SOFTWARE_DIR}" -mindepth 2 -maxdepth 2 -name "${DEFAULT_SRC_EXT}*" -type d 2>/dev/null); do
            try "${RM_BIN} -f '${i}'" && \
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
    destroy_dead_locks
    finalize_shell_reload
}


finalize_shell_reload () {
    update_shell_vars
    reload_shell
    finalize_onquit
}


finalize_onquit () {
    # security_set_normal
    destroy_ramdisk_device
    if [ "${TTY}" = "YES" ]; then
        # Bring back echo
        ${STTY_BIN} echo
    fi
}


destroy_ramdisk_device () {
    if [ -n "${RAMDISK_DEV}" ]; then
        case "${SYSTEM_NAME}" in
            Darwin)
                if [ -n "${RAMDISK_DEV}" ]; then
                    try "diskutil unmountDisk ${RAMDISK_DEV}; diskutil eject ${RAMDISK_DEV};" && \
                        debug "Tmp ramdisk unmounted: $(distd "${RAMDISK_DEV}")"
                fi
                ;;
        esac
        try "${UMOUNT_BIN} -f ${RAMDISK_DEV}" && \
            debug "Tmp ramdisk force-unmounted: $(distd "${RAMDISK_DEV}")"
        unset RAMDISK_DEV
    fi
}


# NOTE: C-c is handled differently, not full finalize is running. f.e. build dir isn't wiped out
finalize_interrupt () {
    untrap_signals
    destroy_ramdisk_device
    destroy_dead_locks
    finalize_onquit
}


finalize_afterbuild () {
    _bund_name="${1}"
    require_prefix_set
    require_namesum_set
    debug "finalize_afterbuild for bundle: $(distd "${_bund_name}"), PREFIX: ${PREFIX}, BUILD_NAMESUM: ${BUILD_NAMESUM}"

    # Cleanup build dir if DEVEL unset:
    if [ -z "${DEVEL}" ]; then
        destroy_ramdisk_device
        destroy_builddir "${PREFIX##*/}" "${BUILD_NAMESUM}"
    else
        # TODO: dump srcdir? here?
        debug "No-Op - not yet implemented"
    fi
    # Destroy lock of just built bundle:
    if [ -n "${_bund_name}" ]; then
        destroy_dead_locks "${_bund_name}"
    fi
}


remove_useless () {
    _rufiles="${*}"
    if [ -n "${_rufiles}" ]; then
        echo "${_rufiles}" | ${XARGS_BIN} -n 1 -P "${CPUS}" -I {} "${ZSH_BIN}" -c "${RM_BIN} -rf {} >/dev/null 2>&1" >> "${LOG}" 2>> "${LOG}" \
            && debug "Useless files wiped out: $(distd "${_rufiles}")" \
                && return 0
    fi
    debug "Failure removing useless files: '$(distd "${_rufiles}")'"
    return 1
}
