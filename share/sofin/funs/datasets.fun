
prepare_service_dataset () {
    _pd_elem="${1}"
    if [ "YES" = "${CAP_SYS_ZFS}" ]; then
        if [ -z "${_pd_elem}" ]; then
            error "prepare_service_dataset() requires an argument with a $(distinct e "BundleName")!"
        fi
        if [ -z "${USER}" ]; then
            error "prepare_service_dataset() requires an env value for: $(distinct e "USER")!"
        fi
        _full_dataset_name="${DEFAULT_ZPOOL}${SERVICES_DIR}${USER}/${_pd_elem}"
        _snap_file="${_pd_elem}-${_version_element}${SERVICE_SNAPSHOT_EXT}"
        _final_snap_file="${_snap_file}${DEFAULT_ARCHIVE_EXT}"
        note "Preparing service dataset: $(distinct n "${_full_dataset_name}"), for bundle: $(distinct n "${_pd_elem}")"
        debug "_pd_elem: ${_pd_elem}"
        ${ZFS_BIN} list -H 2>/dev/null | ${CUT_BIN} -f1 2>/dev/null | ${EGREP_BIN} "${_pd_elem}" >/dev/null 2>&1
        if [ "$?" = "0" ]; then
            try "${ZFS_BIN} umount -f ${_full_dataset_name}"
            run "${ZFS_BIN} send -v -e -L ${_full_dataset_name} | ${XZ_BIN} > ${FILE_CACHE_DIR}${_final_snap_file}"
            try "${ZFS_BIN} mount ${_full_dataset_name}"
        else
            run "${ZFS_BIN} create -o mountpoint=${SERVICES_DIR}${_pd_elem} ${_full_dataset_name}"
            run "${ZFS_BIN} send -v -e -L ${_full_dataset_name} | ${XZ_BIN} > ${FILE_CACHE_DIR}${_final_snap_file}"
            try "${ZFS_BIN} mount ${_full_dataset_name}"
        fi
        _snap_size="$(file_size "${FILE_CACHE_DIR}${_final_snap_file}")"
        if [ "${_snap_size}" = "0" ]; then
            try "${RM_BIN} -vf ${FILE_CACHE_DIR}${_final_snap_file}"
            debug "Service dataset dump is empty for bundle: $(distinct d "${_pd_elem}-${_version_element}")"
        else
            debug "Snapshot of size: $(distinct d "${_snap_size}") is ready for bundle: $(distinct d "${_pd_elem}")"
        fi
        unset _snap_size _version_element _full_dataset_name _final_snap_file _pd_elem
    fi
}
