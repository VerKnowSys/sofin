load_defs () {
    _definitions=${*}
    if [ -z "${_definitions}" ]; then
        error "No definition name specified!"
    else
        for _given_def in ${_definitions}; do
            _name_base="${_given_def##*/}"
            _def="$(lowercase "${_name_base}")"
            if [ -e "${DEFINITIONS_DIR}${_def}${DEFAULT_DEF_EXT}" ]; then
                . "${DEFINITIONS_DIR}${_def}${DEFAULT_DEF_EXT}"

            elif [ -e "${DEFINITIONS_DIR}${_def}" ]; then
                . "${DEFINITIONS_DIR}${_def}"
                _given_def="$(${PRINTF_BIN} '%s' "${_def}" | eval "${CUTOFF_DEF_EXT_GUARD}")"

            else
                # validate available alternatives and quit no matter the result
                show_alt_definitions_and_exit "${_given_def}"
            fi

            # if definition lacks definition of DEF_POSTFIX, after loading
            # the definition file, try to infer DEF_POSTFIX:
            validate_def_postfix "${_given_def}" "${DEF_NAME}"

            # check disabled definition state
            validate_definition_disabled "${DEF_DISABLE_ON}"

        done
    fi

    if [ "${DEF_TYPE}" = "meta" ]; then
        # Skip validations for "not real definition":
        return 0
    fi

    # Perform several sanity checks here..
    for _required_field in  "DEF_NAME=${DEF_NAME}" \
                            "DEF_NAME_DEF_POSTFIX=${DEF_NAME}${DEF_POSTFIX}" \
                            "DEF_VERSION=${DEF_VERSION}" \
                            "DEF_SHA_OR_DEF_GIT_MODE=${DEF_SHA}${DEF_GIT_MODE}" \
                            "DEF_COMPLIANCE=${DEF_COMPLIANCE}" \
                            "DEF_SOURCE_PATH=${DEF_SOURCE_PATH}" \
                            "SYSTEM_VERSION=${SYSTEM_VERSION}" \
                            "OS_TRIPPLE=${OS_TRIPPLE}" \
                            "SYS_SPECIFIC_BINARY_REMOTE=${SYS_SPECIFIC_BINARY_REMOTE}";
        do
            unset _valid_checks
            for _check in   "DEF_NAME" \
                            "DEF_NAME_DEF_POSTFIX" \
                            "DEF_VERSION" \
                            "DEF_SHA_OR_DEF_GIT_MODE" \
                            "DEF_COMPLIANCE" \
                            "DEF_SOURCE_PATH" \
                            "SYSTEM_VERSION" \
                            "OS_TRIPPLE" \
                            "SYS_SPECIFIC_BINARY_REMOTE";
                do
                    if [ "${_check}=" = "${_required_field}" -o \
                         "${_check}=." = "${_required_field}" -o \
                         "${_check}=${DEFAULT_DEF_EXT}" = "${_required_field}" ]; then
                        error "Empty or wrong value for required field: $(diste "${_check}") from definition: $(diste "${_def}")."
                    else
                        # gather passed checks, but print it only once..
                        if [ -z "${_valid_checks}" ]; then
                            _valid_checks="${_check}"
                        else
                            _valid_checks="${_check}, ${_valid_checks}"
                        fi
                    fi
                done
        done
    debug "Requirements validated: $(distd "${_valid_checks}")"
    unset _def _definitions _check _required_field _name_base _given_def _valid_checks
}


load_defaults () {
    . "${DEFINITIONS_DEFAULTS}"
    if [ -z "${COMPLIANCE_CHECK}" ]; then
        # check definition/defaults compliance version
        ${PRINTF_BIN} "${SOFIN_VERSION}" | eval "${EGREP_BIN} '${DEF_COMPLIANCE}'" >/dev/null 2>&1
        if [ "${?}" = "0" ]; then
            COMPLIANCE_CHECK="passed"
        else
            error "Versions mismatch!. DEF_COMPILIANCE='$(diste "${DEF_COMPLIANCE}")' and SOFIN_VERSION='$(diste "${SOFIN_VERSION}")' should match.\n  Hint: Update your definitions repository to latest version!"
        fi
    fi
}


inherit () {
    _inhnm="$(${PRINTF_BIN} '%s' "${1}" | eval "${CUTOFF_DEF_EXT_GUARD}")"
    debug "Loading parent definition: $(distd "${_inhnm}")"
    . ${DEFINITIONS_DIR}${_inhnm}${DEFAULT_DEF_EXT}
}


