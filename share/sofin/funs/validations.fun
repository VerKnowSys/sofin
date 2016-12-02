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
    ${ENV_BIN} 2>/dev/null | ${GREP_BIN} '_BIN=/' 2>/dev/null | while IFS= read -r _envvar
    do
        _var_value="$(${PRINTF_BIN} '%s' "${_envvar}" | ${AWK_BIN} '{sub(/^[A-Z_]*=/, ""); print $1;}' 2>/dev/null)"
        if [ ! -x "${_var_value}" ]; then
            error "Required binary is unavailable: $(diste "${_envvar}")"
        fi
    done || exit "${ERRORCODE_VALIDATE_ENV_FAILURE}"
    unset _var_value _envvar
}


fail_on_bg_job () {
    _deps=${*}
    debug "deps=$(distd "$(${PRINTF_BIN} '%s\n' "${_deps}" | eval "${NEWLINES_TO_SPACES_GUARD}")")"
    create_dirs
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
        if [ -d "/usr/local" ]; then
            _a_files="$(${FIND_BIN} /usr/local -maxdepth 2 -type f 2>/dev/null | ${WC_BIN} -l 2>/dev/null | ${SED_BIN} -e 's/^ *//g;s/ *$//g' 2>/dev/null)"
            if [ "${_a_files}" != "0" ]; then
                if [ "${_a_files}" != "1" ]; then
                    _pstfix="s"
                fi
                warn "$(distw "/usr/local") has been found, which contains: $(distw "${_a_files}+") file${_pstfix}."
            fi
        fi
        unset _a_files _pstfix
    fi
    if [ -n "${DEBUGBUILD}" ]; then
        warn "Debug build is enabled."
    fi
}


check_defs_dir () {
    create_base_datasets
    if [ ! -d "${CACHE_DIR}" ]; then
        debug "No cache directory found. Creating one at: $(distd "${CACHE_DIR}")"
        "${MKDIR_BIN}" -p "${CACHE_DIR}" >/dev/null 2>&1
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
        debug "No sha1 file available for archive, or sha1 value is empty! Removing local bin-builds of: $(distd "${_archive_name}")"
        try "${RM_BIN} -fv ${_archive_name}"
        try "${RM_BIN} -fv ${_current_sha_file}"
    fi
    if [ "${_current_archive_sha1}" != "${_sha1_value}" ]; then
        debug "Bundle archive checksum doesn't match ($(distd "${_current_archive_sha1}") vs $(distd "${_sha1_value}")), removing binary builds and proceeding into build phase"
        try "${RM_BIN} -fv ${_archive_name}"
        try "${RM_BIN} -fv ${_current_sha_file}"
    else
        note "Found correct prebuilt binary archive: $(distn "${_archive_name}")"
    fi
    unset _sha1_value _current_sha_file _current_archive_sha1 _archive_name
}


validate_def_postfix () {
    _arg1="$(${PRINTF_BIN} '%s' "$(lowercase "${1}")" | eval "${CUTOFF_DEF_EXT_GUARD}")"
    _arg2="$(${PRINTF_BIN} '%s' "$(lowercase "${2}")" | eval "${CUTOFF_DEF_EXT_GUARD}")"
    _cigiven_name="${_arg1##*/}" # basename
    _cidefinition_name="${_arg2##*/}"
    # case when DEF_POSTFIX was ommited => use definition file name difference as POSTFIX:
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
    debug "validate_def_postfix: DEF_NAME: ${DEF_NAME}, 1: ${_cigiven_name}, 2: ${_cidefinition_name}, DIFF: ${_cispc_nme_diff}"
    if  [ -z "${DEF_POSTFIX}" ] && \
        [ "${_cispc_nme_diff}" != "${DEF_NAME}" ] && \
        [ "${_cispc_nme_diff}" != "${DEF_NAME}${DEF_POSTFIX}" ]; then
        debug "Inferred DEF_POSTFIX=$(distd "${_cispc_nme_diff}") from definition: $(distd "${DEF_NAME}")"
        DEF_POSTFIX="${_cispc_nme_diff}"
        # TODO: detect if postfix isn't already applied here

    elif [ "${_cispc_nme_diff}" = "${DEF_NAME}" ] && \
         [  "${_cispc_nme_diff}" = "${DEF_NAME}${DEF_POSTFIX}" ]; then
        # NOTE: This is case when dealing with definition file name,
        # that has nothing in common with DEF_NAME (usually it's a postfix).
        # In that case, we should pick specified name, *NOT* DEF_NAME:
        DEF_NAME="${_cigiven_name}"
        unset DEF_POSTFIX

        debug "Inferred DEF_NAME: $(distd "${_cigiven_name}"), no DEF_POSTFIX, since definition file name, has nothing in common with DEF_NAME - which is allowed."

    elif [ -n "${_cispc_nme_diff}" ]; then
        debug "Given-name and definition-name difference: $(distd "${_cispc_nme_diff}")"
    else
        debug "No difference between given-name and definition-name."
    fi
    unset _cidefinition_name _cigiven_name _cispec_name_diff __cut_ext_guard _cispc_nme_diff _l1 _l2
}


validate_definition_disabled () {
    _ch_dis_name="${1}"
    unset DEF_DISABLED_ON
    # check requirement for disabled state:
    if [ -n "${_ch_dis_name}" ]; then
        for _def_disabled in ${_ch_dis_name}; do
            if [ "${SYSTEM_NAME}" = "${_def_disabled}" ]; then
                debug "Disabled: $(distd "${_def_disabled}") on $(distd "${SYSTEM_NAME}")"
                DEF_DISABLED_ON=YES
            fi
        done
    fi
}


validate_pie_on_exports () {
    _bundz=${*}
    if [ -z "${_bundz}" ]; then
        error "At least single bundle name has to be specified for pie validation."
    fi
    if [ "YES" = "${CAP_SYS_HARDENED}" ]; then
        debug "Checking PIE on exports: $(distd "${_bundz}")"
        for _bun in ${_bundz}; do
            if [ -d "${SOFTWARE_DIR}${_bun}/exports" ]; then
                _a_dir="${SOFTWARE_DIR}${_bun}/exports"
            elif [ -d "${SOFTWARE_DIR}${_bun}/exports-disabled" ]; then
                _a_dir="${SOFTWARE_DIR}${_bun}/exports-disabled"
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
                        try "${FILE_BIN} '${_bin}' 2>/dev/null | ${GREP_BIN} 'ELF' 2>/dev/null | ${EGREP_BIN} '${PIE_TYPE_ENTRY}' 2>/dev/null" || \
                            warn "Exported ELF binary: $(distw "${_bin}"), is not a $(distw "${PIE_TYPE_ENTRY}") (not-PIE)!" && \
                                ${PRINTF_BIN} "WARNING: ELF binary: '${_bin}', is not a '${PIE_TYPE_ENTRY}' (not-PIE)!\n" >> "${_pie_indicator}.warn"
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
