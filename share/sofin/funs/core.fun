
debug () {
    _in="${*}"
    if [ -z "${_in}" ]; then
        printf "\n" >&2
        return 0
    fi
    if [ "YES" = "${TTY}" ]; then
        _permdbg="\n"
    else
        unset _permdbg
    fi

    if [ -n "${DEBUG}" ]; then
        printf "# %b   %b%b%b\n" \
                "${ColorGreen} λ" \
                "${ColorDebug}" \
                "${_in}" \
                "${ColorReset}" \
                    >&2
    else
        touch_logsdir_and_logfile
        _dbfn=" "
        if [ -z "${DEBUG}" ]; then
            if [ -n "${DEF_NAME}${DEF_SUFFIX}" ]; then
                # Definition log, log to stderr only
                printf "# %b%b%b%b%b" \
                        "${ColorDebug}" \
                        "${_dbfn}" \
                        "${_in}" \
                        "${ColorReset}" \
                        "${_permdbg}" \
                            2>> "${LOG}-${DEF_NAME}${DEF_SUFFIX}" >&2
            else
                # Main log, all to stderr
                printf "# %b%b%b%b%b" \
                        "${ColorDebug}" \
                        "${_dbfn}" \
                        "${_in}" \
                        "${ColorReset}" \
                        "${_permdbg}" \
                            2>> "${LOG}" >&2
            fi
        else # DEBUG is set. Print to stderr
            printf "# %b%b%b%b%b" \
                    "${ColorDebug}" \
                    "${_dbfn}" \
                    "${_in}" \
                    "${ColorReset}" \
                    "${_permdbg}" \
                        >&2
        fi
        unset _dbgnme _in _dbfn
    fi
    return 0
}


warn () {
    _wrn_msgs="${*}"
    if [ -n "${_wrn_msgs}" ]; then
        if [ "YES" = "${TTY}" ]; then
            printf "\n%b%b%b%b%b\n" \
                    "${ANSI_ONE_LINE_UP}" \
                    "${ColorYellow}" \
                    "   ${_wrn_msgs}" \
                    "${ColorReset}" \
                    "${ANSI_TWO_LINES_DOWN}" \
                        >&2 | "${TEE_BIN}" 2>/dev/null
        else
            printf "%b%b%b\n" \
                    "${ColorYellow}" \
                    "   ${_wrn_msgs}" \
                    "${ColorReset}" \
                        >&2 | "${TEE_BIN}" 2>/dev/null
        fi
    else
        printf "\n" >&2
    fi
    unset _wrn_msgs
    return 0
}


note () {
    _nte_msgs="${*}"
    if [ -n "${_nte_msgs}" ]; then
        if [ "YES" = "${TTY}" ]; then
            printf "\n%b%b%b%b%b" \
                    "${ANSI_ONE_LINE_UP}" \
                    "${ColorGreen}" \
                    "   ${_nte_msgs}" \
                    "${ColorReset}" \
                    "${ANSI_ONE_LINE_DOWN}" \
                        >&2
        else
            printf "%b%b%b\n" \
                    "${ColorGreen}" \
                    "   ${_nte_msgs}" \
                    "${ColorReset}" \
                        >&2
        fi
    else
        printf "\n" >&2
    fi
    unset _nte_msgs
    return 0
}


permnote () {
    _prm_note="${*}"
    if [ -n "${_prm_note}" ]; then
        if [ "YES" = "${TTY}" ]; then
            printf "\n%b%b%b%b%b\n" \
                    "${ANSI_ONE_LINE_UP}" \
                    "${ColorGreen}" \
                    "   ${_prm_note}" \
                    "${ColorReset}" \
                    "${ANSI_TWO_LINES_DOWN}" \
                        >&2
        else
            printf "%b%b%b\n" \
                    "${ColorGreen}" \
                    "   ${_prm_note}" \
                    "${ColorReset}" \
                        >&2
        fi
    else
        printf "\n" >&2
    fi
    unset _prm_note
    return 0
}