update_defs () {
    if [ -n "${USE_UPDATE}" ]; then
        debug "Definitions update skipped on demand"
        return
    fi
    try "${MKDIR_BIN} -p ${LOGS_DIR}"
    _cwd="$(${PWD_BIN} 2>/dev/null)"
    if [ ! -x "${GIT_BIN}" ]; then
        note "Installing initial definition list from tarball to cache dir: $(distn "${CACHE_DIR}")"
        try "${RM_BIN} -rf ${CACHE_DIR}${DEFINITIONS_BASE}"
        try "${MKDIR_BIN} -p ${LOGS_DIR} ${CACHE_DIR}${DEFINITIONS_BASE}"
        _initial_defs="${MAIN_SOURCE_REPOSITORY}${DEFINITIONS_INITIAL_FILE_NAME}${DEFAULT_ARCHIVE_TARBALL_EXT}"
        debug "Fetching latest tarball with initial definitions from: $(distd "${_initial_defs}")"
        _out_file="${FILE_CACHE_DIR}${DEFINITIONS_INITIAL_FILE_NAME}${DEFAULT_ARCHIVE_TARBALL_EXT}"
        retry "${FETCH_BIN} -o ${_out_file} ${FETCH_OPTS} '${_initial_defs}'" && \
            try "${TAR_BIN} -xJf ${_out_file} --directory ${CACHE_DIR}${DEFINITIONS_BASE}" && \
                try "${RM_BIN} -vrf ${_initial_defs}" && \
                    return
    fi
    if [ -d "${CACHE_DIR}${DEFINITIONS_BASE}/${DEFAULT_GIT_DIR_NAME}" -a \
         -f "${DEFINITIONS_DEFAULTS}" ]; then
        cd "${CACHE_DIR}${DEFINITIONS_BASE}"
        _def_cur_branch="$(${GIT_BIN} rev-parse --abbrev-ref HEAD 2>/dev/null)"
        _def_head="$(${CAT_BIN} "${CACHE_DIR}${DEFINITIONS_BASE}/${DEFAULT_GIT_DIR_NAME}/refs/heads/${_def_cur_branch}" 2>/dev/null)"
        if [ -z "${_def_head}" ]; then
            _def_head="HEAD"
        fi
        debug "State of definitions repository was re-set to: $(distd "${_def_head}")"
        if [ "${_def_cur_branch}" != "${BRANCH}" ]; then # use _def_cur_branch value if branch isn't matching default branch
            debug "Checking out branch: $(distd "${_def_cur_branch}")"
            try "${GIT_BIN} checkout ${DEFAULT_GIT_OPTS} -b ${_def_cur_branch}" || \
                try "${GIT_BIN} checkout ${DEFAULT_GIT_OPTS} ${_def_cur_branch}" || \
                    warn "Can't checkout branch: $(distw "${_def_cur_branch}")"

            try "${GIT_BIN} pull ${DEFAULT_GIT_OPTS} origin ${_def_cur_branch}" && \
                note "Branch: $(distn "${_def_cur_branch}") is now at: $(distn "${_def_head}")" && \
                return

            ${PRINTF_BIN} "${ColorRed}%s${ColorReset}\n$(fill)\n" "Error occured: Update from branch: $(diste "${BRANCH}") of repository: $(diste "${REPOSITORY}") wasn't possible. Log's below:"
            show_log_if_available
            return

        else # else use default branch
            debug "Using default branch: $(distd "${BRANCH}")"
            if [ "${_def_cur_branch}" != "${BRANCH}" ]; then
                try "${GIT_BIN} checkout ${DEFAULT_GIT_OPTS} -b ${BRANCH}" || \
                    try "${GIT_BIN} checkout ${DEFAULT_GIT_OPTS} ${BRANCH}" || \
                        warn "Can't checkout branch: $(distw "${BRANCH}")"
            fi
            try "${GIT_BIN} pull ${DEFAULT_GIT_OPTS} origin ${BRANCH}" && \
                note "Branch: $(distn "${BRANCH}") is at: $(distn "${_def_head}")" && \
                    return

            ${PRINTF_BIN} "${ColorRed}%s${ColorReset}\n$(fill)\n" "Error occured: Update from branch: $(diste "${BRANCH}") of repository: $(diste "${REPOSITORY}") wasn't possible. Log's below:"
            show_log_if_available
            return
        fi
    else
        # create cache; clone definitions repository:
        cd "${CACHE_DIR}"
        debug "Cloning repository: $(distd "${REPOSITORY}") from branch: $(distd "${BRANCH}"); LOGS_DIR: $(distd "${LOGS_DIR}"), CACHE_DIR: $(distd "${CACHE_DIR}")"
        try "${RM_BIN} -vrf ${DEFINITIONS_BASE}"
        try "${GIT_BIN} clone ${DEFAULT_GIT_CLONE_OPTS} ${REPOSITORY} ${DEFINITIONS_BASE}" || \
            error "Error cloning branch: $(diste "${BRANCH}") of repository: $(diste "${REPOSITORY}"). Please make sure that given repository and branch are valid!"
        cd "${CACHE_DIR}${DEFINITIONS_BASE}"
        _def_cur_branch="$(${GIT_BIN} rev-parse --abbrev-ref HEAD 2>/dev/null)"
        if [ "${BRANCH}" != "${_def_cur_branch}" ]; then
            try "${GIT_BIN} checkout ${DEFAULT_GIT_OPTS} -b ${BRANCH}" || \
                try "${GIT_BIN} checkout ${DEFAULT_GIT_OPTS} ${BRANCH}" || \
                    warn "Can't checkout branch: $(distw "${BRANCH}")"
        fi
        _def_head="$(${CAT_BIN} "${CACHE_DIR}${DEFINITIONS_BASE}/${DEFAULT_GIT_DIR_NAME}/refs/heads/${_def_cur_branch}" 2>/dev/null)"
        if [ -z "${_def_head}" ]; then
            _def_head="HEAD"
        fi
        try "${GIT_BIN} pull --progress origin ${BRANCH}" && \
            note "Branch: $(distn "${BRANCH}") is currenly at: $(distn "${_def_head}") in repository: $(distn "${REPOSITORY}")" && \
                    return
    fi
    cd "${_cwd}"
    unset _def_head _def_branch _def_cur_branch _out_file _cwd
}


