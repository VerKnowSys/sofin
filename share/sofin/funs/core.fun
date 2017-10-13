
debug () {
    _in="${@}"
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
        _sep="${_sep:-$(distd "λ " ${ColorDarkgray})}"
        if [ "${CAP_TERM_BASH}" = "YES" ]; then
            _dbfile="$(distd "${BASH_SOURCE#${SOFIN_ROOT}/share/}:${BASH_LINENO[0]}" "${ColorBlue}")"
            _fun="$(distd "${FUNCNAME[2]}()" "${ColorBlue}")"

        elif [ "${CAP_TERM_ZSH}" = "YES" ]; then
            # NOTE: $funcstack[2]; ${funcfiletrace[@]} ${funcsourcetrace[@]} ${funcstack[@]} ${functrace[@]}
            _valzz="${funcfiletrace[2]#${SOFIN_ROOT}/share/}"
            _valxx="${funcstack[2]}"
            _dbfile="$(distd "${_valzz}" "${ColorBlue}")"
            _fun="$(distd " ${_valxx}()" "${ColorBlue}")"
        else
            _dbfile=""
            _fun=""
        fi

        touch_logsdir_and_logfile
        _dbfn=" (#${SHLVL}) [${_sep}${_fun} @ ${_dbfile}] "
        if [ -z "${DEBUG}" ]; then
            _dbgnme="$(lowercase "${DEF_NAME}${DEF_SUFFIX}")"
            if [ -n "${_dbgnme}" ]; then
                # Definition log
                ${PRINTF_BIN} "#%b%s%s%b" "${ColorDebug}" "${_dbfn}" "${_in}" "${ColorReset}${_permdbg}" 2>> "${LOG}-${_dbgnme}" >> "${LOG}-${_dbgnme}"
            elif [ -z "${_dbgnme}" ]; then
                # Main log
                ${PRINTF_BIN} "#%b%s%s%b" "${ColorDebug}" "${_dbfn}" "${_in}" "${ColorReset}${_permdbg}" 2>> "${LOG}" >> "${LOG}"
            elif [ ! -d "${LOGS_DIR}" ]; then
                # System logger fallback
                ${LOGGER_BIN} "# λ ${ColorDebug}${_dbfn}${_in}${ColorReset}" 2>/dev/null
            fi
        else # DEBUG is set. Print to stdout
            ${PRINTF_BIN} "#%b%s%s%b\n" "${ColorDebug}" "${_dbfn}" "${_in}" "${ColorReset}" 2>/dev/null
        fi
        unset _dbgnme _in _dbfn _dbfnin _elmz _cee
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
        finalize_interrupt
    fi
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
    _run_params="${@}"
    if [ -n "${_run_params}" ]; then
        touch_logsdir_and_logfile
        ${PRINTF_BIN} '%s\n' "${_run_params}" | eval "${MATCH_PRINT_STDOUT_GUARD}" && _run_shw_prgr=YES
        # debug "$(distd "$(${DATE_BIN} ${DEFAULT_DATE_TRYRUN_OPTS} 2>/dev/null)" ${ColorDarkgray}): $(distd "${RUN_CHAR}" ${ColorWhite}): $(distd "${_run_params}" ${ColorParams}) $(distd "[show-blueout:${_run_shw_prgr:-NO}]" "${ColorBlue}")"
        if [ -z "${DEF_NAME}${DEF_SUFFIX}" ]; then
            if [ -z "${_run_shw_prgr}" ]; then
                eval "PATH=${PATH}${GIT_EXPORTS} ${_run_params}" >> "${LOG}" 2>> "${LOG}"
                check_result ${?} "${_run_params}"
            else
                ${PRINTF_BIN} "%b" "${ColorBlue}"
                eval "PATH=${PATH}${GIT_EXPORTS} ${_run_params}" >> "${LOG}"
                check_result ${?} "${_run_params}"
            fi
        else
            _rnm="$(lowercase "${DEF_NAME}${DEF_SUFFIX}")"
            if [ -z "${_run_shw_prgr}" ]; then
                eval "PATH=${PATH}${GIT_EXPORTS} ${_run_params}" >> "${LOG}-${_rnm}" 2>> "${LOG}-${_rnm}"
                check_result ${?} "${_run_params}"
            else
                ${PRINTF_BIN} "%b" "${ColorBlue}"
                eval "PATH=${PATH}${GIT_EXPORTS} ${_run_params}" >> "${LOG}-${_rnm}"
                check_result ${?} "${_run_params}"
            fi
        fi
    else
        error "Specified an empty command to run()!"
    fi
    unset _rnm _run_shw_prgr _run_params _dt
}


try () {
    _try_params="${@}"
    # NOTE: this one should just eval the task but when DEVEL is unset don't stderr log output from try()
    if [ -z "${TRY_LOUD}" ] && [ -z "${DEVEL}" ]; then
        eval "PATH=${PATH}${GIT_EXPORTS} ${_try_params}" >/dev/null 2>&1 \
            && return 0
        return 1
    fi
    if [ -n "${_try_params}" ]; then
        touch_logsdir_and_logfile
        ${PRINTF_BIN} '%s\n' "${_try_params}" | eval "${MATCH_PRINT_STDOUT_GUARD}" && _show_prgrss=YES
        # _dt="$(distd "$(${DATE_BIN} ${DEFAULT_DATE_TRYRUN_OPTS} 2>/dev/null)" ${ColorDarkgray})"
        # debug "${_dt}: $(distd "${TRY_CHAR}" ${ColorWhite}) $(distd "${_try_params}" ${ColorParams}) $(distd "[${_show_prgrss:-NO}]" "${ColorBlue}")"
        _try_aname="$(lowercase "${DEF_NAME}${DEF_SUFFIX}")"
        if [ -z "${_try_aname}" ]; then
            if [ -z "${_show_prgrss}" ]; then
                eval "PATH=${PATH}${GIT_EXPORTS} ${_try_params}" >> "${LOG}" 2>> "${LOG}" && \
                    return 0
            else
                # show progress on stderr
                ${PRINTF_BIN} "%b" "${ColorBlue}"
                eval "PATH=${PATH}${GIT_EXPORTS} ${_try_params}" >> "${LOG}" && \
                    return 0
            fi
        else
            if [ -z "${_show_prgrss}" ]; then
                eval "PATH=${PATH}${GIT_EXPORTS} ${_try_params}" >> "${LOG}-${_try_aname}" 2>> "${LOG}-${_try_aname}" && \
                    return 0
            else
                ${PRINTF_BIN} "%b" "${ColorBlue}"
                eval "PATH=${PATH}${GIT_EXPORTS} ${_try_params}" >> "${LOG}-${_try_aname}" && \
                    return 0
            fi
        fi
    else
        error "Specified an empty command to try()!"
    fi
    unset _dt _try_aname _try_params
    return 1
}


retry () {
    _targets="${@}"
    _ammo="OOO"
    touch_logsdir_and_logfile
    # check for commands that puts something important/intersting on stdout
    ${PRINTF_BIN} '%s\n' "${_targets}" 2>/dev/null | eval "${MATCH_PRINT_STDOUT_GUARD}" && _rtry_blue=YES
    while [ -n "${_ammo}" ]; do
        if [ -n "${_targets}" ]; then
            # _dt="$(distd "$(${DATE_BIN} ${DEFAULT_DATE_TRYRUN_OPTS} 2>/dev/null)" ${ColorDarkgray})"
            # debug "${_dt}: $(distd "${TRY_CHAR}${NOTE_CHAR}${RUN_CHAR}" ${ColorWhite}) $(distd "${_targets}" ${ColorParams}) $(distd "[${_show_prgrss:-NO}]" "${ColorBlue}")"
            if [ -z "${_rtry_blue}" ]; then
                eval "PATH=${DEFAULT_PATH}${GIT_EXPORTS} ${_targets}" >> "${LOG}" 2>> "${LOG}" && \
                    unset _ammo _targets && \
                        return 0
            else
                ${PRINTF_BIN} "%b" "${ColorBlue}"
                eval "PATH=${DEFAULT_PATH}${GIT_EXPORTS} ${_targets}" >> "${LOG}" && \
                    unset _ammo _targets && \
                        return 0
            fi
        else
            error "Given an empty command to evaluate!"
        fi
        _ammo="$(${PRINTF_BIN} '%s\n' "${_ammo}" 2>/dev/null | ${SED_BIN} 's/O//' 2>/dev/null)"
        debug "Remaining attempts: $(distd "${_ammo}")"
    done
    debug "All available ammo exhausted to invoke a command: $(distd "${_targets}")"
    unset _ammo _targets _rtry_blue
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

    if [ -x "${BEADM_BIN}" ]; then
        debug "Beadm found, turning off readonly mode for default boot environment"
        _active_boot_env="$(${BEADM_BIN} list -H 2>/dev/null | ${EGREP_BIN} -i "R" 2>/dev/null | ${AWK_BIN} '{print $1;}' 2>/dev/null)"

        if [ -n "${CAP_SYS_PRODUCTION}" ]; then
            debug "Production mode disabling readonly for /"
            run "${ZFS_BIN} set readonly=off '${DEFAULT_ZPOOL}/ROOT/${_active_boot_env}'"
        else
            _sp="$(processes_all_sofin)"
            if [ -z "${_sp}" ]; then
                debug "No Sofin processes in background! Turning off readonly mode for: ${DEFAULT_ZPOOL}/ROOT/${_active_boot_env}"
                run "${ZFS_BIN} set readonly=off '${DEFAULT_ZPOOL}/ROOT/${_active_boot_env}'"
            else
                debug "Background Sofin jobs are still around! Leaving readonly mode for ROOT."
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


# summary () {
    # Sofin performance counters:
    # SOFIN_END="${SOFIN_END:-$(${SOFIN_TIMER_BIN} 2>/dev/null)}"
    # SOFIN_RUNTIME="$(calculate_bc "(${SOFIN_END} - ${SOFIN_START:-${SOFIN_END}}) / 1000")"

    # ${PRINTF_BIN} "%b%s%b\n" "${ColorExample}" "$(fill "${SEPARATOR_CHAR2}")" "${ColorReset}" >> "${LOG:-/var/log/sofin}"
    # ${PRINTF_BIN} "%bargs.head: ${ColorYellow}%s\n" "${ColorExample}" "${SOFIN_COMMAND_ARG:-''}" >> "${LOG:-/var/log/sofin}"
    # ${PRINTF_BIN} "%bargs.tail: ${ColorYellow}%s\n" "${ColorExample}" "${SOFIN_ARGS:-''}" >> "${LOG:-/var/log/sofin}"
    # ${PRINTF_BIN} "%bpid: ${ColorYellow}%d${ColorExample}\n" "${ColorExample}" "${SOFIN_PID:-'-1'}" >> "${LOG:-/var/log/sofin}"
    # ${PRINTF_BIN} "%bruntime: ${ColorYellow}%d${ColorExample} ms.\n" "${ColorExample}" "${SOFIN_RUNTIME:-'-1'}" >> "${LOG:-/var/log/sofin}"

    # Show "times" stats from shell:
    # ${PRINTF_BIN} "%bshell times: %b\n" "${ColorExample}" "${ColorReset}" >> "${LOG:-/var/log/sofin}"
    # times >> "${LOG:-/var/log/sofin}"

    # ${PRINTF_BIN} "%b%s%b\n" "${ColorExample}" "$(fill "${SEPARATOR_CHAR2}")" >> "${LOG:-/var/log/sofin}"
# }


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
