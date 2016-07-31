
push_to_all_mirrors () {
    _pbto_bundle_name="${1}"
    _pversion_element="${2}"
    _ptelm_file_name="${_pbto_bundle_name}-${_pversion_element}-${OS_TRIPPLE}${DEFAULT_ARCHIVE_EXT}"
    _ptelm_service_name="${_pbto_bundle_name}-${_pversion_element}${DEFAULT_SERVICE_SNAPSHOT_EXT}"
    _pt_query="$(${HOST_BIN} A "${MAIN_SOFTWARE_ADDRESS}" 2>/dev/null | ${GREP_BIN} 'Address:' 2>/dev/null | eval "${HOST_ADDRESS_GUARD}")"
    debug "Address: $(distinct d "${_pt_query}"), bundle: $(distinct d "${_pbto_bundle_name}"), name: $(distinct d "${_ptelm_file_name}")"
    if [ -z "${_pbto_bundle_name}" ]; then
        error "First argument with a $(distinct e "BundleName") is required!"
    fi
    if [ -z "${_pversion_element}" ]; then
        error "Second argument with a $(distinct e "version-string") is required!"
    fi
    if [ -z "${_pt_query}" ]; then
        error "Unable to determine IP address of: $(distinct e "${MAIN_SOFTWARE_ADDRESS}")"
    else
        debug "Processing mirror(s): $(distinct d "${_pt_query}")"
    fi
    for _ptmirror in ${_pt_query}; do
        _ptaddress="${MAIN_USER}@${_ptmirror}:${MAIN_BINARY_PREFIX}/${SYS_SPECIFIC_BINARY_REMOTE}"
        debug "Remote address inspect: $(distinct d "${_ptaddress}")"
        try "${SSH_BIN} ${DEFAULT_SSH_OPTS} -p ${MAIN_PORT} ${MAIN_USER}@${_ptmirror} '${MKDIR_BIN} -vp ${MAIN_BINARY_PREFIX}/${SYS_SPECIFIC_BINARY_REMOTE}'"

        build_bundle "${_pbto_bundle_name}" "${_ptelm_file_name}" "${_pversion_element}"
        checksum_filecache_element "${_ptelm_file_name}"

        try "${CHMOD_BIN} -v o+r ${FILE_CACHE_DIR}${_ptelm_file_name} ${FILE_CACHE_DIR}${_ptelm_file_name}${DEFAULT_CHKSUM_EXT}" && \
            debug "Set read access for archives: $(distinct d "${_ptelm_file_name}"), $(distinct d "${_ptelm_file_name}${DEFAULT_CHKSUM_EXT}") before we send them to public remote"

        debug "Deploying bin-bundle: $(distinct d "${_ptelm_file_name}") to mirror: $(distinct d "${_ptmirror}")"
        push_software_archive "${_ptelm_file_name}" "${_ptmirror}" "${_ptaddress}"

        build_service_dataset "${_pbto_bundle_name}" "${_pversion_element}"
        push_dset_zfs_stream "${_ptelm_service_name}" "${_pbto_bundle_name}" "${_ptmirror}" "${_pversion_element}"
    done
    note "Push to: $(distinct n "${_pt_query}") was successfull!"
    unset _ptaddress _ptmirror _pversion_element _ptelm_file_name _pt_query
}


