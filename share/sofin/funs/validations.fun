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
    env | ${GREP_BIN} '_BIN=/' 2>/dev/null | while IFS= read -r envvar
    do
        var_value="$(${PRINTF_BIN} "${envvar}" | ${AWK_BIN} '{sub(/^[A-Z_]*=/, ""); print $1;}' 2>/dev/null)"
        if [ ! -x "${var_value}" ]; then
            error "Required binary is unavailable: $(distinct e ${envvar})"
            exit 1
        fi
    done || exit 1
}


fail_on_background_sofin_job () {
    deps=$*
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
    if [ "${APPLICATIONS}" = "" ]; then
        exit
    fi
    if [ "${SYSTEM_NAME}" != "Darwin" ]; then
        if [ -d "/usr/local" ]; then
            files="$(${FIND_BIN} /usr/local -maxdepth 3 -type f 2>/dev/null | ${WC_BIN} -l 2>/dev/null | ${SED_BIN} -e 's/^ *//g;s/ *$//g' 2>/dev/null)"
            if [ "${files}" != "0" ]; then
                warn "/usr/local has been found, and contains ${files}+ file(s)"
            fi
        fi
    fi
    if [ ! -z "${DEBUGBUILD}" ]; then
        warn "Debug build is enabled."
    fi
}


check_definition_dir () {
    if [ ! -d "${SOFTWARE_DIR}" ]; then
        debug "No ${SOFTWARE_DIR} found. Creating one."
        "${MKDIR_BIN}" -p "${SOFTWARE_DIR}"
    fi
    if [ ! -d "${CACHE_DIR}" ]; then
        debug "No cache folder found. Creating one at: ${CACHE_DIR}"
        "${MKDIR_BIN}" -p "${CACHE_DIR}"
    fi
}


validate_alternatives () {
    an_app="$1"
    if [ ! -f "${DEFINITIONS_DIR}${an_app}.def" ]; then
        contents=""
        maybe_version="$(${FIND_BIN} ${DEFINITIONS_DIR} -maxdepth 1 -name ${an_app}\*.def 2>/dev/null)"
        for maybe in ${maybe_version}; do
            elem="$(${BASENAME_BIN} ${maybe} 2>/dev/null)"
            cap_elem="$(capitalize "${elem}")"
            contents="${contents}$(echo "${cap_elem}" | ${SED_BIN} 's/\..*//' 2>/dev/null) "
        done
        if [ "${contents}" != "" ]; then
            warn "No such definition found: $(distinct w ${an_app}). Alternatives found: $(distinct w ${contents})"
        else
            warn "No such definition found: $(distinct w ${an_app}). No alternatives found."
        fi
        exit
    fi
}
