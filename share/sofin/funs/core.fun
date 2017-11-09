
debug () {
    _in="${*}"
    if [ "${TTY}" = "YES" ]; then
        _permdbg="\n"
    else
        unset _permdbg
    fi
    if [ -n "${CAP_SYS_PRODUCTION}" ]; then
        if [ -n "${DEBUG}" ]; then
            ${PRINTF_BIN} "# (%s) λ %b%s%b\n" "${SHLVL}" "${ColorDebug}" "${_in}" "${ColorReset}"
        fi
        return 0
        # ${PRINTF_BIN} "# (%s) λ %b%s%b\n" "${SHLVL}" "${ColorDebug}" "${_in}" "${ColorReset}" >> "${LOG}" 2>> "${LOG}"
    else
        touch_logsdir_and_logfile
        _dbfn=" "
        if [ -z "${DEBUG}" ]; then
            if [ -n "${DEF_NAME}${DEF_SUFFIX}" ]; then
                # Definition log
                ${PRINTF_BIN} "#%b%s%s%b" "${ColorDebug}" "${_dbfn}" "${_in}" "${ColorReset}${_permdbg}" 2>> "${LOG}-${DEF_NAME}${DEF_SUFFIX}" >> "${LOG}-${DEF_NAME}${DEF_SUFFIX}"
            else
                # Main log
                ${PRINTF_BIN} "#%b%s%s%b" "${ColorDebug}" "${_dbfn}" "${_in}" "${ColorReset}${_permdbg}" 2>> "${LOG}" >> "${LOG}"
            fi
        else # DEBUG is set. Print to stdout
            ${PRINTF_BIN} "#%b%s%s%b\n" "${ColorDebug}" "${_dbfn}" "${_in}" "${ColorReset}" 2>/dev/null
        fi
        unset _dbgnme _in _dbfn
    fi
    return 0
}


warn () {
    if [ "${TTY}" = "YES" ]; then
        ${PRINTF_BIN} "${REPLAY_PREVIOUS_LINE}%b%s%b\n\n" "${ColorYellow}" "${@}" "${ColorReset}"
    else
        ${PRINTF_BIN} "%b%s%b\n" "${ColorYellow}" "${@}" "${ColorReset}"
    fi
    return 0
}


note () {
    if [ "${TTY}" = "YES" ]; then
        ${PRINTF_BIN} "${REPLAY_PREVIOUS_LINE}%b%s%b\n" "${ColorGreen}" "${@}" "${ColorReset}"
    else
        ${PRINTF_BIN} "%b%s%b\n" "${ColorGreen}" "${@}" "${ColorReset}"
    fi
    return 0
}


permnote () {
    if [ "${TTY}" = "YES" ]; then
        ${PRINTF_BIN} "${REPLAY_PREVIOUS_LINE}%b%s%b\n\n" "${ColorGreen}" "${@}" "${ColorReset}"
    else
        ${PRINTF_BIN} "%b%s%b\n" "${ColorGreen}" "${@}" "${ColorReset}"
    fi
    return 0
}


error () {
    ${PRINTF_BIN} "%b\n  %s %s\n    %b %b\n\n" "${ColorRed}" "${NOTE_CHAR2}" "Task crashed!" "${0}: ${1}${2}${3}${4}${5}" "${ColorReset}"
    if [ "error" = "${0}" ]; then
        ${PRINTF_BIN} "%b  %s Try: %b%b\n\n" "${ColorRed}" "${NOTE_CHAR2}" "$(diste "s log ${DEF_NAME}${DEF_SUFFIX}") to see the build log." "${ColorReset}"
    fi
    finalize_interrupt
    exit "${ERRORCODE_TASK_FAILURE}"
}


# distdebug
distd () {
    ${PRINTF_BIN} "%b%s%b" "${2:-${ColorDistinct}}" "${1}" "${3:-${ColorDebug}}" 2>/dev/null
    return 0
}


# distnote
distn () {
    ${PRINTF_BIN} "%b%s%b" "${2:-${ColorDistinct}}" "${1}" "${3:-${ColorNote}}" 2>/dev/null
    return 0
}


# distwarn
distw () {
    ${PRINTF_BIN} "%b%s%b" "${2:-${ColorDistinct}}" "${1}" "${3:-${ColorWarning}}" 2>/dev/null
    return 0
}


# disterror
diste () {
    ${PRINTF_BIN} "%b%s%b" "${2:-${ColorDistinct}}" "${1}" "${3:-${ColorError}}" 2>/dev/null
    return 0
}


