
manage_datasets () {
    if [ "YES" = "${CAP_SYS_ZFS}" ]; then
        # start from checking ${SERVICES_DIR}/Bundlename directory
        if [ ! -d "${SERVICE_DIR}" ]; then
            ${MKDIR_BIN} -p "${SERVICE_DIR}/etc" "${SERVICE_DIR}/var" && \
                note "Prepared service directory: $(distinct n ${SERVICE_DIR})"
        fi

        # count Sofin jobs. For more than one job available,
        _sofin_ps_list="$(processes_all_sofin)"
        _sofins_all="$(echo "${_sofin_ps_list}" | ${WC_BIN} -l 2>/dev/null | ${SED_BIN} 's/ //g' 2>/dev/null)"
        _sofins_installing="$(echo "${_sofins_all} - 1" | ${BC_BIN} 2>/dev/null)"
        ${TEST_BIN} -z "${_sofins_installing}" && _sofins_installing="0"
        _jobs_in_parallel="NO"
        if [ ${_sofins_installing} -gt 1 ]; then
            note "Found: $(distinct n ${_sofins_installing}) running Sofin instances. Parallel jobs not allowed"
            _jobs_in_parallel="YES"
        else
            note "Parallel jobs allowed. Traversing several datasets at once.."
        fi

        # Create a dataset for any existing dirs in Services dir that are not ZFS datasets.
        _all_soft="$(${FIND_BIN} ${SERVICES_DIR} -mindepth 1 -maxdepth 1 -type d -not -name '.*' -print 2>/dev/null | ${XARGS_BIN} ${BASENAME_BIN} 2>/dev/null)"
        debug "Checking for non-dataset directories in $(distinct d ${SERVICES_DIR}): EOF:\n$(echo "${_all_soft}" | eval "${NEWLINES_TO_SPACES_GUARD}")\nEOF\n"
        _full_bundname="$(${BASENAME_BIN} "${PREFIX}" 2>/dev/null)"
        for _maybe_dataset in ${_all_soft}; do
            _aname="$(lowercase ${_full_bundname})"
            _app_name_lowercase="$(lowercase ${_maybe_dataset})"
            if [ "${_app_name_lowercase}" = "${_aname}" -o ${_jobs_in_parallel} = "NO" ]; then
                # find name of mount from default ZFS Services:
                _inner_dir=""
                if [ "${USER}" = "root" ]; then
                    _inner_dir="root/"
                else
                    # NOTE: In ServeD-OS there's only 1 inner dir name that's also the cell name
                    no_ending_slash="$(echo "${SERVICES_DIR}" | ${SED_BIN} 's/\/$//' 2>/dev/null)"
                    _inner_dir="$(${ZFS_BIN} list -H 2>/dev/null | ${EGREP_BIN} "${no_ending_slash}$" 2>/dev/null | ${AWK_BIN} '{print $1;}' 2>/dev/null | ${SED_BIN} 's/.*\///' 2>/dev/null)/"
                    if [ -z "${_inner_dir}" ]; then
                        warn "Falling back with inner dir name to current user name: ${USER}/"
                        _inner_dir="${USER}/"
                    fi
                fi
                _certain_dataset="${SERVICES_DIR}${_inner_dir}${_maybe_dataset}"
                certain_fileset="${SERVICES_DIR}${_maybe_dataset}"
                _full_dataset_name="${DEFAULT_ZPOOL}${_certain_dataset}"
                _snap_file="${_maybe_dataset}-${DEF_VERSION}.${SERVICE_SNAPSHOT_POSTFIX}"
                _final_snap_file="${_snap_file}${DEFAULT_ARCHIVE_EXT}"

                # check dataset existence and create/receive it if necessary
                ds_mounted="$(${ZFS_BIN} get -H -o value mounted ${_full_dataset_name} 2>/dev/null)"
                debug "Dataset: $(distinct d ${_full_dataset_name}) is mounted?: $(distinct d ${ds_mounted})"
                if [ "${ds_mounted}" != "yes" ]; then # XXX: rewrite this.. THING below -__
                    debug "Moving $(distinct d ${certain_fileset}) to $(distinct d ${certain_fileset}-tmp)"
                    ${RM_BIN} -f "${certain_fileset}-tmp" >> ${LOG} 2>> ${LOG}
                    ${MV_BIN} -f "${certain_fileset}" "${certain_fileset}-tmp"
                    debug "Creating dataset: $(distinct d ${_full_dataset_name})"
                    create_or_receive "${_full_dataset_name}" "${_final_snap_file}"
                    debug "Copying $(distinct d "${certain_fileset}-tmp/") back to $(distinct d ${certain_fileset})"
                    ${CP_BIN} -RP "${certain_fileset}-tmp/" "${certain_fileset}"
                    debug "Cleaning $(distinct d "${certain_fileset}-tmp/")"
                    ${RM_BIN} -rf "${certain_fileset}-tmp"
                    debug "Dataset created: $(distinct d ${_full_dataset_name})"
                fi

            else # no name match
                debug "No match for: $(distinct d ${_app_name_lowercase})"
            fi
        done
    fi
}