reset_defs () {
    create_dirs
    _cwd="$(${PWD_BIN} 2>/dev/null)"
    cd "${DEFINITIONS_DIR}"
    try "${GIT_BIN} reset --hard HEAD"
    if [ -z "${BRANCH}" ]; then
        BRANCH="stable"
    fi
    _rdefs_branch="$(${CAT_BIN} "${CACHE_DIR}${DEFINITIONS_BASE}/${DEFAULT_GIT_DIR_NAME}/refs/heads/${BRANCH}" 2>/dev/null)"
    if [ -z "${_rdefs_branch}" ]; then
        _rdefs_branch="HEAD"
    fi
    note "Definitions repository reset to: $(distn "${_rdefs_branch}")"
    for line in $(${GIT_BIN} status --short 2>/dev/null | ${CUT_BIN} -f2 -d' ' 2>/dev/null); do
        unset _add_opt
        try "${PRINTF_BIN} '%s' \"${line}\" 2>/dev/null | ${EGREP_BIN} \"patches/\"" && \
            _add_opt="r"
        try "${RM_BIN} -fv${_add_opt} '${line}'" && \
            debug "Removed untracked file${_add_opt:-/dir} from definition repository: $(distd "${line}")"
    done
    update_defs
    cd "${_cwd}"
    unset _rdefs_branch _cwd
}


remove_bundles () {
    _bundle_name=${@}
    if [ -z "${_bundle_name}" ]; then
        error "Second argument with at least one bundle name is required!"
    fi
    # replace + with *
    _bundle_nam="$(${PRINTF_BIN} '%s' "${_bundle_name}" | ${SED_BIN} -e 's#+#*#' 2>/dev/null)"

    # first look for a list with that name:
    if [ -e "${DEFINITIONS_LISTS_DIR}${_bundle_nam}" ]; then
        _picked_bundles="$(${CAT_BIN} ${DEFINITIONS_LISTS_DIR}${_bundle_nam} 2>/dev/null | eval "${NEWLINES_TO_SPACES_GUARD}")"
        debug "Removing list of bundles: $(distd "${_picked_bundles}")"
    else
        _picked_bundles="${_bundle_nam}"
        debug "Removing bundles: $(distd "${_picked_bundles}")"
    fi
    if [ "${_bundle_nam}" != "${_bundle_name}" ]; then
        # Specified + - a wildcard
        _picked_bundles="" # to remove first entry with *
        _found="$(${FIND_BIN} ${SOFTWARE_DIR} -mindepth 1 -maxdepth 1 -iname "${_bundle_nam}" -type d 2>/dev/null)"
        for _bund in ${_found}; do
            _bname="${_bund##*/}"
            _picked_bundles="${_picked_bundles} ${_bname}"
        done
        if [ -z "${_picked_bundles}" ]; then
            debug "No bundles picked? Maybe there's a '+' in definition name? Let's try: $(distd "${_bundle_name}")"
            _picked_bundles="${_bundle_name}" # original name, with + in it
        fi
        unset _found _bund _bname
    fi

    load_defaults
    for _def in ${_picked_bundles}; do
        _given_name="$(capitalize "${_def}")"
        if [ -z "${_given_name}" ]; then
            error "Empty bundle name given as first param!"
        fi
        if [ -d "${SOFTWARE_DIR}${_given_name}" ]; then
            _aname="$(lowercase "${_given_name}")"
            destroy_software_dir "${_given_name}" && \
                debug "Removed bundle: $(distd "${_given_name}")"

            # if removing a single bundle, then look for alternatives. Otherwise, just remove bundle..
            debug "_picked_bundles: ${_picked_bundles}, _given_name: ${_given_name}"
            if [ "${_picked_bundles}" = "${_given_name}" ]; then
                debug "Looking for other installed versions of: $(distd "${_aname}"), that might be exported automatically.."
                _inname="$(${PRINTF_BIN} '%s\n' "$(lowercase "${_given_name}")" | ${SED_BIN} 's/[0-9]*//g' 2>/dev/null)"
                _alternative="$(${FIND_BIN} ${SOFTWARE_DIR} -mindepth 1 -maxdepth 1 -type d -iname "${_inname}*" -not -name "${_given_name}" 2>/dev/null | ${SED_BIN} 's/^.*\///g' 2>/dev/null | ${HEAD_BIN} -n1 2>/dev/null)"
            fi

            if [ -n "${_alternative}" -a \
                 -f "${SOFTWARE_DIR}${_alternative}/$(lowercase "${_alternative}")${DEFAULT_INST_MARK_EXT}" ]; then
                note "Updating environment with already installed alternative: $(distn "${_alternative}")"
                export_binaries "${_alternative}"
                finalize
                unset _given_name _inname _alternative _aname _def
                return 0 # Just pick first available alternative bundle

            elif [ -z "${_alternative}" ]; then
                debug "No alternative: $(distd "${_alternative}") != $(distd "${_given_name}")"
            fi
        fi
    done
    unset _given_name _inname _alternative _aname _def _picked_bundles _bundle_name _bundle_nam
}


available_definitions () {
    if [ -d "${DEFINITIONS_DIR}" ]; then
        cd "${DEFINITIONS_DIR}"
        _alldefs="$(${FIND_BIN} ${DEFINITIONS_DIR} -mindepth 1 -maxdepth 1 -type f -name "*${DEFAULT_DEF_EXT}" 2>/dev/null)"
        permnote "All definitions defined in current cache: $(distn "$(${LS_BIN} -m *def 2>/dev/null | eval "${CUT_TRAILING_SPACES_GUARD}")" "${ColorReset}")"
    fi
    if [ -d "${DEFINITIONS_LISTS_DIR}" ]; then
        cd "${DEFINITIONS_LISTS_DIR}"
        permnote "Available lists: $(distn "$(${LS_BIN} -m * 2>/dev/null | ${SED_BIN} "s/${DEFAULT_DEF_EXT}//g" 2>/dev/null)" "${ColorReset}")"
    fi
    note "Definitions count: $(distn "$(${PRINTF_BIN} '%s' "${_alldefs:-0}" | eval "${FILES_COUNT_GUARD}")")"
}


