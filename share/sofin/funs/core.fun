#!/usr/bin/env sh

debug () {
    _debug_msg="${*}"
    if [ -z "${_debug_msg}" ]; then
        printf "\n" >&2
        return 0
    fi
    create_sofin_dirs
    if [ -n "${DEBUG}" ]; then
        if [ "YES" = "${CAP_TERM_INTERACTIVE}" ]; then
            printf "%b%b λ %b%b%b\n" \
                    "${ColorDark}" \
                    "$(${DATE_BIN} +"%F-%T")" \
                    "${ColorDebug}" \
                    "${_debug_msg}$(fill_interactive_line "${_debug_msg}")" \
                    "${ColorReset}" \
                        >&2
        else
            printf "# %b # %b\n" \
                    "$(${DATE_BIN} +"%F-%T")" \
                    "${_debug_msg}" \
                        >&2
        fi
    else
        if [ -n "${DEF_NAME}${DEF_SUFFIX}" ]; then
            # Definition log, log to stderr only
            printf "# %b%b: %b%b%b\n" \
                    "${ColorDark}" \
                    "$(${DATE_BIN} +"%F-%T")" \
                    "${ColorDebug}" \
                    "${_debug_msg}" \
                    "${ColorReset}" \
                        2>> "${LOG}-${DEF_NAME}${DEF_SUFFIX}" >&2
        else
            # Main log, all to stderr
            printf "# %b%b: %b%b%b\n" \
                    "${ColorDark}" \
                    "$(${DATE_BIN} +"%F-%T")" \
                    "${ColorDebug}" \
                    "${_debug_msg}" \
                    "${ColorReset}" \
                        2>> "${LOG}" >&2
        fi
    fi
    unset _debug_msg
    return 0
}


warn () {
    _wrn_msgs="${*}"
    if [ -n "${_wrn_msgs}" ]; then
        if [ "YES" = "${CAP_TERM_INTERACTIVE}" ]; then
            printf "\n%b%b%b%b%b\n" \
                    "${ANSI_ONE_LINE_UP}" \
                    "${ColorYellow}" \
                    "  ${_wrn_msgs}$(fill_interactive_line "${_wrn_msgs}")" \
                    "${ColorReset}" \
                    "${ANSI_TWO_LINES_DOWN}" \
                        | ${TEE_BIN} "${LOG}" >/dev/stdout 2>/dev/stderr
        else
            printf "%b%b%b\n" \
                    "${ColorYellow}" \
                    "${_wrn_msgs}" \
                    "${ColorReset}" \
                        >&2 >/dev/null
        fi
    else
        printf "\n" >/dev/null
    fi
    unset _wrn_msgs
    return 0
}


