env_reset () {
    # unset conflicting environment variables
    unset LDFLAGS
    unset CFLAGS
    unset CXXFLAGS
    unset CPPFLAGS
    unset PATH
    unset LD_LIBRARY_PATH
    unset LD_PRELOAD
    unset DYLD_LIBRARY_PATH
    unset PKG_CONFIG_PATH
}


debug () {
    _in=${@}
    touch_logsdir_and_logfile
    unset _dbfnin
    if [ "${CAP_TERM_BASH}" = "YES" ]; then
        if [ -n "${FUNCNAME[*]}" ]; then # bash based:
            _elmz="${FUNCNAME[*]}"
            for _cee in ${_elmz}; do
                case "${_cee}" in
                    debug|note|warn|error|distinct)
                        ;;

                    *)
                        if [ -z "${_dbfnin}" ]; then
                            _dbfnin="${_cee}"
                        else
                            _dbfnin="${_cee}->${_dbfnin}"
                        fi
                        ;;
                esac
            done
            _dbfnin="${_dbfnin}(): "
        fi
    elif [ "${CAP_TERM_ZSH}" = "YES" ]; then
        setopt debugbeforecmd
        setopt notify
    else
        _dbfnin="(): "
    fi

    # NOTE: "#" is required for debug mode to work properly
    _dbfn="# ${ColorFunction}${_dbfnin}${ColorViolet}"
    if [ -z "${DEBUG}" ]; then
        _dbgnme="$(lowercase "${DEF_NAME}${DEF_POSTFIX}")"
        if [ -n "${_dbgnme}" -a \
             -d "${LOGS_DIR}" ]; then
            # Definition log
            ${PRINTF_BIN} "${_dbfn}%s${ColorReset}\n" "${_in}" 2>> "${LOG}-${_dbgnme}" >> "${LOG}-${_dbgnme}"
        elif [ -z "${_dbgnme}" -a \
               -d "${LOGS_DIR}" ]; then
            # Main log
            ${PRINTF_BIN} "${_dbfn}%s${ColorReset}\n" "${_in}" 2>> "${LOG}" >> "${LOG}"
        elif [ ! -d "${LOGS_DIR}" ]; then
            # System logger fallback
            ${LOGGER_BIN} "${DEFAULT_NAME}: ${_dbfn}${_in}${ColorReset}" 2>> "${LOG}"
        fi
    else # DEBUG is set. Print to stdout
        ${PRINTF_BIN} "${_dbfn}%s${ColorReset}\n" "${_in}"
    fi
    unset _dbgnme _in _dbfn _dbfnin _elmz _cee
}


warn () {
    ${PRINTF_BIN} "${ColorYellow}%s${ColorReset}\n" "${@}"
}


note () {
    ${PRINTF_BIN} "${ColorGreen}%s${ColorReset}\n" "${@}"
}


error () {
    ${PRINTF_BIN} "\n${ColorRed}%s\n\n  ${FAIL_CHAR} Error:\n          %s\n\n%s${ColorReset}\n\n" \
        "$(fill)" "${@}" "$(fill)$(fill)"
    warn "${NOTE_CHAR2} If you think this error is a bug in definition,"
    warn "  please report an info about encountered problem. Core scenarios:"
    warn "\t$(distinct w "*encountered-design-problem*"),"
    warn "\t$(distinct w "*found-feature-bug*"),"
    warn "\t$(distinct w "*stucked-in-some-undefined-behaviour*"),"
    warn "\t$(distinct w "*caused-data-loss*"),"
    warn "${NOTE_CHAR2} Sofin resources:"
    warn "\t$(distinct w "https://github.com/VerKnowSys/sofin"),"
    warn "\t$(distinct w "https://github.com/VerKnowSys/sofin/wiki/Sofin,-the-software-installer")"
    warn "${NOTE_CHAR2} Sofin issue trackers:"
    warn "\tBitbucket: $(distinct w "${DEFAULT_ISSUE_REPORT_SITE}")"
    warn "\tGithub: $(distinct w "${DEFAULT_ISSUE_REPORT_SITE_ALT}")"
    warn "\n$(fill "${SEPARATOR_CHAR}" 46)$(distinct w "  Daniel (dmilith) Dettlaff  ")$(fill "${SEPARATOR_CHAR}" 5)\n"
    restore_security_state
    exit ${ERRORCODE_TASK_FAILURE}
}


