load_defs () {
    _definitions=$*
    if [ -z "${_definitions}" ]; then
        error "No definition name specified for load_defs()!"
    else
        debug "Trying to load definitions: $(distinct e "${_definitions}")"
        for _given_def in ${_definitions}; do
            _name_base="$(${BASENAME_BIN} "${_given_def}" 2>/dev/null)"
            _definition="$(lowercase "${_name_base}")"
            if [ -e "${DEFINITIONS_DIR}${_definition}${DEFAULT_DEF_EXT}" ]; then
                debug "Loading definition: $(distinct d ${DEFINITIONS_DIR}${_definition}${DEFAULT_DEF_EXT})"
                . ${DEFINITIONS_DIR}${_definition}${DEFAULT_DEF_EXT}
            elif [ -e "${DEFINITIONS_DIR}${_definition}" ]; then
                debug "Loading definition: $(distinct d ${DEFINITIONS_DIR}${_definition})"
                . ${DEFINITIONS_DIR}${_definition}
            else
                error "Can't find definition to load: $(distinct e ${_definition}) from dir: $(distinct e "${DEFINITIONS_DIR}")"
            fi
        done
    fi

    # Perform several sanity checks here..
    for _required_field in  "DEF_NAME=${DEF_NAME}" \
                            "DEF_NAME_DEF_POSTFIX=${DEF_NAME}${DEF_POSTFIX}" \
                            "DEF_VERSION=${DEF_VERSION}" \
                            "DEF_SHA_OR_DEF_GIT_MODE=${DEF_SHA}${DEF_GIT_MODE}" \
                            "DEF_COMPLIANCE=${DEF_COMPLIANCE}" \
                            "DEF_HTTP_PATH=${DEF_HTTP_PATH}" \
                            "SYSTEM_VERSION=${SYSTEM_VERSION}" \
                            "OS_TRIPPLE=${OS_TRIPPLE}" \
                            "RUNTIME_ID=${RUNTIME_ID}" \
                            "SYS_SPECIFIC_BINARY_REMOTE=${SYS_SPECIFIC_BINARY_REMOTE}";
            do
                debug "Required field check: $(distinct d ${_required_field})"
                for _check in   "DEF_NAME" \
                                "DEF_NAME_DEF_POSTFIX" \
                                "DEF_VERSION" \
                                "DEF_SHA_OR_DEF_GIT_MODE" \
                                "DEF_COMPLIANCE" \
                                "DEF_HTTP_PATH" \
                                "SYSTEM_VERSION" \
                                "OS_TRIPPLE" \
                                "RUNTIME_ID" \
                                "SYS_SPECIFIC_BINARY_REMOTE";
                    do
                        if [ "${_check}=" = "${_required_field}" -o \
                             "${_check}=." = "${_required_field}" -o \
                             "${_check}=${DEFAULT_DEF_EXT}" = "${_required_field}" ]; then
                            error "Empty or wrong value for required field: $(distinct e ${_check}) from definition: $(distinct e "${_definition}")."
                        fi
                done
    done
    unset _definition _definitions _check _required_field _name_base _given_def
}


load_defaults () {
    debug "Loading definition defaults"
    . "${DEFAULTS}"
    if [ -z "${COMPLIANCE_CHECK}" ]; then
        # check definition/defaults compliance version
        debug "Version compliance test $(distinct d "${DEF_COMPLIANCE}") vs $(distinct d "${SOFIN_VERSION}")"
        ${PRINTF_BIN} "${SOFIN_VERSION}" | eval "${EGREP_BIN} '${DEF_COMPLIANCE}'" >/dev/null 2>&1
        if [ "$?" = "0" ]; then
            debug "Compliance check passed."
            COMPLIANCE_CHECK="passed"
        else
            error "Versions mismatch!. DEF_COMPILIANCE='$(distinct e "${DEF_COMPLIANCE}")' and SOFIN_VERSION='$(distinct e "${SOFIN_VERSION}")' should match.\n  Hint: Update your definitions repository to latest version!"
        fi
    else
        debug "Check passed previously once. Skipping compliance check"
    fi
}


inherit () {
    . ${DEFINITIONS_DIR}${1}${DEFAULT_DEF_EXT}
}


cleanup_after_tasks () {
    debug "cleanup_after_tasks()"
    update_shell_vars
    reload_zsh_shells
    destroy_locks
}


store_checksum_bundle () {
    _cksname="${1}"
    if [ -z "${_cksname}" ]; then
        error "Empty archive name in function: $(distinct e "store_checksum_bundle()")!"
    fi
    _cksarchive_sha1="$(file_checksum "${_cksname}")"
    if [ -z "${_cksarchive_sha1}" ]; then
        error "Empty checksum for archive: $(distinct e "${_cksname}")"
    fi
    ${PRINTF_BIN} "${_cksarchive_sha1}" > "${_cksname}${DEFAULT_CHKSUM_EXT}" 2>> ${LOG} && \
    debug "Stored checksum: $(distinct d ${_cksarchive_sha1}) for bundle file: $(distinct d "${_cksname}")"
    unset _cksarchive_sha1 _cksname
}


build_software_bundle () {
    _bsbname="${1}"
    _bsbelement="${2}"
    if [ ! -e "./${_bsbname}" ]; then
        ${TAR_BIN} -cJ --use-compress-program="${XZ_BIN} --threads=${CPUS}" -f "${_bsbname}" "./${_bsbelement}" 2>> ${LOG} && \
            note "Bundle archive of: $(distinct n ${_bsbelement}) (using: $(distinct n ${CPUS}) threads) has been built." && \
            return
        ${TAR_BIN} -cJf "${_bsbname}" "./${_bsbelement}" 2>> ${LOG} && \
            note "Bundle archive of: $(distinct n ${_bsbelement}) has been built." && \
            return
        error "Failed to create archives for: $(distinct e ${_bsbelement})"
    else
        if [ ! -e "./${_bsbname}${DEFAULT_CHKSUM_EXT}" ]; then
            debug "Found sha-less archive. It may be incomplete or damaged. Rebuilding.."
            ${RM_BIN} -vf "${_bsbname}" >> ${LOG} 2>> ${LOG}
            ${TAR_BIN} -cJ --use-compress-program="${XZ_BIN} --threads=${CPUS}" -f "${_bsbname}" "./${_bsbelement}" 2>> ${LOG} >> ${LOG} || \
            ${TAR_BIN} -cJf "${_bsbname}" "./${_bsbelement}" 2>> ${LOG} || \
                error "Failed to create archives for: $(distinct e ${_bsbelement})"
            note "Archived bundle: $(distinct n "${_bsbelement}") is ready to deploy"
        else
            note "Archived bundle: $(distinct n "${_bsbelement}") already exists, and will be reused to deploy"
        fi
    fi
    unset _bsbname _bsbelement
}