make_exports () {
    _export_bin="${1}"
    _bundle_name="$(capitalize "${2}")"
    if [ -z "${_export_bin}" ]; then
        error "First argument with $(diste "exported-bin") is required!"
    fi
    if [ -z "${_bundle_name}" ]; then
        error "Second argument with $(diste "BundleName") is required!"
    fi
    for _bindir in "/bin/" "/sbin/" "/libexec/"; do
        debug "Looking into bundle binary dir: $(distd "${SOFTWARE_DIR}${_bundle_name}${_bindir}")"
        if [ -e "${SOFTWARE_DIR}${_bundle_name}${_bindir}${_export_bin}" ]; then
            note "Exporting binary: $(distn "${SOFTWARE_DIR}${_bundle_name}${_bindir}${_export_bin}")"
            _cdir="$(${PWD_BIN} 2>/dev/null)"
            cd "${SOFTWARE_DIR}${_bundle_name}${_bindir}"
            try "${MKDIR_BIN} -p ${SOFTWARE_DIR}${_bundle_name}/exports" # make sure exports dir exists
            try "${LN_BIN} -vfs ..${_bindir}/${_export_bin} ../exports/${_export_bin}"
            cd "${_cdir}"
            unset _cdir _bindir _bundle_name _export_bin
            return
        else
            debug "Export not found: $(distd "${SOFTWARE_DIR}${_bundle_name}${_bindir}${_export_bin}")"
        fi
    done
    error "No executable to export from bin paths of: $(diste "${_bundle_name}/\{bin,sbin,libexec\}/${_export_bin}")"
}


