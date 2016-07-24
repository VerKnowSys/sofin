
build_bundle () {
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
    create_dirs
    note "Pushing binary bundle: $(distinct n ${_push_bundles}) to remote: $(distinct n ${MAIN_BINARY_REPOSITORY})"
    cd "${SOFTWARE_DIR}"
    for _pbelement in ${_push_bundles}; do
        _lowercase_element="$(lowercase "${_pbelement}")"
        if [ -z "${_lowercase_element}" ]; then
            error "push_binbuild(): _lowercase_element is empty!"
        fi
        _install_indicator_file="${SOFTWARE_DIR}${_pbelement}/${_lowercase_element}${DEFAULT_INST_MARK_EXT}"
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
                prepare_service_dataset "${_pbelement}"
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

                    build_bundle "${_element_name}" "${_pbelement}"
                    store_checksum "${_element_name}"

                    try "${CHMOD_BIN} -v o+r ${_element_name} ${_element_name}${DEFAULT_CHKSUM_EXT}" && \
                        debug "Set read access for archives: $(distinct d ${_element_name}), $(distinct d ${_element_name}${DEFAULT_CHKSUM_EXT}) before we send them to public remote"

                    _bin_bundle="${BINBUILDS_CACHE_DIR}${_pbelement}-${_version_element}"
                    debug "Performing a copy of binary bundle to: $(distinct d ${_bin_bundle})"
                    ${MKDIR_BIN} -p ${_bin_bundle} >/dev/null 2>&1
                    run "${CP_BIN} -v ${_element_name} ${_bin_bundle}/"
                    run "${CP_BIN} -v ${_element_name}${DEFAULT_CHKSUM_EXT} ${_bin_bundle}/"

                    push_binary_archive "${_bin_bundle}" "${_element_name}" "${_mirror}" "${_address}"
                    push_zfs_stream "${_final_snap_file}" "${_pbelement}" "${_mirror}"

                done
                # ${RM_BIN} -f "${_element_name}" "${_element_name}${DEFAULT_CHKSUM_EXT}" "${FILE_CACHE_DIR}${_final_snap_file}" >> ${LOG}-${_lowercase_element} 2>> ${LOG}-${_lowercase_element}
            fi
        else
            warn "No version file of software: $(distinct w ${_pbelement}) found! It seems to not be fully installed or broken."
        fi
    done
}


deploy_binbuild () {
    _dbbundles=$*
    create_dirs
    load_defaults
    note "Software bundles to be built and deployed to remote: $(distinct n ${_dbbundles})"
    for _dbbundle in ${_dbbundles}; do
        USE_BINBUILD=NO
        build "${_dbbundle}" || \
            def_error "${_dbbundle}" "Bundle build failed."
    done
    push_binbuild ${_dbbundles} || \
        def_error "${_dbbundle}" "Push failure"
    note "Software bundle deployed successfully: $(distinct n ${_dbbundle})"
    note "$(fill)"
    unset _dbbundles _dbbundle
}


rebuild_bundle () {
    create_dirs
    _a_dependency="$(lowercase "${1}")"
    if [ -z "${_a_dependency}" ]; then
        error "Missing second argument with library/software name."
    fi
    # go to definitions dir, and gather software list that include given _a_dependency:
    _alldefs_avail="$(${FIND_BIN} ${DEFINITIONS_DIR} -maxdepth 1 -type f -name "*${DEFAULT_DEF_EXT}" 2>/dev/null)"
    _those_to_rebuild=""
    for _dep in ${_alldefs_avail}; do
        load_defaults
        . "${_dep}"
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
        build "${_reb_ap_bundle}" || def_error "${_reb_ap_bundle}" "Bundle build failed."
        USE_FORCE=YES
        wipe_remote_archives ${_reb_ap_bundle} || def_error "${_reb_ap_bundle}" "Wipe failed"
        push_binbuild ${_reb_ap_bundle} || def_error "${_reb_ap_bundle}" "Push failure"
    done
    unset _reb_ap_bundle _those_to_rebuild _a_dependency _dep _alldefs_avail _idep _irawname _an_def_nam
}