run () {
    _run_params="${*}"
    if [ -n "${_run_params}" ]; then
        touch_logsdir_and_logfile
        _rnm="${DEF_NAME}${DEF_SUFFIX}"
        if [ -z "${_rnm}" ]; then
            if [ -z "${DEBUG}" ]; then
                eval "PATH=${PATH}${GIT_EXPORTS} ${_run_params}" >> "${LOG}" 2>> "${LOG}" \
                    && check_result ${?} "${_run_params}" \
                    && return 0
            else
                ${PRINTF_BIN} "%b" "${ColorBlue}"
                eval "PATH=${PATH}${GIT_EXPORTS} ${_run_params}" \
                    && check_result ${?} "${_run_params}" \
                    && return 0
            fi
        else
            if [ -z "${DEBUG}" ]; then
                eval "PATH=${PATH}${GIT_EXPORTS} ${_run_params}" >/dev/null 2>> "${LOG}-${_rnm}" \
                    && check_result ${?} "${_run_params}" \
                    && return 0
            else
                ${PRINTF_BIN} "%b" "${ColorBlue}"
                eval "PATH=${PATH}${GIT_EXPORTS} ${_run_params}" \
                    && check_result ${?} "${_run_params}" \
                    && return 0
            fi
        fi
    else
        error "Specified an empty command to run()!"
    fi
    unset _rnm
    error "Failed: run( $(diste "${_run_params}") )!"
}


try () {
    _try_params="${*}"
    if [ -n "${_try_params}" ]; then
        touch_logsdir_and_logfile
        _try_aname="${DEF_NAME}${DEF_SUFFIX}"
        if [ -z "${_try_aname}" ]; then
            if [ -z "${DEBUG}" ]; then
                eval "PATH=${PATH}${GIT_EXPORTS} ${_try_params}" >> "${LOG}" 2>> "${LOG}" \
                    && check_result ${?} "${_try_params}" \
                    && return 0
            else
                # show all progress on stdout.stderr
                ${PRINTF_BIN} "%b" "${ColorBlue}"
                eval "PATH=${PATH}${GIT_EXPORTS} ${_try_params}" \
                    && check_result ${?} "${_try_params}" \
                    && return 0
            fi
        else
            if [ -z "${DEBUG}" ]; then
                eval "PATH=${PATH}${GIT_EXPORTS} ${_try_params}" >/dev/null 2>> "${LOG}-${_try_aname}" \
                    && check_result ${?} "${_try_params}" \
                    && return 0
            else
                ${PRINTF_BIN} "%b" "${ColorBlue}"
                eval "PATH=${PATH}${GIT_EXPORTS} ${_try_params}" \
                    && check_result ${?} "${_try_params}" \
                    && return 0
            fi
        fi
    else
        error "Specified an empty command to try()!"
    fi
    check_result "1" "${_try_params}"
    unset _try_aname _try_params
    return 1
}


retry () {
    _targets="${*}"
    _ammo="OOO"
    touch_logsdir_and_logfile
    while [ -n "${_ammo}" ]; do
        if [ -n "${_targets}" ]; then
            if [ -z "${DEBUG}" ]; then
                eval "PATH=${DEFAULT_PATH}${GIT_EXPORTS} ${_targets}" >> "${LOG}" 2>> "${LOG}" \
                    && check_result ${?} "${_targets}" \
                    && unset _ammo _targets \
                    && return 0
            else
                ${PRINTF_BIN} "%b" "${ColorBlue}"
                eval "PATH=${DEFAULT_PATH}${GIT_EXPORTS} ${_targets}" \
                    && check_result ${?} "${_targets}" \
                    && unset _ammo _targets \
                    && return 0
            fi
        else
            error "Given an empty command to evaluate with retry()!"
        fi
        _ammo="$(${PRINTF_BIN} '%s\n' "${_ammo}" 2>/dev/null | ${SED_BIN} 's/O//' 2>/dev/null)"
        debug "Remaining attempts: $(distd "${_ammo}")"
    done
    debug "All available ammo exhausted to invoke a command: $(distd "${_targets}")"
    check_result "1" "${_targets}"
    unset _ammo _targets
    return 1
}



setup_defs_branch () {
    BRANCH="${BRANCH:-${DEFAULT_DEFINITIONS_BRANCH}}"
}


setup_defs_repo () {
    REPOSITORY="${REPOSITORY:-${DEFAULT_DEFINITIONS_REPOSITORY}}"
}


cleanup_handler () {
    finalize
    debug "Normal exit."
    exit 0
}


interrupt_handler () {
    finalize_interrupt
    warn "Interrupted: $(distw "${SOFIN_PID:-$$}")"
    exit "${ERRORCODE_USER_INTERRUPT}"
}