note () {
    _nte_msgs="${*}"
    if [ -n "${_nte_msgs}" ]; then
        if [ "YES" = "${CAP_TERM_INTERACTIVE}" ]; then
            printf "\n%b%b%b%b%b" \
                    "${ANSI_ONE_LINE_UP}" \
                    "${ColorGreen}" \
                    "  ${_nte_msgs}$(fill_interactive_line "${_nte_msgs}")" \
                    "${ColorReset}" \
                    "${ANSI_ONE_LINE_DOWN}" \
                        >&2
        else
            printf "%b%b%b\n" \
                    "${ColorGreen}" \
                    "${_nte_msgs}" \
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
        if [ "YES" = "${CAP_TERM_INTERACTIVE}" ]; then
            printf "\n%b%b%b%b%b\n" \
                    "${ANSI_ONE_LINE_UP}" \
                    "${ColorGreen}" \
                    "  ${_prm_note}$(fill_interactive_line "${_prm_note}")" \
                    "${ColorReset}" \
                    "${ANSI_TWO_LINES_DOWN}" \
                        >&2
        else
            printf "%b%b%b\n" \
                    "${ColorGreen}" \
                    "${_prm_note}" \
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
        printf "%b\n  %b %b\n    %b\n\n%b%b\n%b%b\n%b\n%b\n\n" \
                "${ColorRed}" \
                "${NOTE_CHAR2}" \
                "Task crashed!" \
                "  ${_err_root}: ${_err_msg}" \
                "$(fill)" \
                "${ColorReset}" \
                "$(show_bundle_log_if_available "${DEF_NAME}${DEF_SUFFIX}")" \
                "${ColorRed}" \
                "$(fill)" \
                "${ColorReset}" \
                    | ${TEE_BIN} "${LOG}" >/dev/stdout 2>/dev/stderr

        if [ "error" = "${_err_root}" ]; then
            printf "%b  %b Try: %b%b\n\n" \
                    "${ColorRed}" \
                    "${NOTE_CHAR2}" \
                    "$(diste "s log ${DEF_NAME}${DEF_SUFFIX}"), to read full task log." \
                    "${ColorReset}" \
                         >&2 >/dev/null
        fi
    else
        printf "%b: %b\n\n" \
            "General Error" \
            "*" \
                >&2 >/dev/null
    fi
    finalize_and_quit_gracefully_with_exitcode "${ERRORCODE_TASK_FAILURE}"
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
        create_sofin_dirs
        _rnm="${DEF_NAME}${DEF_SUFFIX}"
        if [ -z "${_rnm}" ]; then
            if [ -z "${DEBUG}" ]; then
                eval "PATH=${PATH}${GIT_EXPORTS} ${_run_params}" >/dev/null 2>> "${LOG}" \
                    && check_result "${?}" "${_run_params}" \
                    && return 0
            else
                printf "%b\n" "${ColorBlue}" >&2
                eval "PATH=${PATH}${GIT_EXPORTS} ${_run_params}" >&2 2>> "${LOG}" \
                    && check_result "${?}" "${_run_params}" \
                    && return 0
            fi
        else
            if [ -z "${DEBUG}" ]; then
                eval "PATH=${PATH}${GIT_EXPORTS} ${_run_params}" >/dev/null 2>> "${LOG}-${_rnm}" \
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
        create_sofin_dirs
        _try_aname="${DEF_NAME}${DEF_SUFFIX}"
        if [ -z "${_try_aname}" ]; then
            if [ -z "${DEBUG}" ]; then # No DEBUG set -> discard both STDOUT and STDERR for try() calls${CHAR_DOTS}:
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
            if [ -z "${DEBUG}" ]; then # No DEBUG set -> discard both STDOUT and STDERR for try() calls${CHAR_DOTS}:
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
    create_sofin_dirs
    while [ -n "${_ammo}" ]; do
        if [ -n "${_targets}" ]; then
            if [ -z "${DEBUG}" ]; then # No DEBUG set -> discard both STDOUT and STDERR for try() calls${CHAR_DOTS}:
                eval "PATH=${DEFAULT_PATH}${GIT_EXPORTS} ${_targets}" 2>/dev/null \
                    && check_result "${?}" "${_targets}" \
                        && unset _ammo _targets \
                            && return 0
            else
                printf "%b\n" "${ColorBlue}" >&2
                eval "PATH=${DEFAULT_PATH}${GIT_EXPORTS} ${_targets}" 2>> "${LOG}" \
                    && check_result "${?}" "${_targets}" \
                        && unset _ammo _targets \
                            && return 0
            fi
        else
            error "Given an empty command to evaluate with retry()!"
        fi
        _ammo="$(printf "%b\n" "${_ammo}" | ${SED_BIN} 's/O//' 2>/dev/null)"
        sleep 2
        debug "Remaining attempts: $(distd "${_ammo}")"
    done
    debug "All available ammo exhausted to invoke a command: $(distd "${_targets}")"
    check_result "1" "${_targets}"
    unset _ammo _targets
    return 1
}


performance () {
    _a_level="${1}"
    case "${SYSTEM_ARCH}" in
        arm64|aarch64)
            case "${_a_level}" in
                max|top|full)
                    _cmdline="${SYSCTL_BIN} "
                    for _idx in $(${SEQ_BIN} 0 "$(( ${CPUS} - 1 ))"); do
                        _core_freq_max="$(${SYSCTL_BIN} -n "dev.cpu.${_idx}.freq_levels" 2>/dev/null | ${AWK_BIN} '/[0-9]*/ { gsub("/-1", "", $1); print $1}')"
                        _cmdline="${_cmdline} dev.cpu.${_idx}.freq=${_core_freq_max}"
                    done
                    try "${_cmdline}"
                    unset _cmdline _core_freq_max _idx
                    ;;
            esac
            ;;
    esac
}


