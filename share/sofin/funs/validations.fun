check_version () { # $1 => installed version, $2 => available version
    if [ ! "${1}" = "" ]; then
        if [ ! "${2}" = "" ]; then
            if [ ! "${1}" = "${2}" ]; then
                warn "Bundle: $(distw "$(capitalize "${3}")"), version: $(distw "${2}") is definied, but installed version is: $(distw "${1}")"
                FOUND_OUTDATED=YES
            fi
        fi
    fi
}


# validate environment availability or crash
validate_env () {
    for _envvar in $(set | ${GREP_BIN} -EI "^[A-Z]+_BIN=" 2>/dev/null)
    do
        _var_value="${_envvar#*=}"
        if [ ! -x "${_var_value}" ]; then
            error "Required binary is unavailable: $(diste "${_envvar}")"
        fi
    done || exit "${ERRORCODE_VALIDATE_ENV_FAILURE}"
    unset _var_value _envvar
}


fail_on_bg_job () {
    _deps="${*}"
    debug "bgJobs => $(distd "$(printf "%s\n" "${_deps}" | eval "${NEWLINES_TO_SPACES_GUARD}")")"
    acquire_lock_for "${_deps}"
    unset _deps
}


fail_any_bg_jobs () {
    # Traverse through locks, make sure that every pid from lock is dead before cleaning can continue
    for _a_lock in $(${FIND_BIN} "${LOCKS_DIR}" -type f -name "*${DEFAULT_LOCK_EXT}" -print 2>/dev/null); do
        _bundle_name="${_a_lock##*/}"
        _lock_pid="$(${CAT_BIN} "${_a_lock}" 2>/dev/null)"
        if [ -n "${_lock_pid}" ]; then
            try "${KILL_BIN} -0 ${_lock_pid}"
            if [ "${?}" = "0" ]; then
                error "Detected running instance of Sofin, locked on bundle: $(diste "${_bundle_name}") pid: $(diste "${_lock_pid}")"
            fi
        fi
    done
    unset _bundle_name _lock_pid _a_lock
}


validate_reqs () {
    if [ "${SYSTEM_NAME}" != "Darwin" ]; then
        if [ -d "/usr/local/lib" ]; then
            _a_files="$(${FIND_BIN} /usr/local/lib -name '*.so' -or -name '*.o' -or -name '*.la' -or -name '*.a' -maxdepth 5 -type f 2>/dev/null | ${WC_BIN} -l 2>/dev/null | ${SED_BIN} -e 's/^ *//g;s/ *$//g' 2>/dev/null)"
            if [ "${_a_files}" != "0" ]; then
                warn "$(distw "/usr/local/lib") has been found with: $(distw "${_a_files}+") $(distw "possibly unfriendly") libraries!"
            fi
        fi
        unset _a_files _pstfix
    fi
    if [ -n "${DEBUGBUILD}" ]; then
        warn "Debug build is enabled."
    fi
    if [ -z "${LZ4_BIN}" ] || [ -z "${LZ4CAT_BIN}" ]; then
        error "No $(diste Lz4) installed. It's required for long-term/ safe binary builds"
    fi
}


