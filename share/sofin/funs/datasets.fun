
push_dset_zfs_stream () {
    _fin_snapfile="${1}"
    _pselement="${2}"
    _psmirror="${3}"
    if [ -z "${_fin_snapfile}" ]; then
        error "First argument with a $(distinct e "some-snapshot-file.txz") is required!"
    fi
    if [ "YES" = "${CAP_SYS_ZFS}" ]; then
        if [ -z "${_pselement}" ]; then
            error "Second argument with a $(distinct e "BundleName") is required!"
        fi
        if [ -z "${_psmirror}" ]; then
            error "Third argument with a $(distinct e "mirror-IP") is required!"
        fi
        if [ -f "${FILE_CACHE_DIR}${_fin_snapfile}" ]; then
            ${PRINTF_BIN} "${blue}"
            ${SSH_BIN} ${DEFAULT_SSH_OPTS} -p ${MAIN_PORT} "${MAIN_USER}@${_psmirror}" \
                "${MKDIR_BIN} -p ${COMMON_BINARY_REMOTE} ; ${CHMOD_BIN} 755 ${COMMON_BINARY_REMOTE}"

            debug "Setting common access to archive files before we send it: $(distinct d ${_fin_snapfile})"
            try "${CHMOD_BIN} -v a+r ${FILE_CACHE_DIR}${_fin_snapfile}"
            debug "Sending initial service stream to $(distinct d ${MAIN_COMMON_NAME}) repository: $(distinct d ${MAIN_COMMON_REPOSITORY}/${_fin_snapfile})"

            retry "${SCP_BIN} ${DEFAULT_SSH_OPTS} ${DEFAULT_SCP_OPTS} -P ${MAIN_PORT} ${FILE_CACHE_DIR}${_fin_snapfile} ${MAIN_USER}@${_psmirror}:${COMMON_BINARY_REMOTE}/${_fin_snapfile}.partial"
            if [ "$?" = "0" ]; then
                ${PRINTF_BIN} "${blue}"
                ${SSH_BIN} ${DEFAULT_SSH_OPTS} -p ${MAIN_PORT} "${MAIN_USER}@${_psmirror}" \
                    "cd ${COMMON_BINARY_REMOTE} && ${MV_BIN} ${_fin_snapfile}.partial ${_fin_snapfile}"
                debug "Successfully renamed partial file to: $(distinct d "${_fin_snapfile}")"
            else
                error "Failed to send snapshot of $(distinct e "${_pselement}") archive file: $(distinct e "${_fin_snapfile}") to remote host: $(distinct e "${MAIN_USER}@${_psmirror}")!"
            fi
        else
            note "No service stream file available for: $(distinct n ${_pselement})"
        fi
    else
        debug "No ZFS support"
    fi
    unset _psmirror _pselement _fin_snapfile
}


