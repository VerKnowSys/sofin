check_version () { # $1 => installed version, $2 => available version
    if [ ! "${1}" = "" ]; then
        if [ ! "${2}" = "" ]; then
            if [ ! "${1}" = "${2}" ]; then
                warn "Bundle: $(distinct w ${application}), version: $(distinct w ${2}) is definied, but installed version is: $(distinct w ${1})"
                FOUND_OUTDATED=YES
            fi
        fi
    fi
}


# validate environment availability or crash
validate_env () {
    ${ENV_BIN} 2>/dev/null | ${GREP_BIN} '_BIN=/' 2>/dev/null | while IFS= read -r _envvar
    do
        _var_value="$(${PRINTF_BIN} "${_envvar}" | ${AWK_BIN} '{sub(/^[A-Z_]*=/, ""); print $1;}' 2>/dev/null)"
        if [ ! -x "${_var_value}" ]; then
            error "Required binary is unavailable: $(distinct e ${_envvar})"
        fi
    done || exit 1
    unset _var_value _envvar
}


fail_on_bg_job () {
    _deps=$*
    debug "deps=$(distinct d $(echo ${_deps} | eval "${NEWLINES_TO_SPACES_GUARD}"))"
    create_dirs
    acquire_lock_for "${_deps}"
    unset _deps
}


fail_any_bg_jobs () {
    # Traverse through locks, make sure that every pid from lock is dead before cleaning can continue
    for _a_lock in $(${FIND_BIN} "${LOCKS_DIR}" -type f -name "*${DEFAULT_LOCK_EXT}" -print 2>/dev/null); do
        _bundle_name="$(${BASENAME_BIN} ${_a_lock} 2>/dev/null)"
        _lock_pid="$(${CAT_BIN} "${_a_lock}" 2>/dev/null)"
        ${KILL_BIN} -0 ${_lock_pid} 2>/dev/null >/dev/null
        if [ "$?" = "0" ]; then
            error "Detected running instance of Sofin, locked on bundle: $(distinct e "${_bundle_name}") pid: $(distinct e "${_lock_pid}")"
        fi
    done
    unset _bundle_name _lock_pid _a_lock
}


validate_reqs () {
    if [ "${SYSTEM_NAME}" != "Darwin" ]; then
        if [ -d "/usr/local" ]; then
            _a_files="$(${FIND_BIN} /usr/local -maxdepth 3 -type f 2>/dev/null | ${WC_BIN} -l 2>/dev/null | ${SED_BIN} -e 's/^ *//g;s/ *$//g' 2>/dev/null)"
            if [ "${_a_files}" != "0" ]; then
                if [ "${_a_files}" != "1" ]; then
                    _pstfix="s"
                fi
                warn "/usr/local has been found, and contains: $(distinct w ${_a_files}+) file${_pstfix}"
            fi
        fi
        unset _a_files _pstfix
    fi
    if [ ! -z "${DEBUGBUILD}" ]; then
        warn "Debug build is enabled."
    fi
}


check_defs_dir () {
    if [ ! -d "${SOFTWARE_DIR}" ]; then
        debug "No $(distinct d ${SOFTWARE_DIR}) found. Creating one."
        "${MKDIR_BIN}" -p "${SOFTWARE_DIR}" >/dev/null 2>&1
    fi
    if [ ! -d "${CACHE_DIR}" ]; then
        debug "No cache folder found. Creating one at: $(distinct d ${CACHE_DIR})"
        "${MKDIR_BIN}" -p "${CACHE_DIR}" >/dev/null 2>&1
    fi
}


