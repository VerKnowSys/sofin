#!/usr/bin/env sh


# Unique words of the arguments, first occurrence order kept:
requirements_dedup () {
    printf "%b" "${(j: :)${(u)=*}}"
}


# DEF_REQUIREMENTS of definition ${1} as loading it would leave them,
# without sourcing it: the list of the definition it inherits (recursively,
# at most ${2:-8} levels; cleared by "unset DEF_REQUIREMENTS"), then its own
# top-level DEF_REQUIREMENTS= lines evaluated on top of that list, so
# DEF_REQUIREMENTS="${DEF_REQUIREMENTS} more" extends the parent's.
definition_requirements () {
    local _dr_file="${DEFINITIONS_DIR}/${1}${DEFAULT_DEF_EXT}"
    local _dr_depth="${2:-8}"
    local _dr_parent _dr_lines _dr_reqs=""
    if [ ! -f "${_dr_file}" ]; then
        return 0
    fi
    _dr_parent="$(${AWK_BIN} '/^inherit[ \t]/ { gsub(/["\047]/, "", $2); print $2; exit }' "${_dr_file}" 2>/dev/null)"
    _dr_parent="${_dr_parent%${DEFAULT_DEF_EXT}}"
    if [ -n "${_dr_parent}" ] \
    && [ "${_dr_parent}" != "${1}" ] \
    && [ "${_dr_depth}" -gt 0 ]; then
        _dr_reqs="$(definition_requirements "${_dr_parent}" "$(( _dr_depth - 1 ))")"
    fi
    if ${GREP_BIN} -qE '^unset[[:space:]].*DEF_REQUIREMENTS' "${_dr_file}" 2>/dev/null; then
        _dr_reqs=""
    fi
    _dr_lines="$(${AWK_BIN} '/^DEF_REQUIREMENTS=/ { print $0; }' "${_dr_file}" 2>/dev/null)"
    if [ -n "${_dr_lines}" ]; then
        eval "${_dr_lines//DEF_REQUIREMENTS/_dr_reqs}" >/dev/null 2>/dev/null
    fi
    printf "%b" "${(L)_dr_reqs}"
}


extend_requirement_lists () {
    # @definition list extension support:
    for _req_list in ${=DEF_REQUIREMENTS}; do
        case "${_req_list}" in
            @*) ;;
            *) continue ;; # NOTE: only @lists need expanding
        esac
        _req_list="${_req_list/@/}"
        # NOTE: follows "inherit": @curl-lib lists curl's requirements
        _def_requirements="$(definition_requirements "${_req_list}")"
        _def_requirements="${_def_requirements## }"
        if [ -n "${_def_requirements}" ]; then
            DEF_REQUIREMENTS="${DEF_REQUIREMENTS/@${_req_list}/${_def_requirements} ${_req_list}}"
        else
            DEF_REQUIREMENTS="${DEF_REQUIREMENTS/@${_req_list}/${_req_list}}"
        fi
        unset _req_list _def_requirements
    done
    debug "Final DEF_REQUIREMENTS=${ColorDistinct}${DEF_REQUIREMENTS}${ColorDebug}"
}


load_defs () {
    _definitions="${*}"
    if [ -z "${_definitions}" ]; then
        error "No definition name specified!"
    else
        for _given_def in $(to_iter "${_definitions}"); do
            _name_base="${_given_def##*/}"
            _def="${(L)_name_base}"
            if [ -e "${DEFINITIONS_DIR}/${_def}${DEFAULT_DEF_EXT}" ]; then
                . "${DEFINITIONS_DIR}/${_def}${DEFAULT_DEF_EXT}"
            elif [ -e "${DEFINITIONS_DIR}/${_def#?}${DEFAULT_DEF_EXT}" ]; then
                . "${DEFINITIONS_DIR}/${_def#?}${DEFAULT_DEF_EXT}"
            elif [ -e "${DEFINITIONS_DIR}/${_def}" ]; then
                . "${DEFINITIONS_DIR}/${_def}"
            elif [ -e "${DEFINITIONS_DIR}/${_def#?}" ]; then
                . "${DEFINITIONS_DIR}/${_def#?}"
            else
                # validate available alternatives and quit no matter the result
                show_alt_definitions_and_exit "${_given_def}"
            fi

            while [[ "${DEF_REQUIREMENTS}" == *@* ]]; do
                extend_requirement_lists
            done

            # if definition lacks definition of DEF_SUFFIX, after loading
            # the definition file, try to infer DEF_SUFFIX:
            validate_def_suffix "${_given_def}" "${DEF_NAME}"

            # check disabled definition state
            unset CURRENT_DEFINITION_DISABLED
            validate_definition_disabled

            # deduplicate requirements
            DEF_REQUIREMENTS="${(j: :)${(u)=DEF_REQUIREMENTS}}"

            if [ -z "${USE_NO_UTILS}" ] \
            && [ -n "${CAP_SYS_BUILDHOST}" ]; then
                debug "USE_NO_UTILS environment value is unset! Using available BuildHost utilities!"
                validate_util_availability "${DEF_NAME}${DEF_SUFFIX}"
            fi
        done
    fi

    unset _def _definitions _given_def _name_base
}


load_defaults () {
    env_pedantic
    . "${DEFINITIONS_DEFAULTS}"
    env_forgivable
    if [ -z "${COMPLIANCE_CHECK}" ]; then
        # check definition/defaults compliance version
        printf "%b\n" "${SOFIN_VERSION}" | ${EGREP_BIN} "${DEF_COMPLIANCE}" >/dev/null 2>&1
        if [ "0" = "${?}" ]; then
            COMPLIANCE_CHECK="passed"
        else
            error "Versions mismatch!. DEF_COMPILIANCE='${ColorDistinct}${DEF_COMPLIANCE}${ColorError}' and SOFIN_VERSION='${ColorDistinct}${SOFIN_VERSION}${ColorError}' should match.\n  Hint: Update your definitions repository to latest version!"
        fi
    fi
}


inherit () {
    _inhnm="$(printf "%b\n" "${1}" | eval "${CUTOFF_DEF_EXT_GUARD}")"
    _def_inherit="${DEFINITIONS_DIR}/${_inhnm}${DEFAULT_DEF_EXT}"

    env_pedantic \
        && . "${_def_inherit}" \
            && env_forgivable \
                && debug "Loaded parent definition: ${ColorDistinct}${_def_inherit}${ColorDebug}" \
                    && return 0

    debug "NOT loaded parent definition: ${ColorDistinct}${_def_inherit}${ColorDebug}"
    return 0 # don't throw anything using this function?
}