show_outdated () {
    create_dirs
    load_defaults
    if [ -d "${SOFTWARE_DIR}" ]; then
        for _prefix in $(${FIND_BIN} ${SOFTWARE_DIR} -mindepth 1 -maxdepth 1 -type d -not -name ".*" 2>/dev/null); do
            _bundle="$(lowercase "${_prefix##*/}")"
            debug "Bundle name: ${_bundle}, Prefix: ${_prefix}"

            if [ ! -f "${_prefix}/${_bundle}${DEFAULT_INST_MARK_EXT}" ]; then
                warn "Bundle: $(distw "${_bundle}") is not yet installed or damaged."
                continue
            fi
            _bund_vers="$(${CAT_BIN} "${_prefix}/${_bundle}${DEFAULT_INST_MARK_EXT}" 2>/dev/null)"
            if [ ! -f "${DEFINITIONS_DIR}${_bundle}${DEFAULT_DEF_EXT}" ]; then
                warn "No such bundle found: $(distw "${_bundle}")"
                continue
            fi
            load_defs "${_bundle}"
            check_version "${_bund_vers}" "${DEF_VERSION}" "${_bundle}"
        done
    fi

    if [ "${FOUND_OUTDATED}" = "YES" ]; then
        exit ${ERRORCODE_TASK_FAILURE}
    else
        note "Installed bundles seems to be recent"
    fi
    unset _bund_vers
}


wipe_remote_archives () {
    _bund_names=${@}
    _ans="YES"
    if [ -z "${USE_FORCE}" ]; then
        warn "Are you sure you want to wipe binary bundles: $(distw "${_bund_names}") from binary repository: $(distw "${MAIN_BINARY_REPOSITORY}")? (Type $(distw YES) to confirm)"
        read _ans
    fi
    if [ "${_ans}" = "YES" ]; then
        cd "${SOFTWARE_DIR}"
        for _wr_element in ${_bund_names}; do
            _lowercase_element="$(lowercase "${_wr_element}")"
            _remote_ar_name="${_wr_element}-"
            _wr_dig="$(${HOST_BIN} A "${MAIN_SOFTWARE_ADDRESS}" 2>/dev/null | ${GREP_BIN} 'Address:' 2>/dev/null | eval "${HOST_ADDRESS_GUARD}")"
            if [ -z "${_wr_dig}" ]; then
                error "No mirrors found in address: $(diste "${MAIN_SOFTWARE_ADDRESS}")"
            fi
            debug "Using defined mirror(s): $(distd "${_wr_dig}")"
            for _wr_mirr in ${_wr_dig}; do
                note "Wiping out remote: $(distn "${_wr_mirr}") binary archives: $(distn "${_remote_ar_name}")"
                retry "${SSH_BIN} ${DEFAULT_SSH_OPTS} -p ${MAIN_PORT} ${MAIN_USER}@${_wr_mirr} \"${FIND_BIN} ${MAIN_BINARY_PREFIX}/${SYS_SPECIFIC_BINARY_REMOTE} -iname '${_remote_ar_name}' -delete\""
            done
        done
    else
        error "Aborted remote wipe of: $(diste "${_bund_names}")"
    fi
    unset _wr_mirr _remote_ar_name _wr_dig _lowercase_element _wr_element
}


create_apple_bundle_if_necessary () { # XXXXXX
    if [ -n "${DEF_APPLE_BUNDLE}" -a \
         "Darwin" = "${SYSTEM_NAME}" ]; then
        _aname="$(lowercase "${DEF_NAME}${DEF_POSTFIX}")"
        DEF_NAME="$(${PRINTF_BIN} '%s' "${DEF_NAME}" | ${CUT_BIN} -c1 2>/dev/null | ${TR_BIN} '[a-z]' '[A-Z]' 2>/dev/null)$(${PRINTF_BIN} '%s' "${DEF_NAME}" | ${SED_BIN} 's/^[a-zA-Z]//' 2>/dev/null)"
        DEF_BUNDLE_NAME="${PREFIX}.app"
        note "Creating Apple bundle: $(distn "${DEF_NAME}") in: $(distn "${DEF_BUNDLE_NAME}")"
        ${MKDIR_BIN} -p "${DEF_BUNDLE_NAME}/libs" "${DEF_BUNDLE_NAME}/Contents" "${DEF_BUNDLE_NAME}/Contents/Resources/${_aname}" "${DEF_BUNDLE_NAME}/exports" "${DEF_BUNDLE_NAME}/share"
        try "${CP_BIN} -R ${PREFIX}/${DEF_NAME}.app/Contents/* ${DEF_BUNDLE_NAME}/Contents/"
        try "${CP_BIN} -R ${PREFIX}/bin/${_aname} ${DEF_BUNDLE_NAME}/exports/"
        for lib in $(${FIND_BIN} "${PREFIX}" -name '*.dylib' -type f 2>/dev/null); do
            try "${CP_BIN} -vf ${lib} ${DEF_BUNDLE_NAME}/libs/"
        done

        # if symlink exists, remove it.
        try "${RM_BIN} -vf ${DEF_BUNDLE_NAME}/lib"
        try "${LN_BIN} -vs ${DEF_BUNDLE_NAME}/libs ${DEF_BUNDLE_NAME}/lib"

        # move data, and support files from origin:
        try "${CP_BIN} -vR ${PREFIX}/share/${_aname} ${DEF_BUNDLE_NAME}/share/"
        try "${CP_BIN} -vR ${PREFIX}/lib/${_aname} ${DEF_BUNDLE_NAME}/libs/"

        cd "${DEF_BUNDLE_NAME}/Contents"
        try "${TEST_BIN} -L MacOS || ${LN_BIN} -s ../exports MacOS"
        debug "Creating relative libraries search path"
        cd "${DEF_BUNDLE_NAME}"
        note "Processing exported binary: $(distn "${i}")" # XXX: i?
        try "${SOFIN_LIBBUNDLE_BIN} -x ${DEF_BUNDLE_NAME}/Contents/MacOS/${_aname}"
    fi
}


strip_bundle () {
    _sbfdefinition_name="${1}"
    if [ -z "${_sbfdefinition_name}" ]; then
        error "No definition name specified as first param!"
    fi
    load_defaults
    load_defs "${_sbfdefinition_name}"
    if [ -z "${PREFIX}" ]; then
        PREFIX="${SOFTWARE_DIR}$(capitalize "${DEF_NAME}${DEF_POSTFIX}")"
        debug "An empty prefix for: $(distd "${_sbfdefinition_name}"). Resetting to: $(distd "${PREFIX}")"
    fi

    _dirs_to_strip=""
    case "${DEF_STRIP}" in
        all|ALL)
            debug "$(distd "${_sbfdefinition_name}"): Strip both binaries and libraries."
            _dirs_to_strip="${PREFIX}/bin ${PREFIX}/sbin ${PREFIX}/lib ${PREFIX}/libexec"
            ;;

        exports|export|bins|binaries|bin|BIN|BINS)
            debug "$(distd "${_sbfdefinition_name}"): Strip exported binaries only"
            _dirs_to_strip="${PREFIX}/bin ${PREFIX}/sbin ${PREFIX}/libexec"
            ;;

        libs|lib|libexec|LIB|LIBS)
            debug "$(distd "${_sbfdefinition_name}"): Strip libraries only"
            _dirs_to_strip="${PREFIX}/lib"
            ;;

        *)
            warn "$(distw "${_sbfdefinition_name}"): Strip nothing? Valid options are: ALL | BIN | LIB | NO"
            ;;
    esac
    if [ "${DEF_STRIP}" != "no" ]; then
        if [ -z "${DEBUGBUILD}" ]; then
            _counter="0"
            for _stripdir in ${_dirs_to_strip}; do
                if [ -d "${_stripdir}" ]; then
                    _tbstripfiles=$(${FIND_BIN} ${_stripdir} -maxdepth 1 -type f 2>/dev/null)
                    for _file in ${_tbstripfiles}; do
                        _bundlower="$(lowercase "${DEF_NAME}${DEF_POSTFIX}")"
                        if [ -n "${_bundlower}" ]; then
                            ${STRIP_BIN} ${DEFAULT_STRIP_OPTS} ${_file} > "${LOG}-${_bundlower}.strip" 2>> "${LOG}-${_bundlower}.strip"
                        else
                            ${STRIP_BIN} ${DEFAULT_STRIP_OPTS} ${_file} > "${LOG}.strip" 2>/dev/null
                        fi
                        if [ "${?}" = "0" ]; then
                            _counter="${_counter} + 1"
                        else
                            _counter="${_counter} - 1"
                        fi
                    done
                fi
            done
            _sbresult="$(${PRINTF_BIN} '%s\n' "${_counter}" | ${BC_BIN} 2>/dev/null)"
            if [ "${_sbresult}" -lt "0" -o \
                 -z "${_sbresult}" ]; then
                _sbresult="0"
            fi
            debug "$(distd "${_sbresult}") files were stripped"
        else
            warn "Symbol strip disabled for debug build."
        fi
    fi
    unset _sbfdefinition_name _dirs_to_strip _sbresult _counter _files _stripdir _bundlower
}