push_dset_zfs_stream () {
    _psfin_snapfile="${1}"
    _pselement="${2}"
    _psmirror="${3}"
    _psversion_element="${4}"
    if [ -z "${_psfin_snapfile}" ]; then
        error "First argument with a $(distinct e "some-snapshot-file.txz") is required!"
    fi
    if [ "YES" = "${CAP_SYS_ZFS}" ]; then
        if [ -z "${_pselement}" ]; then
            error "Second argument with a $(distinct e "BundleName") is required!"
        fi
        if [ -z "${_psmirror}" ]; then
            error "Third argument with a $(distinct e "mirror-IP") is required!"
        fi
        if [ -z "${_psversion_element}" ]; then
            error "Fourth argument with a $(distinct e "version-string") is required!"
        fi
        debug "push_dset_zfs_stream file: $(distinct d "${_psfin_snapfile}")"
        if [ -f "${FILE_CACHE_DIR}${_psfin_snapfile}" ]; then
            try "${SSH_BIN} ${DEFAULT_SSH_OPTS} -p ${MAIN_PORT} ${MAIN_USER}@${_psmirror} \"${MKDIR_BIN} -vp '${COMMON_BINARY_REMOTE}'; ${CHMOD_BIN} -v 0755 '${COMMON_BINARY_REMOTE}'\""
            try "${CHMOD_BIN} -v a+r ${FILE_CACHE_DIR}${_psfin_snapfile}" && \
                debug "Archive access a+r for: $(distinct d "${_psfin_snapfile}")"
            retry "${SCP_BIN} ${DEFAULT_SSH_OPTS} ${DEFAULT_SCP_OPTS} -P ${MAIN_PORT} ${FILE_CACHE_DIR}${_psfin_snapfile} ${MAIN_USER}@${_psmirror}:${COMMON_BINARY_REMOTE}/${_psfin_snapfile}${DEFAULT_PARTIAL_FILE_EXT}"
            if [ "$?" = "0" ]; then
                debug "Service origin stream was sent to: $(distinct d "${MAIN_COMMON_NAME}") repository: $(distinct d "${MAIN_COMMON_REPOSITORY}/${_psfin_snapfile}")"
                retry "${SSH_BIN} ${DEFAULT_SSH_OPTS} -p ${MAIN_PORT} ${MAIN_USER}@${_psmirror} \"cd ${COMMON_BINARY_REMOTE} && ${MV_BIN} -v ${_psfin_snapfile}${DEFAULT_PARTIAL_FILE_EXT} ${_psfin_snapfile}\"" && \
                    debug "Partial file renamed successfully"
            else
                error "Failed to send service stream of bundle: $(distinct e "${_pselement}") file: $(distinct e "${_psfin_snapfile}") to remote host: $(distinct e "${MAIN_USER}@${_psmirror}")!"
            fi
        else
            warn "No service stream available for bundle: $(distinct w "${_pselement}")"
        fi
    else
        debug "No ZFS support"
    fi
    unset _psmirror _pselement _psfin_snapfile _psfin_snapfile _psversion_element
}


build_service_dataset () {
    _ps_elem="${1}"
    _ps_ver_elem="${2}"
    if [ "YES" = "${CAP_SYS_ZFS}" ]; then
        if [ -z "${_ps_elem}" ]; then
            error "First argument with a $(distinct e "BundleName") is required!"
        fi
        if [ -z "${_ps_ver_elem}" ]; then
            error "Second argument with a $(distinct e "version-string") is required!"
        fi
        if [ -z "${USER}" ]; then
            error "Second argument with env value for: $(distinct e "USER") is required!"
        fi
        _full_dataset_name="${DEFAULT_ZPOOL}${SERVICES_DIR}${USER}/${_ps_elem}"
        _ps_snap_file="${_ps_elem}-${_ps_ver_elem}${DEFAULT_SERVICE_SNAPSHOT_EXT}"
        debug "Dataset name: $(distinct d "${_full_dataset_name}"), snapshot-file: $(distinct d "${_ps_snap_file}")"
        if [ ! -f "${FILE_CACHE_DIR}${_ps_snap_file}" ]; then
            fetch_dset_zfs_stream "${_ps_elem}" "${_ps_snap_file}"
            if [ -f "${FILE_CACHE_DIR}${_ps_snap_file}" ]; then
                debug "Service origin available!"
            else
                debug "Service origin unavailable! Creating new one."
                debug "Grepping for dataset: $(distinct d "${_full_dataset_name}")"
                ${ZFS_BIN} list -H 2>/dev/null | eval "${FIRST_ARG_GUARD}" | ${EGREP_BIN} "${_full_dataset_name}" >/dev/null 2>&1
                if [ "$?" = "0" ]; then
                    note "Preparing to send service dataset: $(distinct n "${_full_dataset_name}"), for bundle: $(distinct n "${_ps_elem}")"
                    try "${ZFS_BIN} umount -f ${_full_dataset_name}"
                    run "${ZFS_BIN} send ${_full_dataset_name} | ${XZ_BIN} ${DEFAULT_XZ_OPTS} > ${FILE_CACHE_DIR}${_ps_snap_file}"
                    try "${ZFS_BIN} mount ${_full_dataset_name}"
                else
                    run "${ZFS_BIN} create -p -o mountpoint=${SERVICES_DIR}${_ps_elem} ${_full_dataset_name}"
                    try "${ZFS_BIN} umount -f ${_full_dataset_name}"
                    run "${ZFS_BIN} send ${_full_dataset_name} | ${XZ_BIN} ${DEFAULT_XZ_OPTS} > ${FILE_CACHE_DIR}${_ps_snap_file}"
                    try "${ZFS_BIN} mount ${_full_dataset_name}"
                fi
                _snap_size="$(file_size "${FILE_CACHE_DIR}${_ps_snap_file}")"
                if [ "${_snap_size}" = "0" ]; then
                    try "${RM_BIN} -vf ${FILE_CACHE_DIR}${_ps_snap_file}"
                    debug "Service dataset dump is empty for bundle: $(distinct d "${_ps_elem}-${_ps_ver_elem}")"
                else
                    debug "Snapshot of size: $(distinct d "${_snap_size}") is ready for bundle: $(distinct d "${_ps_elem}")"
                fi
            fi
        else
            debug "Service ${ORIGIN_ZFS_SNAP_NAME} snapshot file exists: $(distinct d "${FILE_CACHE_DIR}${_ps_snap_file}")"
        fi
        unset _snap_size _ps_ver_elem _full_dataset_name _ps_snap_file _ps_elem
    fi
}