update_defs () {
    if [ -n "${USE_UPDATE}" ]; then
        debug "Definitions update skipped on demand"
        return 0
    fi
    create_sofin_dirs
    _requested_branch="${BRANCH}"
    BRANCH="${BRANCH:-${DEFAULT_DEFINITIONS_BRANCH}}"
    REPOSITORY="${REPOSITORY:-${DEFAULT_DEFINITIONS_REPOSITORY}}"

    (
    if [ ! -x "${GIT_BIN}" ]; then
        permnote "Installing initial definition list from tarball to cache dir: ${ColorDistinct}${CACHE_DIR}${ColorNote}"
        try "${RM_BIN} -rf ${CACHE_DIR}${DEFINITIONS_BASE}; ${MKDIR_BIN} -p ${LOGS_DIR} ${CACHE_DIR}${DEFINITIONS_BASE}"
        _initial_defs="${MAIN_SOURCE_REPOSITORY}${DEFINITIONS_INITIAL_FILE_NAME}${DEFAULT_ARCHIVE_TARBALL_EXT}"
        debug "Fetching latest tarball with initial definitions from: ${ColorDistinct}${_initial_defs}${ColorDebug}"
        _out_file="${FILE_CACHE_DIR}${DEFINITIONS_INITIAL_FILE_NAME}${DEFAULT_ARCHIVE_TARBALL_EXT}"
        retry "${FETCH_BIN} -o ${_out_file} ${FETCH_OPTS} '${_initial_defs}'" \
            && try "${TAR_BIN} -xf ${_out_file} ${TAR_DIRECTORY_ARG} ${CACHE_DIR}${DEFINITIONS_BASE}" \
                && try "${RM_BIN} -vrf ${_out_file}" \
                    && return 0
    fi
    if [ -d "${CACHE_DIR}${DEFINITIONS_BASE}/${DEFAULT_GIT_DIR_NAME}" ] \
    && [ -f "${DEFINITIONS_DEFAULTS}" ]; then
        set_def_cur_branch_and_head () {
            cd "${CACHE_DIR}${DEFINITIONS_BASE}"
            _def_cur_branch="$(${GIT_BIN} rev-parse --abbrev-ref HEAD 2>/dev/null)"
            _def_head="$(${CAT_BIN} "${CACHE_DIR}${DEFINITIONS_BASE}/${DEFAULT_GIT_DIR_NAME}/refs/heads/${_def_cur_branch}" 2>/dev/null)"
        }

        set_def_cur_branch_and_head
        debug "State of definitions repository was re-set to: ${ColorDistinct}${_def_head}${ColorDebug}"
        if [ -z "${_requested_branch}" ] \
        && [ "${_def_cur_branch}" != "${BRANCH}" ]; then # use _def_cur_branch value if branch isn't matching default branch and no BRANCH was requested
            debug "Checking out branch: ${ColorDistinct}${_def_cur_branch}${ColorDebug}"
            try "${GIT_BIN} checkout -b ${_def_cur_branch}" \
                || try "${GIT_BIN} checkout ${_def_cur_branch}" \
                    || warn "Can't checkout branch: ${ColorDistinct}${_def_cur_branch}${ColorWarning}"

            printf "%b" "${ColorBlue}" >&2
            ${GIT_BIN} pull ${DEFAULT_GIT_PULL_FETCH_OPTS} origin ${_def_cur_branch} \
                && permnote "Definitions branch: ${ColorDistinct}${_def_cur_branch}${ColorNote} is now at: ${ColorDistinct}${_def_head}${ColorNote}" \
                    && return 0

        else # else use default branch
            debug "Using default branch: ${ColorDistinct}${BRANCH}${ColorDebug}"
            if [ "${_def_cur_branch}" != "${BRANCH}" ]; then
                try "${GIT_BIN} checkout -b ${BRANCH}" \
                    || try "${GIT_BIN} checkout ${BRANCH}" \
                        || warn "Can't checkout branch: ${ColorDistinct}${BRANCH}${ColorWarning}"
            fi
            printf "%b" "${ColorBlue}" >&2
            ${GIT_BIN} pull ${DEFAULT_GIT_PULL_FETCH_OPTS} origin ${BRANCH} \
                && set_def_cur_branch_and_head \
                && permnote "Definitions branch: ${ColorDistinct}${BRANCH}${ColorNote} is at: ${ColorDistinct}${_def_head}${ColorNote}" \
                    && return 0
        fi

        # Render error header for user:
        printf "\n%b%b\n%b\n%b\n%b%b\n%b\n" \
            "${ColorRed}" \
            "--------------------------------------------------------------------------------" \
            "Failed to update repository: ${ColorDistinct}${REPOSITORY}${ColorError} (affected branch: ${ColorDistinct}${BRANCH}${ColorError})" \
            "Tt's most likely just a dirty state of local definitions cache. ${ColorDistinct}${SOFIN_SHORT_NAME} reset${ColorError} to reset cache to fresh state." \
            "${ColorRed}" \
            "--------------------------------------------------------------------------------" \
            "${ColorReset}" \
                2>/dev/null
    else
        # create cache; clone definitions repository:
        cd "${CACHE_DIR}"
        debug "Cloning repository: ${ColorDistinct}${REPOSITORY}${ColorDebug} from branch: ${ColorDistinct}${BRANCH}${ColorDebug}; LOGS_DIR: ${ColorDistinct}${LOGS_DIR}${ColorDebug}, CACHE_DIR: ${ColorDistinct}${CACHE_DIR}${ColorDebug}"
        try "${RM_BIN} -rf '${DEFINITIONS_BASE}' && ${GIT_BIN} clone --depth 1 ${DEFAULT_GIT_CLONE_OPTS} ${REPOSITORY} ${DEFINITIONS_BASE}" \
            || error "Error cloning branch: ${ColorDistinct}${BRANCH}${ColorError} of repository: ${ColorDistinct}${REPOSITORY}${ColorError}. Please make sure that given repository and branch are valid!"

        cd "${CACHE_DIR}${DEFINITIONS_BASE}"
        _def_cur_branch="$(${GIT_BIN} rev-parse --abbrev-ref HEAD 2>/dev/null)"
        if [ "${BRANCH}" != "${_def_cur_branch}" ]; then
            try "${GIT_BIN} checkout -b ${BRANCH}" \
                || try "${GIT_BIN} checkout ${BRANCH}" \
                    || warn "Can't checkout branch: ${ColorDistinct}${BRANCH}${ColorWarning}"
        fi
        _def_head="HEAD"

        printf "%b" "${ColorBlue}" >&2
        ${GIT_BIN} pull --depth 1 --progress origin ${BRANCH} \
            && _def_head="$(${GIT_BIN} rev-parse HEAD 2>/dev/null)"

        permnote "Repository: ${ColorDistinct}${REPOSITORY}${ColorNote}, on branch: ${ColorDistinct}${BRANCH}${ColorNote}. Commit HEAD: ${ColorDistinct}${_def_head}${ColorNote}."
    fi
    )
    unset _def_head _def_branch _def_cur_branch _out_file _requested_branch
}


reset_defs () {
    (
        cd "${DEFINITIONS_DIR}"
        try "${GIT_BIN} reset --hard HEAD" >> "${LOG}"
        if [ -z "${BRANCH}" ]; then
            BRANCH="stable"
        fi
        _rdefs_branch="$(${CAT_BIN} "${CACHE_DIR}${DEFINITIONS_BASE}/${DEFAULT_GIT_DIR_NAME}/refs/heads/${BRANCH}" 2>/dev/null)"
        if [ -z "${_rdefs_branch}" ]; then
            _rdefs_branch="HEAD"
        fi
        permnote "Definitions repository reset to: ${ColorDistinct}${_rdefs_branch}${ColorNote}"
        for _def_line in $(${GIT_BIN} status --short 2>/dev/null | ${CUT_BIN} -f2 -d' ' 2>/dev/null); do
            unset _add_opt
            printf "%b\n" "${_def_line}" | ${EGREP_BIN} -F 'patches/' >/dev/null 2>&1 \
                && _add_opt="r"
            try "${RM_BIN} -f${_add_opt} '${_def_line}'" \
                && debug "Removed untracked file${_add_opt:-/dir} from definition repository: ${ColorDistinct}${_def_line}${ColorDebug}"
        done
    )
    unset _rdefs_branch _def_line _add_opt
}