track_useful_and_useless_files () {
    if [ "${DEF_CLEAN_USELESS}" = "YES" ]; then
        unset _fordel
        # we shall clean the bundle, from useless files..
        if [ -n "${PREFIX}" ]; then
            # step 0: clean defaults side DEF_DEFAULT_USELESS entries only if DEF_USEFUL is empty
            if [ -n "${DEF_DEFAULT_USELESS}" -a \
                 -z "${DEF_USEFUL}" ]; then
                for _cu_pattern in ${DEF_DEFAULT_USELESS}; do
                    if [ -e "${PREFIX}/${_cu_pattern}" ]; then
                        if [ -z "${_fordel}" ]; then
                            _fordel="${PREFIX}/${_cu_pattern}"
                        else
                            _fordel="${_fordel} ${PREFIX}/${_cu_pattern}"
                        fi
                    # else
                    # debug "Not existent pattern.."
                    fi
                done
            fi

            # step 1: clean definition side DEF_USELESS entries only if DEF_USEFUL is empty
            if [ -n "${DEF_USELESS}" ]; then
                for _cu_pattern in ${DEF_USELESS}; do
                    if [ -n "${_cu_pattern}" ]; then
                        if [ -z "${_fordel}" ]; then
                            _fordel="${PREFIX}/${_cu_pattern}"
                        else
                            _fordel="${_fordel} ${PREFIX}/${_cu_pattern}"
                        fi
                    fi
                done
            fi
        else
            error "No $(distw "PREFIX") defined! Something went wrong (at least)!"
        fi

        unset _dbg_exp_lst
        for _cu_dir in bin sbin libexec; do
            if [ -d "${PREFIX}/${_cu_dir}" ]; then
                _cuall_binaries=$(${FIND_BIN} ${PREFIX}/${_cu_dir} -mindepth 1 -maxdepth 1 -type f -or -type l 2>/dev/null)
                for _cufile in ${_cuall_binaries}; do
                    unset _cu_commit_removal
                    _cubase="${_cufile##*/}" # NOTE: faster "basename"
                    if [ -e "${PREFIX}/exports/${_cubase}" ]; then
                        if [ -z "${_dbg_exp_lst}" ]; then
                            _dbg_exp_lst="${_cubase}"
                        else
                            _dbg_exp_lst="${_dbg_exp_lst} ${_cubase}"
                        fi
                    else
                        # traverse through DEF_USEFUL for _cufile patterns required by software but not exported
                        for _is_useful in ${DEF_USEFUL}; do
                            # NOTE: split each by /, first argument will be subpath f.i. "bin"; second one - file pattern
                            # NOTE: legacy shell string ops sneak peak below:
                            #   ${var#*SubStr}  # will drop begin of string upto first occur of `SubStr`
                            #   ${var##*SubStr} # will drop begin of string upto last occur of `SubStr`
                            #   ${var%SubStr*}  # will drop part of string from last occur of `SubStr` to the end
                            #   ${var%%SubStr*} # will drop part of string from first occur of `SubStr` to the end
                            _subdir="${_is_useful%/*}"
                            _pattern="${_is_useful#*/}"
                            # if subdir matches current prefix subdir and pattern..
                            if [ "${_cu_dir}" = "${_subdir}" ]; then
                                ${PRINTF_BIN} '%s\n' "${_cufile}" 2>/dev/null | ${EGREP_BIN} ".*(.${_pattern}).*" >/dev/null 2>&1
                                if [ "${?}" = "0" ]; then
                                    debug "got: '$(distd "${_cufile}")' match with: $(distd "${_subdir}") ~= '$(distd ".*(.${_pattern}).*")'"
                                    _cu_commit_removal=NO
                                    break; # we got match - one confirmation is enough!
                                fi
                            fi
                        done
                        if [ -z "${_cu_commit_removal}" ]; then
                            if [ -z "${_fordel}" ]; then
                                _fordel="${_cufile}"
                            else
                                _fordel="${_cufile} ${_fordel}"
                            fi
                        else
                            debug "Useful file left intact: $(distd "${_cufile}")"
                        fi
                    fi
                done
            fi
        done

        if [ -n "${_dbg_exp_lst}" ]; then
            debug "Found exports: $(distd "${_dbg_exp_lst}")"
        else
            debug "Empty exports list?"
        fi

        remove_useless "${_fordel}" && \
            debug "Useless files were wiped."
    else
        debug "Useless files cleanup skipped since DEF_CLEAN_USELESS=$(distd "${DEF_CLEAN_USELESS:-''}")!"
    fi
    unset _cu_pattern _cufile _cuall_binaries _cu_commit_removal _cubase _fordel _dbg_exp_lst
}


conflict_resolve () {
    debug "Resolving conflicts for: $(distd "${DEF_CONFLICTS_WITH}")"
    if [ -n "${DEF_CONFLICTS_WITH}" ]; then
        debug "Resolving possible conflicts with: $(distd "${DEF_CONFLICTS_WITH}")"
        for _cr_app in ${DEF_CONFLICTS_WITH}; do
            _crfind_s="$(${FIND_BIN} ${SOFTWARE_DIR} -maxdepth 1 -type d -iname "${_cr_app}*" 2>/dev/null)"
            for _cr_name in ${_crfind_s}; do
                _crn="${_cr_name##*/}"
                if [ -e "${_cr_name}/exports" \
                     -a "${_crn}" != "${DEF_NAME}" \
                     -a "${_crn}" != "${DEF_NAME}${DEF_POSTFIX}" \
                ]; then
                    ${MV_BIN} "${_cr_name}/exports" "${_cr_name}/exports-disabled" && \
                        debug "Resolved conflict with: $(distn "${_crn}")"
                fi
            done
        done
    fi
    unset _crfind_s _cr_app _cr_name _crn
}


