
push_to_all_mirrors () {
    _pbto_bundle_name="${1}"
    _pversion_element="${2}"
    _ptelm_file_name="${_pbto_bundle_name}-${_pversion_element}-${OS_TRIPPLE}${DEFAULT_ARCHIVE_EXT}"
    _ptelm_service_name="${_pbto_bundle_name}-${_pversion_element}"
    _pt_query="$(${HOST_BIN} A "${MAIN_SOFTWARE_ADDRESS}" 2>/dev/null | ${GREP_BIN} 'Address:' 2>/dev/null | eval "${HOST_ADDRESS_GUARD}")"
    debug "Address: $(distd "${_pt_query}"), bundle: $(distd "${_pbto_bundle_name}"), name: $(distd "${_ptelm_file_name}")"
    if [ -z "${_pbto_bundle_name}" ]; then
        error "First argument with a $(diste "BundleName") is required!"
    fi
    if [ -z "${_pversion_element}" ]; then
        error "Second argument with a $(diste "version-string") is required!"
    fi
    if [ -z "${_pt_query}" ]; then
        error "Unable to determine IP address of: $(diste "${MAIN_SOFTWARE_ADDRESS}")"
    else
        debug "Processing mirror(s): $(distd "${_pt_query}")"
    fi
    for _ptmirror in $(echo "${_pt_query}" | ${TR_BIN} ' ' '\n' 2>/dev/null); do
        _ptaddress="${SOFIN_NAME}@${_ptmirror}:${MAIN_BINARY_PREFIX}/${SYS_SPECIFIC_BINARY_REMOTE}"
        debug "Remote address inspect: $(distd "${_ptaddress}")"
        try "${SSH_BIN} ${DEFAULT_SSH_OPTS} -p ${MAIN_SSH_PORT} ${SOFIN_NAME}@${_ptmirror} '${MKDIR_BIN} -vp ${MAIN_BINARY_PREFIX}/${SYS_SPECIFIC_BINARY_REMOTE}'"

        build_bundle "${_pbto_bundle_name}" "${_ptelm_file_name}" "${_pversion_element}"
        checksum_filecache_element "${_ptelm_file_name}"

        try "${CHMOD_BIN} -v o+r ${FILE_CACHE_DIR}${_ptelm_file_name} ${FILE_CACHE_DIR}${_ptelm_file_name}${DEFAULT_CHKSUM_EXT}" && \
            debug "Set read access for archives: $(distd "${_ptelm_file_name}"), $(distd "${_ptelm_file_name}${DEFAULT_CHKSUM_EXT}") before we send them to public remote"

        debug "Deploying bin-bundle: $(distd "${_ptelm_file_name}") to mirror: $(distd "${_ptmirror}")"
        push_software_archive "${_ptelm_file_name}" "${_ptmirror}" "${_ptaddress}"

        build_service_dataset "${_pbto_bundle_name}" "${_pversion_element}"
        _pfin_svc_name="${_ptelm_service_name}${DEFAULT_SERVICE_SNAPSHOT_EXT}"
        if [ "YES" != "${CAP_SYS_ZFS}" ]; then
            # Fallback to tarball extension for service datadir:
            _pfin_svc_name="${_ptelm_service_name}${DEFAULT_ARCHIVE_EXT}"
        fi
        push_dset_zfs_stream "${_pfin_svc_name}" "${_pbto_bundle_name}" "${_ptmirror}" "${_pversion_element}"
    done
    permnote "Bundle pushed successfully: $(distn "${_pbto_bundle_name}")!"
    unset _ptaddress _ptmirror _pversion_element _ptelm_file_name _pt_query
}


