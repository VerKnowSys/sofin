
build_software_bundle () {
    _bsbname="${1}"
    _bsbelement="${2}"
    if [ ! -e "./${_bsbname}" ]; then
        ${PRINTF_BIN} "${blue}"
        ${TAR_BIN} -cJ --totals --use-compress-program="${XZ_BIN} --threads=${CPUS}" -f "${_bsbname}" "./${_bsbelement}" && \
            note "Bundle archive of: $(distinct n ${_bsbelement}) (using: $(distinct n ${CPUS}) threads) has been built." && \
            return
        ${PRINTF_BIN} "${blue}"
        ${TAR_BIN} --totals -cJf "${_bsbname}" "./${_bsbelement}" && \
            note "Bundle archive of: $(distinct n ${_bsbelement}) has been built." && \
            return
        error "Failed to create archives for: $(distinct e ${_bsbelement})"
    else
        if [ ! -e "./${_bsbname}${DEFAULT_CHKSUM_EXT}" ]; then
            debug "Found sha-less archive. It may be incomplete or damaged. Rebuilding.."
            ${RM_BIN} -vf "${_bsbname}" >> ${LOG} 2>> ${LOG}
            ${PRINTF_BIN} "${blue}"
            ${TAR_BIN} --totals -cJ --use-compress-program="${XZ_BIN} --threads=${CPUS}" -f "${_bsbname}" "./${_bsbelement}" || \
                ${TAR_BIN} --totals -cJf "${_bsbname}" "./${_bsbelement}" || \
                error "Failed to create archives for: $(distinct e ${_bsbelement})"
            note "Archived bundle: $(distinct n "${_bsbelement}") is ready to deploy"
        else
            note "Archived bundle: $(distinct n "${_bsbelement}") already exists, and will be reused to deploy"
        fi
    fi
    unset _bsbname _bsbelement
}