export_binaries () {
    _ebdef_name="${1}"
    if [ -z "${_ebdef_name}" ]; then
        error "No definition name specified as first param for export_binaries()!"
    fi
    load_defs "${_ebdef_name}"
    conflict_resolve

    if [ -z "${PREFIX}" ]; then
        PREFIX="${SOFTWARE_DIR}$(capitalize "${DEF_NAME}${DEF_POSTFIX}")"
        debug "An empty prefix in export_binaries() for $(distd "${_ebdef_name}"). Resetting to: $(distd "${PREFIX}")"
    fi
    if [ -d "${PREFIX}/exports-disabled" ]; then # just bring back disabled exports
        debug "Moving $(distd "${PREFIX}/exports-disabled") to $(distd "${PREFIX}/exports")"
        try "${MV_BIN} -v ${PREFIX}/exports-disabled ${PREFIX}/exports"
    fi
    if [ -z "${DEF_EXPORTS}" ]; then
        note "Defined no exports of prefix: $(distn "${PREFIX}")"
    else
        _a_name="$(lowercase "${DEF_NAME}${DEF_POSTFIX}")"
        _an_amount="$(${PRINTF_BIN} '%s\n' "${DEF_EXPORTS}" | ${WC_BIN} -w 2>/dev/null | ${TR_BIN} -d '\t|\r|\ ' 2>/dev/null)"
        debug "Exporting $(distd "${_an_amount}") binaries of prefix: $(distd "${PREFIX}")"
        try "${MKDIR_BIN} -p ${PREFIX}/exports"
        _expolist=""
        for exp in ${DEF_EXPORTS}; do
            for dir in "/bin/" "/sbin/" "/libexec/"; do
                _afile_to_exp="${PREFIX}${dir}${exp}"
                if [ -f "${_afile_to_exp}" ]; then # a file
                    if [ -x "${_afile_to_exp}" ]; then # and it's executable'
                        _acurrdir="$(${PWD_BIN} 2>/dev/null)"
                        cd "${PREFIX}${dir}"
                        try "${LN_BIN} -vfs ..${dir}${exp} ../exports/${exp}"
                        cd "${_acurrdir}"
                        _expo_elem="${_afile_to_exp##*/}"
                        _expolist="${_expolist} ${_expo_elem}"
                    fi
                fi
            done
        done
        debug "List of exports: $(distd "${_expolist}")"
    fi
    unset _expo_elem _acurrdir _afile_to_exp _an_amount _a_name _expolist _ebdef_name
}


hack_def () {
    create_dirs
    if [ -z "${1}" ]; then
        error "No name of pattern to hack given!"
    fi
    _hack_pattern="${1}"
    _abeauty_pat="$(distn "*${_hack_pattern}*")"
    _all_hackdirs=$(${FIND_BIN} ${FILE_CACHE_DIR} -type d -mindepth 2 -maxdepth 2 -iname "*${_hack_pattern}*" 2>/dev/null)
    _all_am="$(${PRINTF_BIN} '%s\n' "${_all_hackdirs}" | ${WC_BIN} -l 2>/dev/null | ${TR_BIN} -d '\t|\r|\ ' 2>/dev/null)"
    ${TEST_BIN} -z "${_all_am}" && _all_am="0"
    if [ -z "${_all_hackdirs}" ]; then
        warn "No matching build dirs found for pattern: $(diste "${_abeauty_pat}")"
    else
        note "Sofin will now walk through: $(distn "${_all_am}") build dirs in: $(distn "${FILE_CACHE_DIR}"), that matches pattern: $(distn "${_abeauty_pat}")"
    fi
    for _a_dir in ${_all_hackdirs}; do
        note
        warn "$(fill)"
        warn "Quit viever/ Exit that shell, to continue with next build dir"
        warn "Sofin will now traverse through build logs, looking for errors.."
        _currdir="$(${PWD_BIN} 2>/dev/null)"
        cd "${_a_dir}"
        _found_any=""
        _log_viewer="${LESS_BIN} ${DEFAULT_LESS_OPTIONS} +/error:"
        for _logfile in config.log build.log CMakeFiles/CMakeError.log CMakeFiles/CMakeOutput.log; do
            if [ -f "${_logfile}" ]; then
                _found_any="yes"
                if [ -n "${DEVEL}" ]; then
                    eval "cd ${_a_dir} && ${ZSH_BIN} --login -c '${_log_viewer} ${_logfile}'"
                else
                    debug "No DEVEL set - only entering BUILD_DIR"
                    eval "cd ${_a_dir} && ${ZSH_BIN} --login"
                fi
            fi
        done
        if [ -z "${_found_any}" ]; then
            note "Entering build dir.."
            eval "cd ${_a_dir} && ${ZSH_BIN} --login"
        fi
        cd "${_currdir}"
        warn "---------------------------------------------------------"
    done
    debug "Hack process finished for pattern: $(distd "${_abeauty_pat}")"
    unset _abeauty_pat _currdir _a_dir _logfile _all_hackdirs _all_am _hack_pattern
}


after_unpack_callback () {
    if [ -n "${DEF_AFTER_UNPACK_METHOD}" ]; then
        debug "Evaluating callback DEF_AFTER_UNPACK_METHOD: $(distd "${DEF_AFTER_UNPACK_METHOD}")"
        run "${DEF_AFTER_UNPACK_METHOD}"
    fi
}


after_export_callback () {
    if [ -n "${DEF_AFTER_EXPORT_METHOD}" ]; then
        debug "Evaluating callback DEF_AFTER_EXPORT_METHOD: $(distd "${DEF_AFTER_EXPORT_METHOD}")"
        run "${DEF_AFTER_EXPORT_METHOD}"
    fi
}


after_patch_callback () {
    if [ -n "${DEF_AFTER_PATCH_METHOD}" ]; then
        debug "Evaluating callback DEF_AFTER_PATCH_METHOD: $(distd "${DEF_AFTER_PATCH_METHOD}")"
        run "${DEF_AFTER_PATCH_METHOD}"
    fi
}