push_dset_zfs_stream () {
    _psfin_snapfile="${1}"
    _pselement="${2}"
    _psmirror="${3}"
    _psversion_element="${4}"
    if [ -z "${_psfin_snapfile}" ]; then
        error "First argument with a $(diste "some-snapshot-file.txz") is required!"
    fi
    if [ -z "${_pselement}" ]; then
        error "Second argument with a $(diste "BundleName") is required!"
    fi
    if [ -z "${_psmirror}" ]; then
        error "Third argument with a $(diste "mirror-IP") is required!"
    fi
    if [ -z "${_psversion_element}" ]; then
        error "Fourth argument with a $(diste "version-string") is required!"
    fi
    debug "push_dset_zfs_stream file: $(distd "${_psfin_snapfile}")"
    if [ -f "${FILE_CACHE_DIR}${_psfin_snapfile}" ]; then
        # create required dirs and stuff:
        try "${SSH_BIN} ${DEFAULT_SSH_OPTS} -p ${MAIN_SSH_PORT} ${SOFIN_NAME}@${_psmirror} \"${MKDIR_BIN} -p '${COMMON_BINARY_REMOTE}'; ${CHMOD_BIN} -v 0755 '${COMMON_BINARY_REMOTE}'\""

        # NOTE: check if service dataset bundle isn't already pushed. ZFS streams cannot be overwritten!
        try "${SSH_BIN} ${DEFAULT_SSH_OPTS} -p ${MAIN_SSH_PORT} ${SOFIN_NAME}@${_psmirror} \"${FILE_BIN} ${COMMON_BINARY_REMOTE}/${_psfin_snapfile}\""
        if [ "${?}" = "0" ]; then
            debug "Service dataset file found existing on remote mirror: $(distd "${_psmirror}"). Service dataset origins can be stored only once (future ZFS-related features will rely on this!)"
        else
            try "${CHMOD_BIN} -v a+r ${FILE_CACHE_DIR}${_psfin_snapfile}" && \
                debug "Archive access a+r for: $(distd "${_psfin_snapfile}")"
            retry "${SCP_BIN} ${DEFAULT_SSH_OPTS} ${DEFAULT_SCP_OPTS} -P ${MAIN_SSH_PORT} ${FILE_CACHE_DIR}${_psfin_snapfile} ${SOFIN_NAME}@${_psmirror}:${COMMON_BINARY_REMOTE}/${_psfin_snapfile}${DEFAULT_PARTIAL_FILE_EXT}"
            if [ "${?}" = "0" ]; then
                debug "Service origin stream was sent to: $(distd "${MAIN_COMMON_NAME}") repository: $(distd "${MAIN_COMMON_REPOSITORY}/${_psfin_snapfile}")"
                retry "${SSH_BIN} ${DEFAULT_SSH_OPTS} -p ${MAIN_SSH_PORT} ${SOFIN_NAME}@${_psmirror} \"cd ${COMMON_BINARY_REMOTE} && ${MV_BIN} -v ${_psfin_snapfile}${DEFAULT_PARTIAL_FILE_EXT} ${_psfin_snapfile}\"" && \
                    debug "Partial file renamed successfully"
            else
                error "Failed to send service stream of bundle: $(diste "${_pselement}") file: $(diste "${_psfin_snapfile}") to remote host: $(diste "${SOFIN_NAME}@${_psmirror}")!"
            fi
        fi
    else
        warn "No service stream available for bundle: $(distw "${_pselement}")"
    fi
    unset _psmirror _pselement _psfin_snapfile _psfin_snapfile _psversion_element
}