push_binbuild () {
    _push_bundles="$*"
    if [ -z "${_push_bundles}" ]; then
        error "push_binbuild(): Arguments cannot be empty!"
    fi
    create_cache_directories
    note "Pushing binary bundle: $(distinct n ${_push_bundles}) to remote: $(distinct n ${MAIN_BINARY_REPOSITORY})"
    cd "${SOFTWARE_DIR}"
    for _pbelement in ${_push_bundles}; do
        _lowercase_element="$(lowercase "${_pbelement}")"
        if [ -z "${_lowercase_element}" ]; then
            error "push_binbuild(): _lowercase_element is empty!"
        fi
        _install_indicator_file="${SOFTWARE_DIR}${_pbelement}/${_lowercase_element}${INSTALLED_MARK}"
        _version_element="$(${CAT_BIN} "${_install_indicator_file}" 2>/dev/null)"
        if [ ! -f "${_install_indicator_file}" ]; then
            error "push_binbuild(): _install_indicator_file: $(distinct e "${_install_indicator_file}") doesn't exists! You can't push a binary build of uncomplete build!"
        fi
        if [ -d "${_pbelement}" -a \
             -f "${_install_indicator_file}" -a \
             ! -z "${_version_element}" ]; then
            if [ ! -L "${_pbelement}" ]; then
                if [ -z "${_version_element}" ]; then
                    error "No version information available for bundle: $(distinct e "${_pbelement}")"
                fi
                _element_name="${_pbelement}-${_version_element}${DEFAULT_ARCHIVE_EXT}"
                debug "element: $(distinct d ${_pbelement}) -> name: $(distinct d ${_element_name})"
                _def_dig_query="$(${HOST_BIN} A ${MAIN_SOFTWARE_ADDRESS} 2>/dev/null | ${GREP_BIN} 'Address:' 2>/dev/null | eval "${HOST_ADDRESS_GUARD}")"

                if [ -z "${_def_dig_query}" ]; then
                    error "No mirrors found in address: $(distinct e ${MAIN_SOFTWARE_ADDRESS})"
                fi
                debug "Using defined mirror(s): $(distinct d "${_def_dig_query}")"
                for _mirror in ${_def_dig_query}; do
                    _address="${MAIN_USER}@${_mirror}:${SYS_SPECIFIC_BINARY_REMOTE}"
                    ${PRINTF_BIN} "${blue}"
                    ${SSH_BIN} ${DEFAULT_SSH_OPTS} -p "${MAIN_PORT}" "${MAIN_USER}@${_mirror}" \
                        "${MKDIR_BIN} -p ${SYS_SPECIFIC_BINARY_REMOTE}"

                    if [ "${SYSTEM_NAME}" = "FreeBSD" ]; then # NOTE: feature designed for FBSD.
                        _svcs_no_slashes="$(echo "${SERVICES_DIR}" | ${SED_BIN} 's/\///g' 2>/dev/null)"
                        _inner_dir="$(${ZFS_BIN} list -H 2>/dev/null | ${GREP_BIN} "${_pbelement}$" 2>/dev/null | ${AWK_BIN} '{print $1;}' 2>/dev/null | ${SED_BIN} "s/.*${_svcs_no_slashes}\///; s/\/.*//" 2>/dev/null)/"
                        _certain_dataset="${SERVICES_DIR}${_inner_dir}${_pbelement}"
                        _full_dataset_name="${DEFAULT_ZPOOL}${_certain_dataset}"
                        _snap_file="${_pbelement}-${_version_element}.${SERVICE_SNAPSHOT_POSTFIX}"
                        _final_snap_file="${_snap_file}${DEFAULT_ARCHIVE_EXT}"
                        _snap_size="0"
                        note "Preparing service dataset: $(distinct n ${_full_dataset_name}), for bundle: $(distinct n ${_pbelement})"
                        ${ZFS_BIN} list -H 2>/dev/null | ${GREP_BIN} "${_pbelement}\$" >/dev/null 2>&1
                        if [ "$?" = "0" ]; then # if dataset exists, unmount it, send to file, and remount back
                            ${PRINTF_BIN} "${blue}"
                            try "${ZFS_BIN} umount ${_full_dataset_name}" || \
                                error "ZFS umount failed for: $(distinct e "${_full_dataset_name}"). Dataset shouldn't be locked nor used on build hosts."
                            ${ZFS_BIN} send "${_full_dataset_name}" \
                                | ${XZ_BIN} > "${_final_snap_file}" 2>> "${LOG}-${_lowercase_element}" && \
                                    _snap_size="$(file_size "${_final_snap_file}")" && \
                                    try "${ZFS_BIN} mount ${_full_dataset_name}"
                        fi
                        if [ "${_snap_size}" = "0" ]; then
                            ${RM_BIN} -vf "${_final_snap_file}" >> "${LOG}-${_lowercase_element}" 2>> "${LOG}-${_lowercase_element}"
                            note "Service dataset has no contents for bundle: $(distinct n ${_pbelement}-${_version_element}), hence upload will be skipped"
                        fi
                    fi

                    build_software_bundle "${_element_name}" "${_pbelement}"
                    store_checksum_bundle "${_element_name}"

                    try "${CHMOD_BIN} -v o+r ${_element_name} ${_element_name}${DEFAULT_CHKSUM_EXT}" && \
                        debug "Set read access for archives: $(distinct d ${_element_name}), $(distinct d ${_element_name}${DEFAULT_CHKSUM_EXT}) before we send them to public remote"

                    _bin_bundle="${BINBUILDS_CACHE_DIR}${_pbelement}-${_version_element}"
                    debug "Performing a copy of binary bundle to: $(distinct d ${_bin_bundle})"
                    ${MKDIR_BIN} -p ${_bin_bundle} >/dev/null 2>&1
                    run "${CP_BIN} -v ${_element_name} ${_bin_bundle}/"
                    run "${CP_BIN} -v ${_element_name}${DEFAULT_CHKSUM_EXT} ${_bin_bundle}/"

                    push_binary_archive "${_bin_bundle}" "${_element_name}" "${_mirror}" "${_address}"
                    push_service_stream_archive "${_final_snap_file}" "${_pbelement}" "${_mirror}"

                done
                ${RM_BIN} -f "${_element_name}" "${_element_name}${DEFAULT_CHKSUM_EXT}" "${_final_snap_file}" >> ${LOG}-${_lowercase_element} 2>> ${LOG}-${_lowercase_element}
            fi
        else
            warn "No version file of software: $(distinct w ${_pbelement}) found! It seems to not be fully installed or broken."
        fi
    done
}


