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

            # if definition lacks definition of DEF_POSTFIX, after loading
            # the definition file, try to infer DEF_POSTFIX:
            validate_definition_postfix "${_given_def}" "${DEF_NAME}"
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
    debug "Inheritance from parent: $(distinct d "${1}")"
    . ${DEFINITIONS_DIR}${1}${DEFAULT_DEF_EXT}
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
    _ch_dis_name="${1}"
    unset DEFINITION_DISABLED
    # check requirement for disabled state:
    if [ ! -z "${_ch_dis_name}" ]; then
        for _def_disabled in ${_ch_dis_name}; do
            if [ "${SYSTEM_NAME}" = "${_def_disabled}" ]; then
                debug "Disabled: $(distinct d "${_def_disabled}") on $(distinct d "${SYSTEM_NAME}")"
                DEFINITION_DISABLED=YES
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
    _bundle_nam="$@"
    if [ -z "${_bundle_nam}" ]; then
        error "Second argument with at least one bundle name is required!"
    fi
    # first look for a list with that name:
    if [ -e "${LISTS_DIR}$(lowercase "${_bundle_nam}")" ]; then
        _picked_bundles="$(${CAT_BIN} ${LISTS_DIR}${_bundle_nam} 2>/dev/null | eval "${NEWLINES_TO_SPACES_GUARD}")"
        debug "Removing list of bundles: $(distinct d ${_picked_bundles})"
    else
        _picked_bundles="${_bundle_nam}"
        debug "Removing bundles: $(distinct d ${_picked_bundles})"
    fi

    load_defaults
    for _def in ${_picked_bundles}; do
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
                debug "_picked_bundles: ${_picked_bundles}, _given_name: ${_given_name}"
                if [ ! "${_picked_bundles}" = "${_given_name}" ]; then
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
    unset _given_name _inname _alternative _aname _def _picked_bundles
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
    if [ -z "${1}" ]; then
        error "Missing second argument with export app is required!"
    fi
    if [ -z "${2}" ]; then
        error "Missing third argument with source app is required!"
    fi
    _export_bin="${1}"
    _bundle_name="$(capitalize "${2}")"
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
    _bund_names="$@"
    _ans="YES"
    if [ -z "${USE_FORCE}" ]; then
        warn "Are you sure you want to wipe binary bundles: $(distinct w ${_bund_names}) from binary repository: $(distinct w ${MAIN_BINARY_REPOSITORY})? (Type $(distinct w YES) to confirm)"
        read _ans
    fi
    if [ "${_ans}" = "YES" ]; then
        cd "${SOFTWARE_DIR}"
        for _wr_element in ${_bund_names}; do
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
        error "Aborted remote wipe of: $(distinct e "${_bund_names}")"
    fi
    unset _wr_mirr _remote_ar_name _wr_dig _lowercase_element _wr_element
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
            if [ "${_sbresult}" -lt "0" -o \
                 -z "${_sbresult}" ]; then
                _sbresult="0"
            fi
            note "$(distinct n "${_sbresult}") files were stripped"
        else
            warn "Debug build is enabled. Strip skipped"
        fi
    fi
    unset _definition_name _dirs_to_strip _sbresult _counter _files _stripdir _bundlower
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
                _tobermlist=""
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
                            if [ -z "${_tobermlist}" ]; then
                                _tobermlist="${_cufile}"
                            else
                                _tobermlist="${_cufile} ${_tobermlist}"
                            fi
                        else
                            debug "Useful _cufile left intact: $(distinct d ${_cufile})"
                        fi
                    fi
                done
                debug "Removing useless files: $(distinct d "${_tobermlist}")"
                ${RM_BIN} -f ${_tobermlist}
            fi
        done
    else
        debug "Useless files cleanup skipped"
    fi
    unset _cu_pattern _cufile _cuall_binaries _cu_commit_removal _cubase _tobermlist
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
        _a_name="$(lowercase "${DEF_NAME}${DEF_POSTFIX}")"
        _an_amount="$(echo "${DEF_EXPORTS}" | ${WC_BIN} -w 2>/dev/null | ${TR_BIN} -d '\t|\r|\ ' 2>/dev/null)"
        debug "Exporting $(distinct d ${_an_amount}) binaries of prefix: $(distinct d ${PREFIX})"
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
    if [ -z "${1}" ]; then
        error "No name of pattern to hack given!"
    fi
    _hack_pattern="${1}"
    _abeauty_pat="$(distinct n "*${_hack_pattern}*")"
    _all_hackdirs=$(${FIND_BIN} ${CACHE_DIR}cache -type d -mindepth 2 -maxdepth 2 -iname "*${_hack_pattern}*" 2>/dev/null)
    _all_am="$(echo "${_all_hackdirs}" | ${WC_BIN} -l 2>/dev/null | ${TR_BIN} -d '\t|\r|\ ' 2>/dev/null)"
    ${TEST_BIN} -z "${_all_am}" && _all_am="0"
    if [ -z "${_all_hackdirs}" ]; then
        warn "No matching build dirs found for pattern: $(distinct e ${_abeauty_pat})"
    else
        note "Sofin will now walk through: $(distinct n ${_all_am}) build dirs in: $(distinct n ${CACHE_DIR}cache), that matches pattern: $(distinct n ${_abeauty_pat})"
    fi
    for _a_dir in ${_all_hackdirs}; do
        note
        warn "$(fill)"
        warn "Quit viever/ Exit that shell, to continue with next build dir"
        warn "Sofin will now traverse through build logs, looking for errors.."
        _currdir="$(${PWD_BIN} 2>/dev/null)"
        cd "${_a_dir}"
        _found_any=""
        _log_viewer="${LESS_BIN} ${LESS_DEFAULT_OPTIONS} +/error:"
        for _logfile in config.log build.log CMakeFiles/CMakeError.log CMakeFiles/CMakeOutput.log; do
            if [ -f "${_logfile}" ]; then
                _found_any="yes"
                eval "cd ${_a_dir} && ${ZSH_BIN} --login -c '${_log_viewer} ${_logfile}'"
            fi
        done
        if [ -z "${_found_any}" ]; then
            note "Entering build dir.."
            eval "cd ${_a_dir} && ${ZSH_BIN} --login"
        fi
        cd "${_currdir}"
        warn "---------------------------------------------------------"
    done
    debug "Hack process finished for pattern: $(distinct d "${_abeauty_pat}")"
    unset _abeauty_pat _currdir _a_dir _logfile _all_hackdirs _all_am _hack_pattern
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