fetch_binbuild () {
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
            ${MKDIR_BIN} -p "${BINBUILDS_CACHE_DIR}${_full_name}" 2>/dev/null
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
                note "Software bundle installed: $(distinct n "${DEF_NAME}"), with version: $(distinct n "${DEF_VERSION}")"
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


build () {
    _build_list=$*

    # Update definitions and perform more checks
    validate_reqs

    store_security_state
    disable_security_features

    PATH="${DEFAULT_PATH}"
    for _bund_name in ${_build_list}; do
        _specified="${_bund_name}" # store original value of user input
        _bund_name="$(lowercase "${_bund_name}")"
        load_defaults
        load_defs "${_bund_name}"
        _pref_base="$(${BASENAME_BIN} "${PREFIX}" 2>/dev/null)"
        if [ "${DEF_DISABLED}" = "YES" ]; then
            _anm="$(capitalize "${_bund_name}")"
            warn "Bundle: $(distinct w "${_anm}") is disabled on: $(distinct w "${OS_TRIPPLE}")"
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

                # Note: this acutally may break definitions like ImageMagick..
                #_common_lowercase="$(lowercase "${DEF_NAME}${DEF_POSTFIX}")"
                _common_lowercase="${DEF_NAME}${DEF_POSTFIX}"
                DEF_NAME="$(capitalize "${_common_lowercase}")"

                # if definition requires root privileges, throw an "exception":
                if [ ! -z "${DEF_REQUIRE_ROOT_ACCESS}" ]; then
                    if [ "${USER}" != "root" ]; then
                        error "Definition requires superuser priviledges: $(distinct e ${_common_lowercase}). Installation aborted."
                    fi
                fi

                PREFIX="${SOFTWARE_DIR}$(capitalize "${_common_lowercase}")"
                BUILD_DIR="${DEFAULT_BUILD_DIR}"
                BUILD_NAMESUM="$(text_checksum "${DEF_NAME}${DEF_POSTFIX}-${DEF_VERSION}")"
                BUILD_DIR_ROOT="${BUILD_DIR}/${BUILD_NAMESUM}"
                _bundl_name="$(capitalize "${_common_lowercase}")"
                SERVICE_DIR="${SERVICES_DIR}${_bundl_name}"

                if [ -z "${DEVEL}" ]; then
                    debug "Cleaning before PROD build in BUILD_DIR_ROOT: $(distinct d "${BUILD_DIR_ROOT}")"
                    ${RM_BIN} -rf "${BUILD_DIR_ROOT}" >/dev/null 2>> ${LOG}
                    ${MKDIR_BIN} -p "${BUILD_DIR_ROOT}" >/dev/null 2>> ${LOG}
                fi

                # These values has to be exported because external build mechanisms
                # has to be able to reach these values to find dependencies and utilities
                export PATH="${PREFIX}/bin:${PREFIX}/sbin:${DEFAULT_PATH}"
                export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig"

                # NOTE: standalone definition has own SERVICES_DIR/Bundlename/ prefix
                if [ -n "${DEF_STANDALONE}" ]; then

                    if [ "YES" = "${CAP_SYS_ZFS}" ]; then
                        _dsname="${DEFAULT_ZPOOL}${SERVICES_DIR}${USER}/${_bundl_name}"
                        debug "ZFS feature enabled. Creating dataset: $(distinct d "${_dsname}")"
                        run "${ZFS_BIN} create -o mountpoint=${SERVICES_DIR}${_bundl_name} ${_dsname}"
                        try "${ZFS_BIN} mount ${_dsname}"
                        unset _dsname
                    else
                        debug "No ZFS feature."
                        try "${MKDIR_BIN} -p ${SERVICE_DIR}"
                    fi
                    try "${CHMOD_BIN} 0710 ${SERVICE_DIR}"
                fi

                try "${MKDIR_BIN} -p ${BUILD_DIR_ROOT}"

                # binary build of whole software bundle
                _full_bund_name="${_common_lowercase}-${DEF_VERSION}"
                ${MKDIR_BIN} -p "${BINBUILDS_CACHE_DIR}${_full_bund_name}" >/dev/null 2>&1

                _an_archive="$(capitalize "${_common_lowercase}")-${DEF_VERSION}${DEFAULT_ARCHIVE_EXT}"
                INSTALLED_INDICATOR="${PREFIX}/${_common_lowercase}${DEFAULT_INST_MARK_EXT}"
                if [ ! -e "${INSTALLED_INDICATOR}" ]; then
                    fetch_binbuild "${_full_bund_name}" "${_common_lowercase}" "${_an_archive}"
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
                            if [ ! -e "${PREFIX}/${_req}${DEFAULT_INST_MARK_EXT}" ]; then
                                CHANGED=YES
                                process "${_req}"
                            fi
                        fi
                        _req_amount="$(${PRINTF_BIN} "${_req_amount} - 1\n" | ${BC_BIN} 2>/dev/null)"
                    done
                fi

                if [ -z "${DONT_BUILD_BUT_DO_EXPORTS}" ]; then
                    if [ -e "${PREFIX}/${_common_lowercase}${DEFAULT_INST_MARK_EXT}" ]; then
                        if [ "${CHANGED}" = "YES" ]; then
                            note "  ${_common_lowercase} ($(distinct n 1) of $(distinct n ${_req_all}))"
                            note "   ${NOTE_CHAR} App dependencies changed. Rebuilding: $(distinct n ${_common_lowercase})"
                            process "${_common_lowercase}"
                            unset CHANGED
                            mark_installed "${DEF_NAME}${DEF_POSTFIX}" "${DEF_VERSION}"
                            show_done "${DEF_NAME}${DEF_POSTFIX}"
                        else
                            note "  ${_common_lowercase} ($(distinct n 1) of $(distinct n ${_req_all}))"
                            show_done "${DEF_NAME}${DEF_POSTFIX}"
                            debug "${SUCCESS_CHAR} $(distinct d ${_common_lowercase}) current: $(distinct d ${_version_element}), definition: [$(distinct d ${DEF_VERSION})] Ok."
                        fi
                    else
                        note "  ${_common_lowercase} ($(distinct n 1) of $(distinct n ${_req_all}))"
                        debug "Right before process call: ${_common_lowercase}"
                        process "${_common_lowercase}"
                        mark_installed "${DEF_NAME}${DEF_POSTFIX}" "${DEF_VERSION}"
                        note "${SUCCESS_CHAR} ${_common_lowercase} [$(distinct n ${DEF_VERSION})]\n"
                    fi
                fi

                export_binaries "${_common_lowercase}"
            done

            after_export_callback

            clean_useless
            strip_bundle "${_common_lowercase}"
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
    debug "BUILD_NAMESUM: $(distinct d ${BUILD_NAMESUM})"
    debug "BUILD_DIR: $(distinct d ${BUILD_DIR})"
    debug "BUILD_DIR_ROOT: $(distinct d ${BUILD_DIR_ROOT})"
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


push_zfs_stream () {
    _fin_snapfile="${1}"
    _pselement="${2}"
    _psmirror="${3}"
    if [ "${SYSTEM_NAME}" = "FreeBSD" ]; then # NOTE: feature designed for FBSD.
        if [ -f "${FILE_CACHE_DIR}${_fin_snapfile}" ]; then
            ${PRINTF_BIN} "${blue}"
            ${SSH_BIN} ${DEFAULT_SSH_OPTS} -p ${MAIN_PORT} "${MAIN_USER}@${_psmirror}" \
                "${MKDIR_BIN} -p ${COMMON_BINARY_REMOTE} ; ${CHMOD_BIN} 755 ${COMMON_BINARY_REMOTE}"

            debug "Setting common access to archive files before we send it: $(distinct d ${_fin_snapfile})"
            ${CHMOD_BIN} -v a+r "${FILE_CACHE_DIR}${_fin_snapfile}" >> ${LOG} 2>> ${LOG}
            debug "Sending initial service stream to $(distinct d ${MAIN_COMMON_NAME}) repository: $(distinct d ${MAIN_COMMON_REPOSITORY}/${_fin_snapfile})"

            retry "${SCP_BIN} ${DEFAULT_SSH_OPTS} ${DEFAULT_SCP_OPTS} -P ${MAIN_PORT} ${FILE_CACHE_DIR}${_fin_snapfile} ${MAIN_USER}@${_psmirror}:${COMMON_BINARY_REMOTE}/${_fin_snapfile}.partial"
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


process () {
    _app_param="$1"
    if [ -z "${_app_param}" ]; then
        error "No param given for process()!"
    fi
    _req_definition="${DEFINITIONS_DIR}$(lowercase "${_app_param}")${DEFAULT_DEF_EXT}"
    debug "Checking requirement: $(distinct d ${_app_param}) file: $(distinct d ${_req_definition})"
    if [ ! -e "${_req_definition}" ]; then
        error "Cannot fetch definition: $(distinct e ${_req_definition})! Aborting!"
    fi

    load_defaults
    load_defs "${_req_definition}"

    compiler_setup
    dump_debug_info

    PATH="${PREFIX}/bin:${PREFIX}/sbin:${DEFAULT_PATH}"
    if [ -z "${DEF_DISABLED}" ]; then
        if [ -z "${DEF_HTTP_PATH}" ]; then
            _definition_no_ext="\
                $(echo "$(${BASENAME_BIN} ${_req_definition} 2>/dev/null)" | \
                ${SED_BIN} -e 's/\..*$//g' 2>/dev/null)"
            note "   ${NOTE_CHAR2} $(distinct n "DEF_HTTP_PATH=\"\"") is undefined for: $(distinct n "${_definition_no_ext}")."
            note "NOTE: It's only valid for meta bundles. You may consider setting: $(distinct n "DEF_CONFIGURE=\"meta\"") in bundle definition file. Type: $(distinct n "s dev ${_definition_no_ext}"))"
        else
            _cwd="$(${PWD_BIN} 2>/dev/null)"
            if [ ! -z "${BUILD_DIR_ROOT}" -a \
                 ! -z "${BUILD_DIR}" -a \
                 ! -z "${BUILD_NAMESUM}" ]; then
                ${MKDIR_BIN} -p "${BUILD_DIR_ROOT}" 2>> ${LOG}
                cd "${BUILD_DIR_ROOT}"
                if [ -z "${DEF_GIT_MODE}" ]; then # Standard http tarball method:
                    _base="$(${BASENAME_BIN} ${DEF_HTTP_PATH} 2>/dev/null)"
                    debug "DEF_HTTP_PATH: $(distinct d ${DEF_HTTP_PATH}) base: $(distinct d ${_base})"
                    if [ ! -e "${FILE_CACHE_DIR}/${_base}" ]; then
                        note "   ${NOTE_CHAR} Fetching required tarball source: $(distinct n ${_base})"
                        cd "${FILE_CACHE_DIR}"
                        retry "${FETCH_BIN} ${FETCH_OPTS} ${DEF_HTTP_PATH}" || \
                            def_error "${DEF_NAME}" "Failed to fetch source: ${DEF_HTTP_PATH}"
                    fi
                    cd "${BUILD_DIR_ROOT}"
                    _dest_file="${FILE_CACHE_DIR}/${_base}"
                    debug "Build root: $(distinct d ${BUILD_DIR_ROOT}), file: $(distinct d ${_dest_file})"
                    if [ -z "${DEF_SHA}" ]; then
                        error "Missing SHA sum for source: $(distinct e ${_dest_file})!"
                    else
                        _a_file_checksum="$(file_checksum ${_dest_file})"
                        if [ "${_a_file_checksum}" = "${DEF_SHA}" ]; then
                            debug "Source tarball checksum is fine"
                        else
                            warn "${WARN_CHAR} Source checksum mismatch: $(distinct w "${_a_file_checksum}") vs $(distinct w "${DEF_SHA}")"
                            _bname="$(${BASENAME_BIN} "${_dest_file}" 2>/dev/null)"
                            warn "${WARN_CHAR} Removing file from cache: $(distinct w "${_bname}") and retrying.."
                            # remove corrupted file
                            ${RM_BIN} -vf "${_dest_file}" >> ${LOG} 2>> ${LOG}
                            # and restart script with same arguments:
                            debug "Evaluating again: $(distinct d "process(${_app_param})")"
                            process "${_app_param}"
                        fi
                        unset _bname _a_file_checksum
                    fi

                    note "   ${NOTE_CHAR} Unpacking source tarball of: $(distinct n "${DEF_NAME}${DEF_POSTFIX}")"
                    debug "Build dir root: $(distinct d "${BUILD_DIR_ROOT}")"
                    try "${TAR_BIN} --directory ${BUILD_DIR_ROOT} -xf ${_dest_file}" || \
                    try "${TAR_BIN} --directory ${BUILD_DIR_ROOT} -xfj ${_dest_file}" || \
                    run "${TAR_BIN} --directory ${BUILD_DIR_ROOT} -xfJ ${_dest_file}"
                else
                    # git method:
                    # .cache/git-cache => git bare repos
                    ${MKDIR_BIN} -p ${GIT_CACHE_DIR}
                    _git_cached="${GIT_CACHE_DIR}${DEF_NAME}${DEF_VERSION}.git"
                    note "   ${NOTE_CHAR} Fetching git repository: $(distinct n ${DEF_HTTP_PATH}${reset})"
                    try "${GIT_BIN} clone ${DEFAULT_GIT_OPTS} --depth 1 --bare ${DEF_HTTP_PATH} ${_git_cached}" || \
                    try "${GIT_BIN} clone ${DEFAULT_GIT_OPTS} --depth 1 --bare ${DEF_HTTP_PATH} ${_git_cached}"
                    if [ "$?" = "0" ]; then
                        debug "Fetched bare repository: $(distinct d "${DEF_NAME}${DEF_VERSION}")"
                    else
                        if [ ! -d "${_git_cached}/branches" -a ! -f "${_git_cached}/config" ]; then
                            note "\n${red}Definitions were not updated. Showing $(distinct n ${LOG_LINES_AMOUNT_ON_ERR}) lines of internal log:${reset}"
                            ${TAIL_BIN} -n${LOG_LINES_AMOUNT_ON_ERR} ${LOG} 2>/dev/null
                            note "$(fill)"
                        else
                            current="$(${PWD_BIN} 2>/dev/null)"
                            debug "Trying to update existing bare repository cache in: $(distinct d ${_git_cached})"
                            cd "${_git_cached}"
                            try "${GIT_BIN} fetch ${DEFAULT_GIT_OPTS} origin ${DEF_GIT_CHECKOUT}" || \
                                try "${GIT_BIN} fetch ${DEFAULT_GIT_OPTS} origin" || \
                                warn "   ${WARN_CHAR} Failed to fetch an update from bare repository: $(distinct w ${_git_cached})"
                            # for empty DEF_VERSION it will fill it with first 16 chars of repository HEAD SHA1:
                            if [ -z "${DEF_VERSION}" ]; then
                                DEF_VERSION="$(${GIT_BIN} rev-parse HEAD 2>/dev/null | ${CUT_BIN} -c -16 2>/dev/null)"
                                debug "Set DEF_VERSION=$(distinct d ${DEF_VERSION}) - based on git commit sha"
                            fi
                            cd "${current}"
                        fi
                    fi
                    # bare repository is already cloned, so we just clone from it now..
                    run "${GIT_BIN} clone ${DEFAULT_GIT_OPTS} ${_git_cached} ${DEF_NAME}${DEF_VERSION}" && \
                    debug "Cloned git respository from git bare cache repository"
                fi

                debug "_app_param: ${_app_param}, DEF_NAME: ${DEF_NAME}, BUILD_DIR_ROOT: ${BUILD_DIR_ROOT}"
                # NOTE: patterns sorted by safety
                for _pati in "*${_app_param}*${DEF_VERSION}*" "*${_app_param}*" "*${DEF_NAME}*${DEF_VERSION}*"  "*${DEF_NAME}*${DEF_VERSION}*" "*${DEF_NAME}*" "*$(lowercase "${DEF_NAME}")*"; do
                    _fd="$(${FIND_BIN} "${BUILD_DIR_ROOT}" -maxdepth 1 -mindepth 1 -type d -iname "${_pati}" 2>/dev/null)"
                    if [ ! -z "${_fd}" ]; then
                        debug "Found build dir: $(distinct d "${_fd}"), for definition: $(distinct d "${DEF_NAME}")"
                        break
                    fi
                done
                if [ -z "${_fd}" ]; then
                    error "No source dir found for definition: $(distinct e "${_app_param}")?"
                fi
                cd "${_fd}"

                # Handle DEF_SOURCE_DIR_POSTFIX here
                if [ ! -z "${_fd}/${DEF_SOURCE_DIR_POSTFIX}" ]; then
                    ${MKDIR_BIN} -p "${_fd}/${DEF_SOURCE_DIR_POSTFIX}"
                    cd "${_fd}/${DEF_SOURCE_DIR_POSTFIX}"
                fi
                _pwd="$(${PWD_BIN} 2>/dev/null)"
                debug "Switched to build dir root: $(distinct d "${_pwd}")"

                if [ ! -z "${DEF_GIT_CHECKOUT}" ]; then
                    note "   ${NOTE_CHAR} Definition branch: $(distinct n ${DEF_GIT_CHECKOUT})"
                    _current_branch="$(${GIT_BIN} rev-parse --abbrev-ref HEAD 2>/dev/null)"
                    if [ "${_current_branch}" != "${DEF_GIT_CHECKOUT}" ]; then
                        try "${GIT_BIN} checkout ${DEFAULT_GIT_OPTS} -b ${DEF_GIT_CHECKOUT}"
                    fi
                    try "${GIT_BIN} checkout ${DEFAULT_GIT_OPTS} ${DEF_GIT_CHECKOUT}"
                fi

                after_update_callback

                _pcpaname="$(lowercase "${DEF_NAME}${DEF_POSTFIX}")"
                _pcpatch_dir="${DEFINITIONS_DIR}patches/${_app_param}"
                if [ -d "${_pcpatch_dir}" ]; then
                    _ps_patches="$(${FIND_BIN} ${_pcpatch_dir}/* -maxdepth 0 -type f 2>/dev/null)"
                    ${TEST_BIN} ! -z "${_ps_patches}" && \
                    note "   ${NOTE_CHAR} Applying common patches for: $(distinct n "${DEF_NAME}${DEF_POSTFIX}")"
                    for _patch in ${_ps_patches}; do
                        for _level in 0 1 2 3 4 5; do
                            debug "Trying to patch source with patch: $(distinct d ${_patch}), level: $(distinct d ${_level})"
                            ${PATCH_BIN} -p${_level} -N -f -i "${_patch}" >> "${LOG}-${_pcpaname}" 2>> "${LOG}-${_pcpaname}" # don't use run.. it may fail - we don't care
                            if [ "$?" = "0" ]; then # skip applying single patch if it already passed
                                debug "Patch: $(distinct d ${_patch}) applied successfully!"
                                break;
                            fi
                        done
                    done
                    _pspatch_dir="${_pcpatch_dir}/${SYSTEM_NAME}"
                    debug "Checking psp dir: $(distinct d ${_pspatch_dir})"
                    if [ -d "${_pspatch_dir}" ]; then
                        note "   ${NOTE_CHAR} Applying platform specific patches for: $(distinct n ${DEF_NAME}${DEF_POSTFIX}/${SYSTEM_NAME})"
                        _ps_patches="$(${FIND_BIN} ${_pspatch_dir}/* -maxdepth 0 -type f 2>/dev/null)"
                        ${TEST_BIN} ! -z "${_ps_patches}" && \
                        for _pspp in ${_ps_patches}; do
                            for _level in 0 1 2 3 4 5; do
                                debug "Patching source code with pspatch: $(distinct d ${_pspp}) (p$(distinct d ${_level}))"
                                ${PATCH_BIN} -p${_level} -N -f -i "${_pspp}" >> "${LOG}-${_pcpaname}" 2>> "${LOG}-${_pcpaname}"
                                if [ "$?" = "0" ]; then # skip applying single patch if it already passed
                                    debug "Patch: $(distinct d ${_pspp}) applied successfully!"
                                    break;
                                fi
                            done
                        done
                    fi
                fi

                after_patch_callback

                note "   ${NOTE_CHAR} Configuring: $(distinct n ${_app_param}), version: $(distinct n ${DEF_VERSION})"
                case "${DEF_CONFIGURE}" in

                    ignore)
                        note "   ${NOTE_CHAR} Configuration skipped for definition: $(distinct n ${_app_param})"
                        ;;

                    no-conf)
                        note "   ${NOTE_CHAR} No configuration for definition: $(distinct n ${_app_param})"
                        DEF_MAKE_METHOD="${DEF_MAKE_METHOD} PREFIX=${PREFIX}"
                        DEF_INSTALL_METHOD="${DEF_INSTALL_METHOD} PREFIX=${PREFIX}"
                        ;;

                    binary)
                        note "   ${NOTE_CHAR} Prebuilt definition of: $(distinct n ${_app_param})"
                        DEF_MAKE_METHOD="true"
                        DEF_INSTALL_METHOD="true"
                        ;;

                    posix)
                        run "./configure -prefix ${PREFIX} -cc $(${BASENAME_BIN} ${CC} 2>/dev/null) ${DEF_CONFIGURE_ARGS}"
                        ;;

                    cmake)
                        ${TEST_BIN} -z "${DEF_CMAKE_BUILD_DIR}" && DEF_CMAKE_BUILD_DIR="." # default - cwd
                        run "${DEF_CONFIGURE} ${DEF_CMAKE_BUILD_DIR} -LH -DCMAKE_INSTALL_RPATH=\"${PREFIX}/lib;${PREFIX}/libexec\" -DCMAKE_INSTALL_PREFIX=${PREFIX} -DCMAKE_BUILD_TYPE=Release -DSYSCONFDIR=${SERVICE_DIR}/etc -DDOCDIR=${SERVICE_DIR}/share/doc -DJOB_POOL_COMPILE=${CPUS} -DJOB_POOL_LINK=${CPUS} -DCMAKE_C_FLAGS=\"${CFLAGS}\" -DCMAKE_CXX_FLAGS=\"${CXXFLAGS}\" ${DEF_CONFIGURE_ARGS}"
                        ;;

                    void|meta|empty|none)
                        DEF_MAKE_METHOD="true"
                        DEF_INSTALL_METHOD="true"
                        ;;

                    *)
                        unset _pic_optional
                        if [ "${SYSTEM_NAME}" != "Darwin" ]; then
                            _pic_optional="--with-pic"
                        fi
                        if [ "${SYSTEM_NAME}" = "Linux" ]; then
                            # NOTE: No /Services feature implemented for Linux.
                            echo "${DEF_CONFIGURE}" | ${GREP_BIN} "configure" >/dev/null 2>&1
                            if [ "$?" = "0" ]; then
                                try "${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS} --prefix=${PREFIX} ${_pic_optional}" || \
                                run "${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS} --prefix=${PREFIX}" # fallback
                            else
                                try "${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS} --prefix=${PREFIX}" || \
                                run "${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS}" # Trust definition
                            fi
                        else
                            # do a simple check for "configure" in DEF_CONFIGURE definition
                            # this way we can tell if we want to put configure options as params
                            echo "${DEF_CONFIGURE}" | ${GREP_BIN} "configure" >/dev/null 2>&1
                            if [ "$?" = "0" ]; then
                                # TODO: add --docdir=${PREFIX}/docs
                                # NOTE: By default try to configure software with these options:
                                #   --sysconfdir=${SERVICE_DIR}/etc
                                #   --localstatedir=${SERVICE_DIR}/var
                                #   --runstatedir=${SERVICE_DIR}/run
                                #   --with-pic
                                # OPTIMIZE: TODO: XXX: use ./configure --help | grep option to
                                #      build configure options quickly
                                try "${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS} --prefix=${PREFIX} --sysconfdir=${SERVICE_DIR}/etc --localstatedir=${SERVICE_DIR}/var --runstatedir=${SERVICE_DIR}/run ${_pic_optional}" || \
                                try "${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS} --prefix=${PREFIX} --sysconfdir=${SERVICE_DIR}/etc --localstatedir=${SERVICE_DIR}/var ${_pic_optional}" || \
                                try "${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS} --prefix=${PREFIX} --sysconfdir=${SERVICE_DIR}/etc --localstatedir=${SERVICE_DIR}/var" || \
                                try "${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS} --prefix=${PREFIX} --sysconfdir=${SERVICE_DIR}/etc ${_pic_optional}" || \
                                try "${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS} --prefix=${PREFIX} --sysconfdir=${SERVICE_DIR}/etc" || \
                                try "${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS} --prefix=${PREFIX} ${_pic_optional}" || \
                                run "${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS} --prefix=${PREFIX}" # last two - only as a fallback

                            else # fallback again:
                                # NOTE: First - try to specify GNU prefix,
                                # then trust prefix given in software definition.
                                try "${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS} --prefix=${PREFIX}" || \
                                run "${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS}"
                            fi
                        fi
                        ;;

                esac

                after_configure_callback
            else
                error "These values cannot be empty: BUILD_DIR, BUILD_DIR_ROOT, BUILD_NAMESUM"
            fi

            # and common part between normal and continue modes:
            note "   ${NOTE_CHAR} Building requirement: $(distinct n ${_app_param})"
            try "${DEF_MAKE_METHOD}" || \
            run "${DEF_MAKE_METHOD}"
            after_make_callback

            debug "Cleaning man dir from previous dependencies, we want to install man pages that belong to LAST requirement which is app bundle itself"
            for place in man share/man share/info share/doc share/docs; do
                ${FIND_BIN} "${PREFIX}/${place}" -delete 2>/dev/null
            done

            note "   ${NOTE_CHAR} Installing requirement: $(distinct n ${_app_param})"
            run "${DEF_INSTALL_METHOD}"
            after_install_callback

            debug "Marking $(distinct d ${_app_param}) as installed in: $(distinct d ${PREFIX})"
            ${TOUCH_BIN} "${PREFIX}/${_app_param}${DEFAULT_INST_MARK_EXT}"
            debug "Writing version: $(distinct d ${DEF_VERSION}) of software: $(distinct d ${DEF_NAME}) installed in: $(distinct d ${PREFIX})"
            ${PRINTF_BIN} "${DEF_VERSION}" > "${PREFIX}/${_app_param}${DEFAULT_INST_MARK_EXT}"

            if [ -z "${DEVEL}" ]; then # if devel mode not set
                debug "Cleaning build dir: $(distinct d ${BUILD_DIR_ROOT}) of bundle: $(distinct d ${DEF_NAME}${DEF_POSTFIX}), after successful build."
                ${RM_BIN} -rf "${BUILD_DIR_ROOT}" >/dev/null 2>> ${LOG}
            else
                debug "Leaving build dir intact when working in devel mode. Last build dir: $(distinct d ${BUILD_DIR_ROOT})"
            fi
            cd "${_cwd}" 2>/dev/null
            unset _cwd
        fi
    else
        warn "   ${WARN_CHAR} Requirement: $(distinct w "${DEF_NAME}${DEF_POSTFIX}") disabled on: $(distinct w ${SYSTEM_NAME})"
        if [ ! -d "${PREFIX}" ]; then # case when disabled requirement is first on list of dependencies
            ${MKDIR_BIN} -p "${PREFIX}"
        fi
        ${TOUCH_BIN} "${PREFIX}/${_req}${DEFAULT_INST_MARK_EXT}"
        ${PRINTF_BIN} "os-default" > "${PREFIX}/${_req}${DEFAULT_INST_MARK_EXT}"
    fi
    unset _req _current_branch
}