build_service_dataset () {
    _ps_elem="${1}"
    _ps_ver_elem="${2}"
    if [ "YES" = "${CAP_SYS_ZFS}" ]; then
        if [ -z "${_ps_elem}" ]; then
            error "First argument with a $(diste "BundleName") is required!"
        fi
        if [ -z "${_ps_ver_elem}" ]; then
            error "Second argument with a $(diste "version-string") is required!"
        fi
        if [ -z "${USER}" ]; then
            error "Second argument with env value for: $(diste "USER") is required!"
        fi
        _full_dataset_name="${DEFAULT_ZPOOL}${SERVICES_DIR}/${USER}/${_ps_elem}"
        _ps_snap_file="${_ps_elem}-${_ps_ver_elem}${DEFAULT_SERVICE_SNAPSHOT_EXT}"
        debug "Dataset name: $(distd "${_full_dataset_name}"), snapshot-file: $(distd "${_ps_snap_file}")"
        if [ ! -f "${FILE_CACHE_DIR}${_ps_snap_file}" ]; then
            fetch_dset_zfs_stream "${_ps_elem}" "${_ps_snap_file}"
            if [ -f "${FILE_CACHE_DIR}${_ps_snap_file}" ]; then
                debug "Service origin available!"
            else
                debug "Service origin unavailable! Creating new one."
                debug "Grepping for dataset: $(distd "${_full_dataset_name}")"
                try "${ZFS_BIN} list -H -t filesystem '${_full_dataset_name}'"
                if [ "${?}" = "0" ]; then
                    note "Preparing to send service dataset: $(distn "${_full_dataset_name}"), for bundle: $(distn "${_ps_elem}")"
                    try "${ZFS_BIN} umount -f '${_full_dataset_name}'"
                    run "${ZFS_BIN} send ${ZFS_SEND_OPTS} '${_full_dataset_name}@${ORIGIN_ZFS_SNAP_NAME}' | ${XZ_BIN} ${DEFAULT_XZ_OPTS} > ${FILE_CACHE_DIR}${_ps_snap_file}"
                    try "${ZFS_BIN} mount '${_full_dataset_name}'" || :
                # else
                #     run "${ZFS_BIN} create -p -o mountpoint=${SERVICES_DIR}/${_ps_elem} '${_full_dataset_name}'"
                #     try "${ZFS_BIN} snapshot '${_full_dataset_name}@${ORIGIN_ZFS_SNAP_NAME}'"
                #     try "${ZFS_BIN} umount -f '${_full_dataset_name}'"
                #     run "${ZFS_BIN} send ${ZFS_SEND_OPTS} '${_full_dataset_name}@${ORIGIN_ZFS_SNAP_NAME}' | ${XZ_BIN} ${DEFAULT_XZ_OPTS} > ${FILE_CACHE_DIR}${_ps_snap_file}"
                #     run "${ZFS_BIN} mount '${_full_dataset_name}'"
                fi
                _snap_size="$(file_size "${FILE_CACHE_DIR}${_ps_snap_file}")"
                if [ "${_snap_size}" = "0" ]; then
                    try "${RM_BIN} -f ${FILE_CACHE_DIR}${_ps_snap_file}"
                    debug "Service dataset dump is empty for bundle: $(distd "${_ps_elem}-${_ps_ver_elem}")"
                else
                    debug "Snapshot of size: $(distd "${_snap_size}") is ready for bundle: $(distd "${_ps_elem}")"
                fi
            fi
        else
            debug "Service ${ORIGIN_ZFS_SNAP_NAME} snapshot file exists: $(distd "${FILE_CACHE_DIR}${_ps_snap_file}")"
        fi
        unset _snap_size _ps_ver_elem _full_dataset_name _ps_snap_file _ps_elem
    else
        # fallback for hosts without ZFS feature
        if [ -z "${_ps_elem}" ]; then
            error "First argument with a $(diste "BundleName") is required!"
        fi
        if [ -z "${_ps_ver_elem}" ]; then
            error "Second argument with a $(diste "version-string") is required!"
        fi
        if [ -z "${USER}" ]; then
            error "Second argument with env value for: $(diste "USER") is required!"
        fi
        _full_svc_dirname="${SERVICES_DIR}/${_ps_elem}"
        _ps_snap_file="${_ps_elem}-${_ps_ver_elem}${DEFAULT_ARCHIVE_TARBALL_EXT}" # XXX: use DEFAULT_ARCHIVE_TARBALL_EXT
        debug "Dir name: $(distd "${_full_svc_dirname}"), snapshot-file: $(distd "${_ps_snap_file}")"
        if [ ! -f "${FILE_CACHE_DIR}${_ps_snap_file}" ]; then
            fetch_dset_zfs_stream "${_ps_elem}" "${_ps_snap_file}"
            if [ -f "${FILE_CACHE_DIR}${_ps_snap_file}" ]; then
                debug "Service origin available!"
            else
                debug "Service origin unavailable! Creating new one."
                try "${MKDIR_BIN} -p ${SERVICES_DIR}/${_ps_elem}"
                run "${TAR_BIN} cJf ${FILE_CACHE_DIR}${_ps_snap_file} ${SERVICES_DIR}/${_ps_elem}"
                _snap_size="$(file_size "${FILE_CACHE_DIR}${_ps_snap_file}")"
                if [ "${_snap_size}" = "0" ]; then
                    try "${RM_BIN} -f ${FILE_CACHE_DIR}${_ps_snap_file}"
                    debug "Service tarball dump is empty for bundle: $(distd "${_ps_elem}-${_ps_ver_elem}")"
                else
                    debug "Snapshot of size: $(distd "${_snap_size}") is ready for bundle: $(distd "${_ps_elem}")"
                fi
            fi
        else
            debug "Service tarball file exists: $(distd "${FILE_CACHE_DIR}${_ps_snap_file}")"
        fi
        unset _snap_size _ps_ver_elem _full_svc_dirname _ps_snap_file _ps_elem
    fi
}


create_service_dataset () {
    _bund_name="${1}"
    if [ -z "${_bund_name}" ]; then
        error "First argument with: $(diste dataset_name) required!"
    fi
    if [ "YES" = "${CAP_SYS_ZFS}" ]; then
        _dataset_name="${DEFAULT_ZPOOL}${SERVICES_DIR}/${USER}/${_bund_name}"
        try "${ZFS_BIN} list -H -o name -t filesystem ${_dataset_name}"
        if [ "0" = "${?}" ]; then
            debug "Service dataset already exists: $(distd "${_dataset_name}")"
        else
            debug "Creating initial service dataset: $(distd "${_dataset_name}") for: $(distd "${_bund_name}")."
            run "${ZFS_BIN} create -p '${_dataset_name}'"
        fi
    else
        debug "ZFS feature disabled"
    fi
    unset _bund_name
}