update_definitions () {
    if [ ! -z "${USE_UPDATE}" ]; then
        debug "Definitions update skipped on demand"
        return
    fi
    note "$(sofin_header)"
    if [ ! -x "${GIT_BIN}" ]; then
        note "Installing initial definition list from tarball to cache dir: $(distinct n ${CACHE_DIR})"
        ${RM_BIN} -rf "${CACHE_DIR}definitions" >> ${LOG} 2>> ${LOG}
        ${MKDIR_BIN} -p "${LOGS_DIR}" "${CACHE_DIR}definitions"
        cd "${CACHE_DIR}definitions"
        _initial_defs="${MAIN_SOURCE_REPOSITORY}initial-definitions${DEFAULT_ARCHIVE_EXT}"
        debug "Fetching latest tarball with initial definitions from: $(distinct d ${_initial_defs})"
        retry "${FETCH_BIN} ${FETCH_OPTS} ${_initial_defs}" && \
            ${TAR_BIN} -xJf *${DEFAULT_ARCHIVE_EXT} >> ${LOG} 2>> ${LOG} && \
            ${RM_BIN} -vrf "$(${BASENAME_BIN} ${_initial_defs} 2>/dev/null)" >> ${LOG} 2>> ${LOG}
            return
    fi
    if [ -d "${CACHE_DIR}definitions/.git" -a \
         -f "${DEFAULTS}" ]; then
        cd "${CACHE_DIR}definitions"
        _current_branch="$(${GIT_BIN} rev-parse --abbrev-ref HEAD 2>/dev/null)"
        _latestsha="$(${CAT_BIN} "${CACHE_DIR}definitions/.git/refs/heads/${_current_branch}" 2>/dev/null)"
        if [ -z "${_latestsha}" ]; then
            _latestsha="HEAD"
        fi
        debug "State of definitions repository was reset to: $(distinct d "${_latestsha}")"
        if [ "${_current_branch}" != "${BRANCH}" ]; then # use _current_branch value if branch isn't matching default branch
            debug "Checking out branch: $(distinct d ${_current_branch})"
            try "${GIT_BIN} checkout ${DEFAULT_GIT_OPTS} -b ${_current_branch}" || \
                try "${GIT_BIN} checkout ${DEFAULT_GIT_OPTS} ${_current_branch}" || \
                    warn "Can't checkout branch: $(distinct w ${_current_branch})"

            try "${GIT_BIN} pull ${DEFAULT_GIT_OPTS} origin ${_current_branch}" && \
                note "Branch: $(distinct n ${_current_branch}) is at: $(distinct n ${_latestsha})" && \
                return

            note "${red}Error occured: Update from branch: $(distinct e ${BRANCH}) of repository: $(distinct e ${REPOSITORY}) wasn't possible. Log below:${reset}"
            ${TAIL_BIN} -n${LOG_LINES_AMOUNT_ON_ERR} "${LOG}" 2>/dev/null
            error "$(fill)"

        else # else use default branch
            debug "Using default branch: $(distinct d ${BRANCH})"
            if [ "${_current_branch}" != "${BRANCH}" ]; then
                try "${GIT_BIN} checkout ${DEFAULT_GIT_OPTS} -b ${BRANCH}" || \
                    try "${GIT_BIN} checkout ${DEFAULT_GIT_OPTS} ${BRANCH}" || \
                        warn "Can't checkout branch: $(distinct w ${BRANCH})"
            fi
            try "${GIT_BIN} pull ${DEFAULT_GIT_OPTS} origin ${BRANCH}" && \
                note "Branch: $(distinct n ${BRANCH}) is at: $(distinct n ${_latestsha})" && \
                return

            note "${red}Error occured: Update from branch: $(distinct e ${BRANCH}) of repository: $(distinct e ${REPOSITORY}) wasn't possible. Log's below:${reset}"
            ${TAIL_BIN} -n${LOG_LINES_AMOUNT_ON_ERR} ${LOG} 2>/dev/null
            error "$(fill)"
        fi
    else
        # create cache; clone definitions repository:
        ${MKDIR_BIN} -p "${CACHE_DIR}" 2>/dev/null
        ${MKDIR_BIN} -p "${LOGS_DIR}" 2>/dev/null

        cd "${CACHE_DIR}"
        debug "Cloning repository: $(distinct d ${REPOSITORY}) from branch: $(distinct d ${BRANCH}); LOGS_DIR: $(distinct d ${LOGS_DIR}), CACHE_DIR: $(distinct d ${CACHE_DIR})"
        ${RM_BIN} -vrf definitions >> ${LOG} 2>> ${LOG} # if something is already here, wipe it out from cache
        try "${GIT_BIN} clone ${DEFAULT_GIT_OPTS} ${REPOSITORY} definitions" || \
            error "Error cloning branch: $(distinct e ${BRANCH}) of repository: $(distinct e ${REPOSITORY}). Please make sure that given repository and branch are valid!"
        cd "${CACHE_DIR}definitions"
        _current_branch="$(${GIT_BIN} rev-parse --abbrev-ref HEAD 2>/dev/null)"
        if [ "${BRANCH}" != "${_current_branch}" ]; then
            try "${GIT_BIN} checkout ${DEFAULT_GIT_OPTS} -b ${BRANCH}" || \
                try "${GIT_BIN} checkout ${DEFAULT_GIT_OPTS} ${BRANCH}" || \
                    warn "Can't checkout branch: $(distinct w ${BRANCH})"
        fi
        _latestsha="$(${CAT_BIN} "${CACHE_DIR}definitions/.git/refs/heads/${_current_branch}" 2>/dev/null)"
        if [ -z "${_latestsha}" ]; then
            _latestsha="HEAD"
        fi
        try "${GIT_BIN} pull --progress origin ${BRANCH}" && \
            note "Branch: $(distinct n ${BRANCH}) is currenly at: $(distinct n "${_latestsha}") in repository: $(distinct n ${REPOSITORY})" && \
            return

        note "${red}Error occured: Update from branch: $(distinct n ${BRANCH}) of repository: $(distinct n ${REPOSITORY}) wasn't possible. Log below:${reset}"
        ${TAIL_BIN} -n${LOG_LINES_AMOUNT_ON_ERR} ${LOG} 2>/dev/null
        error "$(fill)"
    fi
}


check_disabled () {
    # check requirement for disabled state:
    export ALLOW="1"
    if [ ! -z "$1" ]; then
        for disabled in ${1}; do
            if [ "${SYSTEM_NAME}" = "${disabled}" ]; then
                export ALLOW="0"
            fi
        done
    fi
}


file_checksum () {
    _fcsmname="$1"
    if [ -z "${_fcsmname}" ]; then
        error "Empty file name given for function: $(distinct e "file_checksum()")"
    fi
    case ${SYSTEM_NAME} in
        Minix|Darwin|Linux)
            ${PRINTF_BIN} "$(${SHA_BIN} "${_fcsmname}" 2>/dev/null | ${CUT_BIN} -d' ' -f1 2>/dev/null)"
            ;;

        FreeBSD)
            ${PRINTF_BIN} "$(${SHA_BIN} -q "${_fcsmname}" 2>/dev/null)"
            ;;
    esac
    unset _fcsmname
}


push_binbuild () {
    create_cache_directories
    note "Pushing binary bundle: $(distinct n ${SOFIN_ARGS}) to remote: $(distinct n ${MAIN_BINARY_REPOSITORY})"
    cd "${SOFTWARE_DIR}"
    for _pbelement in ${SOFIN_ARGS}; do
        _lowercase_element="$(lowercase "${_pbelement}")"
        if [ -z "${_lowercase_element}" ]; then
            error "push_binbuild(): _lowercase_element is empty!"
        fi
        _install_indicator_file="${_pbelement}/${_lowercase_element}${INSTALLED_MARK}"
        _version_element="$(${CAT_BIN} "${_install_indicator_file}" 2>/dev/null)"
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
                        "${MKDIR_BIN} -p ${SYS_SPECIFIC_BINARY_REMOTE}" >> "${LOG}-${_lowercase_element}" 2>> "${LOG}-${_lowercase_element}"

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
            warn "Not found software: $(distinct w ${_pbelement})!"
        fi
    done
}