deploy_binbuild () {
    _dbbundles=$*
    create_cache_directories
    load_defaults
    note "Software bundles to be built and deployed to remote: $(distinct n ${_dbbundles})"
    for _dbbundle in ${_dbbundles}; do
        USE_BINBUILD=NO
        build_all "${_dbbundle}" || \
            def_error "${_dbbundle}" "Bundle build failed."
    done
    push_binbuild ${_dbbundles} || \
        def_error "${_dbbundle}" "Push failure"
    note "Software bundle deployed successfully: $(distinct n ${_dbbundle})"
    note "$(fill)"
    unset _dbbundles _dbbundle
}


rebuild_bundle () {
    create_cache_directories
    _a_dependency="$(lowercase "${2}")"
    if [ -z "${_a_dependency}" ]; then
        error "Missing second argument with library/software name."
    fi
    # go to definitions dir, and gather software list that include given _a_dependency:
    _alldefs_avail="$(${FIND_BIN} ${DEFINITIONS_DIR} -maxdepth 1 -type f -name "*${DEFAULT_DEF_EXT}" 2>/dev/null)"
    _those_to_rebuild=""
    for _dep in ${_alldefs_avail}; do
        load_defaults
        load_defs "${_dep}"
        echo "${DEF_REQUIREMENTS}" | ${GREP_BIN} "${_a_dependency}" >/dev/null 2>&1
        if [ "$?" = "0" ]; then
            _idep="$(${BASENAME_BIN} "${_dep}" 2>/dev/null)"
            _irawname="$(${PRINTF_BIN} "${_idep}" | ${SED_BIN} "s/${DEFAULT_DEF_EXT}//g" 2>/dev/null)"
            _an_def_nam="$(capitalize "${_irawname}")"
            _those_to_rebuild="${_an_def_nam} ${_those_to_rebuild}"
        fi
    done

    note "Will rebuild, wipe and push these bundles: $(distinct n ${_those_to_rebuild})"
    for _reb_ap_bundle in ${_those_to_rebuild}; do
        if [ "${_reb_ap_bundle}" = "Git" -o "${_reb_ap_bundle}" = "Zsh" ]; then
            continue
        fi
        remove_bundles "${_reb_ap_bundle}"
        USE_BINBUILD=NO
        build_all "${_reb_ap_bundle}" || def_error "${_reb_ap_bundle}" "Bundle build failed."
        USE_FORCE=YES
        wipe_remote_archives ${_reb_ap_bundle} || def_error "${_reb_ap_bundle}" "Wipe failed"
        push_binbuild ${_reb_ap_bundle} || def_error "${_reb_ap_bundle}" "Push failure"
    done
    unset _reb_ap_bundle _those_to_rebuild _a_dependency _dep _alldefs_avail _idep _irawname _an_def_nam
}