fetch_dset_zfs_stream () {
    _fdz_bund_name="${1}"
    _fdz_out_file="${2}"
    if [ -z "${_fdz_bund_name}" ] || [ -z "${_fdz_out_file}" ]; then
        error "Expected two arguments: $(diste "bundle-name") and $(diste "name-out-file")."
    fi
    if [ "YES" = "${CAP_SYS_ZFS}" ]; then
        _commons_path="${MAIN_COMMON_REPOSITORY}/${_fdz_out_file}"
        debug "Fetch service stream-dataset: $(distd "${FILE_CACHE_DIR}${_fdz_out_file}")"
        retry "${FETCH_BIN} -o ${FILE_CACHE_DIR}${_fdz_out_file} ${FETCH_OPTS} '${_commons_path}'"
        if [ "${?}" = "0" ]; then
            _dataset_name="${DEFAULT_ZPOOL}${SERVICES_DIR}/${USER}/${_fdz_bund_name}"
            try "${XZCAT_BIN} '${FILE_CACHE_DIR}${_fdz_out_file}' | ${ZFS_BIN} receive ${ZFS_RECEIVE_OPTS} '${_dataset_name}' | ${TAIL_BIN} -n1 2>/dev/null" && \
                    note "Received service dataset: $(distn "${_dataset_name}")"
            unset _dataset_name
        else
            debug "Origin service dataset unavailable for: $(distd "${_fdz_bund_name}")."
            return 1
        fi
    else
        debug "ZFS feature disabled. Falling back to tarballs.."
        _commons_path="${MAIN_COMMON_REPOSITORY}/${_fdz_out_file}"
        debug "Fetch service stream-tarball: $(distd "${FILE_CACHE_DIR}${_fdz_out_file}")"
        retry "${FETCH_BIN} -o ${FILE_CACHE_DIR}${_fdz_out_file} ${FETCH_OPTS} '${_commons_path}'"
        if [ "${?}" = "0" ]; then
            try "${TAR_BIN} xf ${FILE_CACHE_DIR}${_fdz_out_file} --directory ${SERVICES_DIR}" && \
                note "Received service tarball for service: $(distn "${_fdz_bund_name}")"
            unset _tarball_name
        else
            debug "Origin service tarball unavailable for: $(distd "${_fdz_bund_name}")."
            return 1
        fi
    fi
    unset _fdz_bund_name _fdz_out_file _commons_path
}


try_fetch_service_dir () {
    _dset_create="${1}"
    if [ -z "${_dset_create}" ]; then
        error "First argument with $(diste "BundleName") is required!"
    fi
    _dset_version="${2}"
    if [ -z "${_dset_version}" ]; then
        error "Second argument with $(diste "version") is required!"
    fi
    if [ "YES" = "${CAP_SYS_ZFS}" ]; then
        _svce_origin="${_dset_create}-${_dset_version}${DEFAULT_SERVICE_SNAPSHOT_EXT}"
        _svce_org_file="${FILE_CACHE_DIR}${_svce_origin}"
        if [ ! -f "${_svce_org_file}" ]; then
            retry "${FETCH_BIN} -o ${_svce_org_file} ${FETCH_OPTS} ${MAIN_COMMON_REPOSITORY}/${_svce_origin}" && \
                debug "Service origin fetched successfully: $(distd "${_svce_origin}")"
        fi
        if [ -f "${_svce_org_file}" ]; then
            # NOTE: each user dataset is made of same origin, hence you can apply snapshots amongst them..
            try "${ZFS_BIN} list '${DEFAULT_ZPOOL}${SERVICES_DIR}/${USER}/${_dset_create}'"
            if [ "0" = "$?" ]; then
                debug "Service origin is already present for: $(distd "${_svce_origin}")"
            else
                run "${XZCAT_BIN} "${_svce_org_file}" | ${ZFS_BIN} receive ${ZFS_RECEIVE_OPTS} '${DEFAULT_ZPOOL}${SERVICES_DIR}/${USER}/${_dset_create}' | ${TAIL_BIN} -n1 2>/dev/null" && \
                    debug "Service origin received successfully: $(distd "${_svce_origin}")"
            fi
        else
            debug "No Service origin file available! Skipped."
        fi
    else
        debug "Creating regular service-directory: $(distd "${SERVICES_DIR}/${_dset_create}")"
        try "${MKDIR_BIN} -p '${SERVICES_DIR}/${_dset_create}'"
        try "${CHMOD_BIN} -v 0710 '${SERVICES_DIR}/${_dset_create}'"
    fi
    unset _dset_create
}


unmount_and_destroy () {
    _dataset_name="${1}"
    try "${ZFS_BIN} list -H -t filesystem '${_dataset_name}'"
    if [ "${?}" = "0" ]; then
        try "${ZFS_BIN} umount -f '${_dataset_name}' > /dev/null"
        try "${ZFS_BIN} destroy -fr '${_dataset_name}' > /dev/null"
        if [ "${?}" = "0" ]; then
            debug "Service dataset destroyed: $(distd "${_dataset_name}")"
        else
            warn "Service dataset NOT destroyed: $(distd "${_dataset_name}")"
        fi
    fi
    unset _dataset_name
}


destroy_service_dir () {
    _dset_destroy="${1}"
    if [ -z "${_dset_destroy}" ]; then
        error "First argument with $(diste "BundleName") to destroy is required!"
    fi
    if [ "YES" = "${CAP_SYS_ZFS}" ]; then
        unmount_and_destroy "${DEFAULT_ZPOOL}${SERVICES_DIR}/${USER}/${_dset_destroy}"
    else
        try "${RM_BIN} -rf '${SERVICES_DIR}/${_dset_destroy}'" && \
            debug "Removed regular software-directory: $(distd "${SERVICES_DIR}/${_dset_destroy}")"
    fi
    unset _dset_destroy
}