prepare_service_dataset () {
    _pd_elem="${1}"
    if [ "YES" = "${CAP_SYS_ZFS}" ]; then
        if [ -z "${_pd_elem}" ]; then
            error "First argument with a $(distinct e "BundleName") is required!"
        fi
        if [ -z "${USER}" ]; then
            error "Second argument with env value for: $(distinct e "USER") is required!"
        fi
        _full_dataset_name="${DEFAULT_ZPOOL}${SERVICES_DIR}${USER}/${_pd_elem}"
        _snap_file="${_pd_elem}-${_version_element}${SERVICE_SNAPSHOT_EXT}"
        _final_snap_file="${_snap_file}${DEFAULT_ARCHIVE_EXT}"

        debug "_pd_elem: ${_pd_elem}"
        fetch_dset_zfs_stream "${_pd_elem}" "${_final_snap_file}"

        ${ZFS_BIN} list -H 2>/dev/null | ${CUT_BIN} -f1 2>/dev/null | ${EGREP_BIN} "${_pd_elem}" >/dev/null 2>&1
        if [ "$?" = "0" ]; then
            note "Preparing to send service dataset: $(distinct n "${_full_dataset_name}"), for bundle: $(distinct n "${_pd_elem}")"
            try "${ZFS_BIN} umount -f ${_full_dataset_name}"
            run "${ZFS_BIN} send ${_full_dataset_name} | ${XZ_BIN} > ${FILE_CACHE_DIR}${_final_snap_file}"
            try "${ZFS_BIN} mount ${_full_dataset_name}"
        else
            run "${ZFS_BIN} create -p -o mountpoint=${SERVICES_DIR}${_pd_elem} ${_full_dataset_name}"
            run "${ZFS_BIN} send ${_full_dataset_name} | ${XZ_BIN} > ${FILE_CACHE_DIR}${_final_snap_file}"
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


fetch_dset_zfs_stream () {
    _bund_name="${1}"
    _final_snap_file="${2}"
    if [ -z "${_bund_name}" -o \
         -z "${_final_snap_file}" ]; then
        error "Expected two arguments: $(distinct e dataset_name) and $(distinct e final_snapshot_file)."
    fi
    _commons_path="${MAIN_COMMON_REPOSITORY}/${_final_snap_file}"
    retry "${FETCH_BIN} ${FETCH_OPTS} -o ${FILE_CACHE_DIR}${_final_snap_file} ${_commons_path}"
    if [ "$?" = "0" ]; then
        _dataset_name="${DEFAULT_ZPOOL}${SERVICES_DIR}${USER}/${_bund_name}"
        try "${XZCAT_BIN} ${FILE_CACHE_DIR}${_final_snap_file} | ${ZFS_BIN} receive -v ${_dataset_name}" && \
        unset _dataset_name
            debug "Creating service dataset: $(distinct d "${_dataset_name}"), from file stream: $(distinct d "${_final_snap_file}")."
                note "Received service dataset for: $(distinct n "${_dataset_name}")"
            debug "Initial service dataset unavailable for: $(distinct d "${_bund_name}")"
    else
        debug "ZFS feature disabled"
    fi
    unset _bund_name _final_snap_file _commons_path
}


create_service_dir () {
    _dset_create="${1}"
    if [ -z "${_dset_create}" ]; then
        error "First argument with $(distinct e "BundleName") is required!"
    fi
    if [ "YES" = "${CAP_SYS_ZFS}" ]; then
        _dsname="${DEFAULT_ZPOOL}${SERVICES_DIR}${USER}/${_dset_create}"
        debug "Creating ZFS service-dataset: $(distinct d "${_dsname}")"
        try "${ZFS_BIN} list ${_dsname}" || \
            try "${ZFS_BIN} create -p -o mountpoint=${SERVICES_DIR}${_dset_create} ${_dsname}"
        try "${ZFS_BIN} mount ${_dsname}"
        unset _dsname
    else
        debug "Creating regular service-directory: $(distinct d "${SERVICES_DIR}${_dset_create}")"
        try "${MKDIR_BIN} -p ${SERVICES_DIR}${_dset_create}"
    fi
    try "${CHMOD_BIN} 0710 ${SERVICES_DIR}${_dset_create}"
    unset _dset_create
}


destroy_service_dir () {
    _dset_destroy="${1}"
    if [ -z "${_dset_destroy}" ]; then
        error "First argument with $(distinct e "BundleName") to destroy is required!"
    fi
    if [ "YES" = "${CAP_SYS_ZFS}" ]; then
        _dsname="${DEFAULT_ZPOOL}${SERVICES_DIR}${USER}/${_dset_destroy}"
        debug "Destroying dataset: $(distinct d "${_dsname}")"
        try "${ZFS_BIN} umount -f ${_dsname}"
        try "${ZFS_BIN} destroy -r ${_dsname}"
        unset _dsname
    else
        debug "Removing regular software-directory: $(distinct d "${SERVICES_DIR}${_dset_destroy}")"
        try "${RM_BIN} -rf ${SERVICES_DIR}${_dset_destroy}"
    fi
    unset _dset_destroy
}


create_base_datasets () {
    if [ "YES" = "${CAP_SYS_ZFS}" ]; then
        debug "Creating base software-dataset: $(distinct d "${DEFAULT_ZPOOL}${SOFTWARE_DIR}")"
        _dsname="${DEFAULT_ZPOOL}${SOFTWARE_DIR}${USER}"
        try "${ZFS_BIN} list ${_dsname}" || \
            try "${ZFS_BIN} create -p -o mountpoint=${SOFTWARE_DIR} ${_dsname}"
        try "${ZFS_BIN} mount ${_dsname}"
        unset _dsname

        debug "Creating base services-dataset: $(distinct d "${DEFAULT_ZPOOL}${SERVICES_DIR}")"
        _dsname="${DEFAULT_ZPOOL}${SERVICES_DIR}${USER}"
        try "${ZFS_BIN} list ${_dsname}" || \
            try "${ZFS_BIN} create -p -o mountpoint=${SERVICES_DIR} ${_dsname}"
        try "${ZFS_BIN} mount ${_dsname}"
        unset _dsname
    fi
}


create_software_dir () {
    _dset_create="${1}"
    if [ -z "${_dset_create}" ]; then
        error "First argument with $(distinct e "BundleName") is required!"
    fi
    if [ "YES" = "${CAP_SYS_ZFS}" ]; then
        _dsname="${DEFAULT_ZPOOL}${SOFTWARE_DIR}${USER}/${_dset_create}"
        debug "Creating ZFS software-dataset: $(distinct d "${_dsname}")"
        try "${ZFS_BIN} list ${_dsname}" || \
            try "${ZFS_BIN} create -p -o mountpoint=${SOFTWARE_DIR}${_dset_create} ${_dsname}"
        try "${ZFS_BIN} mount ${_dsname}"
        unset _dsname
    else
        debug "Creating regular software-directory: $(distinct d "${SOFTWARE_DIR}${_dset_create}")"
        try "${MKDIR_BIN} -p ${SOFTWARE_DIR}${_dset_create}"
    fi
    try "${CHMOD_BIN} 0710 ${SOFTWARE_DIR}${_dset_create}"
    unset _dset_create
}


destroy_software_dir () {
    _dset_destroy="${1}"
    if [ -z "${_dset_destroy}" ]; then
        error "First argument with $(distinct e "BundleName") to destroy is required!"
    fi
    if [ "YES" = "${CAP_SYS_ZFS}" ]; then
        _dsname="${DEFAULT_ZPOOL}${SOFTWARE_DIR}${USER}/${_dset_destroy}"
        debug "Destroying software-dataset: $(distinct d "${_dsname}")"
        try "${ZFS_BIN} umount -f ${_dsname}"
        try "${ZFS_BIN} destroy -r ${_dsname}"
        unset _dsname
    else
        debug "Removing regular software-directory: $(distinct d "${SOFTWARE_DIR}${_dset_destroy}")"
        try "${RM_BIN} -rf ${SOFTWARE_DIR}${_dset_destroy}"
    fi
    unset _dset_destroy
}


create_builddir () {
    _cb_bundle_name="${1}"
    _dset_namesum="${2}"
    if [ -z "${_cb_bundle_name}" ]; then
        error "First argument with $(distinct e "BundleName") is required!"
    fi
    if [ "YES" = "${CAP_SYS_ZFS}" ]; then
        if [ -z "${_dset_namesum}" ]; then
            error "Second argument with $(distinct e "dataset-checksum") is required!"
        fi
        _dset="${DEFAULT_ZPOOL}${SOFTWARE_DIR}${USER}/${_cb_bundle_name}/${DEFAULT_SRC_EXT}${_dset_namesum}"
        debug "Creating ZFS build-dataset with checksum: $(distinct d "${_dset_namesum}") of $(distinct d "${_dset}")"
        try "${ZFS_BIN} create -p -o mountpoint=${SOFTWARE_DIR}${_cb_bundle_name}/${DEFAULT_SRC_EXT}${_dset_namesum} ${_dset}"
        try "${ZFS_BIN} mount ${_dset}"
        unset _dset _dset_namesum
    else
        debug "Creating regular build-directory: $(distinct d "${SOFTWARE_DIR}${_cb_bundle_name}")"
        try "${MKDIR_BIN} -p ${SOFTWARE_DIR}${_cb_bundle_name}"
    fi
    unset _cb_bundle_name _dset_namesum
}


destroy_builddir () {
    _deste_bund_name="${1}"
    _dset_sum="${2}"
    if [ -z "${_deste_bund_name}" ]; then
        error "First argument with $(distinct e "build-bundle-directory") is required!"
    fi
    if [ "YES" = "${CAP_SYS_ZFS}" ]; then
        if [ -z "${_dset_sum}" ]; then
            error "Second argument with $(distinct e "bundle-sha-sum") is required!"
        fi
        _dsname="${DEFAULT_ZPOOL}${SOFTWARE_DIR}${USER}/${_deste_bund_name}/${DEFAULT_SRC_EXT}${_dset_sum}"
        if [ -z "${DEVEL}" ]; then
            debug "Destroying ZFS build-dataset: $(distinct d "${_dsname}")"
            try "${ZFS_BIN} umount -f ${_dsname}"
            try "${ZFS_BIN} destroy -r ${_dsname}"
        else
            debug "DEVEL mode enabled, skipped dataset destroy: $(distinct d "${_dsname}")"
        fi
        unset _dsname
    else
        debug "Removing regular build-directory: $(distinct d "${SOFTWARE_DIR}${_deste_bund_name}")"
        try "${RM_BIN} -fr ${SOFTWARE_DIR}${_deste_bund_name}"
    fi
    unset _deste_bund_name
}


recreate_builddir () {
    destroy_builddir "${1}" "${2}"
    create_builddir "${1}" "${2}"
}