try_fetch_binbuild () {
    _full_name="${1}"
    _bbaname="${2}"
    _bb_archive="${3}"
    if [ ! -z "${USE_BINBUILD}" ]; then
        debug "Binary build check was skipped"
    else
        _bbaname="$(lowercase "${_bbaname}")"
        if [ -z "${_bbaname}" ]; then
            error "Cannot fetch binbuild! An empty definition name given!"
        fi
        if [ -z "${_bb_archive}" ]; then
            error "Cannot fetch binbuild! An empty archive name given!"
        fi
        _full_name="$(capitalize "${_full_name}")"
        if [ ! -e "${BINBUILDS_CACHE_DIR}${_full_name}/${_bb_archive}" ]; then
            cd ${BINBUILDS_CACHE_DIR}${_full_name}
            try "${FETCH_BIN} ${FETCH_OPTS} '${MAIN_BINARY_REPOSITORY}${OS_TRIPPLE}/${_bb_archive}${DEFAULT_CHKSUM_EXT}'" || \
                try "${FETCH_BIN} ${FETCH_OPTS} '${MAIN_BINARY_REPOSITORY}${OS_TRIPPLE}/${_bb_archive}${DEFAULT_CHKSUM_EXT}'"
            if [ "$?" = "0" ]; then
                try "${FETCH_BIN} ${FETCH_OPTS} '${MAIN_BINARY_REPOSITORY}${OS_TRIPPLE}/${_bb_archive}'" || \
                    try "${FETCH_BIN} ${FETCH_OPTS} '${MAIN_BINARY_REPOSITORY}${OS_TRIPPLE}/${_bb_archive}'" || \
                    try "${FETCH_BIN} ${FETCH_OPTS} '${MAIN_BINARY_REPOSITORY}${OS_TRIPPLE}/${_bb_archive}'" || \
                    error "Failure fetching available binary build for: $(distinct e "${_bb_archive}"). Please check your DNS / Network setup!"
            else
                note "No binary build available for: $(distinct n ${OS_TRIPPLE}/${DEF_NAME}${DEF_POSTFIX}-${DEF_VERSION})"
            fi
        fi

        cd "${SOFTWARE_DIR}"
        debug "_bb_archive: $(distinct d ${_bb_archive}). Expecting binbuild to be available in: $(distinct d ${BINBUILDS_CACHE_DIR}${_full_name}/${_bb_archive})"

        # validate binary build:
        if [ -e "${BINBUILDS_CACHE_DIR}${_full_name}/${_bb_archive}" ]; then
            validate_archive_sha1 "${BINBUILDS_CACHE_DIR}${_full_name}/${_bb_archive}"
        fi

        # after sha1 validation we may continue with binary build if file still exists
        if [ -e "${BINBUILDS_CACHE_DIR}${_full_name}/${_bb_archive}" ]; then
            ${TAR_BIN} -xJf "${BINBUILDS_CACHE_DIR}${_full_name}/${_bb_archive}" >> "${LOG}-${_bbaname}" 2>> "${LOG}-${_bbaname}"
            if [ "$?" = "0" ]; then # if archive is valid
                note "Software bundle installed: $(distinct n ${DEF_NAME}${DEF_POSTFIX}), with version: $(distinct n ${DEF_VERSION})"
                DONT_BUILD_BUT_DO_EXPORTS=YES
            else
                debug "  ${NOTE_CHAR} No binary bundle available for: $(distinct n ${DEF_NAME}${DEF_POSTFIX})"
                ${RM_BIN} -fr "${BINBUILDS_CACHE_DIR}${_full_name}"
            fi
        else
            debug "Binary build checksum doesn't match for: $(distinct n ${_full_name})"
        fi
    fi
}