create_base_datasets () {
    if [ "YES" = "${CAP_SYS_ZFS}" ]; then
        _soft_origin="${DEFAULT_ZPOOL}${SOFTWARE_DIR}"
        try "${ZFS_BIN} list -H -t filesystem '${_soft_origin}'" || \
            receive_origin "${_soft_origin}" "Software"

        _serv_origin="${DEFAULT_ZPOOL}${SERVICES_DIR}"
        try "${ZFS_BIN} list -H -t filesystem '${_serv_origin}'" || \
            receive_origin "${_serv_origin}" "Services"

        unset _soft_origin _serv_origin
    fi
}


receive_origin () {
    _dname="${1}"
    _dorigin_base="${2}"
    _dtype="${3}"
    if [ -z "${_dname}" ]; then
        error "No dataset name given!"
    fi
    if [ -z "${_dorigin_base}" ]; then
        error "No dataset bae given! Should be one of 'Services' or 'Software'"
    fi
    if [ -n "${_dtype}" ]; then
        # _dname="/${USER}/${_dname}"
        _head="${_dorigin_base}-user"
    else
        # NOOP:
        return 0
    fi
    _origin_name="${_head}-${ORIGIN_ZFS_SNAP_NAME}${DEFAULT_SOFTWARE_SNAPSHOT_EXT}"
    _origin_file="${FILE_CACHE_DIR}/${_origin_name}"
    if [ ! -f "${_origin_file}" ]; then
        run "${FETCH_BIN} -o ${_origin_file} ${FETCH_OPTS} ${MAIN_COMMON_REPOSITORY}/${_origin_name}" && \
            debug "Origin fetched successfully: $(distd "${_origin_name}")"
    fi
    if [ -f "${_origin_file}" ]; then
        debug "_dname: $(distd "${_dname}")"
        # NOTE: each user dataset is made of same origin, hence you can apply snapshots amongst them..
        run "${XZCAT_BIN} "${_origin_file}" | ${ZFS_BIN} receive ${ZFS_RECEIVE_OPTS} '${_dname}' | ${TAIL_BIN} -n1 2>/dev/null" && \
            debug "Origin received successfully: $(distd "${_origin_name}")"
    else
        error "No origin file available! That's mandatory to have this file: $(diste "${_origin_file}")"
    fi
    unset _dname _origin_file
}


create_software_dir () {
    _dset_create="${1}"
    if [ -z "${_dset_create}" ]; then
        error "First argument with $(diste "BundleName") is required!"
    fi
    if [ "YES" = "${CAP_SYS_ZFS}" ]; then
        _dsname="${DEFAULT_ZPOOL}${SOFTWARE_DIR}/${USER}/${_dset_create}"
        try "${ZFS_BIN} list -H -t filesystem '${_dsname}'" || \
            receive_origin "${_dsname}" "Software" "user" && \
                debug "Received ZFS software-dataset: $(distd "${_dsname}")"
        run "${ZFS_BIN} set mountpoint=${SOFTWARE_DIR}/${_dset_create} '${_dsname}'"
        try "${ZFS_BIN} mount '${_dsname}'" || :
        unset _dsname
    else
        debug "Creating regular software-directory: $(distd "${SOFTWARE_DIR}/${_dset_create}")"
        try "${MKDIR_BIN} -p '${SOFTWARE_DIR}/${_dset_create}'"
    fi
    try "${CHMOD_BIN} 0711 '${SOFTWARE_DIR}/${_dset_create}'"
    unset _dset_create
}


destroy_software_dir () {
    _dset_destroy="${1}"
    if [ -z "${_dset_destroy}" ]; then
        error "First argument with $(diste "BundleName") to destroy is required!"
    fi
    if [ "YES" = "${CAP_SYS_ZFS}" ]; then
        _dsname="${DEFAULT_ZPOOL}${SOFTWARE_DIR}/${USER}/${_dset_destroy}"
        try "${ZFS_BIN} umount -f '${_dsname}'"
        try "${ZFS_BIN} destroy -fr '${_dsname}'" && \
            debug "Destroyed software-dataset: $(distd "${_dsname}")"
        try "${RM_BIN} -rf '${SOFTWARE_DIR}/${_dset_destroy}'"
        unset _dsname
    else
        debug "Removing regular software-directory: $(distd "${SOFTWARE_DIR}/${_dset_destroy}")"
        try "${RM_BIN} -rf '${SOFTWARE_DIR}/${_dset_destroy}'"
    fi
    unset _dset_destroy
}