validate_archive_sha1 () {
    _archive_name="${1}"
    if [ ! -f "${_archive_name}" ] || \
         [ -z "${_archive_name}" ]; then
         error "Specified empty $(diste archive_name), or file doesn't exist: $(diste "${_archive_name}")"
    fi
    # checking archive sha1 checksum
    if [ -e "${_archive_name}" ]; then
        _current_archive_sha1="$(file_checksum "${_archive_name}")"
        debug "current_archive_sha1: $(distd "${_current_archive_sha1}")"
    else
        error "No bundle archive found?"
    fi
    _current_sha_file="${_archive_name}${DEFAULT_CHKSUM_EXT}"
    _sha1_value="$(${CAT_BIN} "${_current_sha_file}" 2>/dev/null)"
    if [ ! -f "${_current_sha_file}" ] || \
               [ -z "${_sha1_value}" ]; then
        debug "No sha1 file available for archive, or sha1 value is empty! Removing local binary build(s) of: $(distd "${_archive_name}")"
        try "${RM_BIN} -f ${_archive_name} ${_current_sha_file}"
    fi
    if [ "${_current_archive_sha1}" != "${_sha1_value}" ]; then
        debug "Bundle archive checksum doesn't match (is: $(distd "${_current_archive_sha1}") but got: $(distd "${_sha1_value}"), removing binary builds and proceeding into build phase"
        try "${RM_BIN} -f ${_archive_name} ${_current_sha_file}"
    else
        permnote "Cached archive found: $(distn "${_archive_name##*/}")"
    fi
    unset _sha1_value _current_sha_file _current_archive_sha1 _archive_name
}


validate_def_postfix () {
    _arg1="$(printf '%s' "$(lowercase "${1}")" | eval "${CUTOFF_DEF_EXT_GUARD}")"
    _arg2="$(printf '%s' "$(lowercase "${2}")" | eval "${CUTOFF_DEF_EXT_GUARD}")"
    _cigiven_name="${_arg1##*/}" # basename
    _cidefinition_name="${_arg2##*/}"
    # case when DEF_SUFFIX was ommited => use definition file name difference as POSTFIX:
    _l1="${#_cidefinition_name}"
    _l2="${#_cigiven_name}"
    if [ "${_l1}" -gt "${_l2}" ]; then
        _cispc_nme_diff="$(difftext "${_cidefinition_name}" "${_cigiven_name}")"
    elif [ "${_l2}" -gt "${_l1}" ]; then
        _cispc_nme_diff="$(difftext "${_cigiven_name}" "${_cidefinition_name}")"
    else # equal
        # if difference is the name itself..
        _cispc_nme_diff="$(difftext "${_cigiven_name}" "$(lowercase "${DEF_NAME}")")"
    fi
    debug "validate_def_postfix() for: $(distd "${DEF_NAME}"), 1: $(distd "${_cigiven_name}"), 2: $(distd "${_cidefinition_name}"), DIFF: $(distd "${_cispc_nme_diff}")"
    if  [ -z "${DEF_SUFFIX}" ] && \
        [ "${_cispc_nme_diff}" != "${DEF_NAME}" ] && \
        [ "${_cispc_nme_diff}" != "${DEF_NAME}${DEF_SUFFIX}" ]; then
        debug "Inferred DEF_SUFFIX=$(distd "${_cispc_nme_diff}") from definition: $(distd "${DEF_NAME}")"
        DEF_SUFFIX="${_cispc_nme_diff}"
        # TODO: detect if postfix isn't already applied here

    elif [ "${_cispc_nme_diff}" = "${DEF_NAME}" ] && \
         [  "${_cispc_nme_diff}" = "${DEF_NAME}${DEF_SUFFIX}" ]; then
        # NOTE: This is case when dealing with definition file name,
        # that has nothing in common with DEF_NAME (usually it's a postfix).
        # In that case, we should pick specified name, *NOT* DEF_NAME:
        DEF_NAME="${_cigiven_name}"
        unset DEF_SUFFIX

        debug "Inferred DEF_NAME: $(distd "${_cigiven_name}"), no DEF_SUFFIX, since definition file name, has nothing in common with DEF_NAME - which is allowed."

    elif [ -n "${_cispc_nme_diff}" ]; then
        debug "Given-name and definition-name difference: $(distd "${_cispc_nme_diff}")"
    else
        debug "No difference between given-name and definition-name."
    fi
    unset _cidefinition_name _cigiven_name _cispec_name_diff __cut_ext_guard _cispc_nme_diff _l1 _l2
}


validate_definition_disabled () {
    # check requirement for disabled state:
    for _def_disable_on in $(to_iter "${DEF_DISABLE_ON}"); do
        if [ "${SYSTEM_NAME}" = "${_def_disable_on}" ]; then
            debug "Disabled: $(distd "${_def_disable_on}") on $(distd "${SYSTEM_NAME}")"
            DEF_DISABLED_ON=YES
        fi
    done
}


validate_util_availability () {
    _req_name="$(lowercase "${1}")"
    _req_util_indicator="${SOFIN_UTILS_DIR}/$(capitalize "${_req_name}")/${_req_name}${DEFAULT_INST_MARK_EXT}"
    debug "Checking req name: $(distd "${_req_name}") with installing indicator: $(distd "${_req_util_indicator}")"
    if [ -f "${_req_util_indicator}" ]; then
        debug "Utility available for: $(distd "${_req_name}"). Disabling"
        DEF_DISABLED_ON=YES
    fi
}


validate_pie_on_exports () {
    _bundz="${*}"
    if [ -z "${_bundz}" ]; then
        error "At least single bundle name has to be specified for pie validation."
    fi
    if [ "YES" = "${CAP_SYS_HARDENED}" ]; then
        debug "Checking PIE on exports: $(distd "${_bundz}")"
        for _bun in $(to_iter "${_bundz}"); do
            if [ -d "${SOFTWARE_DIR}/${_bun}/exports" ]; then
                _a_dir="${SOFTWARE_DIR}/${_bun}/exports"
            elif [ -d "${SOFTWARE_DIR}/${_bun}/exports-disabled" ]; then
                _a_dir="${SOFTWARE_DIR}/${_bun}/exports-disabled"
            else
                debug "No exports of bundle: $(distd "${_bun}"). PIE validation skipped."
                return 0
            fi
            _pie_indicator="${SOFTWARE_DIR}/${_bun}/$(lowercase "${_bun}")${DEFAULT_PIE_MARK_EXT}"
            if [ -f "${_pie_indicator}" ]; then
                debug "PIE exports were checked already for bundle: $(distd "${_bun}")"
                continue
            else
                for _bin in $(${FIND_BIN} "${_a_dir}" -mindepth 1 -maxdepth 1 -type l 2>/dev/null | ${XARGS_BIN} "${READLINK_BIN}" -f 2>/dev/null); do
                    try "${FILE_BIN} '${_bin}' 2>/dev/null | ${GREP_BIN} 'ELF' 2>/dev/null"
                    if [ "$?" = "0" ]; then # it's ELF binary/library:
                        big_fat_warn () {
                            warn "Security - Exported ELF binary: $(distw "${_bin}"), is not a $(distw "${PIE_TYPE_ENTRY}") (not-PIE)!"
                            printf "SECURITY: ELF binary: '${_bin}', is not a '${PIE_TYPE_ENTRY}' (not-PIE)!\n" >> "${_pie_indicator}.warn"
                        }
                        try "${FILE_BIN} '${_bin}' 2>/dev/null | ${GREP_BIN} 'ELF' 2>/dev/null | ${EGREP_BIN} '${PIE_TYPE_ENTRY}' 2>/dev/null" || big_fat_warn
                    else
                        debug "Executable, but not an ELF: $(distd "${_bin}")"
                    fi
                done
                run "${TOUCH_BIN} ${_pie_indicator}" && \
                    debug "PIE check done for bundle: $(distd "${_bun}")"
            fi
        done

    else
        debug "Nothing required."
    fi
    unset _bin _a_dir _pie_indicator _bun _bundz
}


validate_kern_loaded_dtrace () {
    if [ -n "${CAP_SYS_DTRACE}" ]; then
        case "${SYSTEM_NAME}" in
            FreeBSD)
                debug "Making sure dtrace kernel module is loaded"
                ${KLDSTAT_BIN} 2>/dev/null | ${GREP_BIN} -F 'dtraceall' >/dev/null 2>&1 \
                    || try "${KLDLOAD_BIN} dtraceall"
                ;;
        esac
    fi
}