remove_bundles () {
    _bundles="${*}"
    if [ -z "${_bundles}" ]; then
        error "Argument with at least one bundle name is required!"
    fi
    unset _destroyed
    load_sysctl_buildhost_hardening
    for _def in $(to_iter "${_bundles}"); do
        _given_name="$(capitalize_abs "${_def}")"
        if [ -z "${_given_name}" ]; then
            error "Empty bundle name given as first param!"
        fi
        load_defaults
        load_defs "${_def}"
        validate_loaded_def
        crash_if_mission_critical "${_given_name}"
        if [ -d "${SOFTWARE_DIR}/${_given_name}" ]; then
            _aname="$(lowercase "${_given_name}")"
            destroy_software_dir "${_given_name}" \
                && _destroyed="${_given_name} ${_destroyed}"

            # if removing a single bundle, then look for alternatives. Otherwise, just remove bundle..
            # if [ "${_picked_bundles}" = "${_given_name}" ]; then
            #     debug "Looking for other installed versions of: $(distd "${_given_name}"), that might be exported automatically.."
            #     _inname="$(printf "%b\n" "${_given_name}" | ${SED_BIN} 's/[0-9]*//g' 2>/dev/null)"
            #     _alternative="$(${FIND_BIN} "${SOFTWARE_DIR%/}" -mindepth 1 -maxdepth 1 -type d -iname "${_inname}*" -not -name "${_given_name}" 2>/dev/null | ${SED_BIN} 's/^.*\///g' 2>/dev/null | ${HEAD_BIN} -n1 2>/dev/null)"
            # fi
            # if [ -n "${_alternative}" ] \
            # && [ -f "${SOFTWARE_DIR}/${_alternative}/$(lowercase "${_alternative}")${DEFAULT_INST_MARK_EXT}" ]; then
            #     permnote "Updating environment for installed alternative: $(distn "${_alternative}")"
            #     export_binaries "${_alternative}"
            #     finalize_complete_standard_task
            #     unset _given_name _inname _alternative _aname _def
            #     return 0 # Just pick first available alternative bundle
            # elif [ -z "${_alternative}" ]; then
            #     debug "No alternative: $(distd "${_alternative}") != $(distd "${_given_name}")"
            # fi
        fi
    done

    if [ -n "${_destroyed}" ]; then
        permnote "Bundle(s) destroyed: ${ColorDistinct}${_destroyed}${ColorNote}"
    fi
    # for _bundle_name in $(to_iter "${_bundles}"); do
        # replace + with *
        # _bundle_nam="$(printf "%b\n" "${_bundle_name}" | ${SED_BIN} -e 's#+#*#' 2>/dev/null)"
        # # first look for a list with that name:
        # if [ -e "${DEFINITIONS_LISTS_DIR}${_bundle_nam}" ]; then
        #     _picked_bundles="$(${CAT_BIN} "${DEFINITIONS_LISTS_DIR}${_bundle_nam}" 2>/dev/null | eval "${NEWLINES_TO_SPACES_GUARD}")"
        # else
        #     _picked_bundles="${_bundle_nam}"
        # fi
        # if [ "${_bundle_nam}" != "${_bundle_name}" ]; then
        #     # Specified + - a wildcard
        #     _picked_bundles="" # to remove first entry with *
        #     for _bund in $(${FIND_BIN} "${SOFTWARE_DIR}" -mindepth 1 -maxdepth 1 -iname "${_bundle_nam}" -type d 2>/dev/null); do
        #         _bname="${_bund##*/}"
        #         _picked_bundles="${_picked_bundles} ${_bname}"
        #     done
        #     if [ -z "${_picked_bundles}" ]; then
        #         debug "No bundles picked? Maybe there's a '+' in definition name? Let's try: $(distd "${_bundle_name}")"
        #         _picked_bundles="${_bundle_name}" # original name, with + in it
        #     fi
        #     unset _found _bund _bname
        # fi
        # load_defaults
    # done
    unset _given_name _inname _alternative _aname _def _picked_bundles _bundle_name _bundle_nam _destroyed
}


available_definitions () {
    if [ -d "${DEFINITIONS_LISTS_DIR}" ]; then
        _lists="$(${FIND_BIN} "${DEFINITIONS_LISTS_DIR}" -mindepth 1 -maxdepth 1 -type f 2>/dev/null | ${SORT_BIN} | ${AWK_BIN} -F/ '{print $NF}' | ${TR_BIN} '\n' ' ')"
        permnote "Available definitions lists: ${ColorDistinct}${_lists}${ColorNote}"
    fi
    if [ -d "${DEFINITIONS_DIR}" ]; then
        _alldefs="$(${FIND_BIN} "${DEFINITIONS_DIR}" -mindepth 1 -maxdepth 1 -type f -name "*${DEFAULT_DEF_EXT}" 2>/dev/null | ${SORT_BIN} )"
        _alldefs_count="$(printf "%b\n" "${_alldefs}" | ${TR_BIN} '\n' ' ' | eval "${WORDS_COUNT_GUARD}")"
        unset _disabled_defs
        permnote "All definitions: ${ColorDistinct}$(echo "${_alldefs}" | ${AWK_BIN} -F/ '{print $NF}' | ${SED_BIN} "s/${DEFAULT_DEF_EXT}//g" 2>/dev/null | ${TR_BIN} '\n' ' ')${ColorNote}"

        for _def in $(to_iter "${_alldefs}"); do
            _deffile="$(echo ${_def%"${DEFAULT_DEF_EXT}"} | ${AWK_BIN} -F/ '{print $NF}')"
            load_defaults

            unset CURRENT_DEFINITION_DISABLED
            . "${_def}"
            validate_definition_disabled
            if [ "${CURRENT_DEFINITION_DISABLED}" = "YES" ]; then
                _disabled_defs="${_disabled_defs}\n${ColorRed}${_deffile}"
            fi
        done
        permnote "Definitions total: ${ColorDistinct}${_alldefs_count:-0}${ColorNote}"

        note
        load_defaults
        _disabled_defs="$(echo ${_disabled_defs} | ${SORT_BIN} | ${TR_BIN} '\n' ' ')"
        permnote "Definitions disabled for the ${ColorDistinct}${SYSTEM_NAME}-${SYSTEM_ARCH}${ColorNote} system:${ColorDistinct}${_disabled_defs}${ColorNote}"

        _disabled_count="$(printf "%b\n" "${_disabled_defs}" | eval "${WORDS_COUNT_GUARD}")"
        permnote "Disabled definitions total: ${ColorDistinct}${_disabled_count}${ColorNote}"
    fi
    unset _disabled_defs _disabled_count _lists _alldefs _alldefs_count _def _deffile
}


make_exports () {
    _export_bin="${1}"
    _bundle_name="$(capitalize_abs "${2}")"
    if [ -z "${_export_bin}" ]; then
        error "First argument with ${ColorDistinct}exported-bin${ColorError} is required!"
    fi
    if [ -z "${_bundle_name}" ]; then
        error "Second argument with ${ColorDistinct}BundleName${ColorError} is required!"
    fi
    try "${MKDIR_BIN} -p '${SOFTWARE_DIR}/${_bundle_name}/exports' '${SERVICES_DIR}/${_bundle_name}/exports'"
    for _bindir in "/bin/" "/sbin/" "/libexec/"; do
        # SOFTWARE_DIR:
        if [ -e "${SOFTWARE_DIR}/${_bundle_name}${_bindir}${_export_bin}" ]; then
            permnote "Exporting binary: ${ColorDistinct}${SOFTWARE_DIR}/${_bundle_name}${_bindir}${_export_bin}${ColorNote}"
            (
                cd "${SOFTWARE_DIR}/${_bundle_name}${_bindir}"
                try "${RM_BIN} -f ../exports/${_export_bin}; ${LN_BIN} -s ..${_bindir}/${_export_bin} ../exports/${_export_bin}"
                try "${CHMOD_BIN} a+x ${_export_bin}"
            )
            unset _bindir _bundle_name _export_bin
            return 0
        else
            debug "Export not found: ${ColorDistinct}${SOFTWARE_DIR}/${_bundle_name}${_bindir}${_export_bin}${ColorDebug}"
        fi

        # SERVICES_DIR:
        if [ -e "${SERVICES_DIR}/${_bundle_name}${_bindir}${_export_bin}" ]; then
            permnote "Exporting binary: ${ColorDistinct}${SERVICES_DIR}/${_bundle_name}${_bindir}${_export_bin}${ColorNote}"
            (
                cd "${SERVICES_DIR}/${_bundle_name}${_bindir}"
                try "${RM_BIN} -f ../exports/${_export_bin}; ${LN_BIN} -s ..${_bindir}/${_export_bin} ../exports/${_export_bin}"
                try "${CHMOD_BIN} a+x ${_export_bin}"
            )
            unset _bindir _bundle_name _export_bin
            return 0
        else
            debug "Export not found: ${ColorDistinct}${SERVICES_DIR}/${_bundle_name}${_bindir}${_export_bin}${ColorDebug}"
        fi
    done
    error "No executable to export from bin paths of: ${ColorDistinct}${_bundle_name}/\{bin,sbin,libexec\}/${_export_bin}${ColorError}"
}