after_configure_callback () {
    if [ -n "${DEF_AFTER_CONFIGURE_METHOD}" ]; then
        debug "Evaluating callback DEF_AFTER_CONFIGURE_METHOD: $(distd "${DEF_AFTER_CONFIGURE_METHOD}")"
        run "${DEF_AFTER_CONFIGURE_METHOD}"
    fi
}


after_make_callback () {
    if [ -n "${DEF_AFTER_MAKE_METHOD}" ]; then
        debug "Evaluating callback DEF_AFTER_MAKE_METHOD: $(distd "${DEF_AFTER_MAKE_METHOD}")"
        run "${DEF_AFTER_MAKE_METHOD}"
    fi
}


after_test_callback () {
    if [ -n "${DEF_AFTER_TEST_METHOD}" ]; then
        debug "Evaluating callback DEF_AFTER_TEST_METHOD: $(distd "${DEF_AFTER_TEST_METHOD}")"
        run "${DEF_AFTER_TEST_METHOD}"
    fi
}


after_install_callback () {
    if [ -n "${DEF_AFTER_INSTALL_METHOD}" ]; then
        debug "Evaluating callback DEF_AFTER_INSTALL_METHOD: $(distd "${DEF_AFTER_INSTALL_METHOD}")"
        run "${DEF_AFTER_INSTALL_METHOD}"
    fi
}


traverse_patchlevels () {
    _trav_patches=${*}
    for _patch in ${_trav_patches}; do
        for _level in 0 1 2 3 4 5; do # Up to: -p5
            debug "Applying patch: $(distd "${_patch##*/}"), level: $(distd "${_level}")"
            try "${PATCH_BIN} -p${_level} -N -f -i ${_patch}"
            if [ "${?}" = "0" ]; then # skip applying single patch if it already passed
                debug "Patch: patches$(distd "${_patch##*patches}") applied successfully!"
                break;
            fi
        done
    done
    unset _trav_patches
}


apply_definition_patches () {
    _pcpaname="$(lowercase "${1}")"
    if [ -z "${_pcpaname}" ]; then
        error "First argument with definition name is required!"
    fi
    _common_patches_dir="${DEFINITIONS_DIR}patches/${_app_param}/"
    _platform_patches_dir="${_common_patches_dir}${SYSTEM_NAME}/"
    if [ -d "${_common_patches_dir}" ]; then
        _ps_patches="$(${FIND_BIN} ${_common_patches_dir}* -maxdepth 0 -type f 2>/dev/null)"
        if [ -n "${_ps_patches}" ]; then
            note "   ${NOTE_CHAR} Applying common patches for: $(distn "${_pcpaname}")"
            traverse_patchlevels ${_ps_patches}
        fi
        debug "Checking psp dir: $(distd "${_platform_patches_dir}")"
        if [ -d "${_platform_patches_dir}" ]; then
            _ps_patches="$(${FIND_BIN} ${_platform_patches_dir}* -maxdepth 0 -type f 2>/dev/null)"
            if [ -n "${_ps_patches}" ]; then
                note "   ${NOTE_CHAR} Applying platform specific patches for: $(distn "${_pcpaname}/${SYSTEM_NAME}")"
                traverse_patchlevels ${_ps_patches}
            fi
        fi
    fi
    unset _ps_patches _pspp _level _patch _platform_patches_dir _pcpaname _common_patches_dir
}


clone_or_fetch_git_bare_repo () {
    _source_path="${1}"
    _bare_name="${2}"
    _chk_branch="${3}"
    _build_dir="${4}"
    _git_cached="${GIT_CACHE_DIR}${_bare_name}${DEFAULT_GIT_DIR_NAME}"
    try "${MKDIR_BIN} -p ${GIT_CACHE_DIR}"
    note "   ${NOTE_CHAR} Fetching source repository: $(distn "${_source_path}")"
    try "${GIT_BIN} clone ${DEFAULT_GIT_CLONE_OPTS} --mirror ${_source_path} ${_git_cached}" || \
        try "${GIT_BIN} clone ${DEFAULT_GIT_CLONE_OPTS} --mirror ${_source_path} ${_git_cached}"
    if [ "${?}" = "0" ]; then
        debug "Cloned bare repository: $(distd "${_bare_name}")"
    elif [ -d "${_git_cached}" ]; then
        _cwddd="$(${PWD_BIN} 2>/dev/null)"
        debug "Trying to update  existing bare repository cache in: $(distd "${_git_cached}")"
        cd "${_git_cached}"
        try "${GIT_BIN} fetch ${DEFAULT_GIT_OPTS} origin ${_chk_branch}" || \
            warn "   ${WARN_CHAR} Failed to fetch an update from bare repository: $(distw "${_git_cached}") [branch: $(distw "${_chk_branch}")]"
        cd "${_cwddd}"
    elif [ ! -d "${_git_cached}/branches" -a \
           ! -f "${_git_cached}/config" ]; then
        error "Failed to fetch source repository: $(diste "${_source_path}") [branch: $(diste "${_chk_branch}")]"
    fi

    # bare repository is already cloned, so we just clone from it now..
    _dest_repo="${_build_dir}/${_bare_name}-${_chk_branch}"
    try "${RM_BIN} -rf '${_dest_repo}'"
    debug "Attempting to clone from cached repository: $(distd "${_git_cached}").."
    run "${GIT_BIN} clone ${DEFAULT_GIT_CLONE_OPTS} -b ${_chk_branch} ${_git_cached} ${_dest_repo}" && \
        debug "Cloned branch: $(distd "${_chk_branch}") from cached repository: $(distd "${_git_cached}")"
    unset _git_cached _bare_name _chk_branch _build_dir _dest_repo
}
