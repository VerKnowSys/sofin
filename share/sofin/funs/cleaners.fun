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
            permnote "Purge clean: $(distd "clean_purge()")"
            clean_purge
            ;;

        dist) # distclean
            permnote "Dist clean: $(distn "clean_logs(), clean_filecache(), clean_all_bdirs_leftovers()")"
            clean_logs
            clean_filecache
            clean_all_bdirs_leftovers
            ;;

        *) # clean
            permnote "Clean: $(distn "${clean_all_bdirs_leftovers}")"
            clean_all_bdirs_leftovers
            ;;
    esac
    create_sofin_dirs
}


destroy_ramdisk_device () {
    if [ -n "${RAMDISK_DEV}" ]; then
        cd /
        debug "${0}: destroy_ramdisk_device(): RAM_DISK_DEVICE: $(distd "${RAMDISK_DEV}")"
        case "${SYSTEM_NAME}" in
            Darwin)
                try "${DISKUTIL_BIN} unmountDisk ${RAMDISK_DEV}" \
                    && debug "${0}: RAMdisk device unmounted: $(distd "${RAMDISK_DEV}")"
                try "${DISKUTIL_BIN} eject ${RAMDISK_DEV}" \
                    && debug "${0}: RAMdisk device ejected: $(distd "${RAMDISK_DEV}")" \
                        && unset RAMDISK_DEV
                ;;

            *)
                try "${UMOUNT_BIN} -f ${RAMDISK_DEV}" \
                    && debug "${0}: RAMdisk device unmounted: $(distd "${RAMDISK_DEV}")" \
                        && unset RAMDISK_DEV
                ;;
        esac
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
    untrap_signals
    destroy_ramdisk_device
    set_system_dataset_writable
    set_software_dataset_writable
    finalize_and_quit_gracefully
}


# Task to call as last for all other finalize_* functions:
finalize_and_quit_gracefully () {
    _errorcode="${1:-${ERRORCODE_NORMAL_EXIT}}"
    load_sysctl_system_production_hardening
    set_system_dataset_readonly
    set_software_dataset_readonly
    if [ "YES" = "${CAP_TERM_INTERACTIVE}" ]; then
        ${STTY_BIN} echo \
            && debug "Interactive Terminal Echo is now: $(distd "*enabled*")"
    fi
    exit "${_errorcode}"
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
        printf "%b\n" "${_rufiles}" | ${XARGS_BIN} -n 1 -P "4" -I {} "${SHELL}" -c "${RM_BIN} -rf {}" >/dev/null 2>&1 \
            && debug "Useless files wiped out: $(distd "${_rufiles}")"
    else
        debug "No bundle name given! NO-OP."
    fi
}