distinct () {
    _msg_type="${1}"
    shift
    _contents="${@}"
    if [ -z "${_msg_type}" ]; then
        error "No message type given as first param for: ${DISTINCT_COLOUR}distinct()${ColorRed}!"
    fi
    case "${_msg_type}" in
        n|note)
            ${PRINTF_BIN} "${DISTINCT_COLOUR}%s${ColorGreen}" "${_contents}" 2>/dev/null
            ;;

        d|debug)
            ${PRINTF_BIN} "${DISTINCT_COLOUR}%s${ColorViolet}" "${_contents}" 2>/dev/null
            ;;

        w|warn)
            ${PRINTF_BIN} "${DISTINCT_COLOUR}%s${ColorYellow}" "${_contents}" 2>/dev/null
            ;;

        e|error)
            ${PRINTF_BIN} "${DISTINCT_COLOUR}%s${ColorRed}" "${_contents}" 2>/dev/null
            ;;

        *)
            ${PRINTF_BIN} "${_msg_type}%s${ColorReset}" "${_contents}" 2>/dev/null
            ;;
    esac
    unset _msg_type _contents
}


run () {
    _run_params="${@}"
    if [ -n "${_run_params}" ]; then
        touch_logsdir_and_logfile
        ${PRINTF_BIN} '%s\n' "${_run_params}" | eval "${MATCH_PRINT_STDOUT_GUARD}" && _run_shw_prgr=YES
        if [ -n "${GIT_ROOT_DIR}" ]; then
            _git_path=":${GIT_ROOT_DIR}/bin:${GIT_ROOT_DIR}/libexec/git-core"
        else
            unset _git_path
        fi
        debug "$(distinct ${ColorDarkgray} "$(${DATE_BIN} ${DEFAULT_DATE_TRYRUN_OPTS} 2>/dev/null)"): $(distinct ${ColorWhite} ${RUN_CHAR}): $(distinct ${ColorParams} "${_run_params}") $(distinct ${ColorBlue} "[show-blueout:${_run_shw_prgr:-NO}]")"
        if [ -z "${DEF_NAME}${DEF_POSTFIX}" ]; then
            if [ -z "${_run_shw_prgr}" ]; then
                eval "PATH=${PATH}${_git_path} ${_run_params}" >> "${LOG}" 2>> "${LOG}"
                check_result ${?} "${_run_params}"
            else
                ${PRINTF_BIN} "${ColorBlue}"
                eval "PATH=${PATH}${_git_path} ${_run_params}" >> "${LOG}"
                check_result ${?} "${_run_params}"
            fi
        else
            _rnm="$(lowercase "${DEF_NAME}${DEF_POSTFIX}")"
            if [ -z "${_run_shw_prgr}" ]; then
                eval "PATH=${PATH}${_git_path} ${_run_params}" >> "${LOG}-${_rnm}" 2>> "${LOG}-${_rnm}"
                check_result ${?} "${_run_params}"
            else
                ${PRINTF_BIN} "${ColorBlue}"
                eval "PATH=${PATH}${_git_path} ${_run_params}" >> "${LOG}-${_rnm}"
                check_result ${?} "${_run_params}"
            fi
        fi
    else
        error "Specified an empty command to run()!"
    fi
    unset _rnm _run_shw_prgr _run_params _dt _git_root _git_path
}