error () {
    _err_root="${0}"
    _err_msg="${*}"
    if [ -n "${_err_msg}" ]; then
        printf "%b\n  %b %b\n    %b %b\n\n" \
                "${ColorRed}" \
                "${NOTE_CHAR2}" \
                "Task crashed!" \
                "   ${_err_root}: ${_err_msg}" \
                "${ColorReset}" \
                    >&2 | "${TEE_BIN}" >/dev/null

        if [ "error" = "${_err_root}" ]; then
            printf "%b  %b Try: %b%b\n\n" \
                    "${ColorRed}" \
                    "${NOTE_CHAR2}" \
                    "   $(diste "s log ${DEF_NAME}${DEF_SUFFIX}"), to read the task log." \
                    "${ColorReset}" \
                         >&2 | "${TEE_BIN}" >/dev/null
        fi
    else
        printf "%b: %b\n\n" \
            "General Error" \
            "*" \
                >&2 | "${TEE_BIN}" >/dev/null
    fi
    finalize_after_signal_interrupt
    exit "${ERRORCODE_TASK_FAILURE}"
}


# distdebug
distd () {
    printf "%b%b%b" "${2:-${ColorDistinct}}" "${1}" "${3:-${ColorDebug}}" 2>/dev/null
    return 0
}


# distnote
distn () {
    printf "%b%b%b" "${2:-${ColorDistinct}}" "${1}" "${3:-${ColorNote}}" 2>/dev/null
    return 0
}


# distwarn
distw () {
    printf "%b%b%b" "${2:-${ColorDistinct}}" "${1}" "${3:-${ColorWarning}}" 2>/dev/null
    return 0
}


# disterror
diste () {
    printf "%b%b%b" "${2:-${ColorDistinct}}" "${1}" "${3:-${ColorError}}" 2>/dev/null
    return 0
}