# create_service_dataset () {
#     _bund_name="${1}"
#     if [ -z "${_bund_name}" ]; then
#         error "First argument with: $(distinct e dataset_name) required!"
#     fi
#     if [ "YES" = "${CAP_SYS_ZFS}" ]; then
#         debug "Initial service dataset unavailable for: $(distinct d "${_bund_name}")"
#         _dataset_name="${DEFAULT_ZPOOL}${SERVICES_DIR}${USER}/${_bund_name}"
#         try "${ZFS_BIN} create -p ${_dataset_name}"
#     else
#         debug "ZFS feature disabled"
#     fi
#     unset _bund_name _final_snap_file _commons_path
# }


fetch_dset_zfs_stream () {
    _fdz_bund_name="${1}"
    _fdz_out_file="${2}"
    if [ -z "${_fdz_bund_name}" -o \
         -z "${_fdz_out_file}" ]; then
        error "Expected two arguments: $(distinct e "bundle-name") and $(distinct e "name-out-file")."
    fi
    if [ "YES" = "${CAP_SYS_ZFS}" ]; then
        _commons_path="${MAIN_COMMON_REPOSITORY}/${_fdz_out_file}"
        debug "Fetch service stream-dataset: $(distinct d "${FILE_CACHE_DIR}${_fdz_out_file}")"
        retry "${FETCH_BIN} -o ${FILE_CACHE_DIR}${_fdz_out_file} ${FETCH_OPTS} '${_commons_path}'"
        if [ "$?" = "0" ]; then
            _dataset_name="${DEFAULT_ZPOOL}${SERVICES_DIR}${USER}/${_fdz_bund_name}"
            debug "Creating service dataset: $(distinct d "${_dataset_name}"), from file stream: $(distinct d "${_fdz_out_file}")."
            retry "${XZCAT_BIN} ${FILE_CACHE_DIR}${_fdz_out_file} | ${ZFS_BIN} receive -F -v ${_dataset_name} && ${ZFS_BIN} rename \"${_dataset_name}@${DEFAULT_GIT_SNAPSHOT_HEAD}\" ${ORIGIN_ZFS_SNAP_NAME}" && \
                    note "Received service dataset: $(distinct n "${_dataset_name}")"
            unset _dataset_name
        else
            debug "Origin service dataset unavailable for: $(distinct d "${_fdz_bund_name}")."
            return 1
        fi
    else
        debug "ZFS feature disabled"
    fi
    unset _fdz_bund_name _fdz_out_file _commons_path
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
        try "${RM_BIN} -rf ${SERVICES_DIR}${_dset_destroy}"
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
        try "${RM_BIN} -rf ${SOFTWARE_DIR}${_dset_destroy}"
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
        debug "Creating ZFS build-dataset: $(distinct d "${_dset}")"
        try "${ZFS_BIN} create -p -o mountpoint=${SOFTWARE_DIR}${_cb_bundle_name}/${DEFAULT_SRC_EXT}${_dset_namesum} ${_dset}"
        try "${ZFS_BIN} mount ${_dset}"
        unset _dset _dset_namesum
    else
        _bdir="${SOFTWARE_DIR}${_cb_bundle_name}/${DEFAULT_SRC_EXT}${_dset_namesum}"
        debug "Creating regular build-directory: $(distinct d "${_bdir}")"
        try "${MKDIR_BIN} -p ${_bdir}"
    fi
    unset _bdir _cb_bundle_name _dset_namesum
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
            try "${RM_BIN} -fr ${SOFTWARE_DIR}${_deste_bund_name}/${DEFAULT_SRC_EXT}${_dset_sum}"
        else
            debug "DEVEL mode enabled, skipped dataset destroy: $(distinct d "${_dsname}")"
        fi
        unset _dsname
    else
        _bdir="${SOFTWARE_DIR}${_deste_bund_name}/${DEFAULT_SRC_EXT}${_dset_sum}"
        debug "Removing regular build-directory: $(distinct d "${_bdir}")"
        try "${RM_BIN} -fr ${_bdir}"
    fi
    unset _deste_bund_name _bdir _deste_bund_name _dset_sum _dsname
}