show_available_versions_of_bundles () {
    _bundles="${*}"
    _resource="${MAIN_BINARY_REPOSITORY}${OS_TRIPPLE}"
    debug "REMOTE resource: ${_resource}"

    for _bundle in $(to_iter "${_bundles}"); do
        permnote "Available versions of binary bundle: ${ColorDistinct}${_bundle}${ColorDebug}"

        if [ -x "${CURL_BIN}" ]; then
            ${CURL_BIN} -sL "${MAIN_BINARY_REPOSITORY}${OS_TRIPPLE}" \
                | ${SED_BIN} -e 's/<[^>]*>//g' \
                | ${GREP_BIN} -i "${_bundle}" \
                | ${GREP_BIN} -v "${DEFAULT_CHKSUM_EXT}"
        else
            ${FETCH_BIN} -qo- "${MAIN_BINARY_REPOSITORY}${OS_TRIPPLE}" \
                | ${SED_BIN} -e 's/<[^>]*>//g' \
                | ${GREP_BIN} -i "${_bundle}" \
                | ${GREP_BIN} -v "${DEFAULT_CHKSUM_EXT}"
        fi
    done

    unset _bundle _bundles _resource
}


show_outdated () {
    _raw="${1}"
    load_defaults
    if [ -d "${SOFTWARE_DIR}" ]; then
        for _old_prefix in $(${FIND_BIN} "${SOFTWARE_DIR%/}" -mindepth 1 -maxdepth 1 -type d -not -name ".*" 2>/dev/null); do
            _bundle_cap="${_old_prefix##*/}"
            _bundle="$(lowercase "${_bundle_cap}")"
            if [ ! -f "${_old_prefix}/${_bundle}${DEFAULT_INST_MARK_EXT}" ]; then
                if [ -z "${_raw}" ]; then
                    warn "Bundle: ${ColorDistinct}${_bundle_cap}${ColorWarning} is not yet installed or damaged."
                fi
                continue
            fi
            _bund_vers="$(${CAT_BIN} "${_old_prefix}/${_bundle}${DEFAULT_INST_MARK_EXT}" 2>/dev/null)"
            if [ ! -f "${DEFINITIONS_DIR}/${_bundle}${DEFAULT_DEF_EXT}" ]; then
                if [ "${_bundle}" != "${SOFIN_NAME}" ]; then
                    if [ -z "${_raw}" ]; then
                        warn "No such bundle: '${ColorDistinct}${_bundle_cap}${ColorWarning}' of prefix: '${ColorDistinct}${_old_prefix##*/}${ColorWarning}' found!"
                    fi
                fi
                continue
            fi
            load_defs "${_bundle}"
            check_version "${_bund_vers}" "${DEF_VERSION}" "${_bundle}" "${_raw}"
        done
    fi

    if [ -z "${_raw}" ]; then
        if [ "${FOUND_OUTDATED}" = "YES" ]; then
            finalize_and_quit_gracefully_with_exitcode "${ERRORCODE_TASK_FAILURE}"
        else
            permnote "All currently installed bundles look recent!"
        fi
    fi
    unset _bund_vers _raw
}


wipe_remote_archives () {
    _bund_names="${*}"
    _ans="YES"
    if [ -z "${USE_FORCE}" ]; then
        warn "Are you sure you want to wipe binary bundles: ${ColorDistinct}${_bund_names}${ColorWarning} from binary repository: ${ColorDistinct}${MAIN_BINARY_REPOSITORY}${ColorWarning}? (Type ${ColorDistinct}YES${ColorWarning} to confirm)"
        read -r _ans
    fi
    if [ "${_ans}" = "YES" ]; then
        (
            cd "${SOFTWARE_DIR}"
            for _wr_element in $(to_iter "${_bund_names}"); do
                _lowercase_element="$(lowercase "${_wr_element}")"
                _remote_ar_name="${_wr_element}-[0-9]*" # NOTE: Name-version* - matches both archives and their checksums
                _wr_dig="$(${HOST_BIN} "${MAIN_SOFTWARE_ADDRESS}" 2>/dev/null | ${CUT_BIN} -d' ' -f4 2>/dev/null)"
                if [ -z "${_wr_dig}" ]; then
                    error "No mirrors found in address: ${ColorDistinct}${MAIN_SOFTWARE_ADDRESS}${ColorError}"
                fi
                debug "Using defined mirror(s): ${ColorDistinct}${_wr_dig}${ColorDebug}"
                for _wr_mirr in $(to_iter "${_wr_dig}"); do
                    permnote "Wiping out remote: ${ColorDistinct}${_wr_mirr}${ColorNote} binary archives: ${ColorDistinct}${_remote_ar_name}${ColorNote}"
                    retry "${SSH_BIN} ${DEFAULT_SSH_OPTS} -p ${SOFIN_SSH_PORT} ${SOFIN_NAME}@${_wr_mirr} \"${FIND_BIN} ${MAIN_BINARY_PREFIX}/${SYS_SPECIFIC_BINARY_REMOTE} -iname '${_remote_ar_name}' -delete\""
                done
            done
        )
    else
        error "Aborted remote wipe of: ${ColorDistinct}${_bund_names}${ColorError}"
    fi
    unset _wr_mirr _remote_ar_name _wr_dig _lowercase_element _wr_element
}


# create_apple_bundle_if_necessary () { # XXXXXX
#     if [ -n "${DEF_APPLE_BUNDLE}" ] && [ "Darwin" = "${SYSTEM_NAME}" ]; then
#         _aname="$(lowercase "${DEF_NAME}${DEF_SUFFIX}")"
#         DEF_NAME="$(printf "%b\n" "${DEF_NAME}" | ${CUT_BIN} -c1 2>/dev/null | ${TR_BIN} '[a-z]' '[A-Z]' 2>/dev/null)$(printf "%b\n" "${DEF_NAME}" | ${SED_BIN} 's/^[a-zA-Z]//' 2>/dev/null)"
#         DEF_BUNDLE_NAME="${PREFIX}.app"
#         note "Creating Apple bundle: $(distn "${DEF_NAME}") in: $(distn "${DEF_BUNDLE_NAME}")"
#         ${MKDIR_BIN} -p "${DEF_BUNDLE_NAME}/libs" "${DEF_BUNDLE_NAME}/Contents" "${DEF_BUNDLE_NAME}/Contents/Resources/${_aname}" "${DEF_BUNDLE_NAME}/exports" "${DEF_BUNDLE_NAME}/share"
#         try "${CP_BIN} -R ${PREFIX}/${DEF_NAME}.app/Contents/* ${DEF_BUNDLE_NAME}/Contents/"
#         try "${CP_BIN} -R ${PREFIX}/bin/${_aname} ${DEF_BUNDLE_NAME}/exports/"
#         for lib in $(${FIND_BIN} "${PREFIX}" -name '*.dylib' -type f 2>/dev/null); do
#             try "${CP_BIN} -vf ${lib} ${DEF_BUNDLE_NAME}/libs/"
#         done

#         # if symlink exists, remove it.
#         try "${RM_BIN} -f ${DEF_BUNDLE_NAME}/lib"
#         try "${LN_BIN} -s ${DEF_BUNDLE_NAME}/libs ${DEF_BUNDLE_NAME}/lib"

#         # move data, and support files from origin:
#         try "${CP_BIN} -vR ${PREFIX}/share/${_aname} ${DEF_BUNDLE_NAME}/share/"
#         try "${CP_BIN} -vR ${PREFIX}/lib/${_aname} ${DEF_BUNDLE_NAME}/libs/"

#         cd "${DEF_BUNDLE_NAME}/Contents"
#         try "${TEST_BIN} -L MacOS || ${LN_BIN} -s ../exports MacOS"
#         debug "Creating relative libraries search path"
#         cd "${DEF_BUNDLE_NAME}"
#         note "Processing exported binary: $(distn "${i}")" # XXX: i?
#         try "${SOFIN_LIBBUNDLE_BIN} -x ${DEF_BUNDLE_NAME}/Contents/MacOS/${_aname}"
#     fi
# }