run () {
    _run_params="${*}"
    if [ -n "${_run_params}" ]; then
        touch_logsdir_and_logfile
        _rnm="${DEF_NAME}${DEF_SUFFIX}"
        if [ -z "${_rnm}" ]; then
            if [ -z "${DEBUG}" ]; then
                # No DEBUG set -> discard both STDOUT and STDERR for try() calls…:
                eval "PATH=${PATH}${GIT_EXPORTS} ${_run_params}" >/dev/null 2>&1 \
                    && check_result "${?}" "${_run_params}" \
                    && return 0
            else
                printf "%b\n" "${ColorBlue}" >&2
                eval "PATH=${PATH}${GIT_EXPORTS} ${_run_params}" 2>> "${LOG}" \
                    && check_result "${?}" "${_run_params}" \
                    && return 0
            fi
        else
            if [ -z "${DEBUG}" ]; then
                eval "PATH=${PATH}${GIT_EXPORTS} ${_run_params}" >/dev/null 2>&1 \
                    && check_result "${?}" "${_run_params}" \
                    && return 0
            else
                printf "%b\n" "${ColorBlue}" >&2
                eval "PATH=${PATH}${GIT_EXPORTS} ${_run_params}" >&2 2>> "${LOG}-${_rnm}" \
                    && check_result "${?}" "${_run_params}" \
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
            if [ -z "${DEBUG}" ]; then # No DEBUG set -> discard both STDOUT and STDERR for try() calls…:
                eval "PATH=${PATH}${GIT_EXPORTS} ${_try_params}" >/dev/null 2>&1 \
                    && check_result "${?}" "${_try_params}" \
                        && return 0
            else
                # show all progress on stderr
                printf "%b\n" "${ColorBlue}" >&2
                eval "PATH=${PATH}${GIT_EXPORTS} ${_try_params}" >&2 2>> "${LOG}" \
                    && check_result "${?}" "${_try_params}" \
                        && return 0
            fi
        else
            if [ -z "${DEBUG}" ]; then # No DEBUG set -> discard both STDOUT and STDERR for try() calls…:
                eval "PATH=${PATH}${GIT_EXPORTS} ${_try_params}" >/dev/null 2>&1 \
                    && check_result "${?}" "${_try_params}" \
                        && return 0
            else
                printf "%b\n" "${ColorBlue}" >&2
                eval "PATH=${PATH}${GIT_EXPORTS} ${_try_params}" >&2 2>> "${LOG}-${_try_aname}" \
                    && check_result "${?}" "${_try_params}" \
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
            if [ -z "${DEBUG}" ]; then # No DEBUG set -> discard both STDOUT and STDERR for try() calls…:
                eval "PATH=${DEFAULT_PATH}${GIT_EXPORTS} ${_targets}" 2>/dev/null >&2  \
                    && check_result "${?}" "${_targets}" \
                        && unset _ammo _targets \
                            && return 0
            else
                printf "%b\n" "${ColorBlue}" >&2
                eval "PATH=${DEFAULT_PATH}${GIT_EXPORTS} ${_targets}" 2>> "${LOG}" >&2  \
                    && check_result "${?}" "${_targets}" \
                        && unset _ammo _targets \
                            && return 0
            fi
        else
            error "Given an empty command to evaluate with retry()!"
        fi
        _ammo="$(printf "%b\n" "${_ammo}" | ${SED_BIN} 's/O//' 2>/dev/null)"
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


initialize () {
    set_system_dataset_writable
    set_software_dataset_writable

    create_dirs
    create_base_datasets
    check_definitions_availability
    trap_signals

    if [ "${TTY}" = "YES" ]; then
        ${STTY_BIN} -echo \
            && debug "Interactive Terminal Echo is now: $(distd "*disabled*")"
    fi
}


signal_handler_interrupt () {
    warn "Received Interrupt-Signal from some Human!…" 2>&1
    warn "Service will shutdown immediatelly after completing required cleanup-duties…" 2>&1
    finalize_after_signal_interrupt
    warn "Service Terminated." 2>&1
    exit "${ERRORCODE_USER_INTERRUPT}"
}


# signal_handler_terminate () {
#     warn "Terminated: $(distw "${SOFIN_PID:-$$}")"
#     finalize_complete_standard_task
#     warn "Terminated: Bye!"
#     exit "${ERRORCODE_TERMINATED}"
# }


signal_handler_no_operation () {
    debug "NOOP signal.triggered."
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

    # Associate signals with function handler:
    trap 'signal_handler_interrupt' INT
    trap 'signal_handler_interrupt' QUIT
    trap 'signal_handler_interrupt' TERM

    # Associate 'No-Op' signals:
    trap 'signal_handler_no_operation' HUP
    trap 'signal_handler_no_operation' INFO
    trap 'signal_handler_no_operation' USR1
    trap 'signal_handler_no_operation' USR2 # This signal is used to "reload shell"-feature. Sofin should ignore it when triggered directly
    trap 'signal_handler_no_operation' WINCH

    debug "trap_signals(): Interruption triggers were associated with signals: $(distd "INT, QUIT, TERM")."
    debug "trap_signals(): No-Op triggers were associated with signals: $(distd "HUP, INFO, USR1, USR2, WINCH")!"
    return 0
}


untrap_signals () {
    # No-Op for each handled trigger:
    trap - INT
    trap - TERM
    trap - QUIT
    trap - HUP
    trap - USR1
    trap - USR2
    trap - INFO
    trap - WINCH

    debug "untrap_signals(): Signal trigger handlers were unassociated for: $(distd "INT, QUIT, TERM, HUP, INFO, USR1, USR2, WINCH")."
    return 0
}


set_system_dataset_readonly () {
    if [ "YES" = "${CAP_SYS_ZFS}" ] \
    && [ -x "${BEADM_BIN}" ] \
    && [ "root" = "${USER}" ] \
    && [ -z "${CAP_SYS_JAILED}" ]; then
        _active_boot_env="$(${BEADM_BIN} list -H 2>/dev/null | ${EGREP_BIN} "R" 2>/dev/null | ${AWK_BIN} '{print $1;}' 2>/dev/null)"
        _boot_dataset="${DEFAULT_ZPOOL}/ROOT/${_active_boot_env}"
        if [ -n "${CAP_SYS_PRODUCTION}" ]; then
            try "${ZFS_BIN} set readonly=on '${_boot_dataset}'" \
                && debug "System dataset: $(distd "${_boot_dataset}") is now: READ-ONLY"
        else
            _sp="$(processes_all_sofin)"
            if [ -z "${_sp}" ]; then
                try "${ZFS_BIN} set readonly=on '${_boot_dataset}'" \
                    && debug "No background Sofin processes found. System dataset: '$(distd "${_boot_dataset}") is now: READ-ONLY'"
            else
                debug "Background Sofin found in background! System dataset: '$(distd "${_boot_dataset}") is untouched.'"
            fi
        fi
    fi
}


set_system_dataset_writable () {
    if [ -x "${BEADM_BIN}" ] \
    && [ "root" = "${USER}" ] \
    && [ -z "${CAP_SYS_JAILED}" ]; then
        _active_boot_env="$(${BEADM_BIN} list -H | ${EGREP_BIN} "R" 2>/dev/null | ${AWK_BIN} '{print $1;}' 2>/dev/null)"
        try "${ZFS_BIN} set readonly=off '${DEFAULT_ZPOOL}/ROOT/${_active_boot_env}'" \
            && debug "System dataset: $(distd "${DEFAULT_ZPOOL}/ROOT/${_active_boot_env}") is now: WRITABLE"
    fi
}


# store_security_state () {
#     if [ "YES" = "${CAP_SYS_HARDENED}" ]; then
#         if [ -z "${CAP_SYS_PRODUCTION}" ]; then
#             try "${RM_BIN} -f ${DEFAULT_SECURITY_STATE_FILE}"
#             debug "Storing current security state to file: $(distd "${DEFAULT_SECURITY_STATE_FILE}")"
#             for _key in ${DEFAULT_HARDEN_KEYS}; do
#                 _sss_value="$(${SYSCTL_BIN} -n "${_key}" 2>/dev/null)"
#                 _sss_cntnt="${SYSCTL_BIN} ${_key}=${_sss_value}"
#                 printf "%b\n" "${_sss_cntnt}" >> "${DEFAULT_SECURITY_STATE_FILE}" 2>/dev/null
#             done
#             unset _key _sss_cntnt _sss_value
#         else
#             debug "Store disabled in production mode"
#         fi
#     else
#         debug "No hardening capabilities in system"
#     fi
# }


# disable_security_features () {
#     if [ "YES" = "${CAP_SYS_HARDENED}" ]; then
#         if [ -z "${CAP_SYS_PRODUCTION}" ]; then
#             debug "Disabling all security features (this host is NOT production).."
#             try "${RM_BIN} -f '${DEFAULT_SECURITY_STATE_FILE}'"
#             for _key in ${DEFAULT_HARDEN_KEYS}; do
#                 try "${SYSCTL_BIN} ${_key}=0"
#             done
#             unset _key _dsf_name
#         else
#             debug "Security features left intact cause in production mode."
#         fi
#     else
#         debug "No hardening capabilities in system"
#     fi
# }


create_dirs () {
    if [ ! -d "${LOGS_DIR}" ] \
    || [ ! -d "${CACHE_DIR}" ] \
    || [ ! -d "${FILE_CACHE_DIR}" ] \
    || [ ! -d "${LOCKS_DIR}" ]; then
        try "${MKDIR_BIN} -p '${CACHE_DIR}' '${FILE_CACHE_DIR}' '${LOCKS_DIR}' '${LOGS_DIR}'"
    fi
}


# Converts space-separated argument list to newline separated "Shell POSIX-Array"
to_iter () {
    printf "%b\n" "${@}" | ${TR_BIN} ' ' '\n' 2>/dev/null
}


link_utilities () {
    debug "Linking all utilities…" # simple exports for utils
    _sofin_svc_dir="${SERVICES_DIR}/${SOFIN_BUNDLE_NAME}"
    try "${MKDIR_BIN} -p '${_sofin_svc_dir}/exports'"
    for _tool_bundle in $(${FIND_BIN} "${_sofin_svc_dir}" -mindepth 1 -maxdepth 1 -type d -name '[A-Z0-9]*' 2>/dev/null); do
        for _export in $(${LS_BIN} "${_tool_bundle}/exports" 2>/dev/null); do
            run "${RM_BIN} -f '${_sofin_svc_dir}/exports/${_export##*/}'; ${LN_BIN} -s '${_tool_bundle}/exports/${_export##*/}' '${_sofin_svc_dir}/exports/${_export##*/}'"
        done
    done
    unset _sofin_svc_dir _tool_bundle _export
}