build_all () {
    _build_list=$*

    # Update definitions and perform more checks
    check_requirements

    PATH="${DEFAULT_PATH}"
    for _bund_name in ${_build_list}; do
        _specified="${_bund_name}" # store original value of user input
        _bund_name="$(lowercase "${_bund_name}")"
        load_defaults
        validate_alternatives "${_bund_name}"
        load_defs "${_bund_name}" # prevent installation of requirements of disabled _defname:
        check_disabled "${DEF_DISABLE_ON}" # after which just check if it's not disabled
        _pref_base="$(${BASENAME_BIN} "${PREFIX}" 2>/dev/null)"
        if [ "${DEFINITION_DISABLED}" = "YES" -a \
             ! -z "${_pref_base}" -a \
             "/" != "${_pref_base}" ]; then
            warn "Bundle: $(distinct w ${_bund_name}) disabled on: $(distinct w "${OS_TRIPPLE}")"
            ${RM_BIN} -rf "${PREFIX}" >> ${LOG} 2>> ${LOG}
            unset _pref_base
        else
            unset _pref_base
            for _req_name in ${DEFINITIONS_DIR}${_bund_name}${DEFAULT_DEF_EXT}; do
                unset DONT_BUILD_BUT_DO_EXPORTS
                debug "Reading definition: $(distinct d ${_req_name})"
                load_defaults
                load_defs "${_req_name}"
                if [ -z "${DEF_REQUIREMENTS}" ]; then
                    debug "No app requirements"
                else
                    pretouch_logs ${DEF_REQUIREMENTS}
                fi
                check_disabled "${DEF_DISABLE_ON}" # after which just check if it's not disabled

                # Note: this acutally may break definitions like ImageMagick..
                #_common_lowercase="$(lowercase "${DEF_NAME}${DEF_POSTFIX}")"
                _common_lowercase="${DEF_NAME}${DEF_POSTFIX}"
                DEF_NAME="$(capitalize ${_common_lowercase})"

                # some additional convention check:
                if [ "${DEF_NAME}" != "${_specified}" -a \
                     "${_common_lowercase}" != "${_specified}" ]; then
                    warn "You specified lowercase name of bundle: $(distinct w ${_specified}), which is in contradiction to Sofin's convention (bundle - capitalized: f.e. 'Rust', dependencies and definitions - lowercase: f.e. 'yaml')."
                fi
                # if definition requires root privileges, throw an "exception":
                if [ ! -z "${REQUIRE_ROOT_ACCESS}" ]; then
                    if [ "${USERNAME}" != "root" ]; then
                        error "Definition requires superuser priviledges: $(distinct e ${_common_lowercase}). Installation aborted."
                    fi
                fi

                export PREFIX="${SOFTWARE_DIR}$(capitalize "${_common_lowercase}")"
                export SERVICE_DIR="${SERVICES_DIR}${_common_lowercase}"
                if [ ! -z "${DEF_STANDALONE}" ]; then
                    ${MKDIR_BIN} -p "${SERVICE_DIR}"
                    ${CHMOD_BIN} 0710 "${SERVICE_DIR}"
                fi

                # binary build of whole software bundle
                _full_bund_name="${_common_lowercase}-${DEF_VERSION}"
                ${MKDIR_BIN} -p "${BINBUILDS_CACHE_DIR}${_full_bund_name}" >/dev/null 2>&1

                _an_archive="$(capitalize "${_common_lowercase}")-${DEF_VERSION}${DEFAULT_ARCHIVE_EXT}"
                INSTALLED_INDICATOR="${PREFIX}/${_common_lowercase}${INSTALLED_MARK}"

                if [ "${SOFIN_CONTINUE_BUILD}" = "YES" ]; then # normal build by default
                    note "Continuing build in: $(distinct n ${PREVIOUS_BUILD_DIR})"
                    cd "${PREVIOUS_BUILD_DIR}"
                else
                    if [ ! -e "${INSTALLED_INDICATOR}" ]; then
                        try_fetch_binbuild "${_full_bund_name}" "${_common_lowercase}" "${_an_archive}"
                    else
                        _already_installed_version="$(${CAT_BIN} ${INSTALLED_INDICATOR} 2>/dev/null)"
                        if [ "${DEF_VERSION}" = "${_already_installed_version}" ]; then
                            debug "$(distinct d ${_common_lowercase}) bundle is installed with version: $(distinct d ${_already_installed_version})"
                        else
                            warn "$(distinct w ${_common_lowercase}) bundle is installed with version: $(distinct w ${_already_installed_version}), different from defined: $(distinct w "${DEF_VERSION}")"
                        fi
                        DONT_BUILD_BUT_DO_EXPORTS=YES
                        unset _already_installed_version
                    fi
                fi

                if [ -z "${DONT_BUILD_BUT_DO_EXPORTS}" ]; then
                    if [ -z "${DEF_REQUIREMENTS}" ]; then
                        note "Installing: $(distinct n ${DEF_FULL_NAME}), version: $(distinct n ${DEF_VERSION})"
                    else
                        note "Installing: $(distinct n ${DEF_FULL_NAME}), version: $(distinct n ${DEF_VERSION}), with requirements: $(distinct n ${DEF_REQUIREMENTS})"
                    fi
                    _req_amount="$(${PRINTF_BIN} "${DEF_REQUIREMENTS}" | ${WC_BIN} -w 2>/dev/null | ${AWK_BIN} '{print $1;}' 2>/dev/null)"
                    _req_amount="$(${PRINTF_BIN} "${_req_amount} + 1\n" | ${BC_BIN} 2>/dev/null)"
                    _req_all="${_req_amount}"
                    for _req in ${DEF_REQUIREMENTS}; do
                        if [ ! -z "${DEF_USER_INFO}" ]; then
                            warn "${DEF_USER_INFO}"
                        fi
                        if [ -z "${_req}" ]; then
                            note "No additional requirements defined"
                            break
                        else
                            note "  ${_req} ($(distinct n ${_req_amount}) of $(distinct n ${_req_all}) remaining)"
                            if [ ! -e "${PREFIX}/${_req}${INSTALLED_MARK}" ]; then
                                export CHANGED=YES
                                execute_process "${_req}"
                            fi
                        fi
                        export _req_amount="$(${PRINTF_BIN} "${_req_amount} - 1\n" | ${BC_BIN} 2>/dev/null)"
                    done
                fi

                if [ -z "${DONT_BUILD_BUT_DO_EXPORTS}" ]; then
                    if [ -e "${PREFIX}/${_common_lowercase}${INSTALLED_MARK}" ]; then
                        if [ "${CHANGED}" = "YES" ]; then
                            note "  ${_common_lowercase} ($(distinct n 1) of $(distinct n ${_req_all}))"
                            note "   ${NOTE_CHAR} App dependencies changed. Rebuilding: $(distinct n ${_common_lowercase})"
                            execute_process "${_common_lowercase}"
                            unset CHANGED
                            mark "${DEF_NAME}${DEF_POSTFIX}" "${DEF_VERSION}"
                            show_done
                        else
                            note "  ${_common_lowercase} ($(distinct n 1) of $(distinct n ${_req_all}))"
                            show_done
                            debug "${SUCCESS_CHAR} $(distinct d ${_common_lowercase}) current: $(distinct d ${_version_element}), definition: [$(distinct d ${DEF_VERSION})] Ok."
                        fi
                    else
                        note "  ${_common_lowercase} ($(distinct n 1) of $(distinct n ${_req_all}))"
                        debug "Right before execute_process call: ${_common_lowercase}"
                        execute_process "${_common_lowercase}"
                        mark "${DEF_NAME}${DEF_POSTFIX}" "${DEF_VERSION}"
                        note "${SUCCESS_CHAR} ${_common_lowercase} [$(distinct n ${DEF_VERSION})]\n"
                    fi
                fi

                export_binaries "${_common_lowercase}"
            done

            after_export_callback

            clean_useless
            strip_bundle_files "${_common_lowercase}"
            manage_datasets
            create_apple_bundle_if_necessary
        fi
    done
    update_shell_vars
    unset _build_list _common_lowercase _req_all _req
}