try () {
    _try_params="${@}"
    if [ -n "${_try_params}" ]; then
        touch_logsdir_and_logfile
        ${PRINTF_BIN} "${_try_params}\n" | eval "${MATCH_PRINT_STDOUT_GUARD}" && _show_prgrss=YES
        _dt="$(distinct ${ColorDarkgray} "$(${DATE_BIN} ${DEFAULT_DATE_TRYRUN_OPTS} 2>/dev/null)")"
        debug "${_dt}: $(distinct ${ColorWhite} "${TRY_CHAR}") $(distinct ${ColorParams} "${_try_params}") $(distinct ${ColorBlue} "[${_show_prgrss:-NO}]")"
        _try_aname="$(lowercase "${DEF_NAME}${DEF_POSTFIX}")"
        if [ -z "${_try_aname}" ]; then
            if [ -z "${_show_prgrss}" ]; then
                eval "PATH=${PATH} ${_try_params}" >> "${LOG}" 2>> "${LOG}" && \
                    return 0
            else
                # show progress on stderr
                ${PRINTF_BIN} "${ColorBlue}"
                eval "PATH=${PATH} ${_try_params}" >> "${LOG}" && \
                    return 0
            fi
        else
            if [ -z "${_show_prgrss}" ]; then
                eval "PATH=${PATH} ${_try_params}" >> "${LOG}-${_try_aname}" 2>> "${LOG}-${_try_aname}" && \
                    return 0
            else
                ${PRINTF_BIN} "${ColorBlue}"
                eval "PATH=${PATH} ${_try_params}" >> "${LOG}-${_try_aname}" && \
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
    unset _git_path
    touch_logsdir_and_logfile
    # check for commands that puts something important/intersting on stdout
    ${PRINTF_BIN} '%s\n' "${_targets}" 2>/dev/null | eval "${MATCH_PRINT_STDOUT_GUARD}" && _rtry_blue=YES
    if [ -n "${GIT_ROOT_DIR}" ]; then
        _git_path=":${GIT_ROOT_DIR}/bin:${GIT_ROOT_DIR}/libexec/git-core"
    fi
    while [ -n "${_ammo}" ]; do
        if [ -n "${_targets}" ]; then
            _dt="$(distinct ${ColorDarkgray} "$(${DATE_BIN} ${DEFAULT_DATE_TRYRUN_OPTS} 2>/dev/null)")"
            debug "${_dt}: $(distinct ${ColorWhite} "${TRY_CHAR}${NOTE_CHAR}${RUN_CHAR}") $(distinct ${ColorParams} "${_targets}") $(distinct ${ColorBlue} "[${_show_prgrss:-NO}]")"
            if [ -z "${_rtry_blue}" ]; then
                eval "PATH=${DEFAULT_PATH}${_git_path} ${_targets}" >> "${LOG}" 2>> "${LOG}" && \
                    unset _ammo _targets && \
                        return 0
            else
                ${PRINTF_BIN} "${ColorBlue}"
                eval "PATH=${DEFAULT_PATH}${_git_path} ${_targets}" >> "${LOG}" && \
                    unset _ammo _targets && \
                        return 0
            fi
        else
            error "Given an empty command to evaluate!"
        fi
        _ammo="$(${PRINTF_BIN} '%s\n' "${_ammo}" 2>/dev/null | ${SED_BIN} 's/O//' 2>/dev/null)"
        debug "Remaining attempts: $(distinct d "${_ammo}")"
    done
    debug "All available ammo exhausted to invoke a command: $(distinct d "${_targets}")"
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
    warn "Interrupted: $(distinct w "${SOFIN_PID:-$$}")"
    finalize
    exit ${ERRORCODE_USER_INTERRUPT}
}


terminate_handler () {
    warn "Terminated: $(distinct w "${SOFIN_PID:-$$}")"
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
    trap - USR2 # This signal is used to "reload shell"-feature. Sofin should ignore it
}


restore_security_state () {
    if [ "YES" = "${CAP_SYS_HARDENED}" ]; then
        if [ -f "${DEFAULT_SECURITY_STATE_FILE}" ]; then
            note "Restoring pre-build security state"
            . ${DEFAULT_SECURITY_STATE_FILE} >> "${LOG}" 2>> "${LOG}"
        else
            debug "No security state file found: $(distinct d "${DEFAULT_SECURITY_STATE_FILE}")"
        fi
    else
        debug "No hardening capabilities in system"
    fi
}


store_security_state () {
    if [ "YES" = "${CAP_SYS_HARDENED}" ]; then
        try "${RM_BIN} -f ${DEFAULT_SECURITY_STATE_FILE}"
        debug "Storing current security state to file: $(distinct d "${DEFAULT_SECURITY_STATE_FILE}")"
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