create_builddir () {
    _cb_bundle_name="${1}"
    _dset_namesum="${2}"
    if [ -z "${_cb_bundle_name}" ]; then
        error "First argument with $(diste "BundleName") is required!"
    fi
    _bdir="${SOFTWARE_DIR}/${_cb_bundle_name}/${DEFAULT_SRC_EXT}${_dset_namesum}"
    try "${MKDIR_BIN} -p '${_bdir}'"

    if [ -n "${CAP_SYS_BUILDHOST}" ]; then
        try "${UMOUNT_BIN} -f ${_bdir}" && \
            debug "Unmounted build-dir ramdisk: $(distd "${_bdir}")"

        case "${SYSTEM_NAME}" in
            Darwin)
                destroy_ramdisk_device
                _ramfs_size_mb=4096
                _ramfs_sectors=$((${_ramfs_size_mb}*1024*1024/512))
                RAMDISK_DEV="$(${HDID_BIN} -nomount ram://${_ramfs_sectors} 2>/dev/null)"

                debug "Darwin ramdisk dev: $(distd "${RAMDISK_DEV}")"
                run "${NEWFS_HFS_BIN} -v '${_cb_bundle_name}' ${RAMDISK_DEV}"
                run "${MOUNT_BIN} -o noatime -t hfs ${RAMDISK_DEV} ${_bdir}" && \
                    debug "Mounted tmpfs build-directory: $(distd "${_bdir}")"
                ;;

            FreeBSD)
                RAMDISK_DEV="${_bdir}"
                debug "Mounting clean 5GiB tmpfs build-dir: $(distd "${RAMDISK_DEV}")"
                run "${MOUNT_BIN} -t tmpfs -o size=5G,mode=0750 tmpfs ${RAMDISK_DEV}" && \
                    debug "Mounted tmpfs build-directory: $(distd "${RAMDISK_DEV}")"
                ;;
        esac
        export RAMDISK_DEV
    fi
    unset _bdir _cb_bundle_name _dset_namesum
}


destroy_builddir () {
    _deste_bund_name="${1}"
    _dset_sum="${2}"
    if [ -z "${_deste_bund_name}" ]; then
        error "First argument with $(diste "build-bundle-directory") is required!"
    fi
    _bdir="${SOFTWARE_DIR}/${_deste_bund_name}/${DEFAULT_SRC_EXT}${_dset_sum}"
    if [ -n "${CAP_SYS_BUILDHOST}" ]; then
        case "${SYSTEM_NAME}" in
            Darwin)
                if [ -n "${RAMDISK_DEV}" ]; then
                    try "diskutil eject ${RAMDISK_DEV}" && \
                        debug "Tmp ramdisk unmounted: $(distd "${RAMDISK_DEV}")"
                fi
                ;;
        esac
        destroy_ramdisk_device
        try "${UMOUNT_BIN} -f ${_bdir}" && \
            debug "Tmp build-dir force-unmounted: $(distd "${_bdir}")"
        try "${RM_BIN} -rf '${_bdir}'" && \
            debug "Tmp build-dir removed: $(distd "${_bdir}")"
    fi
    unset _deste_bund_name _bdir _deste_bund_name _dset_sum
}


create_software_bundle_archive () {
    _csbname="${1}"
    _csbelem="${2}"
    _csversion="${3}"
    if [ -z "${_csbname}" ]; then
        error "First argument with $(diste "BundleName") is required!"
    fi
    if [ -z "${_csbelem}" ]; then
        error "Second argument with $(diste "file-element-name") is required!"
    fi
    if [ -z "${_csversion}" ]; then
        error "Third argument with $(diste "version-string") is required!"
    fi
    _cddestfile="${FILE_CACHE_DIR}${_csbelem}"
    if [ "YES" = "${CAP_SYS_ZFS}" ]; then
        _inst_ind="${_csbname}/$(lowercase "${_csbname}")${DEFAULT_INST_MARK_EXT}"
        if [ -f "${SOFTWARE_DIR}/${_inst_ind}" ]; then
            _csbd_dataset="${DEFAULT_ZPOOL}${SOFTWARE_DIR}/${USER}/${_csbname}"
            debug "Creating archive from snapshot: $(distd "${ORIGIN_ZFS_SNAP_NAME}") dataset: $(distd "${_csbd_dataset}") to file: $(distd "${_cddestfile}")"
            _cdir="$(${PWD_BIN} 2>/dev/null)"
            cd /tmp
            try "${RM_BIN} -rf ${SOFTWARE_DIR}/${_csbname}/${DEFAULT_SRC_EXT}*"
            try "${ZFS_BIN} snapshot '${_csbd_dataset}@${ORIGIN_ZFS_SNAP_NAME}'"
            try "${ZFS_BIN} umount -f '${_csbd_dataset}'"
            try "${ZFS_BIN} send ${ZFS_SEND_OPTS} '${_csbd_dataset}@${ORIGIN_ZFS_SNAP_NAME}' | ${XZ_BIN} ${DEFAULT_XZ_OPTS} > ${_cddestfile}" && \
                note "Created bin-bundle from dataset: $(distd "${_csbd_dataset}")"
            cd "${_cdir}"
            try "${ZFS_BIN} mount '${_csbd_dataset}'" || :
        else
            error "Can't build snapshot from broken/empty bundle dir: $(diste "${SOFTWARE_DIR}/${_inst_ind}")"
        fi
    else
        debug "No ZFS-binbuilds feature. Falling back to tarballs.."
        _cdir="$(${PWD_BIN} 2>/dev/null)"
        cd "${SOFTWARE_DIR}"
        try "${TAR_BIN} --use-compress-program='${XZ_BIN} ${DEFAULT_XZ_OPTS}' --totals -cJf ${_cddestfile} ${_csbname}" || \
            try "${TAR_BIN} --totals -cJf ${_cddestfile} ${_csbname}" || \
                error "Failed to create archive file: $(diste "${_cddestfile}")"
        cd "${_cdir}"
    fi
    unset _csbname _csbelem _cddestfile _cdir _csversion _csbd_dataset
}