dump_debug_info () {
    debug "-------------- PRE CONFIGURE SETTINGS DUMP --------------"
    debug "CPUS (used): $(distinct d ${CPUS})"
    debug "ALL_CPUS: $(distinct d ${ALL_CPUS})"
    debug "MAKE_OPTS: $(distinct d ${MAKE_OPTS})"
    debug "FETCH_OPTS: $(distinct d ${FETCH_OPTS})"
    debug "PREFIX: $(distinct d ${PREFIX})"
    debug "SERVICE_DIR: $(distinct d ${SERVICE_DIR})"
    debug "CURRENT_DIR: $(distinct d $(${PWD_BIN} 2>/dev/null))"
    debug "BUILD_DIR_ROOT: $(distinct d ${BUILD_DIR_ROOT})"
    debug "BUILD_DIR: $(distinct d ${BUILD_DIR})"
    debug "PATH: $(distinct d ${PATH})"
    debug "CC: $(distinct d ${CC})"
    debug "CXX: $(distinct d ${CXX})"
    debug "CPP: $(distinct d ${CPP})"
    debug "CXXFLAGS: $(distinct d ${CXXFLAGS})"
    debug "CFLAGS: $(distinct d ${CFLAGS})"
    debug "LDFLAGS: $(distinct d ${LDFLAGS})"
    debug "LD_LIBRARY_PATH: $(distinct d ${LD_LIBRARY_PATH})"
    debug "-------------- PRE CONFIGURE SETTINGS DUMP ENDS ---------"
}