terminate_handler () {
    finalize
    warn "Terminated: $(distw "${SOFIN_PID:-$$}")"
    exit "${ERRORCODE_TERMINATED}"
}


noop_handler () {
    debug "Handled signal USR2 with noop()"
}


trap_signals () {
    # No    Name         Default Action       Description
    # 1     SIGHUP       terminate process    terminal line hangup
    # 2     SIGINT       terminate process    interrupt program
    # 3     SIGQUIT      create core image    quit program
    # 4     SIGILL       create core image    illegal instruction
    # 5     SIGTRAP      create core image    trace trap
    # 6     SIGABRT      create core image    abort program (formerly SIGIOT)
    # 7     SIGEMT       create core image    emulate instruction executed
    # 8     SIGFPE       create core image    floating-point exception
    # 9     SIGKILL      terminate process    kill program
    # 10    SIGBUS       create core image    bus error
    # 11    SIGSEGV      create core image    segmentation violation
    # 12    SIGSYS       create core image    non-existent system call invoked
    # 13    SIGPIPE      terminate process    write on a pipe with no reader
    # 14    SIGALRM      terminate process    real-time timer expired
    # 15    SIGTERM      terminate process    software termination signal
    # 16    SIGURG       discard signal       urgent condition present on socket
    # 17    SIGSTOP      stop process         stop (cannot be caught or ignored)
    # 18    SIGTSTP      stop process         stop signal generated from keyboard
    # 19    SIGCONT      discard signal       continue after stop
    # 20    SIGCHLD      discard signal       child status has changed
    # 21    SIGTTIN      stop process         background read attempted from control terminal
    # 22    SIGTTOU      stop process         background write attempted to control terminal
    # 23    SIGIO        discard signal       I/O is possible on a descriptor (see fcntl(2))
    # 24    SIGXCPU      terminate process    cpu time limit exceeded (see setrlimit(2))
    # 25    SIGXFSZ      terminate process    file size limit exceeded (see setrlimit(2))
    # 26    SIGVTALRM    terminate process    virtual time alarm (see setitimer(2))
    # 27    SIGPROF      terminate process    profiling timer alarm (see setitimer(2))
    # 28    SIGWINCH     discard signal       Window size change
    # 29    SIGINFO      discard signal       status request from keyboard
    # 30    SIGUSR1      terminate process    User defined signal 1
    # 31    SIGUSR2      terminate process    User defined signal 2
    #
    # if [ "YES" = "${CAP_TERM_ZSH}" ]; then
        # trap - ERR
    #el
    # if [ "YES" = "${CAP_TERM_BASH}" ]; then
    # #     trap 'cleanup_handler' EXIT
    #     trap 'error' ERR
    # fi
    trap 'interrupt_handler' INT
    trap 'terminate_handler' TERM
    trap 'noop_handler' USR2 # This signal is used to "reload shell"-feature. Sofin should ignore it

    if [ -x "${BEADM_BIN}" ]; then
        if [ -n "${CAP_SYS_PRODUCTION}" ]; then
            debug "Production mode, skipping readonly mode for /"
        else
            _active_boot_env="$(${BEADM_BIN} list -H | ${EGREP_BIN} -i "R" 2>/dev/null | ${AWK_BIN} '{print $1;}' 2>/dev/null)"
            debug "Turn on readonly mode for: $(distd "${DEFAULT_ZPOOL}/ROOT/${_active_boot_env}")"
            try "${ZFS_BIN} set readonly=on '${DEFAULT_ZPOOL}/ROOT/${_active_boot_env}'"
        fi
    fi
    return 0
}


untrap_signals () {

    # if [ "YES" = "${CAP_TERM_ZSH}" ]; then
    #     trap - ZERR
    # el
    # if [ "YES" = "${CAP_TERM_BASH}" ]; then
    #     trap - ERR
    # fi
    # trap - EXIT
    trap - INT
    trap - TERM
    trap - USR2

    if [ "YES" = "${CAP_SYS_ZFS}" ] && [ -x "${BEADM_BIN}" ]; then
        debug "Beadm found, turning off readonly mode for default boot environment"
        _active_boot_env="$(${BEADM_BIN} list -H 2>/dev/null | ${EGREP_BIN} -i "R" 2>/dev/null | ${AWK_BIN} '{print $1;}' 2>/dev/null)"
        _boot_dataset="${DEFAULT_ZPOOL}/ROOT/${_active_boot_env}"
        if [ -n "${CAP_SYS_PRODUCTION}" ]; then
            debug "Production mode disabling readonly for dataset: '$(distd "${_boot_dataset}")'"
            run "${ZFS_BIN} set readonly=off '${_boot_dataset}'"
        else
            _sp="$(processes_all_sofin)"
            if [ -z "${_sp}" ]; then
                debug "No Sofin processes in background! Turning off readonly mode for dataset: '$(distd "${_boot_dataset}")'"
                run "${ZFS_BIN} set readonly=off '${_boot_dataset}'"
            else
                debug "Background Sofin jobs are still around! Leaving readonly mode for dataset: '$(distd "${_boot_dataset}")'"
            fi
        fi
    fi
}