strip_bundle () {
    _sbfdefinition_name="${1}"
    if [ -z "${_sbfdefinition_name}" ]; then
        error "No definition name specified as first param!"
    fi
    load_defaults
    load_defs "${_sbfdefinition_name}"
    if [ -z "${PREFIX}" ]; then
        PREFIX="${SOFTWARE_DIR}/$(capitalize_abs "${DEF_NAME}${DEF_SUFFIX}")"
        debug "An empty prefix for: ${ColorDistinct}${_sbfdefinition_name}${ColorDebug}. Resetting to: ${ColorDistinct}${PREFIX}${ColorDebug}"
    fi
    if [ -f "${PREFIX}/${_sbfdefinition_name}${DEFAULT_STRIPPED_MARK_EXT}" ]; then
        debug "Bundle looks like already stripped: ${ColorDistinct}${_sbfdefinition_name}${ColorDebug}"
        return 0
    fi

    DEF_STRIP="${DEF_STRIP:-NO}" # unset DEF_STRIP to say "NO", but don't allow no value further
    unset _dirs_to_strip
    # TODO: chdir to SERVICE_DIR/ PREFIX to save up 4096 max input length for args
    case "${DEF_STRIP}" in
        no|NO|none|NONE|nothing|NOTHING)
            debug "${ColorDistinct}${_sbfdefinition_name}${ColorDebug}: No symbols will be stripped from bundle: ${ColorDistinct}${_sbfdefinition_name}${ColorDebug}"
            ;;

        all|ALL)
            debug "${ColorDistinct}${_sbfdefinition_name}${ColorDebug}: Strip both binaries and libraries."
            _dirs_to_strip="${SERVICE_DIR}/bin ${SERVICE_DIR}/sbin ${SERVICE_DIR}/lib ${SERVICE_DIR}/libexec ${PREFIX}/bin ${PREFIX}/sbin ${PREFIX}/lib ${PREFIX}/libexec"
            ;;

        exports|export|bins|binaries|bin|BIN|BINS)
            debug "${ColorDistinct}${_sbfdefinition_name}${ColorDebug}: Strip exported binaries only"
            _dirs_to_strip="${SERVICE_DIR}/bin ${SERVICE_DIR}/sbin ${SERVICE_DIR}/libexec ${PREFIX}/bin ${PREFIX}/sbin ${PREFIX}/libexec"
            ;;

        libs|lib|libexec|LIB|LIBS)
            debug "${ColorDistinct}${_sbfdefinition_name}${ColorDebug}: Strip libraries only"
            _dirs_to_strip="${SERVICE_DIR}/lib ${PREFIX}/lib"
            ;;
    esac

    #
    # NOTE: Currently unhandled file types:
    # _data="data"
    # _text="ASCII text executable"
    # _link="symbolic link to"
    # _script="script text executable"
    #
    _files_counter="0"
    _to_be_stripped_list=""
    unset _exec_ft _lib_ft _universal_ft
    case "${SYSTEM_NAME}" in
        Darwin)
            # NOTE: no arch suffix, to match both x86_64 and arm64 binaries:
            _exec_ft="Mach-O 64-bit executable"
            _lib_ft="Mach-O 64-bit dynamically linked shared library"
            _universal_ft="Mach-O universal binary"
            ;;

        FreeBSD|Linux)
            _exec_ft="ELF 64-bit LSB"
            _lib_ft="ELF 64-bit LSB shared object"
            ;;
    esac

    for _stripdir in $(to_iter "${_dirs_to_strip}"); do
        if [ -d "${_stripdir}" ]; then
            for _file in $(${FIND_BIN} "${_stripdir}" -maxdepth 1 -type f -not -name '*.la' -not -name '*.sh' 2>/dev/null); do
                # NOTE: Darwin: don't touch vendor signed binaries (f.e. prebuilt Vault, Consul).
                #       Stripping breaks their Developer ID signature, and the system kills them on launch:
                if [ "Darwin" = "${SYSTEM_NAME}" ] \
                && /usr/bin/codesign -dv "${_file}" 2>&1 | ${GREP_BIN} -E "^TeamIdentifier=[A-Z0-9]" >/dev/null 2>&1; then
                    debug "Skipping vendor signed file: ${ColorDistinct}${_file}${ColorDebug}"
                    continue
                fi
                _file_type="$(${FILE_BIN} -b "${_file}" 2>/dev/null)"
                for _type in "${_exec_ft}" "${_lib_ft}" "${_universal_ft}"; do
                    if [ -z "${_type}" ]; then # NOTE: empty pattern would match any file
                        continue
                    fi
                    printf "%b\n" "${_file_type}" | ${GREP_BIN} -F "${_type}" >/dev/null 2>&1
                    if [ "0" = "${?}" ]; then
                        _files_counter=$(( ${_files_counter} + 1 ))
                        if [ -z "${_to_be_stripped_list}" ]; then
                            _to_be_stripped_list="${_file}"
                        else
                            _to_be_stripped_list="${_to_be_stripped_list} ${_file}"
                        fi
                        break # NOTE: each file is listed once
                    fi
                done
            done
        fi
    done
    if [ -n "${_to_be_stripped_list}" ]; then
        if [ -z "${DEF_KEEP_DEBUG_SYMBOLS}" ]; then
            debug "Stripping debug information from build products…"
            for _file in $(to_iter "${_to_be_stripped_list}"); do
                debug "Stripping ${ColorDistinct}${_file}${ColorDebug}"
                try "${STRIP_BIN} ${DEFAULT_STRIP_OPTS} ${_file}"
            done
        else
            debug "Splitting debug information into separate files…"
            _debug_dest_dir="${PREFIX}/.debug"
            mkdir -p "${_debug_dest_dir}"
            for _file in $(to_iter "${_to_be_stripped_list}"); do
                _dbgfile_basename="${_file##*/}.debug"
                debug "Coying debug data from: ${ColorDistinct}${_file}${ColorDebug} to: ${ColorDistinct}${_debug_dest_dir}/${_dbgfile_basename}${ColorDebug}"
                try "${OBJCOPY_BIN} --only-keep-debug ${_file} ${_debug_dest_dir}/${_dbgfile_basename}"
                debug "Stripping ${ColorDistinct}${_file}${ColorDebug}"
                try "${STRIP_BIN} ${DEFAULT_STRIP_OPTS} ${_file}"
                debug "Associate separated debug file to debug file"
                try "${OBJCOPY_BIN} --add-gnu-debuglink=${_debug_dest_dir}/${_dbgfile_basename} ${_file}"
            done
        fi
        # NOTE: mark bundle as stripped, so it's not stripped again on the next build:
        try "${TOUCH_BIN} '${PREFIX}/${_sbfdefinition_name}${DEFAULT_STRIPPED_MARK_EXT}'"
    fi
    unset _sbfdefinition_name _dirs_to_strip _files_counter _file _stripdir _bundlower _to_be_stripped_list _debug_dest_dir _dbgfile_basename
}


