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
    ${ENV_BIN} 2>/dev/null | ${GREP_BIN} '_BIN=/' 2>/dev/null | while IFS= read -r envvar
    do
        var_value="$(${PRINTF_BIN} "${envvar}" | ${AWK_BIN} '{sub(/^[A-Z_]*=/, ""); print $1;}' 2>/dev/null)"
        if [ ! -x "${var_value}" ]; then
            error "Required binary is unavailable: $(distinct e ${envvar})"
        fi
    done || exit 1
}


fail_on_background_sofin_job () {
    deps=$*
    debug "fail_on_background_sofin_job(): deps=$(distinct d $(echo ${deps} | eval "${NEWLINES_TO_SPACES_GUARD}"))"
    create_cache_directories
    acquire_lock_for "${deps}"
    unset deps
}


fail_on_any_background_jobs () {
    # Traverse through locks, make sure that every pid from lock is dead before cleaning can continue
    for a_lock in $(${FIND_BIN} "${LOCKS_DIR}" -type f -name "*${DEFAULT_LOCK_EXT}" -print 2>/dev/null); do
        bundle_name="$(${BASENAME_BIN} ${a_lock} 2>/dev/null)"
        lock_pid="$(${CAT_BIN} "${a_lock}" 2>/dev/null)"
        ${KILL_BIN} -0 ${lock_pid} 2>/dev/null >/dev/null
        if [ "$?" = "0" ]; then
            error "Detected running instance of Sofin, locked on bundle: $(distinct e "${bundle_name}") pid: $(distinct e "${lock_pid}")"
        fi
    done
}


check_requirements () {
    if [ -z "${APPLICATIONS}" ]; then
        debug "check_requirements(): APPLICATIONS is empty! Exitting"
        exit
    fi
    if [ "${SYSTEM_NAME}" != "Darwin" ]; then
        if [ -d "/usr/local" ]; then
            files="$(${FIND_BIN} /usr/local -maxdepth 3 -type f 2>/dev/null | ${WC_BIN} -l 2>/dev/null | ${SED_BIN} -e 's/^ *//g;s/ *$//g' 2>/dev/null)"
            if [ "${files}" != "0" ]; then
                if [ "${files}" != "1" ]; then
                    pstfix="s"
                fi
                warn "/usr/local has been found, and contains: $(distinct w ${files}+) file${pstfix}"
            fi
        fi
        unset files pstfix
    fi
    if [ ! -z "${DEBUGBUILD}" ]; then
        warn "Debug build is enabled."
    fi
}


check_definition_dir () {
    if [ ! -d "${SOFTWARE_DIR}" ]; then
        debug "No $(distinct d ${SOFTWARE_DIR}) found. Creating one."
        "${MKDIR_BIN}" -p "${SOFTWARE_DIR}"
    fi
    if [ ! -d "${CACHE_DIR}" ]; then
        debug "No cache folder found. Creating one at: $(distinct d ${CACHE_DIR})"
        "${MKDIR_BIN}" -p "${CACHE_DIR}"
    fi
}


validate_alternatives () {
    an_app="$1"
    if [ ! -f "${DEFINITIONS_DIR}${an_app}${DEFAULT_DEF_EXT}" ]; then
        contents=""
        maybe_version="$(${FIND_BIN} ${DEFINITIONS_DIR} -maxdepth 1 -name ${an_app}\*${DEFAULT_DEF_EXT} 2>/dev/null)"
        for maybe in ${maybe_version}; do
            elem="$(${BASENAME_BIN} ${maybe} 2>/dev/null)"
            cap_elem="$(capitalize "${elem}")"
            contents="${contents}$(echo "${cap_elem}" | ${SED_BIN} 's/\..*//' 2>/dev/null) "
        done
        if [ -z "${contents}" ]; then
            warn "No such definition found: $(distinct w ${an_app}). No alternatives found."
        else
            warn "No such definition found: $(distinct w ${an_app}). Alternatives found: $(distinct w ${contents})"
        fi
        exit
    fi
    unset an_app elem cap_elem contents maybe_version
}


validate_archive_sha1 () {
    archive_name="$1"
    if [ ! -f "${archive_name}" -o \
           -z "${archive_name}" ]; then
         error "validate_archive_sha1(): Specified empty $(distinct e archive_name), or file doesn't exists: $(distinct e ${archive_name})"
    fi
    # checking archive sha1 checksum
    if [ -e "${archive_name}" ]; then
        current_archive_sha1="$(file_checksum "${archive_name}")"
        debug "current_archive_sha1: $(distinct d ${current_archive_sha1})"
    else
        error "No bundle archive found?"
    fi
    current_sha_file="${archive_name}${DEFAULT_CHKSUM_EXT}"
    sha1_value="$(${CAT_BIN} ${current_sha_file} 2>/dev/null)"
    if [ ! -f "${current_sha_file}" -o \
           -z "${sha1_value}" ]; then
        ${RM_BIN} -fv "${archive_name}" >> ${LOG} 2>> ${LOG}
        ${RM_BIN} -fv "${current_sha_file}" >> ${LOG} 2>> ${LOG}
    fi
    debug "Checking SHA1 match: $(distinct d ${current_archive_sha1}) vs $(distinct d ${sha1_value})"
    if [ "${current_archive_sha1}" != "${sha1_value}" ]; then
        debug "Bundle archive checksum doesn't match ($(distinct d "${current_archive_sha1}") vs $(distinct d "${sha1_value}")), removing binary builds and proceeding into build phase"
        ${RM_BIN} -fv ${archive_name} >> ${LOG} 2>> ${LOG}
        ${RM_BIN} -fv ${current_sha_file} >> ${LOG} 2>> ${LOG}
    else
        note "Found correct prebuilt binary archive: $(distinct n "${archive_name}")"
    fi
}