restore_security_state () {
    if [ "YES" = "${CAP_SYS_HARDENED}" ]; then
        if [ -z "${CAP_SYS_PRODUCTION}" ]; then
            if [ -f "${DEFAULT_SECURITY_STATE_FILE}" ]; then
                note "Restoring pre-build security state"
                . "${DEFAULT_SECURITY_STATE_FILE}" #>> "${LOG}" 2>> "${LOG}"
            else
                debug "No security state file found: $(distd "${DEFAULT_SECURITY_STATE_FILE}")"
            fi
        else
            debug "Restore disabled in production mode"
        fi
    else
        debug "No hardening capabilities in system"
    fi
}


store_security_state () {
    if [ "YES" = "${CAP_SYS_HARDENED}" ]; then
        if [ -z "${CAP_SYS_PRODUCTION}" ]; then
            try "${RM_BIN} -f ${DEFAULT_SECURITY_STATE_FILE}"
            debug "Storing current security state to file: $(distd "${DEFAULT_SECURITY_STATE_FILE}")"
            for _key in ${DEFAULT_HARDEN_KEYS}; do
                _sss_value="$(${SYSCTL_BIN} -n "${_key}" 2>/dev/null)"
                _sss_cntnt="${SYSCTL_BIN} ${_key}=${_sss_value}"
                ${PRINTF_BIN} "%s\n" "${_sss_cntnt}" >> "${DEFAULT_SECURITY_STATE_FILE}" 2>/dev/null
            done
            unset _key _sss_cntnt _sss_value
        else
            debug "Store disabled in production mode"
        fi
    else
        debug "No hardening capabilities in system"
    fi
}


disable_security_features () {
    if [ "YES" = "${CAP_SYS_HARDENED}" ]; then
        if [ -z "${CAP_SYS_PRODUCTION}" ]; then
            debug "Disabling all security features (this host is NOT production).."
            try "${RM_BIN} -f ${DEFAULT_SECURITY_STATE_FILE}"
            for _key in ${DEFAULT_HARDEN_KEYS}; do
                try "${SYSCTL_BIN} ${_key}=0"
            done
            unset _key _dsf_name
        else
            debug "Security features left intact cause in production mode."
        fi
    else
        debug "No hardening capabilities in system"
    fi
}


create_dirs () {
    if [ ! -d "${LOGS_DIR}" ] || \
       [ ! -d "${CACHE_DIR}" ] || \
       [ ! -d "${FILE_CACHE_DIR}" ] || \
       [ ! -d "${LOCKS_DIR}" ]; then
        try "${MKDIR_BIN} -p \"${CACHE_DIR}\" \"${FILE_CACHE_DIR}\" \"${LOCKS_DIR}\" \"${LOGS_DIR}\""
    fi
}


initialize () {
    check_os
    create_dirs
    create_base_datasets
    trap_signals

    if [ "${TTY}" = "YES" ]; then
        # turn echo off
        ${STTY_BIN} -echo
    fi
}


# Converts space-separated argument list to newline separated "Shell POSIX-Array"
to_iter () {
    ${PRINTF_BIN} '%s\n' "${@}" | eval "${SPACES_TO_NEWLINES_GUARD}"
}


link_utilities () {
    debug "Linking all utilities…" # simple exports for utils
    _sofin_svc_dir="${SERVICES_DIR}/${SOFIN_BUNDLE_NAME}"
    try "${MKDIR_BIN} -p '${_sofin_svc_dir}/exports'"
    for _tool_bundle in $(${FIND_BIN} "${_sofin_svc_dir}" -mindepth 1 -maxdepth 1 -type d -name '[A-Z0-9]*' 2>/dev/null); do
        for _export in $(${LS_BIN} "${_tool_bundle}/exports" 2>/dev/null); do
            debug "Link: '$(distd "${_tool_bundle}/exports/${_export##*/}")' => '$(distd "${_sofin_svc_dir}/exports/${_export##*/}'")"
            run "${LN_BIN} -fs '${_tool_bundle}/exports/${_export##*/}' '${_sofin_svc_dir}/exports/${_export##*/}'"
        done
    done
    unset _sofin_svc_dir _tool_bundle _export
}