afterbuild_manage_files_of_bundle () {
    if [ "${DEF_CLEAN_USELESS}" = "YES" ]; then
        unset _fordel
        # we shall clean the bundle, from useless files..
        if [ -d "${PREFIX}" ]; then
            # step 0: clean defaults side DEF_DEFAULT_USELESS entries only if DEF_USEFUL is empty
            if [ -n "${DEF_DEFAULT_USELESS}" ] \
            && [ -z "${DEF_USEFUL}" ]; then
                for _cu_pattern in $(to_iter "${DEF_DEFAULT_USELESS}"); do
                    if [ -e "${PREFIX}/${_cu_pattern}" ]; then
                        if [ -z "${_fordel}" ]; then
                            _fordel="${PREFIX}/${_cu_pattern}"
                        else
                            _fordel="${_fordel} ${PREFIX}/${_cu_pattern}"
                        fi
                    fi
                done
            fi

            # step 1: clean definition side DEF_USELESS entries only if DEF_USEFUL is empty
            if [ -n "${DEF_USELESS}" ]; then
                for _cu_pattern in $(to_iter "${DEF_USELESS}"); do
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
            error "${ColorDistinct}PREFIX=${PREFIX}${ColorWarning} NOT found!"
        fi

        unset _dbg_exp_lst
        for _cu_dir in bin sbin libexec; do
            if [ -d "${PREFIX}/${_cu_dir}" ]; then
                for _cufile in $(${FIND_BIN} "${PREFIX}/${_cu_dir}" -mindepth 1 -maxdepth 1 -type f -or -type l 2>/dev/null); do
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
                        for _is_useful in $(to_iter "${DEF_USEFUL}"); do
                            # NOTE: split each by /, first argument will be subpath for instance: "bin"; second one - file pattern
                            # NOTE: legacy shell string ops sneak peak below:
                            #   ${var#*SubStr}  # will drop begin of string upto first occur of `SubStr`
                            #   ${var##*SubStr} # will drop begin of string upto last occur of `SubStr`
                            #   ${var%SubStr*}  # will drop part of string from last occur of `SubStr` to the end
                            #   ${var%%SubStr*} # will drop part of string from first occur of `SubStr` to the end
                            _subdir="${_is_useful%/*}"
                            _pattern="${_is_useful#*/}"
                            # if subdir matches current prefix subdir and pattern..
                            if [ "${_cu_dir}" = "${_subdir}" ]; then
                                printf "%b\n" "${_cufile}" 2>/dev/null | ${EGREP_BIN} ".*(.${_pattern}).*" >/dev/null 2>&1
                                if [ "${?}" = "0" ]; then
                                    # debug "got: '$(distd "${_cufile}")' match with: $(distd "${_subdir}") ~= '$(distd ".*(.${_pattern}).*")'"
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
                        # else
                        #     debug "File considered to be useful: $(distd "${_cufile}")"
                        fi
                    fi
                done
            fi
        done

        if [ -n "${_dbg_exp_lst}" ]; then
            debug "Found exports: ${ColorDistinct}${_dbg_exp_lst}${ColorDebug}. Proceeding with useless files cleanup of: ${ColorDistinct}${_fordel}${ColorDebug}"
            remove_useless_files_of_bundle "${_fordel}"
        else
            debug "Empty exports list? Useless files removal skipped (cause it's damn annoing). Remember to invoke afterbuild_manage_files_of_bundle() _after_ you do exports!"
        fi
    else
        debug "Useless files cleanup skipped since DEF_CLEAN_USELESS=${ColorDistinct}${DEF_CLEAN_USELESS:-''}${ColorDebug}!"
    fi
    unset _cu_pattern _cufile _cuall_binaries _cu_commit_removal _cubase _fordel _dbg_exp_lst
}


conflict_resolve () {
    if [ ! -f "${SOFIN_ENV_ENABLED_INDICATOR_FILE}" ]; then
        debug "Sofin ENV is NOT set, performing conflicts resolve!"
        if [ -n "${DEF_CONFLICTS_WITH}" ]; then
            _appname="$(capitalize_abs "${DEF_NAME}${DEF_SUFFIX}")"
            debug "Seeking possible bundle conflicts: ${ColorDistinct}${DEF_CONFLICTS_WITH}${ColorDebug}"
            for _app in $(to_iter "${DEF_CONFLICTS_WITH}"); do
                for _soft in $(${FIND_BIN} "${SOFTWARE_DIR}" -maxdepth 1 -type d -iname "${_app}*" 2>/dev/null); do
                    _soft_name="${_soft##*/}"
                    if [ -d "${_soft}/exports" ] \
                    && [ "${_soft_name}" != "Zsh" ]; then # NOTE: Avoid task for one critical bundle: Zsh - since this may cause system turn to locked-state-without-default=$SHELL
                        debug "conflict_resolve(name=${ColorDistinct}${_soft_name}${ColorDebug}, def_name=${ColorDistinct}${_appname}${ColorDebug}):"
                        if [ "${_soft_name}" != "${_appname}" ]; then
                            debug "Disabling bundle exports of: ${ColorDistinct}${_soft_name}${ColorDebug} -> in conflict with: ${ColorDistinct}${_appname}${ColorDebug}"
                            try "${MV_BIN} ${_soft}/exports ${_soft}/exports-disabled"
                        fi
                    fi
                done
                for _service in $(${FIND_BIN} "${SERVICES_DIR}" -maxdepth 1 -type d -iname "${_app}*" 2>/dev/null); do
                    _sv_name="${_service##*/}"
                    if [ -d "${_service}/exports" ]; then
                        debug "conflict_resolve(name=${ColorDistinct}${_sv_name}${ColorDebug}, def_name=${ColorDistinct}${_appname}${ColorDebug}):"
                        if [ "${_sv_name}" != "${_appname}" ]; then
                            debug "Disabling bundle exports of: ${ColorDistinct}${_service}${ColorDebug} -> in conflict with: ${ColorDistinct}${_appname}${ColorDebug}"
                            try "${MV_BIN} '${_service}/exports' '${_service}/exports-disabled'"
                        fi
                    fi
                done
            done
            unset _app _soft _soft_name _service _sv_name
        fi
    else
        debug "Sofin ENV is set, conflicts resolve skipped!"
    fi
}


export_binaries () {
    _ebdef_name="${1}"
    if [ -z "${_ebdef_name}" ]; then
        error "No definition name specified as first param for export_binaries()!"
    fi
    load_defs "${_ebdef_name}"
    conflict_resolve

    if [ -d "${PREFIX}/exports-disabled" ]; then # just bring back disabled exports
        debug "Exporting back previously disabled exports dir from: '${ColorDistinct}${PREFIX}/exports-disabled${ColorDebug}' to '${ColorDistinct}${PREFIX}/exports${ColorDebug}'"
        run "${MV_BIN} ${PREFIX}/exports-disabled ${PREFIX}/exports"
    fi
    if [ -d "${SERVICE_DIR}/exports-disabled" ]; then # just bring back disabled exports
        debug "Exporting back previously disabled exports dir from: '${ColorDistinct}${SERVICE_DIR}/exports-disabled${ColorDebug}' to '${ColorDistinct}${SERVICE_DIR}/exports${ColorDebug}'"
        run "${MV_BIN} ${SERVICE_DIR}/exports-disabled ${SERVICE_DIR}/exports"
    fi
    if [ -z "${DEF_EXPORTS}" ]; then
        permnote "Defined no exports of prefix: ${ColorDistinct}${PREFIX}${ColorNote}"
    else
        _an_amount="$(printf "%b\n" "${DEF_EXPORTS}" | ${AWK_BIN} '{print NF;}' 2>/dev/null)"
        debug "Exporting ${ColorDistinct}${_an_amount}${ColorDebug} binaries of prefixes: ${ColorDistinct}${PREFIX}${ColorDebug} + ${ColorDistinct}${SERVICE_DIR}${ColorDebug}"
        try "${MKDIR_BIN} -p ${PREFIX}/exports ${SERVICE_DIR}/exports"
        unset _expolist
        for _xp in $(to_iter "${DEF_EXPORTS}"); do
            for dir in "/libexec/" "/bin/" "/sbin/"; do

                _soft_to_exp="${PREFIX}${dir}${_xp}"
                if [ -x "${_soft_to_exp}" ]; then
                    (
                        cd "${PREFIX}${dir}"
                        try "${RM_BIN} -f ../exports/${_xp}; ${LN_BIN} -s ..${dir}${_xp} ../exports/${_xp}"
                    )
                    _expo_elem="${_soft_to_exp##*/}"
                    _expolist="${_expolist} ${_expo_elem}"
                fi

                _service_to_exp="${SERVICE_DIR}${dir}${_xp}"
                if [ -x "${_service_to_exp}" ]; then
                    (
                        cd "${SERVICE_DIR}${dir}"
                        try "${RM_BIN} -f ../exports/${_xp}; ${LN_BIN} -s ..${dir}${_xp} ../exports/${_xp}"
                    )
                    _expo_elem="${_service_to_exp##*/}"
                    _expolist="${_expolist} ${_expo_elem}"
                fi

            done
        done

        if [ -z "${_expolist}" ]; then
            error "Declared DEF_EXPORTS: ${ColorDistinct}${DEF_EXPORTS}${ColorError}, but nothing was experted for: ${ColorDistinct}${DEF_NAME}${DEF_SUFFIX}${ColorError}!"
        fi

        permnote "${ColorDistinct}$(capitalize "${_ebdef_name}")${ColorNote} bundle exports:${ColorDistinct}${_expolist}${ColorNote}"
    fi
    unset _expo_elem _acurrdir _an_amount _expolist _ebdef_name _soft_to_exp _service_to_exp
}


after_unpack_callback () {
    if [ -n "${DEF_AFTER_UNPACK_METHOD}" ]; then
        run "${DEF_AFTER_UNPACK_METHOD}" \
            && debug "Evaluated callback DEF_AFTER_UNPACK_METHOD: ${ColorDistinct}${DEF_AFTER_UNPACK_METHOD}${ColorDebug}"
    fi
}