# returns name of device which is used in main ZFS pool:
boot_device_name () {
    for _dsk in $(${GEOM_BIN} disk list 2>/dev/null | ${EGREP_BIN} -i "Geom name:" 2>/dev/null | ${SED_BIN} 's/^.*\: //' 2>/dev/null); do

        if [ "YES" = "${CAP_SYS_ZFS}" ]; then
            ${ZPOOL_BIN} status "${DEFAULT_ZPOOL}" 2>/dev/null | \
                ${EGREP_BIN} -i "${_dsk}p[0-9]+" >/dev/null 2>&1 && \
                ${PRINTF_BIN} '%s\n' "${_dsk}" && \
                return 0
        else
            ${MOUNT_BIN} 2>/dev/null | \
                ${EGREP_BIN} -i "/dev/${_dsk}" >/dev/null 2>&1 && \
                ${PRINTF_BIN} '%s\n' "${_dsk}" && \
                return 0
        fi
    done

    return 1
}


install_software_from_binbuild () {
    _isfb_archive="${1}"
    _isfb_fullname="${2}"
    if [ "YES" = "${CAP_SYS_ZFS}" ]; then
        # On systems with ZFS capability, we use zfs receive instead of tarballing:
        _isfb_dataset="${DEFAULT_ZPOOL}${SOFTWARE_DIR}/${USER}/${_isfb_fullname}"
        debug "isfb: $(distd "${_isfb_archive}"), isff: $(distd "${_isfb_fullname}"), isfbdset: $(distd "${_isfb_dataset}")"
        try "${ZFS_BIN} list -H -t filesystem ${_isfb_dataset} >> ${LOG} 2>/dev/null"
        if [ "${?}" = "0" ]; then
            note "Software dataset: $(distn "${_isfb_fullname}") already present. Will be destroyed!"
            run "${ZFS_BIN} destroy -r '${_isfb_dataset}'"
        fi
        debug "Installing ZFS based binary build to dataset: $(distd "${_isfb_dataset}")"
        run "${XZCAT_BIN} '${FILE_CACHE_DIR}${_isfb_archive}' | ${ZFS_BIN} receive -F ${ZFS_RECEIVE_OPTS} '${_isfb_dataset}' | ${TAIL_BIN} -n1 2>/dev/null" && \
                note "Installed: $(distn "${_isfb_fullname}")" && \
                    DONT_BUILD_BUT_DO_EXPORTS=YES
        # fi
    else
        try "${TAR_BIN} -xJf ${FILE_CACHE_DIR}${_isfb_archive} --directory ${SOFTWARE_DIR}"
        if [ "${?}" = "0" ]; then
            note "Installed binary build: $(distn "${_isfb_fullname}")"
            DONT_BUILD_BUT_DO_EXPORTS=YES
        else
            debug "No binary bundle available for: $(distd "${_isfb_fullname}")"
            try "${RM_BIN} -f ${FILE_CACHE_DIR}${_isfb_archive} ${FILE_CACHE_DIR}${_isfb_archive}${DEFAULT_CHKSUM_EXT}"
        fi
    fi
}