initialize () {
    trap_signals

    if [ "YES" = "${CAP_TERM_INTERACTIVE}" ]; then
        ${STTY_BIN} -echo \
            && debug "Interactive Terminal Echo is now: $(distd "*disabled*")"
    fi

    set_system_dataset_writable
    set_software_dataset_writable

    set_software_dataset_unmountable
    set_services_dataset_unmountable
    create_sofin_dirs
    create_base_datasets
    check_definitions_availability
}


signal_handler_interrupt () {
    warn "Received Interruption signal! Will shutdown immediatelly after completing required cleanup-duties${CHAR_DOTS}"
    warn "Terminating task: $(distw "${SOFIN_CMDLINE}")!"
    finalize_after_signal_interrupt "${ERRORCODE_USER_INTERRUPT}"
}


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
    # trap 'signal_handler_no_operation' WINCH

    debug "trap_signals(): Interruption triggers were associated with signals: $(distd "INT, QUIT, TERM")."
    debug "trap_signals(): No-Op triggers were associated with signals: $(distd "HUP, INFO, USR1, USR2")!"
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
    # trap - WINCH

    debug "untrap_signals(): Signal trigger handlers were unassociated for: $(distd "INT, QUIT, TERM, HUP, INFO, USR1, USR2, WINCH")."
    return 0
}


set_system_dataset_readonly () {
    if [ "YES" = "${CAP_SYS_ZFS}" ] \
    && [ -x "${BECTL_BIN}" ] \
    && [ "root" = "${USER}" ] \
    && [ -z "${CAP_SYS_JAILED}" ]; then
        _active_boot_env="$(${BECTL_BIN} list -H 2>/dev/null | ${EGREP_BIN} "R" 2>/dev/null | ${AWK_BIN} '{print $1;}' 2>/dev/null)"
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
    if [ -x "${BECTL_BIN}" ] \
    && [ "root" = "${USER}" ] \
    && [ -z "${CAP_SYS_JAILED}" ]; then

        try "${ZFS_BIN} set readonly=off '${DEFAULT_ZPOOL}/ROOT/${_active_boot_env}'" \
            && debug "System dataset: $(distd "${DEFAULT_ZPOOL}/ROOT/${_active_boot_env}") is now: WRITABLE"
    fi
}


create_sofin_dirs () {
    if [ ! -d "${LOGS_DIR}" ] \
    || [ ! -d "${FILE_CACHE_DIR}" ] \
    || [ ! -d "${LOCKS_DIR}" ]; then
        ${MKDIR_BIN} -p "${FILE_CACHE_DIR}" "${LOCKS_DIR}" "${LOGS_DIR}" 2>/dev/null
        ${TOUCH_BIN} "${LOG}" >/dev/null 2>&1 # touch default Sofin log file.
        debug "create_sofin_dirs(): Done!"
    fi
}


# Converts space-separated argument list to newline separated "Shell POSIX-Array"
to_iter () {
    printf "%b\n" "${@}" | ${TR_BIN} ' ' '\n' 2>/dev/null
}


link_utilities () {
    debug "Linking all utilities${CHAR_DOTS}" # simple exports for utils
    _sofin_svc_dir="${SERVICES_DIR}/${SOFIN_BUNDLE_NAME}/"
    try "${MKDIR_BIN} -p '${_sofin_svc_dir}/exports'"
    for _tool_bundle in $(${FIND_BIN} "${_sofin_svc_dir}" -mindepth 1 -maxdepth 1 -type d -name '[A-Z0-9]*' 2>/dev/null); do
        for _export in $(${LS_BIN} "${_tool_bundle}/exports" 2>/dev/null); do
            run "${RM_BIN} -f '${_sofin_svc_dir}/exports/${_export##*/}'; ${LN_BIN} -s '${_tool_bundle}/exports/${_export##*/}' '${_sofin_svc_dir}/exports/${_export##*/}'"
        done
    done
    unset _sofin_svc_dir _tool_bundle _export
}