deploy_binbuild () {
    create_cache_directories
    load_defaults
    shift
    _dbbundles=$*
    note "Software bundles to be built and deployed to remote: $(distinct n ${_dbbundles})"
    for _dbbundle in ${_dbbundles}; do
        BUNDLES="${_dbbundle}"
        USE_BINBUILD=NO
        build_all || def_error "${_dbbundle}" "Bundle build failed."
    done
    push_binbuild ${_dbbundles} || def_error "${_dbbundle}" "Push failure"
    note "Software bundle deployed successfully: $(distinct n ${_dbbundle})"
    note "$(fill)"
    unset _dbbundles _dbbundle
}


reset_definitions () {
    create_cache_directories
    cd "${DEFINITIONS_DIR}"
    ${GIT_BIN} reset --hard HEAD >/dev/null 2>&1
    if [ -z "${BRANCH}" ]; then
        BRANCH="stable"
    fi
    _branch="$(${CAT_BIN} ${CACHE_DIR}definitions/.git/refs/heads/${BRANCH} 2>/dev/null)"
    if [ -z "${_branch}" ]; then
        _branch="HEAD"
    fi
    note "State of definitions repository was reset to: $(distinct n "${_branch}")"
    for line in $(${GIT_BIN} status --short 2>/dev/null | ${CUT_BIN} -f2 -d' ' 2>/dev/null); do
        ${RM_BIN} -fv "${line}" >> "${LOG}" 2>> "${LOG}" && \
            debug "Removed untracked file: $(distinct d "${line}")"
    done
    update_definitions
}


remove_bundles () {
    _bundle_nam="${2}"
    if [ -z "${_bundle_nam}" ]; then
        error "Second argument with bundle name is required!"
    fi

    # first look for a list with that name:
    if [ -e "${LISTS_DIR}${_bundle_nam}" ]; then
        BUNDLES="$(${CAT_BIN} ${LISTS_DIR}${_bundle_nam} 2>/dev/null | eval "${NEWLINES_TO_SPACES_GUARD}")"
        debug "Removing list of bundles: $(distinct d ${BUNDLES})"
    else
        BUNDLES="${SOFIN_ARGS}"
        debug "Removing bundles: $(distinct d ${BUNDLES})"
    fi

    load_defaults
    for _def in ${BUNDLES}; do
        _given_name="$(capitalize "${_def}")"
        if [ -z "${_given_name}" ]; then
            error "remove_bundles(): _given_name is empty!"
        fi
        if [ -d "${SOFTWARE_DIR}${_given_name}" ]; then
            if [ "${_given_name}" = "/" ]; then
                error "Czy Ty orzeszki?"
            fi
            _aname="$(lowercase "${_given_name}")"
            debug "Given name: _given_name: ${_given_name}, _aname: ${_aname}"
            note "Removing software bundle(s): $(distinct n ${_given_name})"
            if [ -z "${_aname}" ]; then
                ${RM_BIN} -rfv "${SOFTWARE_DIR}${_given_name}" >> "${LOG}" 2>> "${LOG}"
            else
                ${RM_BIN} -rfv "${SOFTWARE_DIR}${_given_name}" >> "${LOG}-${_aname}" 2>> "${LOG}-${_aname}"
                # if removing a single bundle, then look for alternatives. Otherwise, just remove bundle..
                debug "BUNDLES: ${BUNDLES}, _given_name: ${_given_name}"
                if [ ! "${BUNDLES}" = "${_given_name}" ]; then
                    debug "Looking for other installed versions of: $(distinct d ${_aname}), that might be exported automatically.."
                    _inname="$(echo "${_given_name}" | ${SED_BIN} 's/[0-9]*//g' 2>/dev/null)"
                    _alternative="$(${FIND_BIN} ${SOFTWARE_DIR} -maxdepth 1 -type d -name "${_inname}*" -not -name "${_given_name}" 2>/dev/null | ${SED_BIN} 's/^.*\///g' 2>/dev/null | ${HEAD_BIN} -n1 2>/dev/null)"
                fi
            fi
            if [ ! -z "${_alternative}" -a \
                   -f "${SOFTWARE_DIR}${_alternative}/$(lowercase ${_alternative})${INSTALLED_MARK}" ]; then
                note "Updating environment with already installed alternative: $(distinct n ${_alternative})"
                export_binaries "${_alternative}"
                cleanup_after_tasks
                unset _given_name _inname _alternative _aname _def
                exit # Just pick first available alternative bundle

            elif [ -z "${_alternative}" ]; then
                debug "No alternative: $(distinct d ${_alternative}) != $(distinct d ${_given_name})"
            fi
        else
            warn "Bundle: $(distinct w ${_given_name}) not installed."
        fi
    done
    unset _given_name _inname _alternative _aname _def
}


available_definitions () {
    cd "${DEFINITIONS_DIR}"
    note "Available definitions:"
    ${LS_BIN} -m *def 2>/dev/null | ${SED_BIN} "s/${DEFAULT_DEF_EXT}//g" 2>/dev/null
    note "Definitions count:"
    ${LS_BIN} -a *def 2>/dev/null | ${WC_BIN} -l 2>/dev/null
    cd "${LISTS_DIR}"
    note "Available lists:"
    ${LS_BIN} -m * 2>/dev/null | ${SED_BIN} "s/${DEFAULT_DEF_EXT}//g" 2>/dev/null
}


make_exports () {
    if [ -z "${2}" ]; then
        error "Missing second argument with export app is required!"
    fi
    if [ -z "${3}" ]; then
        error "Missing third argument with source app is required!"
    fi
    _export_bin="${2}"
    _bundle_name="$(capitalize "${3}")"
    for _bindir in "/bin/" "/sbin/" "/libexec/"; do
        debug "Looking into bundle binary dir: $(distinct d ${SOFTWARE_DIR}${_bundle_name}${_bindir})"
        if [ -e "${SOFTWARE_DIR}${_bundle_name}${_bindir}${_export_bin}" ]; then
            note "Exporting binary: $(distinct n ${SOFTWARE_DIR}${_bundle_name}${_bindir}${_export_bin})"
            cd "${SOFTWARE_DIR}${_bundle_name}${_bindir}"
            ${MKDIR_BIN} -p "${SOFTWARE_DIR}${_bundle_name}/exports" # make sure exports dir exists
            _aname="$(lowercase ${_bundle_name})"
            ${LN_BIN} -vfs "..${_bindir}/${_export_bin}" "../exports/${_export_bin}" >> "${LOG}-${_aname}"

            cd / # Go outside of bundle directory after exports
            unset _aname _bindir _bundle_name _export_bin
            return 0
        else
            debug "Export not found: $(distinct d ${SOFTWARE_DIR}${_bundle_name}${_bindir}${_export_bin})"
        fi
    done
    error "No executable to export from bin paths of: $(distinct e "${_bundle_name}/\{bin,sbin,libexec\}/${_export_bin}")"
}