after_export_callback () {
    if [ -n "${DEF_AFTER_EXPORT_METHOD}" ]; then
        run "${DEF_AFTER_EXPORT_METHOD}" \
            && debug "Evaluated callback DEF_AFTER_EXPORT_METHOD: ${ColorDistinct}${DEF_AFTER_EXPORT_METHOD}${ColorDebug}"
    fi
}


after_patch_callback () {
    if [ -n "${DEF_AFTER_PATCH_METHOD}" ]; then
        run "${DEF_AFTER_PATCH_METHOD}" \
            && debug "Evaluated callback DEF_AFTER_PATCH_METHOD: ${ColorDistinct}${DEF_AFTER_PATCH_METHOD}${ColorDebug}"
    fi
}


after_configure_callback () {
    if [ -n "${DEF_AFTER_CONFIGURE_METHOD}" ]; then
        run "${DEF_AFTER_CONFIGURE_METHOD}" \
            && debug "Evaluated callback DEF_AFTER_CONFIGURE_METHOD: ${ColorDistinct}${DEF_AFTER_CONFIGURE_METHOD}${ColorDebug}"
    fi
}


after_make_callback () {
    if [ -n "${DEF_AFTER_MAKE_METHOD}" ]; then
        run "${DEF_AFTER_MAKE_METHOD}" \
            && debug "Evaluated callback DEF_AFTER_MAKE_METHOD: ${ColorDistinct}${DEF_AFTER_MAKE_METHOD}${ColorDebug}"
    fi
}


after_test_callback () {
    if [ -n "${DEF_AFTER_TEST_METHOD}" ]; then
        run "${DEF_AFTER_TEST_METHOD}" \
            && debug "Evaluated callback DEF_AFTER_TEST_METHOD: ${ColorDistinct}${DEF_AFTER_TEST_METHOD}${ColorDebug}"
    fi
}


after_install_callback () {
    if [ -n "${DEF_AFTER_INSTALL_METHOD}" ]; then
        run "${DEF_AFTER_INSTALL_METHOD}" \
            && debug "Evaluated callback DEF_AFTER_INSTALL_METHOD: ${ColorDistinct}${DEF_AFTER_INSTALL_METHOD}${ColorDebug}"
    fi
}


apply_patch () {
    _def2patch="${1}"
    _abspatch="${2}"
    for _level in $(${SEQ_BIN} 0 5 2>/dev/null); do # From p0 to-p5
        try "${PATCH_BIN} -p${_level} -N -f -i ${_abspatch} >> '${LOG}-${_def2patch}' 2>> '${LOG}-${_def2patch}'" \
            && debug "Forward patch applied: ${ColorDistinct}${_abspatch}${ColorDebug} (level: ${ColorDistinct}${_level}${ColorDebug})" \
                && return 0
        try "${PATCH_BIN} -p${_level} -R -f -i ${_abspatch} >> '${LOG}-${_def2patch}' 2>> '${LOG}-${_def2patch}'" \
            && debug "Reversed patch applied: ${ColorDistinct}${_abspatch}${ColorDebug} (level: ${ColorDistinct}${_level}${ColorDebug})" \
                && return 0
    done
    warn "   ${WARN_CHAR} Failed to apply patch: ${ColorDistinct}${_abspatch##*/}${ColorWarning} for: ${ColorDistinct}${_def2patch}${ColorWarning}"
    unset _level _def2patch _abspatch
    return 1
}


traverse_patchlevels () {
    _trav_name="${1}"
    shift
    _trav_patches="${*}"
    _at_least_one_patch_failed="NO"
    for _patch in $(to_iter "${_trav_patches}"); do
        apply_patch "${_trav_name}" "${_patch}" || \
            _at_least_one_patch_failed=YES
    done
    unset _trav_patches _patch _trav_name
    if [ "YES" = "${_at_least_one_patch_failed}" ]; then
        return 1
    fi
    return 0
}


apply_definition_patches () {
    _pcpaname="$(lowercase "${1}")"
    if [ -z "${_pcpaname}" ]; then
        error "First argument with definition name is required!"
    fi
    _common_patches_dir="${DEFINITIONS_DIR}/patches/${_pcpaname}"
    _platform_patches_dir="${_common_patches_dir}/${SYSTEM_NAME}"
    if [ -d "${_common_patches_dir}/" ]; then
        _ps_patches="$(${FIND_BIN} "${_common_patches_dir}/" -mindepth 1 -maxdepth 1 -type f 2>/dev/null)"
        if [ -n "${_ps_patches}" ]; then
            traverse_patchlevels "${_pcpaname}" "${_ps_patches}" && \
                note "   ${NOTE_CHAR} Applied common patches for: ${ColorDistinct}${_pcpaname}${ColorNote}"
        fi
        if [ -d "${_platform_patches_dir}/" ]; then
            _ps_patches="$(${FIND_BIN} "${_platform_patches_dir}/" -mindepth 1 -maxdepth 1 -type f 2>/dev/null)"
            if [ -n "${_ps_patches}" ]; then
                traverse_patchlevels "${_pcpaname}" "${_ps_patches}" && \
                    note "   ${NOTE_CHAR} Applied platform specific patches for: ${ColorDistinct}${_pcpaname}/${SYSTEM_NAME}${ColorNote}"
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
    note "   ${NOTE_CHAR} Fetching source repository: ${ColorDistinct}${_source_path}${ColorNote}"
    try "${GIT_BIN} clone --jobs=${CPUS} --recursive --mirror ${_source_path} ${_git_cached}" \
        || try "${GIT_BIN} clone --jobs=${CPUS} --mirror ${_source_path} ${_git_cached}"
    if [ "${?}" = "0" ]; then
        debug "Cloned bare repository: ${ColorDistinct}${_bare_name}${ColorDebug}"
    elif [ -d "${_git_cached}" ]; then
        (
            debug "Trying to update existing bare repository cache in: ${ColorDistinct}${_git_cached}${ColorDebug}"
            cd "${_git_cached}"
            try "${GIT_BIN} fetch ${DEFAULT_GIT_PULL_FETCH_OPTS} origin ${_chk_branch} >> ${LOG}" \
                || warn "   ${WARN_CHAR} Failed to fetch an update from bare repository: ${ColorDistinct}${_git_cached}${ColorWarning} [branch: ${ColorDistinct}${_chk_branch}${ColorWarning}]"
        )
    elif [ ! -d "${_git_cached}/branches" ] \
      && [ ! -f "${_git_cached}/config" ]; then
        error "Failed to fetch source repository: ${ColorDistinct}${_source_path}${ColorError} [branch: ${ColorDistinct}${_chk_branch}${ColorError}]"
    fi

    # bare repository is already cloned, so we just clone from it now..
    _dest_repo="${_build_dir}/${_bare_name}-${_chk_branch}"
    try "${RM_BIN} -rf '${_dest_repo}'"
    debug "Attempting to clone from cached repository: ${ColorDistinct}${_git_cached}${ColorDebug}.."
    run "${GIT_BIN} clone --depth 1 --progress --recursive --jobs=${CPUS} --branch ${_chk_branch} --single-branch ${_git_cached} ${_dest_repo}" \
        && debug "Cloned branch: ${ColorDistinct}${_chk_branch}${ColorDebug} from cached repository: ${ColorDistinct}${_git_cached}${ColorDebug}"
    unset _git_cached _bare_name _chk_branch _build_dir _dest_repo
}


