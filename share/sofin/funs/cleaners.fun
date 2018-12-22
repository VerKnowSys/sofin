clean_purge () {
    try "${RM_BIN} -rf '${CACHE_DIR}'" \
        && debug "Clean: Purged everything."
}


clean_logs () {
    try "${RM_BIN} -rf '${LOGS_DIR}'" \
        && debug "Clean: Logs wiped out."
}


clean_filecache () {
    try "${RM_BIN} -rf '${FILE_CACHE_DIR}'" \
        && debug "Clean: Files-cache wiped out."
}


clean_all_bdirs_leftovers () {
    if [ "YES" = "${CAP_SYS_ZFS}" ]; then
        for i in $(${ZFS_BIN} list -H -o name -t filesystem 2>/dev/null | ${EGREP_BIN} "${DEFAULT_SRC_EXT}" 2>/dev/null); do
            try "${ZFS_BIN} destroy -fR '${i}'" \
                && debug "Dataset destroyed: $(distd "${i}")"
        done
    else
        for i in $(${FIND_BIN} "${SOFTWARE_DIR}" -mindepth 2 -maxdepth 2 -name "${DEFAULT_SRC_EXT}*" -type d 2>/dev/null); do
            try "${RM_BIN} -f '${i}'" \
                && debug "Empty dir removed using <slow-file-IO>: $(distd "${i}")"
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


destroy_ramdisk_device () {
    if [ -n "${RAMDISK_DEV}" ]; then
        case "${SYSTEM_NAME}" in
            Darwin)
                if [ -n "${RAMDISK_DEV}" ]; then
                    try "diskutil unmountDisk ${RAMDISK_DEV}; diskutil eject ${RAMDISK_DEV} >/dev/null 2>&1" \
                        && debug "Tmp ramdisk unmounted: $(distd "${RAMDISK_DEV}")"
                fi
                ;;
        esac
        try "${UMOUNT_BIN} -f '${RAMDISK_DEV}' >/dev/null 2>&1" \
            && debug "Ramdisk device unmounted: $(distd "${RAMDISK_DEV}")"
        unset RAMDISK_DEV
    fi
}


# Standard finalizing task:
finalize_complete_standard_task () {
    finalize_with_shell_reload
}


# Task called on demand (manually).
# Currently used by:
#   `s reload`, `s env`, `s reset`…:
finalize_with_shell_reload () {
    update_shell_vars
    reload_shell
    finalize_and_quit_gracefully
}


# NOTE: C-c is handled differently:
# finalize_complete_standard_task() is called:
finalize_after_signal_interrupt () {
    set_system_dataset_writable
    set_software_dataset_writable
    untrap_signals
    finalize_and_quit_gracefully
}


# Task to call as last for all other finalize_* functions:
finalize_and_quit_gracefully () {
    load_sysctl_system_production_hardening
    destroy_ramdisk_device
    if [ "${TTY}" = "YES" ]; then
        # Bring back echo to the terminal:
        ${STTY_BIN} echo
    fi
    set_system_readonly
    set_software_dataset_readonly
}


finalize_afterbuild_tasks_for_bundle () {
    _bund_name="${1}"
    if [ -n "${_bund_name}" ]; then
        debug "finalize_afterbuild_tasks_for_bundle():: $(distd "${_bund_name}") with PREFIX=$(distd "${PREFIX}"), BUILD_NAMESUM: ${BUILD_NAMESUM}"
        require_prefix_set
        require_namesum_set
        destroy_builddir "${PREFIX##*/}" "${BUILD_NAMESUM}"
        destroy_dead_locks_of_bundle "${_bund_name}"
    else
        debug "finalize_afterbuild_tasks_for_bundle(): Empty Bundle. NO-OP!"
    fi
}


remove_useless_files_of_bundle () {
    _rufiles="${*}"
    if [ -n "${_rufiles}" ]; then
        echo "${_rufiles}" | ${XARGS_BIN} -n 1 -P "${CPUS}" -I {} "${SH_BIN}" -c "${RM_BIN} -rf {} >/dev/null 2>&1" >/dev/null 2>&1 \
            && debug "Useless files wiped out: $(distd "${_rufiles}")"
    else
        debug "No bundle name given! NO-OP."
    fi
}