show_outdated () {
    create_cache_directories
    load_defaults
    if [ -d "${SOFTWARE_DIR}" ]; then
        for _prefix in $(${FIND_BIN} ${SOFTWARE_DIR} -mindepth 1 -maxdepth 1 -type d 2>/dev/null); do
            _bundle="$(${BASENAME_BIN} "${_prefix}" 2>/dev/null | ${TR_BIN} '[A-Z]' '[a-z]' 2>/dev/null)" # lowercase for case sensitive fs

            if [ ! -f "${_prefix}/${_bundle}${INSTALLED_MARK}" ]; then
                warn "Bundle: $(distinct w ${_bundle}) is not yet installed or damaged."
                continue
            fi
            _bund_vers="$(${CAT_BIN} "${_prefix}/${_bundle}${INSTALLED_MARK}" 2>/dev/null)"
            if [ ! -f "${DEFINITIONS_DIR}${_bundle}${DEFAULT_DEF_EXT}" ]; then
                warn "No such bundle found: $(distinct w ${_bundle})"
                continue
            fi
            load_defs "${_bundle}"
            check_version "${_bund_vers}" "${DEF_VERSION}"
        done
    fi

    if [ "${outdated}" = "YES" ]; then
        exit 1
    else
        note "All installed bundles looks recent"
    fi
    unset _bund_vers
}


wipe_remote_archives () {
    ANS="YES"
    if [ -z "${USE_FORCE}" ]; then
        warn "Are you sure you want to wipe binary bundles: $(distinct w ${SOFIN_ARGS}) from binary repository: $(distinct w ${MAIN_BINARY_REPOSITORY})? (Type $(distinct w YES) to confirm)"
        read ANS
    fi
    if [ "${ANS}" = "YES" ]; then
        cd "${SOFTWARE_DIR}"
        for _wr_element in ${SOFIN_ARGS}; do
            _lowercase_element="$(lowercase ${_wr_element})"
            _remote_ar_name="${_wr_element}-"
            _wr_dig="$(${HOST_BIN} A ${MAIN_SOFTWARE_ADDRESS} 2>/dev/null | ${GREP_BIN} 'Address:' 2>/dev/null | eval "${HOST_ADDRESS_GUARD}")"
            if [ -z "${_wr_dig}" ]; then
                error "No mirrors found in address: $(distinct e ${MAIN_SOFTWARE_ADDRESS})"
            fi
            debug "Using defined mirror(s): $(distinct d "${_wr_dig}")"
            for _wr_mirr in ${_wr_dig}; do
                note "Wiping out remote: $(distinct n ${_wr_mirr}) binary archives: $(distinct n "${_remote_ar_name}")"
                ${PRINTF_BIN} "${blue}"
                ${SSH_BIN} ${DEFAULT_SSH_OPTS} -p ${MAIN_PORT} "${MAIN_USER}@${_wr_mirr}" \
                    "${FIND_BIN} ${SYS_SPECIFIC_BINARY_REMOTE} -iname '${_remote_ar_name}' -print -delete" 2>> "${LOG}"
            done
        done
    else
        error "Aborted remote wipe of: $(distinct e "${SOFIN_ARGS}")"
    fi
    unset _wr_mirr _remote_ar_name _wr_dig _lowercase_element _wr_element
}