available_bundles () {
    if [ -x "${CURL_BIN}" ]; then
        _fetch_cmd="${CURL_BIN}"
        _fetch_opts="-s"
    else
        _fetch_cmd="${FETCH_BIN}"
        _fetch_opts="-qo-"
    fi

    permnote "Binary bundles available for ${ColorDistinct}${OS_TRIPPLE}${ColorNote} system:"
    _bundlelist="$(${_fetch_cmd} ${_fetch_opts} "${MAIN_BINARY_REPOSITORY}/${OS_TRIPPLE}/" | "${GREP_BIN}" -E "(${DEFAULT_ARCHIVE_TARBALL_EXT}|${DEFAULT_SOFTWARE_SNAPSHOT_EXT})" 2>/dev/null \
    | "${GREP_BIN}" -v "sha1" 2>/dev/null | "${CUT_BIN}" -d "\"" -f2 | "${SED_BIN}" -E "s/-${OS_TRIPPLE}(\\${DEFAULT_ARCHIVE_TARBALL_EXT}|\\${DEFAULT_SOFTWARE_SNAPSHOT_EXT})//g")"

    for _bundle in $(to_iter "${_bundlelist}"); do
        load_defaults
        _bundle=$(echo "${_bundle}" | "${SED_BIN}" -E "s/-([0-9])/ \1/g" )
        _bname=$(echo "${_bundle}" | "${CUT_BIN}" -d" " -f1 )
        _bver=$(echo "${_bundle}" | "${CUT_BIN}" -d" " -f2 )
        if [ -e "${DEFINITIONS_DIR}/$(lowercase "${_bname}")${DEFAULT_DEF_EXT}" ]; then
            load_defs "${_bname}"
        else
            debug "Definition for bundle ${ColorDistinct}${_bname}${ColorDebug} not found, skipping."
            continue
        fi

        if [ "${_bver}" = "${DEF_VERSION}" ] && [ "${CURRENT_DEFINITION_DISABLED}" != "YES" ]; then
            permnote "${ColorDistinct}${_bname}${ColorNote} [${ColorDistinct}${_bver}${ColorNote}]"
        else
            printf "  %b%b%b\n" "${ColorDark}" "${_bname} [${_bver}]" ${ColorReset} >&2
        fi
    done

    permnote "Bundles highlighted in ${ColorDistinct}cyan${ColorNote} are the current versions to be installed by Sofin. Greyed out are versions or bundles currently disabled for your system version."
}


guess_next_versions () {
    _version="${1}"
    _major="$(printf "%b" "${_version}" | ${AWK_BIN} 'BEGIN {FS="."} {print $1}')"
    _minor="$(printf "%b" "${_version}" | ${AWK_BIN} 'BEGIN {FS="."} {print $2}')"
    _patch="$(printf "%b" "${_version}" | ${AWK_BIN} 'BEGIN {FS="."} {print $3}')"
    debug "guess_next_versions input: ${ColorDistinct}${_major} ${_minor} ${_patch}${ColorDebug}"

    # handle no patch version:
    case "${_patch}" in
        "")
            case "${_minor}" in
                "")
                    case "${_major}" in
                        *[_-]*) # ignore versions like icu: "4c-70_1"
                            debug "Skipping custom version pattern: ${ColorDistinct}${_major}${ColorDebug}"
                            ;;

                        *)
                            _major_origin="${_major}"

                            _last_char="$(printf "%b" ${_major} | ${AWK_BIN} '{print substr($0,length,1)}')"
                            _last_char_next="$(printf "%b" "${_last_char}" | ${TR_BIN} "0-9a-z" "1-9a-z_")" # next char tr trick
                            _major="$(printf "%b" "${_major}" | ${SED_BIN} -e "s/${_last_char}/${_last_char_next}/")"
                            printf "%b " "${_major}"

                            _next_number="$(printf "%b" "${_major_origin}" | ${SED_BIN} -e "s/${_last_char}//")"
                            _next_number="$(( ${_next_number} + 1))"
                            _major="${_next_number}a"
                            printf "%b" "${_major}"
                            ;;
                    esac
                    ;;

                *[a-z]|*[A-Z]) # case when version contains alphanumerics like "1.23b" should return "1.23c" or "1.24a"
                    _minor_origin="${_minor}"

                    _last_char="$(printf "%b" ${_minor} | ${AWK_BIN} '{print substr($0,length,1)}')"
                    _last_char_next="$(printf "%b" "${_last_char}" | ${TR_BIN} "0-9a-z" "1-9a-z_")" # next char tr trick
                    _minor="$(printf "%b" "${_minor}" | ${SED_BIN} -e "s/${_last_char}/${_last_char_next}/")"
                    printf "%b.%b " "${_major}" "${_minor}"

                    _next_number="$(printf "%b" "${_minor_origin}" | ${SED_BIN} -e "s/${_last_char}//")"
                    _next_number="$(( ${_next_number} + 1))"
                    _minor="${_next_number}a"
                    printf "%b.%b" "${_major}" "${_minor}"
                    ;;

                *)
                    printf "%b.%b " "${_major}" "$(( ${_minor} + 1 ))"
                    printf "%b.%b" "$(( ${_major} + 1 ))" "0"
                    ;;
            esac
            ;;

        *[a-z]|*[A-Z])
            _patch_origin="${_patch}"

            _last_char="$(printf "%b" ${_patch} | ${AWK_BIN} '{print substr($0,length,1)}')"
            _last_char_next="$(printf "%b" "${_last_char}" | ${TR_BIN} "0-9a-z" "1-9a-z_")" # next char tr trick
            _patch="$(printf "%b" "${_patch}" | ${SED_BIN} -e "s/${_last_char}/${_last_char_next}/")"
            printf "%b.%b.%b " "${_major}" "${_minor}" "${_patch}"

            _next_number="$(printf "%b" "${_patch_origin}" | ${SED_BIN} -e "s/${_last_char}//")"
            _next_number="$(( ${_next_number} + 1))"
            _patch="${_next_number}a"
            printf "%b.%b.%b" "${_major}" "${_minor}" "${_patch}"
            ;;

        "0")
            printf "%b.%b.%b " "${_major}" "$(( ${_minor} + 1 ))" "0"
            printf "%b.%b.%b" "${_major}" "${_minor}" "$(( ${_patch} + 1 ))"
            ;;

        *)
            printf "%b.%b.%b " "${_major}" "${_minor}" "$(( ${_patch} + 1 ))"
            printf "%b.%b.%b" "${_major}" "$(( ${_minor} + 1 ))" "0"
            ;;
    esac
    unset _version _major _minor _patch
}


show_new_origin_updates () {
    _definitions="${*}"
    if [ -x "${CURL_BIN}" ]; then
        _fetch_cmd="${CURL_BIN}"
        _fetch_opts="-sSfL -m5 -O"
    else
        _fetch_cmd="${FETCH_BIN}"
        _fetch_opts="-q -T5"
    fi

    # handle case when we wish to show all origin updates
    case "${_definitions}" in
        "@" | "all")
            _definitions="$(${FIND_BIN} "${DEFINITIONS_DIR}" -mindepth 1 -maxdepth 1 -type f -name "*${DEFAULT_DEF_EXT}" 2>/dev/null | ${SORT_BIN})"
            ;;
    esac

    for _definition in $(to_iter "${_definitions}"); do
        debug "Processing origin of bundle: ${ColorDistinct}${_definition}${ColorDebug}"
        load_defaults
        load_defs "${_definition}"

        if [ -n "${DEF_ORIGIN}" ]; then
            _possible_next_versions="$(guess_next_versions "${DEF_VERSION}")"
            for _possible_next in $(to_iter "${_possible_next_versions}"); do
                _possible_next="${_possible_next##*/}"
                case "${_possible_next}" in
                    "defaults.def" | "skeleton.def")
                        ;;

                    *)
                        _next_version_origin="$(printf "%b\n" "${DEF_ORIGIN}" | ${SED_BIN} -e "s/${DEF_VERSION}/${_possible_next}/g")"
                        debug "Next version of ${ColorDistinct}${_definition##*/}${ColorDebug} could have origin: ${ColorDistinct}${_next_version_origin}${ColorDebug}"
                        cd /tmp
                        try "${_fetch_cmd} ${_fetch_opts} ${_next_version_origin}"
                        if [ "0" = "${?}" ]; then
                            warn "Possible new version of definition: ${ColorDistinct}${DEF_NAME}${DEF_SUFFIX}${ColorWarning} found. Origin: ${ColorDistinct}${_next_version_origin}${ColorWarning}"
                        fi
                        ${RM_BIN} -f "${_next_version_origin##*/}"
                        ;;
                esac
            done
        else
            debug "No origin for: ${ColorDistinct}${_definition##*/}${ColorDebug}"
        fi
    done

    unset _bundles _bundle
}