push_software_archive () {
    _bpbundle_file="${1}"
    _bpamirror="${2}"
    _bpaddress="${3}"
    if [ -z "${_bpbundle_file}" ]; then
        error "First argument: $(diste "BundleName") is empty!"
    fi
    if [ -z "${_bpamirror}" ]; then
        error "Third argument: $(diste "mirror-name") is empty!"
    fi
    if [ -z "${_bpaddress}" ]; then
        error "Fourth argument: $(diste "mirror-address") is empty!"
    fi
    _bpfn_file="${FILE_CACHE_DIR}${_bpbundle_file}"
    _bpfn_file_dest="${_bpaddress}/${_bpbundle_file}"
    _bpfn_chksum_file="${FILE_CACHE_DIR}${_bpbundle_file}${DEFAULT_CHKSUM_EXT}"
    _bpfn_chksum_file_dest="${_bpaddress}/${_bpbundle_file}${DEFAULT_CHKSUM_EXT}"
    _bpshortsha="$(${CAT_BIN} "${_bpfn_chksum_file}" 2>/dev/null | ${CUT_BIN} -c -16 2>/dev/null)"
    _bp_remotfs_file="${MAIN_BINARY_PREFIX}/${SYS_SPECIFIC_BINARY_REMOTE}/${_bpbundle_file}"
    if [ -z "${_bpshortsha}" ]; then
        error "No sha checksum in file: $(diste "${_bpfn_chksum_file}")"
    fi
    debug "BundleName: $(distd "${_bpbundle_file}"), bundle_file: $(distd "${_bpbundle_file}"), repository address: $(distd "${_bpaddress}")"
    retry "${SCP_BIN} ${DEFAULT_SSH_OPTS} ${DEFAULT_SCP_OPTS} -P ${MAIN_SSH_PORT} ${_bpfn_file} ${_bpfn_file_dest}${DEFAULT_PARTIAL_FILE_EXT}"
    if [ "${?}" = "0" ]; then
        retry "${SCP_BIN} ${DEFAULT_SSH_OPTS} ${DEFAULT_SCP_OPTS} -P ${MAIN_SSH_PORT} ${_bpfn_chksum_file} ${_bpfn_chksum_file_dest}" || \
            error "Failed to send the checksum file: $(diste "${_bpfn_chksum_file}") to: $(diste "${_bpfn_chksum_file_dest}")"
        retry "${SSH_BIN} ${DEFAULT_SSH_OPTS} -p ${MAIN_SSH_PORT} ${SOFIN_NAME}@${_bpamirror} \"${MV_BIN} -v ${_bp_remotfs_file}${DEFAULT_PARTIAL_FILE_EXT} ${_bp_remotfs_file}\"" && \
            debug "Partial file renamed to destination name: $(distd "${_bp_remotfs_file}")"
    else
        error "Failed to push binary build of: $(diste "${_bpbundle_file}") to remote: $(diste "${_bp_remotfs_file}")"
    fi
    unset _bpbundle_file _bpbundle_file _bpamirror _bpaddress _bpshortsha _bpfn_chksum_file _bp_remotfs_file _bpfn_chksum_file _bpfn_chksum_file_dest
}


require_prefix_set () {
    if [ -z "${PREFIX}" ]; then
        error "PREFIX can't be empty!"
    fi
}


require_namesum_set () {
    if [ -z "${BUILD_NAMESUM}" ]; then
        error "BUILD_NAMESUM can't be empty!"
    fi
}


do_prefix_snapshot () {
    _snap_name="${1}"
    if [ -z "${_snap_name}" ]; then
        error "Snapshot name can't be empty!"
    fi
    if [ -n "${USER}" ]; then
        require_prefix_set
        require_namesum_set
        if [ "YES" = "${CAP_SYS_ZFS}" ]; then
            _pr_name="${PREFIX##*/}"
            _pr_soft="${DEFAULT_ZPOOL}${SOFTWARE_DIR}/${USER}/${_pr_name}"
            _pr_serv="${DEFAULT_ZPOOL}${SERVICES_DIR}/${USER}/${_pr_name}"
            debug "Name: $(distd "${_pr_name}"), Software dir: $(distd "${_pr_soft}"), Service dir: $(distd "${_pr_serv}")"

            # # Try removing existing snaps:
            do_snaps_destroy () {
                try "${ZFS_BIN} destroy -r '${_pr_soft}@${_snap_name}'"
                try "${ZFS_BIN} destroy -r '${_pr_serv}@${_snap_name}'"
                return 0
            }

            # # Do snapshots:
            do_snaps () {
                try "${ZFS_BIN} snapshot '${_pr_soft}@${_snap_name}'" \
                    && try "${ZFS_BIN} snapshot '${_pr_serv}@${_snap_name}'" \
                    && return 0
                return 1
            }

            do_snaps_destroy \
                && do_snaps \
                && return 0

            debug "Failed snapshot? 1. $(distd "${_snap_name}_${TIMESTAMP}@${_snap_name}");  2. $(distd "${_pr_serv}@${_snap_name}")"
            return 1
        fi
    else
        debug "Value of USER unset!"
    fi
}


after_unpack_snapshot () {
    do_prefix_snapshot "after_unpack"
}


after_patch_snapshot () {
    do_prefix_snapshot "after_patch"
}


after_configure_snapshot () {
    do_prefix_snapshot "after_configure"
}


after_make_snapshot () {
    do_prefix_snapshot "after_make"
}


after_test_snapshot () {
    do_prefix_snapshot "after_test"
}


after_install_snapshot () {
    do_prefix_snapshot "after_install"
}


after_export_snapshot () {
    do_prefix_snapshot "after_export"
}