push_binary_archive () {
    _bpbundle_file="${1}"
    _uniqname="${2}"
    _bpamirror="${3}"
    _bpaddress="${4}"
    _bpshortsha="$(${CAT_BIN} "${_uniqname}${DEFAULT_CHKSUM_EXT}" 2>/dev/null | ${CUT_BIN} -c -16 2>/dev/null)…"
    note "Pushing archive sha1: $(distinct n ${_bpshortsha}) to remote.."
    debug "name: $(distinct d ${_uniqname}), bundle_file: $(distinct d ${_bpbundle_file}), repository address: $(distinct d ${_bpaddress})"
    retry "${SCP_BIN} ${DEFAULT_SSH_OPTS} ${DEFAULT_SCP_OPTS} -P ${MAIN_PORT} ${_uniqname} ${_bpaddress}/${_uniqname}.partial" || \
        def_error "${_uniqname}" "Unable to push: $(distinct e "${_bpbundle_file}") bundle to: $(distinct e "${_bpaddress}/${_bpbundle_file}")"
    if [ "$?" = "0" ]; then
        ${PRINTF_BIN} "${blue}"
        ${SSH_BIN} ${DEFAULT_SSH_OPTS} -p ${MAIN_PORT} ${MAIN_USER}@${_bpamirror} \
            "cd ${SYS_SPECIFIC_BINARY_REMOTE} && ${MV_BIN} ${_uniqname}.partial ${_uniqname}"
        retry "${SCP_BIN} ${DEFAULT_SSH_OPTS} ${DEFAULT_SCP_OPTS} -P ${MAIN_PORT} ${_uniqname}${DEFAULT_CHKSUM_EXT} ${_bpaddress}/${_uniqname}${DEFAULT_CHKSUM_EXT}" || \
            def_error ${_uniqname}${DEFAULT_CHKSUM_EXT} "Error sending: $(distinct e ${_uniqname}${DEFAULT_CHKSUM_EXT}) file to: $(distinct e "${_bpaddress}/${_bpbundle_file}")"
    else
        error "Failed to push binary build of: $(distinct e ${_uniqname}) to remote: $(distinct e ${MAIN_BINARY_REPOSITORY}${OS_TRIPPLE}/${_uniqname})"
    fi
    unset _bpbundle_file _uniqname _bpamirror _bpaddress _bpshortsha
}


push_service_stream_archive () {
    _fin_snapfile="${1}"
    _pselement="${2}"
    _psmirror="${3}"
    if [ "${SYSTEM_NAME}" = "FreeBSD" ]; then # NOTE: feature designed for FBSD.
        if [ -f "${_fin_snapfile}" ]; then
            ${PRINTF_BIN} "${blue}"
            ${SSH_BIN} ${DEFAULT_SSH_OPTS} -p ${MAIN_PORT} "${MAIN_USER}@${_psmirror}" \
                "cd ${MAIN_BINARY_PREFIX}; ${MKDIR_BIN} -p ${MAIN_COMMON_NAME} ; ${CHMOD_BIN} 755 ${MAIN_COMMON_NAME}"

            debug "Setting common access to archive files before we send it: $(distinct d ${_fin_snapfile})"
            ${CHMOD_BIN} -v a+r "${_fin_snapfile}" >> ${LOG} 2>> ${LOG}
            debug "Sending initial service stream to $(distinct d ${MAIN_COMMON_NAME}) repository: $(distinct d ${MAIN_COMMON_REPOSITORY}/${_fin_snapfile})"

            retry "${SCP_BIN} ${DEFAULT_SSH_OPTS} ${DEFAULT_SCP_OPTS} -P ${MAIN_PORT} ${_fin_snapfile} ${MAIN_USER}@${_psmirror}:${COMMON_BINARY_REMOTE}/${_fin_snapfile}.partial"
            if [ "$?" = "0" ]; then
                ${PRINTF_BIN} "${blue}"
                ${SSH_BIN} ${DEFAULT_SSH_OPTS} -p ${MAIN_PORT} "${MAIN_USER}@${_psmirror}" \
                    "cd ${COMMON_BINARY_REMOTE} && ${MV_BIN} ${_fin_snapfile}.partial ${_fin_snapfile}"
            else
                error "Failed to send service snapshot archive file: $(distinct e "${_fin_snapfile}") to remote host: $(distinct e "${MAIN_USER}@${_psmirror}")!"
            fi
        else
            note "No service stream available for: $(distinct n ${_pselement})"
        fi
    fi
    unset _psmirror _pselement _fin_snapfile
}