recreate_builddir () {
    destroy_builddir "${1}" "${2}"
    create_builddir "${1}" "${2}"
}


create_software_bundle_archive () {
    _csbname="${1}"
    _csbelem="${2}"
    _csversion="${3}"
    if [ -z "${_csbname}" ]; then
        error "First argument with $(distinct e "BundleName") is required!"
    fi
    if [ -z "${_csbelem}" ]; then
        error "Second argument with $(distinct e "file-element-name") is required!"
    fi
    if [ -z "${_csversion}" ]; then
        error "Third argument with $(distinct e "version-string") is required!"
    fi
    _cddestfile="${FILE_CACHE_DIR}${_csbelem}"
    debug "Creating destfile: $(distinct d "${_cddestfile}")"
    if [ "YES" = "${CAP_SYS_ZFS}" ]; then
        _csbd_dataset="${DEFAULT_ZPOOL}${SOFTWARE_DIR}${USER}/${_csbname}"
        debug "Creating archive from dataset: $(distinct d "${_csbd_dataset}") to file: $(distinct d "${_cddestfile}")"
        try "${ZFS_BIN} umount -f ${_csbd_dataset}"
        retry "${ZFS_BIN} send ${_csbd_dataset} | ${XZ_BIN} ${DEFAULT_XZ_OPTS} > ${_cddestfile}" && \
            note "Created ZFS binbundle from dataset: $(distinct d "${_csbd_dataset}")"
        try "${ZFS_BIN} mount ${_csbd_dataset}"
    else
        debug "No ZFS-binbuilds feature. Falling back to tarballs.."
        _cdir="$(${PWD_BIN} 2>/dev/null)"
        cd "${SOFTWARE_DIR}"
        try "${TAR_BIN} --use-compress-program='${XZ_BIN} ${DEFAULT_XZ_OPTS}' --totals -cJf ${_cddestfile} ${_csbname}" || \
            try "${TAR_BIN} --totals -cJf ${_cddestfile} ${_csbname}" || \
                error "Failed to create archive file: $(distinct e "${_cddestfile}")"
        cd "${_cdir}"
    fi
    unset _csbname _csbelem _cddestfile _cdir _csversion _csbd_dataset
}


install_software_from_binbuild () {
    _isfb_archive="${1}"
    _isfb_fullname="${2}"
    if [ "YES" = "${CAP_SYS_ZFS}" ]; then
        # On systems with ZFS capability, we use zfs receive instead of tarballing:
        _isfb_dataset="${DEFAULT_ZPOOL}${SOFTWARE_DIR}${USER}/${_isfb_fullname}"
        ${ZFS_BIN} list -H 2>/dev/null | eval "${FIRST_ARG_GUARD}" | ${EGREP_BIN} "${_isfb_dataset}" >/dev/null 2>&1
        if [ "$?" != "0" ]; then
            debug "Installing ZFS based binary build to dataset: $(distinct d "${_isfb_dataset}")"
            run "${XZCAT_BIN} ${FILE_CACHE_DIR}${_isfb_archive} | ${ZFS_BIN} receive -F -v ${_isfb_dataset} &&
                ${ZFS_BIN} rename ${_isfb_dataset}@${DEFAULT_GIT_SNAPSHOT_HEAD} ${ORIGIN_ZFS_SNAP_NAME}" && \
                    note "Installed: $(distinct n "${_isfb_fullname}")" && \
                        DONT_BUILD_BUT_DO_EXPORTS=YES
        else
            note "Installation not necessary for already existing dataset: $(distinct n "${_isfb_fullname}")"
            DONT_BUILD_BUT_DO_EXPORTS=YES
        fi
    else
        try "${TAR_BIN} -xJf ${FILE_CACHE_DIR}${_isfb_archive} --directory ${SOFTWARE_DIR}"
        if [ "$?" = "0" ]; then
            note "Installed bin-build: $(distinct n "${_isfb_fullname}")"
            DONT_BUILD_BUT_DO_EXPORTS=YES
        else
            debug "No binary bundle available for: $(distinct d "${_bbaname}")"
            try "${RM_BIN} -vf ${FILE_CACHE_DIR}${_isfb_archive} ${FILE_CACHE_DIR}${_isfb_archive}${DEFAULT_CHKSUM_EXT}"
        fi
    fi
}


