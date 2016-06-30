check_version () { # $1 => installed version, $2 => available version
    if [ ! "${1}" = "" ]; then
        if [ ! "${2}" = "" ]; then
            if [ ! "${1}" = "${2}" ]; then
                warn "Bundle: $(distinct w ${application}), version: $(distinct w ${2}) is definied, but installed version is: $(distinct w ${1})"
                export outdated=YES
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


fail_on_background_sofin_job () {
    _deps=$*
    debug "fail_on_background_sofin_job(): deps=$(distinct d $(echo ${_deps} | eval "${NEWLINES_TO_SPACES_GUARD}"))"
    create_cache_directories
    acquire_lock_for "${_deps}"
    unset _deps
}


fail_on_any_background_jobs () {
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


check_requirements () {
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


check_definition_dir () {
    if [ ! -d "${SOFTWARE_DIR}" ]; then
        debug "No $(distinct d ${SOFTWARE_DIR}) found. Creating one."
        "${MKDIR_BIN}" -p "${SOFTWARE_DIR}" >/dev/null 2>&1
    fi
    if [ ! -d "${CACHE_DIR}" ]; then
        debug "No cache folder found. Creating one at: $(distinct d ${CACHE_DIR})"
        "${MKDIR_BIN}" -p "${CACHE_DIR}" >/dev/null 2>&1
    fi
}


validate_alternatives () {
    _an_app="$1"
    if [ ! -f "${DEFINITIONS_DIR}${_an_app}${DEFAULT_DEF_EXT}" ]; then
        _contents=""
        _maybe_version="$(${FIND_BIN} ${DEFINITIONS_DIR} -maxdepth 1 -name ${_an_app}\*${DEFAULT_DEF_EXT} 2>/dev/null)"
        for _maybe in ${_maybe_version}; do
            _elem="$(${BASENAME_BIN} "${_maybe}" 2>/dev/null)"
            _cap_elem="$(capitalize "${_elem}")"
            _contents="${_contents}$(echo "${_cap_elem}" | ${SED_BIN} 's/\..*//' 2>/dev/null) "
        done
        if [ -z "${_contents}" ]; then
            warn "No such definition found: $(distinct w ${_an_app}). No alternatives found."
        else
            warn "No such definition found: $(distinct w ${_an_app}). Alternatives found: $(distinct w ${_contents})"
        fi
        exit
    fi
    unset _an_app _elem _cap_elem _contents _maybe_version
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


validate_definition_postfix () {
    __cut_ext_guard='${SED_BIN} -e "s#${DEFAULT_DEF_EXT}##" 2>/dev/null'
    _cigiven_name="$(${BASENAME_BIN} "$(echo "$(lowercase "${1}")" | eval "${__cut_ext_guard}")")"
    _cidefinition_name="$(${BASENAME_BIN} "$(echo "$(lowercase "${1}")" | eval "${__cut_ext_guard}")")"
    # case when DEF_POSTFIX was ommited => use definition file name difference as POSTFIX:
    _cispc_nme_diff="$(difftext "${_cigiven_name}" "${_cidefinition_name}")"
    if [ -z "${DEF_POSTFIX}" -a \
       ! -z "${_cispc_nme_diff}" ]; then
       debug "Inferred value from definition file name: DEF_POSTFIX=$(distinct d "${_cispc_nme_diff}")"
       DEF_POSTFIX="${_cispc_nme_diff}"
    fi
    unset _cidefinition_name _cigiven_name _cispec_name_diff __cut_ext_guard
}