validate_sys_limits () {

    # Limits for production CAP_SYS_HARDENED environment:
    _ulimit_core="0"
    _ulimit_nofile="16384"
    _ulimit_stackkb="131070"
    _ulimit_up_max_ps="8192"

    if [ "YES" = "${CAP_SYS_WORKSTATION}" ]; then
        _ulimit_nofile="16384"
        _ulimit_stackkb="16384"
        _ulimit_up_max_ps="512"
        debug "Initialised limits for Darwin workstation"
    fi

    try "ulimit -n ${_ulimit_nofile}" || \
        warn "Sofin has failed to set reasonable environment limit of open files: $(distw "${_ulimit_nofile}"). Local limit is: "$(ulimit -n)". Troubles may follow!"
    try "ulimit -s ${_ulimit_stackkb}" || \
        warn "Sofin has failed to set reasonable environment limit of stack (in kb) to value: $(distw "${_ulimit_stackkb}"). Local limit is: "$(ulimit -s)". Troubles may follow!"
    try "ulimit -u ${_ulimit_up_max_ps}" || \
        warn "Sofin has failed to set reasonable environment limit of running processes to: $(distw "${_ulimit_up_max_ps}"). Local limit is: "$(ulimit -u)". Troubles may follow!"
    try "ulimit -c ${_ulimit_core}" || \
        warn "Sofin has failed to set core size limit to: $(distw "${_ulimit_core}"). Local limit is: "$(ulimit -c)".!"

    return 0
}