execute_process () {
    _app_param="$1"
    if [ -z "${_app_param}" ]; then
        error "No param given for execute_process()!"
    fi
    _req_definition="${DEFINITIONS_DIR}$(lowercase "${_app_param}")${DEFAULT_DEF_EXT}"
    debug "Checking requirement: $(distinct d ${_app_param}) file: $(distinct d ${_req_definition})"
    if [ ! -e "${_req_definition}" ]; then
        error "Cannot fetch definition: $(distinct e ${_req_definition})! Aborting!"
    fi

    load_defaults
    load_defs "${_req_definition}"
    check_disabled "${DEF_DISABLE_ON}" # check requirement for disabled state:

    setup_sofin_compiler
    dump_debug_info

    export PATH="${PREFIX}/bin:${PREFIX}/sbin:${DEFAULT_PATH}"
    if [ "${ALLOW}" = "1" ]; then
        if [ -z "${DEF_HTTP_PATH}" ]; then
            _definition_no_ext="\
                $(echo "$(${BASENAME_BIN} ${_req_definition} 2>/dev/null)" | \
                ${SED_BIN} -e 's/\..*$//g' 2>/dev/null)"
            note "   ${NOTE_CHAR2} $(distinct n "DEF_HTTP_PATH=\"\"") is undefined for: $(distinct n "${_definition_no_ext}")."
            note "NOTE: It's only valid for meta bundles. You may consider setting: $(distinct n "DEF_CONFIGURE=\"meta\"") in bundle definition file. Type: $(distinct n "s dev ${_definition_no_ext}"))"
        else
            _cwd="$(${PWD_BIN} 2>/dev/null)"
            if [ -z "${SOFIN_CONTINUE_BUILD}" ]; then
                export BUILD_DIR_ROOT="${CACHE_DIR}cache/${DEF_NAME}${DEF_POSTFIX}-${DEF_VERSION}-${RUNTIME_ID}/"
                ${RM_BIN} -rf "${BUILD_DIR_ROOT}" >> ${LOG} 2>> ${LOG}
                ${MKDIR_BIN} -p "${BUILD_DIR_ROOT}" >/dev/null 2>&1
                cd "${BUILD_DIR_ROOT}"
                if [ -z "${DEF_GIT_MODE}" ]; then # Standard http tarball method:
                    _base="$(${BASENAME_BIN} ${DEF_HTTP_PATH} 2>/dev/null)"
                    debug "DEF_HTTP_PATH: $(distinct d ${DEF_HTTP_PATH}) base: $(distinct d ${_base})"
                    if [ ! -e ${BUILD_DIR_ROOT}/../${_base} ]; then
                        note "   ${NOTE_CHAR} Fetching required tarball source: $(distinct n ${_base})"
                        retry "${FETCH_BIN} ${FETCH_OPTS} ${DEF_HTTP_PATH}"
                        ${MV_BIN} ${_base} ${BUILD_DIR_ROOT}/.. >> ${LOG} 2>> ${LOG}
                    fi

                    _dest_file="${BUILD_DIR_ROOT}/../${_base}"
                    debug "Build dir: $(distinct d ${BUILD_DIR_ROOT}), file: $(distinct d ${_dest_file})"
                    if [ -z "${DEF_SHA}" ]; then
                        error "Missing SHA sum for source: $(distinct e ${_dest_file})!"
                    else
                        _a_file_checksum="$(file_checksum ${_dest_file})"
                        if [ "${_a_file_checksum}" = "${DEF_SHA}" ]; then
                            debug "Source tarball checksum is fine"
                        else
                            warn "${WARN_CHAR} Source tarball checksum mismatch detected!"
                            warn "${WARN_CHAR} $(distinct w ${_a_file_checksum}) vs $(distinct w ${DEF_SHA})"
                            warn "${WARN_CHAR} Removing corrupted file from cache: $(distinct w ${_dest_file}) and retrying.."
                            # remove corrupted file
                            ${RM_BIN} -vf "${_dest_file}" >> ${LOG} 2>> ${LOG}
                            # and restart script with same arguments:
                            debug "Evaluating again: $(distinct d "execute_process(${_app_param})")"
                            execute_process "${_app_param}"
                        fi
                    fi

                    note "   ${NOTE_CHAR} Unpacking source tarball of: $(distinct n ${DEF_NAME}${DEF_POSTFIX})"
                    debug "Build dir root: $(distinct d ${BUILD_DIR_ROOT})"
                    try "${TAR_BIN} -xf ${_dest_file}" || \
                    try "${TAR_BIN} -xfj ${_dest_file}" || \
                    run "${TAR_BIN} -xfJ ${_dest_file}"
                else
                    # git method:
                    # .cache/git-cache => git bare repos
                    ${MKDIR_BIN} -p ${GIT_CACHE_DIR}
                    _git_cached="${GIT_CACHE_DIR}${DEF_NAME}${DEF_VERSION}.git"
                    note "   ${NOTE_CHAR} Fetching git repository: $(distinct n ${DEF_HTTP_PATH}${reset})"
                    try "${GIT_BIN} clone ${DEFAULT_GIT_OPTS} --depth 1 --bare ${DEF_HTTP_PATH} ${_git_cached}" || \
                    try "${GIT_BIN} clone ${DEFAULT_GIT_OPTS} --depth 1 --bare ${DEF_HTTP_PATH} ${_git_cached}" || \
                    try "${GIT_BIN} clone ${DEFAULT_GIT_OPTS} --depth 1 --bare ${DEF_HTTP_PATH} ${_git_cached}"
                    if [ "$?" = "0" ]; then
                        debug "Fetched bare repository: $(distinct d ${DEF_NAME}${DEF_VERSION})"
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

                export BUILD_DIR="$(${FIND_BIN} ${BUILD_DIR_ROOT}/* -maxdepth 0 -type d -name "*${DEF_VERSION}*" 2>/dev/null)"
                if [ -z "${BUILD_DIR}" ]; then
                    export BUILD_DIR=$(${FIND_BIN} ${BUILD_DIR_ROOT}/* -maxdepth 0 -type d 2>/dev/null) # try any dir instead
                fi
                if [ ! -z "${DEF_SOURCE_DIR_POSTFIX}" ]; then
                    export BUILD_DIR="${BUILD_DIR}/${DEF_SOURCE_DIR_POSTFIX}"
                fi
                cd "${BUILD_DIR}"
                debug "Switched to build dir: $(distinct d ${BUILD_DIR})"

                if [ ! -z "${DEF_GIT_CHECKOUT}" ]; then
                    note "   ${NOTE_CHAR} Definition branch: $(distinct n ${DEF_GIT_CHECKOUT})"
                    _current_branch="$(${GIT_BIN} rev-parse --abbrev-ref HEAD 2>/dev/null)"
                    if [ "${_current_branch}" != "${DEF_GIT_CHECKOUT}" ]; then
                        try "${GIT_BIN} checkout ${DEFAULT_GIT_OPTS} -b ${DEF_GIT_CHECKOUT}"
                    fi
                    try "${GIT_BIN} checkout ${DEFAULT_GIT_OPTS} ${DEF_GIT_CHECKOUT}"
                fi

                after_update_callback

                _aname="$(lowercase ${DEF_NAME}${DEF_POSTFIX})"
                LIST_DIR="${DEFINITIONS_DIR}patches/${_app_param}"
                if [ -d "${LIST_DIR}" ]; then
                    _ps_patches="$(${FIND_BIN} ${LIST_DIR}/* -maxdepth 0 -type f 2>/dev/null)"
                    ${TEST_BIN} ! -z "${_ps_patches}" && \
                    note "   ${NOTE_CHAR} Applying common patches for: $(distinct n ${DEF_NAME}${DEF_POSTFIX})"
                    for _patch in ${_ps_patches}; do
                        for _level in 0 1 2 3 4 5; do
                            debug "Trying to patch source with patch: $(distinct d ${_patch}), level: $(distinct d ${_level})"
                            ${PATCH_BIN} -p${_level} -N -f -i "${_patch}" >> "${LOG}-${_aname}" 2>> "${LOG}-${_aname}" # don't use run.. it may fail - we don't care
                            if [ "$?" = "0" ]; then # skip applying single patch if it already passed
                                debug "Patch: $(distinct d ${_patch}) applied successfully!"
                                break;
                            fi
                        done
                    done
                    _pspatch_dir="${LIST_DIR}/${SYSTEM_NAME}"
                    debug "Checking psp dir: $(distinct d ${_pspatch_dir})"
                    if [ -d "${_pspatch_dir}" ]; then
                        note "   ${NOTE_CHAR} Applying platform specific patches for: $(distinct n ${DEF_NAME}${DEF_POSTFIX}/${SYSTEM_NAME})"
                        _ps_patches="$(${FIND_BIN} ${_pspatch_dir}/* -maxdepth 0 -type f 2>/dev/null)"
                        ${TEST_BIN} ! -z "${_ps_patches}" && \
                        for _pspp in ${_ps_patches}; do
                            for _level in 0 1 2 3 4 5; do
                                debug "Patching source code with pspatch: $(distinct d ${_pspp}) (p$(distinct d ${_level}))"
                                ${PATCH_BIN} -p${_level} -N -f -i "${_pspp}" >> "${LOG}-${_aname}" 2>> "${LOG}-${_aname}"
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
                        export DEF_MAKE_METHOD="${DEF_MAKE_METHOD} PREFIX=${PREFIX}"
                        export DEF_INSTALL_METHOD="${DEF_INSTALL_METHOD} PREFIX=${PREFIX}"
                        ;;

                    binary)
                        note "   ${NOTE_CHAR} Prebuilt definition of: $(distinct n ${_app_param})"
                        export DEF_MAKE_METHOD="true"
                        export DEF_INSTALL_METHOD="true"
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
                                try "${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS} --prefix=${PREFIX} ${_pic_optional} --sysconfdir=/etc" || \
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

            else # in "continue-build" mode, we reuse current cache dir..
                export BUILD_DIR_ROOT="${PREVIOUS_BUILD_DIR}"
                export BUILD_DIR="${PREVIOUS_BUILD_DIR}"
                cd "${BUILD_DIR}"
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
            ${TOUCH_BIN} "${PREFIX}/${_app_param}${INSTALLED_MARK}"
            debug "Writing version: $(distinct d ${DEF_VERSION}) of software: $(distinct d ${DEF_NAME}) installed in: $(distinct d ${PREFIX})"
            ${PRINTF_BIN} "${DEF_VERSION}" > "${PREFIX}/${_app_param}${INSTALLED_MARK}"

            if [ -z "${DEVEL}" ]; then # if devel mode not set
                debug "Cleaning build dir: $(distinct d ${BUILD_DIR_ROOT}) of bundle: $(distinct d ${DEF_NAME}${DEF_POSTFIX}), after successful build."
                ${RM_BIN} -rf "${BUILD_DIR_ROOT}" >> ${LOG} 2>> ${LOG}
            else
                debug "Leaving build dir intact when working in devel mode. Last build dir: $(distinct d ${BUILD_DIR_ROOT})"
            fi
            cd "${_cwd}" 2>/dev/null
            unset _cwd
        fi
    else
        warn "   ${WARN_CHAR} Requirement: $(distinct w ${DEF_NAME}) disabled on: $(distinct w ${SYSTEM_NAME})"
        if [ ! -d "${PREFIX}" ]; then # case when disabled requirement is first on list of dependencies
            ${MKDIR_BIN} -p "${PREFIX}"
        fi
        ${TOUCH_BIN} "${PREFIX}/${_req}${INSTALLED_MARK}"
        ${PRINTF_BIN} "os-default" > "${PREFIX}/${_req}${INSTALLED_MARK}"
    fi
    unset _req _current_branch
}


create_apple_bundle_if_necessary () { # XXXXXX
    if [ ! -z "${DEF_APPLE_BUNDLE}" ]; then
        _aname="$(lowercase "${DEF_NAME}${DEF_POSTFIX}")"
        DEF_NAME="$(${PRINTF_BIN} "${DEF_NAME}" | ${CUT_BIN} -c1 2>/dev/null | ${TR_BIN} '[a-z]' '[A-Z]' 2>/dev/null)$(${PRINTF_BIN} "${DEF_NAME}" | ${SED_BIN} 's/^[a-zA-Z]//' 2>/dev/null)"
        DEF_BUNDLE_NAME="${PREFIX}.app"
        note "Creating Apple bundle: $(distinct n ${DEF_NAME} )in: $(distinct n ${DEF_BUNDLE_NAME})"
        ${MKDIR_BIN} -p "${DEF_BUNDLE_NAME}/libs" "${DEF_BUNDLE_NAME}/Contents" "${DEF_BUNDLE_NAME}/Contents/Resources/${_aname}" "${DEF_BUNDLE_NAME}/exports" "${DEF_BUNDLE_NAME}/share"
        ${CP_BIN} -R ${PREFIX}/${DEF_NAME}.app/Contents/* "${DEF_BUNDLE_NAME}/Contents/"
        ${CP_BIN} -R ${PREFIX}/bin/${_aname} "${DEF_BUNDLE_NAME}/exports/"
        for lib in $(${FIND_BIN} "${PREFIX}" -name '*.dylib' -type f 2>/dev/null); do
            ${CP_BIN} -vf ${lib} ${DEF_BUNDLE_NAME}/libs/ >> ${LOG}-${_aname} 2>> ${LOG}-${_aname}
        done

        # if symlink exists, remove it.
        ${RM_BIN} -vf ${DEF_BUNDLE_NAME}/lib >> ${LOG} 2>> ${LOG}
        ${LN_BIN} -vs "${DEF_BUNDLE_NAME}/libs ${DEF_BUNDLE_NAME}/lib" >> ${LOG} 2>> ${LOG}

        # move data, and support files from origin:
        ${CP_BIN} -vR "${PREFIX}/share/${_aname}" "${DEF_BUNDLE_NAME}/share/" >> ${LOG} 2>> ${LOG}
        ${CP_BIN} -vR "${PREFIX}/lib/${_aname}" "${DEF_BUNDLE_NAME}/libs/" >> ${LOG} 2>> ${LOG}

        cd "${DEF_BUNDLE_NAME}/Contents"
        ${TEST_BIN} -L MacOS || ${LN_BIN} -s ../exports MacOS >> ${LOG}-${_aname} 2>> ${LOG}-${_aname}
        debug "Creating relative libraries search path"
        cd ${DEF_BUNDLE_NAME}
        note "Processing exported binary: $(distinct n ${i})"
        ${SOFIN_LIBBUNDLE_BIN} -x "${DEF_BUNDLE_NAME}/Contents/MacOS/${_aname}" >> ${LOG}-${_aname} 2>> ${LOG}-${_aname}
    fi
}


strip_bundle_files () {
    _definition_name="${1}"
    if [ -z "${_definition_name}" ]; then
        error "No definition name specified as first param for strip_bundle_files()!"
    fi
    load_defaults # reset possible cached values
    load_defs "${_definition_name}"
    if [ -z "${PREFIX}" ]; then
        PREFIX="${SOFTWARE_DIR}$(capitalize "${DEF_NAME}${DEF_POSTFIX}")"
        debug "An empty prefix in strip_bundle_files() for $(distinct d ${_definition_name}). Resetting to: $(distinct d ${PREFIX})"
    fi

    _dirs_to_strip=""
    case "${DEF_STRIP}" in
        all)
            debug "strip_bundle_files($(distinct d "${_definition_name}")): Strip both binaries and libraries."
            _dirs_to_strip="${PREFIX}/bin ${PREFIX}/sbin ${PREFIX}/lib ${PREFIX}/libexec"
            ;;

        exports)
            debug "strip_bundle_files($(distinct d "${_definition_name}")): Strip exported binaries only"
            _dirs_to_strip="${PREFIX}/bin ${PREFIX}/sbin ${PREFIX}/libexec"
            ;;

        libs)
            debug "strip_bundle_files($(distinct d "${_definition_name}")): Strip libraries only"
            _dirs_to_strip="${PREFIX}/lib"
            ;;

        *)
            debug "strip_bundle_files($(distinct d "${_definition_name}")): Strip nothing"
            ;;
    esac
    if [ "${DEF_STRIP}" != "no" ]; then
        _bundlower="$(lowercase "${DEF_NAME}${DEF_POSTFIX}")"
        if [ -z "${DEBUGBUILD}" ]; then
            _counter="0"
            for _stripdir in ${_dirs_to_strip}; do
                if [ -d "${_stripdir}" ]; then
                    _tbstripfiles=$(${FIND_BIN} ${_stripdir} -maxdepth 1 -type f 2>/dev/null)
                    for _file in ${_tbstripfiles}; do
                        ${STRIP_BIN} "${_file}" >> "${LOG}-${_bundlower}.strip" 2>> "${LOG}-${_bundlower}.strip"
                        if [ "$?" = "0" ]; then
                            _counter="${_counter} + 1"
                        else
                            _counter="${_counter} - 1"
                        fi
                    done
                fi
            done
            _sbresult="$(echo "${_counter}" | ${BC_BIN} 2>/dev/null)"
            if [ "${_sbresult}" -lt "0" ]; then
                _sbresult="0"
            fi
            note "$(distinct n ${_sbresult}) files were stripped"
        else
            warn "Debug build is enabled. Strip skipped"
        fi
    fi
    unset _definition_name _dirs_to_strip _sbresult _counter _files _stripdir _bundlower
}


manage_datasets () {
    case ${SYSTEM_NAME} in
        Darwin) # disabled for now, since OSX finds more problems than they're
            ;;

        Linux) # Not supported
            ;;

        Minix) # Not supported
            ;;

        *)
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
            export _jobs_in_parallel="NO"
            if [ ${_sofins_installing} -gt 1 ]; then
                note "Found: $(distinct n ${_sofins_installing}) running Sofin instances. Parallel jobs not allowed"
                export _jobs_in_parallel="YES"
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
                    if [ "${USERNAME}" = "root" ]; then
                        _inner_dir="root/"
                    else
                        # NOTE: In ServeD-OS there's only 1 inner dir name that's also the cell name
                        no_ending_slash="$(echo "${SERVICES_DIR}" | ${SED_BIN} 's/\/$//' 2>/dev/null)"
                        _inner_dir="$(${ZFS_BIN} list -H 2>/dev/null | ${EGREP_BIN} "${no_ending_slash}$" 2>/dev/null | ${AWK_BIN} '{print $1;}' 2>/dev/null | ${SED_BIN} 's/.*\///' 2>/dev/null)/"
                        if [ -z "${_inner_dir}" ]; then
                            warn "Falling back with inner dir name to current user name: ${USERNAME}/"
                            _inner_dir="${USERNAME}/"
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
            ;;
    esac
}


clean_useless () {
    if [ "${DEF_CLEAN_USELESS}" = "YES" ]; then
        # we shall clean the bundle, from useless files..
        if [ ! -z "${PREFIX}" ]; then
            # step 0: clean defaults side DEF_DEFAULT_USELESS entries only if DEF_USEFUL is empty
            if [ ! -z "${DEF_DEFAULT_USELESS}" ]; then
                for _cu_pattern in ${DEF_DEFAULT_USELESS}; do
                    if [ ! -z "${PREFIX}" -a \
                           -z "${DEF_USEFUL}" ]; then # TODO: implement ignoring DEF_USEFUL entries here!
                        debug "Pattern of DEF_DEFAULT_USELESS: $(distinct d ${_cu_pattern})"
                        ${RM_BIN} -vrf ${PREFIX}/${_cu_pattern} >> ${LOG} 2>> ${LOG}
                    fi
                done
            fi

            # step 1: clean definition side DEF_USELESS entries only if DEF_USEFUL is empty
            if [ ! -z "${DEF_USELESS}" ]; then
                for _cu_pattern in ${DEF_USELESS}; do
                    if [ ! -z "${PREFIX}" -a \
                         ! -z "${_cu_pattern}" ]; then
                        debug "Pattern of DEF_USELESS: $(distinct d ${PREFIX}/${_cu_pattern})"
                        ${RM_BIN} -vrf ${PREFIX}/${_cu_pattern} >> ${LOG} 2>> ${LOG}
                    fi
                done
            fi
        fi

        for _cu_dir in bin sbin libexec; do
            if [ -d "${PREFIX}/${_cu_dir}" ]; then
                _cuall_binaries=$(${FIND_BIN} ${PREFIX}/${_cu_dir} -maxdepth 1 -type f -or -type l 2>/dev/null)
                for _cufile in ${_cuall_binaries}; do
                    _cubase="$(${BASENAME_BIN} ${_cufile} 2>/dev/null)"
                    if [ -e "${PREFIX}/exports/${_cubase}" ]; then
                        debug "Found export: $(distinct d ${_cubase})"
                    else
                        # traverse through DEF_USEFUL for _cufile patterns required by software but not exported
                        _cu_commit_removal=""
                        for is_useful in ${DEF_USEFUL}; do
                            echo "${_cufile}" | ${GREP_BIN} "${is_useful}" >/dev/null 2>&1
                            if [ "$?" = "0" ]; then
                                _cu_commit_removal="no"
                            fi
                        done
                        if [ -z "${_cu_commit_removal}" ]; then
                            debug "Removing useless _cufile: $(distinct d ${_cufile})"
                            ${RM_BIN} -f ${_cufile}
                        else
                            debug "Useful _cufile left intact: $(distinct d ${_cufile})"
                        fi
                    fi
                done
            fi
        done
    else
        debug "Useless files cleanup skipped"
    fi
    unset _cu_pattern _cufile _cuall_binaries _cu_commit_removal _cubase
}


conflict_resolve () {
    debug "Resolving conflicts for: $(distinct d "${DEF_CONFLICTS_WITH}")"
    if [ ! -z "${DEF_CONFLICTS_WITH}" ]; then
        debug "Resolving possible conflicts with: $(distinct d ${DEF_CONFLICTS_WITH})"
        for _cr_app in ${DEF_CONFLICTS_WITH}; do
            _crfind_s="$(${FIND_BIN} ${SOFTWARE_DIR} -maxdepth 1 -type d -iname "${_cr_app}*" 2>/dev/null)"
            for _cr_name in ${_crfind_s}; do
                _crn="$(${BASENAME_BIN} "${_cr_name}" 2>/dev/null)"
                if [ -e "${_cr_name}/exports" \
                     -a "${_crn}" != "${DEF_NAME}" \
                     -a "${_crn}" != "${DEF_NAME}${DEF_POSTFIX}" \
                ]; then
                    ${MV_BIN} "${_cr_name}/exports" "${_cr_name}/exports-disabled" && \
                        debug "Resolved conflict with: $(distinct n ${_crn})"
                fi
            done
        done
    fi
    unset _crfind_s _cr_app _cr_name _crn
}


export_binaries () {
    _ebdef_name="$1"
    if [ -z "${_ebdef_name}" ]; then
        error "No definition name specified as first param for export_binaries()!"
    fi
    load_defs "${_ebdef_name}"
    conflict_resolve

    if [ -z "${PREFIX}" ]; then
        PREFIX="${SOFTWARE_DIR}$(capitalize "${DEF_NAME}${DEF_POSTFIX}")"
        debug "An empty prefix in export_binaries() for $(distinct d ${_ebdef_name}). Resetting to: $(distinct d ${PREFIX})"
    fi
    if [ -d "${PREFIX}/exports-disabled" ]; then # just bring back disabled exports
        debug "Moving $(distinct d ${PREFIX}/exports-disabled) to $(distinct d ${PREFIX}/exports)"
        ${MV_BIN} "${PREFIX}/exports-disabled" "${PREFIX}/exports"
    fi
    if [ -z "${DEF_EXPORTS}" ]; then
        note "Defined no binaries to export of prefix: $(distinct n ${PREFIX})"
    else
        _a_name="$(lowercase ${DEF_NAME}${DEF_POSTFIX})"
        _an_amount="$(echo "${DEF_EXPORTS}" | ${WC_BIN} -w 2>/dev/null | ${TR_BIN} -d '\t|\r|\ ' 2>/dev/null)"
        debug "Exporting $(distinct n ${_an_amount}) binaries of prefix: $(distinct n ${PREFIX})"
        ${MKDIR_BIN} -p "${PREFIX}/exports" >/dev/null 2>&1
        _expolist=""
        for exp in ${DEF_EXPORTS}; do
            for dir in "/bin/" "/sbin/" "/libexec/"; do
                _afile_to_exp="${PREFIX}${dir}${exp}"
                if [ -f "${_afile_to_exp}" ]; then # a file
                    if [ -x "${_afile_to_exp}" ]; then # and it's executable'
                        _acurrdir="$(${PWD_BIN} 2>/dev/null)"
                        cd "${PREFIX}${dir}"
                        ${LN_BIN} -vfs "..${dir}${exp}" "../exports/${exp}" >> "${LOG}-${_a_name}" 2>> "${LOG}-${_a_name}"
                        cd "${_acurrdir}"
                        _expo_elem="$(${BASENAME_BIN} ${_afile_to_exp} 2>/dev/null)"
                        _expolist="${_expolist} ${_expo_elem}"
                    fi
                fi
            done
        done
        debug "List of exports: $(distinct d "${_expolist}")"
    fi
    unset _expo_elem _acurrdir _afile_to_exp _an_amount _a_name _expolist _ebdef_name
}


hack_definition () {
    create_cache_directories
    if [ -z "${2}" ]; then
        error "No pattern specified"
    fi
    _hack_pattern="${2}"
    _abeauty_pat="$(distinct n "*${_hack_pattern}*")"
    _all_hackdirs=$(${FIND_BIN} ${CACHE_DIR}cache -type d -mindepth 2 -maxdepth 2 -iname "*${_hack_pattern}*" 2>/dev/null)
    _all_am="$(echo "${_all_hackdirs}" | ${WC_BIN} -l 2>/dev/null | ${TR_BIN} -d '\t|\r|\ ' 2>/dev/null)"
    ${TEST_BIN} -z "${_all_am}" && _all_am="0"
    if [ -z "${_all_hackdirs}" ]; then
        error "No matching build dirs found for pattern: $(distinct e ${_abeauty_pat})"
    else
        note "Sofin will now walk through: $(distinct n ${_all_am}) build dirs in: $(distinct n ${CACHE_DIR}cache), that matches pattern: $(distinct n ${_abeauty_pat})"
    fi
    for _a_dir in ${_all_hackdirs}; do
        note
        warn "$(fill)"
        warn "Quit viever/ Exit that shell, to continue with next build dir"
        warn "Sofin will now traverse through build logs, looking for errors.."

        currdir="$(${PWD_BIN} 2>/dev/null)"
        cd "${_a_dir}"

        found_any=""
        log_viewer="${LESS_BIN} ${LESS_DEFAULT_OPTIONS} +/error:"
        for logfile in config.log build.log CMakeFiles/CMakeError.log CMakeFiles/CMakeOutput.log; do
            if [ -f "${logfile}" ]; then
                found_any="yes"
                eval "cd ${_a_dir} && ${ZSH_BIN} --login -c '${log_viewer} ${logfile} || exit'"
            fi
        done
        if [ -z "${found_any}" ]; then
            note "Entering build dir.."
            eval "cd ${_a_dir} && ${ZSH_BIN} --login"
        fi
        cd "${currdir}"
        warn "---------------------------------------------------------"
    done
    note "Hack process finished for pattern: ${_abeauty_pat}"
}


rebuild_application () {
    create_cache_directories
    if [ "$2" = "" ]; then
        error "Missing second argument with library/software name."
    fi
    _a_dependency="$2"

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
            _an_def_nam="$(capitalize ${_irawname})"
            _those_to_rebuild="${_an_def_nam} ${_those_to_rebuild}"
        fi
    done

    note "Will rebuild, wipe and push these bundles: $(distinct n ${_those_to_rebuild})"
    for _reb_ap_bundle in ${_those_to_rebuild}; do
        if [ "${_reb_ap_bundle}" = "Git" -o "${_reb_ap_bundle}" = "Zsh" ]; then
            continue
        fi
        remove_bundles ${_reb_ap_bundle}
        USE_BINBUILD=NO
        BUNDLES="${_reb_ap_bundle}"
        build_all || def_error "${_reb_ap_bundle}" "Bundle build failed."
        USE_FORCE=YES
        wipe_remote_archives ${_reb_ap_bundle} || def_error "${_reb_ap_bundle}" "Wipe failed"
        push_binbuild ${_reb_ap_bundle} || def_error "${_reb_ap_bundle}" "Push failure"
    done
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
        confirm () {
            debug "Fetched archive: $(distinct d ${BINBUILDS_CACHE_DIR}${_full_name}/${_bb_archive})"
        }
        if [ ! -e "${BINBUILDS_CACHE_DIR}${_full_name}/${_bb_archive}" ]; then
            cd ${BINBUILDS_CACHE_DIR}${_full_name}
            try "${FETCH_BIN} ${FETCH_OPTS} ${MAIN_BINARY_REPOSITORY}${OS_TRIPPLE}/${_bb_archive}${DEFAULT_CHKSUM_EXT}" || \
                try "${FETCH_BIN} ${FETCH_OPTS} ${MAIN_BINARY_REPOSITORY}${OS_TRIPPLE}/${_bb_archive}${DEFAULT_CHKSUM_EXT}"
            if [ "$?" = "0" ]; then
                $(try "${FETCH_BIN} ${FETCH_OPTS} ${MAIN_BINARY_REPOSITORY}${OS_TRIPPLE}/${_bb_archive}" && confirm) || \
                $(try "${FETCH_BIN} ${FETCH_OPTS} ${MAIN_BINARY_REPOSITORY}${OS_TRIPPLE}/${_bb_archive}" && confirm) || \
                $(try "${FETCH_BIN} ${FETCH_OPTS} ${MAIN_BINARY_REPOSITORY}${OS_TRIPPLE}/${_bb_archive}" && confirm) || \
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
                export DONT_BUILD_BUT_DO_EXPORTS=YES
            else
                debug "  ${NOTE_CHAR} No binary bundle available for: $(distinct n ${DEF_NAME}${DEF_POSTFIX})"
                ${RM_BIN} -fr "${BINBUILDS_CACHE_DIR}${_full_name}"
            fi
        else
            debug "Binary build checksum doesn't match for: $(distinct n ${_full_name})"
        fi
    fi
}


after_update_callback () {
    if [ ! -z "${DEF_AFTER_UNPACK_CALLBACK}" ]; then
        debug "Running after unpack callback: $(distinct d "${DEF_AFTER_UNPACK_CALLBACK}")"
        run "${DEF_AFTER_UNPACK_CALLBACK}"
    fi
}


after_export_callback () {
    if [ ! -z "${DEF_AFTER_EXPORT_CALLBACK}" ]; then
        debug "Executing DEF_AFTER_EXPORT_CALLBACK: $(distinct d "${DEF_AFTER_EXPORT_CALLBACK}")"
        run "${DEF_AFTER_EXPORT_CALLBACK}"
    fi
}


after_patch_callback () {
    if [ ! -z "${DEF_AFTER_PATCH_CALLBACK}" ]; then
        debug "Running after patch callback: $(distinct d "${DEF_AFTER_PATCH_CALLBACK}")"
        run "${DEF_AFTER_PATCH_CALLBACK}"
    fi
}


after_configure_callback () {
    if [ ! -z "${DEF_AFTER_CONFIGURE_CALLBACK}" ]; then
        debug "Running after configure callback: $(distinct d "${DEF_AFTER_CONFIGURE_CALLBACK}")"
        run "${DEF_AFTER_CONFIGURE_CALLBACK}"
    fi
}


after_make_callback () {
    if [ ! -z "${DEF_AFTER_MAKE_CALLBACK}" ]; then
        debug "Running after make callback: $(distinct d "${DEF_AFTER_MAKE_CALLBACK}")"
        run "${DEF_AFTER_MAKE_CALLBACK}"
    fi
}


after_install_callback () {
    if [ ! "${DEF_AFTER_INSTALL_CALLBACK}" = "" ]; then
        debug "After install callback: $(distinct d "${DEF_AFTER_INSTALL_CALLBACK}")"
        run "${DEF_AFTER_INSTALL_CALLBACK}"
    fi
}


build_all () {
    # Update definitions and perform more checks
    check_requirements

    PATH=${DEFAULT_PATH}
    for _bund_name in ${BUNDLES}; do
        _specified="${_bund_name}" # store original value of user input
        _bund_name="$(lowercase ${_bund_name})"
        load_defaults
        validate_alternatives "${_bund_name}"
        load_defs "${_bund_name}" # prevent installation of requirements of disabled _defname:
        check_disabled "${DEF_DISABLE_ON}" # after which just check if it's not disabled
        _pref_base="$(${BASENAME_BIN} ${PREFIX} 2>/dev/null)"
        if [ ! "${ALLOW}" = "1" -a \
             ! -z "${_pref_base}" -a \
             "/" != "${_pref_base}" ]; then
            warn "Bundle: $(distinct w ${_bund_name}) disabled on architecture: $(distinct w ${OS_TRIPPLE})"
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

                _an_archive="${_common_lowercase}-${DEF_VERSION}${DEFAULT_ARCHIVE_EXT}"
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
                            debug "$(distinct n ${_common_lowercase}) bundle is installed with version: $(distinct n ${_already_installed_version})"
                        else
                            warn "$(distinct w ${_common_lowercase}) bundle is installed with version: $(distinct w ${_already_installed_version}), different from defined: $(distinct w "${DEF_VERSION}")"
                        fi
                        export DONT_BUILD_BUT_DO_EXPORTS=YES
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
    note "Pushing archive #$(distinct n ${_bpshortsha}) to remote repository with address: ${_bpaddress}"
    debug "name: ${_uniqname}, bundle_file: ${_bpbundle_file}"
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

            retry "${SCP_BIN} ${DEFAULT_SSH_OPTS} ${DEFAULT_SCP_OPTS} -P ${MAIN_PORT} ${_fin_snapfile} ${MAIN_USER}@${_psmirror}:${MAIN_BINARY_PREFIX}/${COMMON_BINARY_REMOTE}/${_fin_snapfile}.partial"
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