validate_archive_sha1 () {
    _archive_name="$1"
    if [ ! -f "${_archive_name}" -o \
           -z "${_archive_name}" ]; then
         error "validate_archive_sha1(): Specified empty $(distinct e archive_name), or file doesn't exists: $(distinct e ${_archive_name})"
    fi
    # checking archive sha1 checksum
    if [ -e "${_archive_name}" ]; then
        _current_archive_sha1="$(file_checksum "${_archive_name}")"
        debug "current_archive_sha1: $(distinct d ${_current_archive_sha1})"
    else
        error "No bundle archive found?"
    fi
    _current_sha_file="${_archive_name}${DEFAULT_CHKSUM_EXT}"
    _sha1_value="$(${CAT_BIN} ${_current_sha_file} 2>/dev/null)"
    if [ ! -f "${_current_sha_file}" -o \
           -z "${_sha1_value}" ]; then
        ${RM_BIN} -fv "${_archive_name}" >> ${LOG} 2>> ${LOG}
        ${RM_BIN} -fv "${_current_sha_file}" >> ${LOG} 2>> ${LOG}
    fi
    debug "Checking SHA1 match: $(distinct d ${_current_archive_sha1}) vs $(distinct d ${_sha1_value})"
    if [ "${_current_archive_sha1}" != "${_sha1_value}" ]; then
        debug "Bundle archive checksum doesn't match ($(distinct d "${_current_archive_sha1}") vs $(distinct d "${sha1_value}")), removing binary builds and proceeding into build phase"
        ${RM_BIN} -fv "${_archive_name}" >> ${LOG} 2>> ${LOG}
        ${RM_BIN} -fv "${_current_sha_file}" >> ${LOG} 2>> ${LOG}
    else
        note "Found correct prebuilt binary archive: $(distinct n "${_archive_name}")"
    fi
    unset _sha1_value _current_sha_file _current_archive_sha1 _archive_name
}


validate_def_postfix () {
    _cigiven_name="$(${BASENAME_BIN} "$(echo "$(lowercase "${1}")" | eval "${CUTOFF_DEF_EXT_GUARD}")")"
    _cidefinition_name="$(${BASENAME_BIN} "$(echo "$(lowercase "${2}")" | eval "${CUTOFF_DEF_EXT_GUARD}")")"
    debug "_cigiven_name: $(distinct d "${_cigiven_name}"), _cidefinition_name: $(distinct d "${_cidefinition_name}")"
    # case when DEF_POSTFIX was ommited => use definition file name difference as POSTFIX:
    _l1="$(${PRINTF_BIN} "${_cidefinition_name}" | ${WC_BIN} -c 2>/dev/null)"
    _l2="$(${PRINTF_BIN} "${_cigiven_name}" | ${WC_BIN} -c 2>/dev/null)"
    if [ "${_l1}" -gt "${_l2}" ]; then
        _cispc_nme_diff="$(difftext "${_cidefinition_name}" "${_cigiven_name}")"
    elif [ "${_l2}" -gt "${_l1}" ]; then
        _cispc_nme_diff="$(difftext "${_cigiven_name}" "${_cidefinition_name}")"
    else # equal
        _cispc_nme_diff="$(difftext "${_cigiven_name}" "$(lowercase "${DEF_NAME}")")"
    fi
    if [ -z "${DEF_POSTFIX}" -a \
       ! -z "${_cispc_nme_diff}" ]; then
       debug "Inferred DEF_POSTFIX=$(distinct d "${_cispc_nme_diff}") from definition: $(distinct d "${DEF_NAME}")"
       DEF_POSTFIX="${_cispc_nme_diff}"
    elif [ ! -z "${_cispc_nme_diff}" ]; then
        debug "Difference: $(distinct d "${_cispc_nme_diff}")"
    else
        debug "No difference."
    fi
    unset _cidefinition_name _cigiven_name _cispec_name_diff __cut_ext_guard _cispc_nme_diff _l1 _l2
}


validate_definition_disabled () {
    _ch_dis_name="${1}"
    unset DEF_DISABLED
    # check requirement for disabled state:
    if [ ! -z "${_ch_dis_name}" ]; then
        for _def_disabled in ${_ch_dis_name}; do
            if [ "${SYSTEM_NAME}" = "${_def_disabled}" ]; then
                debug "Disabled: $(distinct d "${_def_disabled}") on $(distinct d "${SYSTEM_NAME}")"
                DEF_DISABLED=YES
            fi
        done
    fi
}