push_software_archive () {
    _bpbundle_file="${1}"
    _bpamirror="${2}"
    _bpaddress="${3}"
    if [ -z "${_bpbundle_file}" ]; then
        error "First argument: $(distinct e "BundleName") is empty!"
    fi
    if [ -z "${_bpamirror}" ]; then
        error "Third argument: $(distinct e "mirror-name") is empty!"
    fi
    if [ -z "${_bpaddress}" ]; then
        error "Fourth argument: $(distinct e "mirror-address") is empty!"
    fi
    _bpfn_file="${FILE_CACHE_DIR}${_bpbundle_file}"
    _bpfn_file_dest="${_bpaddress}/${_bpbundle_file}"
    _bpfn_chksum_file="${FILE_CACHE_DIR}${_bpbundle_file}${DEFAULT_CHKSUM_EXT}"
    _bpfn_chksum_file_dest="${_bpaddress}/${_bpbundle_file}${DEFAULT_CHKSUM_EXT}"
    _bpshortsha="$(${CAT_BIN} "${_bpfn_chksum_file}" 2>/dev/null | ${CUT_BIN} -c -16 2>/dev/null)"
    _bp_remotfs_file="${MAIN_BINARY_PREFIX}/${SYS_SPECIFIC_BINARY_REMOTE}/${_bpbundle_file}"
    if [ -z "${_bpshortsha}" ]; then
        error "No sha checksum in file: $(distinct e "${_bpfn_chksum_file}")"
    fi
    debug "BundleName: $(distinct d "${_bpbundle_file}"), bundle_file: $(distinct d "${_bpbundle_file}"), repository address: $(distinct d "${_bpaddress}")"
    retry "${SCP_BIN} ${DEFAULT_SSH_OPTS} ${DEFAULT_SCP_OPTS} -P ${MAIN_PORT} ${_bpfn_file} ${_bpfn_file_dest}${DEFAULT_PARTIAL_FILE_EXT}"
    if [ "$?" = "0" ]; then
        retry "${SCP_BIN} ${DEFAULT_SSH_OPTS} ${DEFAULT_SCP_OPTS} -P ${MAIN_PORT} ${_bpfn_chksum_file} ${_bpfn_chksum_file_dest}" || \
            def_error "${_bpbundle_file}" "Error sending checksum file: $(distinct e "${_bpfn_chksum_file}") to: $(distinct e "${_bpfn_chksum_file_dest}")"
        retry "${SSH_BIN} ${DEFAULT_SSH_OPTS} -p ${MAIN_PORT} ${MAIN_USER}@${_bpamirror} \"${MV_BIN} -v ${_bp_remotfs_file}${DEFAULT_PARTIAL_FILE_EXT} ${_bp_remotfs_file}\"" && \
            debug "Partial file renamed to destination name: $(distinct d "${_bp_remotfs_file}")"
    else
        error "Failed to push binary build of: $(distinct e "${_bpbundle_file}") to remote: $(distinct e "${_bp_remotfs_file}")"
    fi
    unset _bpbundle_file _bpbundle_file _bpamirror _bpaddress _bpshortsha _bpfn_chksum_file _bp_remotfs_file _bpfn_chksum_file _bpfn_chksum_file_dest
}


try_destroy_binbuild () {
    if [ -n "${PREFIX}" -a \
         -d "${PREFIX}" ]; then
        if [ -n "${BUILD_NAMESUM}" ]; then
            destroy_builddir "$(${BASENAME_BIN} "${PREFIX}" 2>/dev/null)" "${BUILD_NAMESUM}"
        else
            # shouldn't happen..
            warn "No BUILD_NAMESUM set! Can't identift build-dir!"
        fi
    else
        debug "Empty prefix. No build-dir to destroy"
    fi
}
