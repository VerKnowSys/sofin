
debug () {
    _in=${@}
    if [ -n "${CAP_SYS_PRODUCTION}" ]; then
        if [ -n "${DEBUG}" ]; then
            ${PRINTF_BIN} "# (%s) λ ${ColorDebug}%s${ColorReset}\n" "${SHLVL}" "${@}"
        else
            ${PRINTF_BIN} "# (%s) λ ${ColorDebug}%s${ColorReset}\n" "${SHLVL}" "${@}" >/dev/null
        fi
    else
        _sep="${_sep:-$(distd "λ " ${ColorDarkgray})}"
        if [ "${CAP_TERM_BASH}" = "YES" ]; then
            _dbfile="$(distd "${BASH_SOURCE#/usr/share/sofin/}:${BASH_LINENO[0]}" ${ColorBlue})"
            _fun="$(distd "${FUNCNAME[2]}()" ${ColorBlue})"

        elif [ "${CAP_TERM_ZSH}" = "YES" ]; then
            # NOTE: $funcstack[2]; ${funcfiletrace[@]} ${funcsourcetrace[@]} ${funcstack[@]} ${functrace[@]}
            _dbfile="$(distd "${funcfiletrace[2]#/usr/share/sofin/}" ${ColorBlue})"
            _fun="$(distd " ${funcstack[2]}()" ${ColorBlue})"

        else
            _dbfile=""
            _fun=""
        fi

        _dbfn=" (${SHLVL}) [${_sep}${_fun} @ ${_dbfile}] "
        if [ -z "${DEBUG}" ]; then
            _dbgnme="$(lowercase "${DEF_NAME}${DEF_POSTFIX}")"
            if [ -n "${_dbgnme}" -a \
                 -d "${LOGS_DIR}" ]; then
                # Definition log
                ${PRINTF_BIN} "#${ColorDebug}%s%s${ColorReset}\n" "${_dbfn}" "${_in}" 2>> "${LOG}-${_dbgnme}" >> "${LOG}-${_dbgnme}"
            elif [ -z "${_dbgnme}" -a \
                   -d "${LOGS_DIR}" ]; then
                # Main log
                ${PRINTF_BIN} "#${ColorDebug}%s%s${ColorReset}\n" "${_dbfn}" "${_in}" 2>> "${LOG}" >> "${LOG}"
            elif [ ! -d "${LOGS_DIR}" ]; then
                # System logger fallback
                ${LOGGER_BIN} "# λ ${ColorDebug}${_dbfn}${_in}${ColorReset}" 2>> "${LOG}"
            fi
        else # DEBUG is set. Print to stdout
            ${PRINTF_BIN} "#${ColorDebug}%s%s${ColorReset}\n" "${_dbfn}" "${_in}"
        fi
        unset _dbgnme _in _dbfn _dbfnin _elmz _cee
    fi
}


warn () {
    ${PRINTF_BIN} "${ColorYellow}%s${ColorReset}\n" "${@}"
}


note () {
    ${PRINTF_BIN} "${ColorGreen}%s${ColorReset}\n" "${@}"
}


error () {
    ${PRINTF_BIN} "\n\n${ColorRed}%s\n\n  ${FAIL_CHAR} Error!\n\n    %s\n\n%s\n\n\n" \
        "$(fill "${SEPARATOR_CHAR2}")" "${@}" "$(fill "${SEPARATOR_CHAR2}")"
    warn "  ${NOTE_CHAR2} If you think this error is a bug in definition, please report an info about"
    warn "    encountered problem on one of issue trackers:"
    ${PRINTF_BIN} "\n"
    warn "  ${NOTE_CHAR}  Bitbucket: $(distw "${DEFAULT_ISSUE_REPORT_SITE}")"
    warn "  ${NOTE_CHAR}  Github: $(distw "${DEFAULT_ISSUE_REPORT_SITE_ALT}")"
    ${PRINTF_BIN} "\n"
    warn "$(fill "${SEPARATOR_CHAR}" 46)$(distw "  Daniel (dmilith) Dettlaff  ")$(fill "${SEPARATOR_CHAR}" 5)"
    restore_security_state
    ${PRINTF_BIN} "\n"
    # TODO: add "history backtrace". Play with: fc -lnd -5, but separate sh/zsh history file should solve the problem
    exit ${ERRORCODE_TASK_FAILURE}
}


# distdebug
distd () {
    ${PRINTF_BIN} "${2:-${ColorDistinct}}%s${3:-${ColorDebug}}" "${1}" 2>/dev/null
}


# distnote
distn () {
    ${PRINTF_BIN} "${2:-${ColorDistinct}}%s${3:-${ColorNote}}" "${1}" 2>/dev/null
}


# distwarn
distw () {
    ${PRINTF_BIN} "${2:-${ColorDistinct}}%s${3:-${ColorWarning}}" "${1}" 2>/dev/null
}


# disterror
diste () {
    ${PRINTF_BIN} "${2:-${ColorDistinct}}%s${3:-${ColorError}}" "${1}" 2>/dev/null
}


run () {
    _run_params="${@}"
    if [ -n "${_run_params}" ]; then
        touch_logsdir_and_logfile
        ${PRINTF_BIN} '%s\n' "${_run_params}" | eval "${MATCH_PRINT_STDOUT_GUARD}" && _run_shw_prgr=YES
        debug "$(distd "$(${DATE_BIN} ${DEFAULT_DATE_TRYRUN_OPTS} 2>/dev/null)" ${ColorDarkgray}): $(distd "${RUN_CHAR}" ${ColorWhite}): $(distd "${_run_params}" ${ColorParams}) $(distd "[show-blueout:${_run_shw_prgr:-NO}]" ${ColorBlue})"
        if [ -z "${DEF_NAME}${DEF_POSTFIX}" ]; then
            if [ -z "${_run_shw_prgr}" ]; then
                eval "export PATH=${PATH}${GIT_EXPORTS} && ${_run_params}" >> "${LOG}" 2>> "${LOG}"
                check_result ${?} "${_run_params}"
            else
                ${PRINTF_BIN} "${ColorBlue}"
                eval "export PATH=${PATH}${GIT_EXPORTS} && ${_run_params}" >> "${LOG}"
                check_result ${?} "${_run_params}"
            fi
        else
            _rnm="$(lowercase "${DEF_NAME}${DEF_POSTFIX}")"
            if [ -z "${_run_shw_prgr}" ]; then
                eval "export PATH=${PATH}${GIT_EXPORTS} && ${_run_params}" >> "${LOG}-${_rnm}" 2>> "${LOG}-${_rnm}"
                check_result ${?} "${_run_params}"
            else
                ${PRINTF_BIN} "${ColorBlue}"
                eval "export PATH=${PATH}${GIT_EXPORTS} && ${_run_params}" >> "${LOG}-${_rnm}"
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
    if [ -n "${_try_params}" ]; then
        touch_logsdir_and_logfile
        ${PRINTF_BIN} "${_try_params}\n" | eval "${MATCH_PRINT_STDOUT_GUARD}" && _show_prgrss=YES
        _dt="$(distd "$(${DATE_BIN} ${DEFAULT_DATE_TRYRUN_OPTS} 2>/dev/null)" ${ColorDarkgray})"
        debug "${_dt}: $(distd "${TRY_CHAR}" ${ColorWhite}) $(distd "${_try_params}" ${ColorParams}) $(distd "[${_show_prgrss:-NO}]" ${ColorBlue})"
        _try_aname="$(lowercase "${DEF_NAME}${DEF_POSTFIX}")"
        if [ -z "${_try_aname}" ]; then
            if [ -z "${_show_prgrss}" ]; then
                eval "export PATH=${PATH}${GIT_EXPORTS} && ${_try_params}" >> "${LOG}" 2>> "${LOG}" && \
                    return 0
            else
                # show progress on stderr
                ${PRINTF_BIN} "${ColorBlue}"
                eval "export PATH=${PATH}${GIT_EXPORTS} && ${_try_params}" >> "${LOG}" && \
                    return 0
            fi
        else
            if [ -z "${_show_prgrss}" ]; then
                eval "export PATH=${PATH}${GIT_EXPORTS} && ${_try_params}" >> "${LOG}-${_try_aname}" 2>> "${LOG}-${_try_aname}" && \
                    return 0
            else
                ${PRINTF_BIN} "${ColorBlue}"
                eval "export PATH=${PATH}${GIT_EXPORTS} && ${_try_params}" >> "${LOG}-${_try_aname}" && \
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
    _targets=${*}
    _ammo="OOO"
    touch_logsdir_and_logfile
    # check for commands that puts something important/intersting on stdout
    ${PRINTF_BIN} '%s\n' "${_targets}" 2>/dev/null | eval "${MATCH_PRINT_STDOUT_GUARD}" && _rtry_blue=YES
    while [ -n "${_ammo}" ]; do
        if [ -n "${_targets}" ]; then
            _dt="$(distd "$(${DATE_BIN} ${DEFAULT_DATE_TRYRUN_OPTS} 2>/dev/null)" ${ColorDarkgray})"
            debug "${_dt}: $(distd "${TRY_CHAR}${NOTE_CHAR}${RUN_CHAR}" ${ColorWhite}) $(distd "${_targets}" ${ColorParams}) $(distd "[${_show_prgrss:-NO}]" ${ColorBlue})"
            if [ -z "${_rtry_blue}" ]; then
                eval "PATH=${DEFAULT_PATH}${GIT_EXPORTS} ${_targets}" >> "${LOG}" 2>> "${LOG}" && \
                    unset _ammo _targets && \
                        return 0
            else
                ${PRINTF_BIN} "${ColorBlue}"
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
    # setting up definitions repository
    if [ -z "${BRANCH}" ]; then
        BRANCH="${DEFAULT_DEFINITIONS_BRANCH}"
    fi
}


setup_defs_repo () {
    if [ -z "${REPOSITORY}" ]; then
        REPOSITORY="${DEFAULT_DEFINITIONS_REPOSITORY}"
    fi
}


cleanup_handler () {
    finalize
    debug "Normal exit."
    return 0
}


interrupt_handler () {
    warn "Interrupted: $(distw "${SOFIN_PID:-$$}")"
    finalize
    exit ${ERRORCODE_USER_INTERRUPT}
}


terminate_handler () {
    warn "Terminated: $(distw "${SOFIN_PID:-$$}")"
    finalize
    exit ${ERRORCODE_TERMINATED}
}


noop_handler () {
    debug "Handled signal USR2 with noop()"
}


handle_error () {
    debug "ErrorLine: ${ColorViolet}${1}"
}


trap_signals () {
    trap 'cleanup_handler' EXIT
    if [ "YES" = "${CAP_TERM_BASH}" ]; then
        trap 'handle_error $LINENO' ERR
    fi
    trap 'interrupt_handler' INT
    trap 'terminate_handler' TERM
    trap 'noop_handler' USR2 # This signal is used to "reload shell"-feature. Sofin should ignore it
}


untrap_signals () {
    trap - EXIT
    if [ "YES" = "${CAP_TERM_BASH}" ]; then
        trap - ERR
    fi
    trap - INT
    trap - TERM
    trap 'noop_handler' USR2 # This signal is used to "reload shell"-feature. Sofin should ignore it
}


restore_security_state () {
    if [ "YES" = "${CAP_SYS_HARDENED}" ]; then
        if [ -f "${DEFAULT_SECURITY_STATE_FILE}" ]; then
            note "Restoring pre-build security state"
            . ${DEFAULT_SECURITY_STATE_FILE} >> "${LOG}" 2>> "${LOG}"
        else
            debug "No security state file found: $(distd "${DEFAULT_SECURITY_STATE_FILE}")"
        fi
    else
        debug "No hardening capabilities in system"
    fi
}


store_security_state () {
    if [ "YES" = "${CAP_SYS_HARDENED}" ]; then
        try "${RM_BIN} -f ${DEFAULT_SECURITY_STATE_FILE}"
        debug "Storing current security state to file: $(distd "${DEFAULT_SECURITY_STATE_FILE}")"
        for _key in ${DEFAULT_HARDEN_KEYS}; do
            _sss_value="$(${SYSCTL_BIN} -n "${_key}" 2>/dev/null)"
            _sss_cntnt="${SYSCTL_BIN} ${_key}=${_sss_value}"
            ${PRINTF_BIN} "${_sss_cntnt}\n" >> ${DEFAULT_SECURITY_STATE_FILE} 2>/dev/null
        done
        unset _key _sss_cntnt _sss_value
    else
        debug "No hardening capabilities in system"
    fi
}


disable_security_features () {
    if [ "YES" = "${CAP_SYS_HARDENED}" ]; then
        debug "Disabling all security features.."
        try "${RM_BIN} -f ${DEFAULT_SECURITY_STATE_FILE}"
        for _key in ${DEFAULT_HARDEN_KEYS}; do
            try "${SYSCTL_BIN} ${_key}=0"
        done
        unset _key _dsf_name
    else
        debug "No hardening capabilities in system"
    fi
}


summary () {
    # Sofin performance counters:
    SOFIN_END="${SOFIN_END:-$(${SOFIN_MICROSECONDS_UTILITY_BIN})}"
    SOFIN_RUNTIME="$(calculate_bc "(${SOFIN_END} - ${SOFIN_START:-${SOFIN_END}}) / 1000")"

    ${PRINTF_BIN} "${ColorExample}%s${ColorReset}\n" "$(fill ${SEPARATOR_CHAR2})" >> "${LOG:-/var/log/sofin}"
    ${PRINTF_BIN} "${ColorExample}args.head: ${ColorYellow}%s\n" "${SOFIN_COMMAND_ARG:-''}" >> "${LOG:-/var/log/sofin}"
    ${PRINTF_BIN} "${ColorExample}args.tail: ${ColorYellow}%s\n" "${SOFIN_ARGS:-''}" >> "${LOG:-/var/log/sofin}"
    ${PRINTF_BIN} "${ColorExample}pid: ${ColorYellow}%d${ColorExample}\n" "${SOFIN_PID:--1}" >> "${LOG:-/var/log/sofin}"
    ${PRINTF_BIN} "${ColorExample}runtime: ${ColorYellow}%d${ColorExample} ms.\n" "${SOFIN_RUNTIME:--1}" >> "${LOG:-/var/log/sofin}"

    # Show "times" stats from shell:
    ${PRINTF_BIN} "${ColorExample}shell times: ${ColorReset}\n" >> "${LOG:-/var/log/sofin}"
    times >> "${LOG:-/var/log/sofin}"

    ${PRINTF_BIN} "${ColorExample}%s${ColorReset}\n" "$(fill ${SEPARATOR_CHAR2})" >> "${LOG:-/var/log/sofin}"
}


initialize () {
    setup_defs_branch
    setup_defs_repo
    check_defs_dir
    check_os
    trap_signals
}
