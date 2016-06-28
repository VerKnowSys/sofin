env_reset () {
    # unset conflicting environment variables
    debug "env_reset()"
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


cecho () {
    if [ "${TTY}" = "YES" ]; then # if it's terminal then use colors
        ${PRINTF_BIN} "${2}${1}${reset}\n"
    else
        ${PRINTF_BIN} "${1}\n"
    fi
}


debug () {
    if [ -z "${DEBUG}" ]; then
        _dbgnme="$(echo "${DEF_NAME}${DEF_POSTFIX}" | ${TR_BIN} '[A-Z]' '[a-z]' 2>/dev/null)"
        if [ ! -z "${_dbgnme}" -a -d "${LOGS_DIR}" ]; then
            cecho "# $1" ${magenta} >> "${LOG}-${_dbgnme}" 2>> "${LOG}-${_dbgnme}"
        elif [ -z "${_dbgnme}" -a -d "${LOGS_DIR}" ]; then
            cecho "# $1" ${magenta} >> "${LOG}" 2>> "${LOG}"
        elif [ ! -d "${LOGS_DIR}" ]; then
            ${LOGGER_BIN} "sofin: $1"
        fi
        unset _dbgnme
    else
        cecho "# $1" ${magenta} # NOTE: this "#" is required for debug mode to work properly with generation of ~/.profile
    fi
}


warn () {
    cecho "$1" ${yellow}
}


note () {
    cecho "$1" ${green}
}


error () {
    cecho
    cecho "$(fill)" ${red}
    cecho "${FAIL_CHAR} Error: $1" ${red}
    cecho "$(fill)" ${red}
    warn "\n$(fill)"
    warn "${NOTE_CHAR2} Since I'm very serious about software code quality overall,"
    warn "  please don't hesitate to report an issue(s) if you encounter a problem,"
    warn "  or for instance experience one of scenarios:"
    warn "\t$(distinct w "*found-design-problem*"),"
    warn "\t$(distinct w "*feature-bug*"),"
    warn "\t$(distinct w "*stucked-in-some-undefined-behaviour*"),"
    warn "\t$(distinct w "*caused-data-loss*"),"
    warn "\t$(distinct w "*found-regressions*"),"
    warn "${NOTE_CHAR2} Sofin resources:"
    warn "\t$(distinct w "https://github.com/VerKnowSys/sofin"),"
    warn "\t$(distinct w "https://github.com/VerKnowSys/sofin/wiki/Sofin,-the-software-installer")"
    warn "${NOTE_CHAR2} Sofin issue trackers:"
    warn "\tBitbucket: $(distinct w "${DEFAULT_ISSUE_REPORT_SITE}")"
    warn "\tGithub: $(distinct w "${DEFAULT_ISSUE_REPORT_SITE_ALT}")"
    warn "\n$(fill "${SEPARATOR_CHAR}" 46)$(distinct w "  Daniel (dmilith) Dettlaff  ")$(fill "${SEPARATOR_CHAR}" 5)\n"
    exit 1
}


distinct () {
    msg_type="${1}"
    shift
    content="$*"
    if [ -z "${msg_type}" ]; then
        error "No message type given as first param for: ${DISTINCT_COLOUR}distinct()${red}!"
    fi
    case ${msg_type} in
        n|note)
            ${PRINTF_BIN} "${DISTINCT_COLOUR}${content}${green}"
            ;;

        d|debug)
            ${PRINTF_BIN} "${DISTINCT_COLOUR}${content}${magenta}"
            ;;

        w|warn)
            ${PRINTF_BIN} "${DISTINCT_COLOUR}${content}${yellow}"
            ;;

        e|error)
            ${PRINTF_BIN} "${DISTINCT_COLOUR}${content}${red}"
            ;;

        *)
            ${PRINTF_BIN} "${msg_type}${content}${reset}"
            ;;
    esac
}


run () {
    if [ ! -z "$1" ]; then
        _run_params="$@"
        unset _run_show_stdout_progress
        echo "${_run_params}" | eval "${MATCH_FETCH_CMDS_GUARD}" && _run_show_stdout_progress=YES
        _rnm="$(lowercase "${DEF_NAME}${DEF_POSTFIX}")"
        debug "$(${DATE_BIN} +%s 2>/dev/null) run($(distinct d ${_run_params}))"
        if [ -z "${_rnm}" ]; then
            if [ -z "${_run_show_stdout_progress}" ]; then
                eval PATH="${PATH}" "${_run_params}" >> "${LOG}" 2>> "${LOG}"
                check_command_result $? "${_run_params}"
            else
                ${PRINTF_BIN} "${blue}"
                eval PATH="${PATH}" "${_run_params}" >> "${LOG}"
                check_command_result $? "${_run_params}"
            fi
        else
            if [ -z "${_run_show_stdout_progress}" ]; then
                eval PATH="${PATH}" "${_run_params}" >> "${LOG}-${_rnm}" 2>> "${LOG}-${_rnm}"
                check_command_result $? "${_run_params}"
            else
                ${PRINTF_BIN} "${blue}"
                eval PATH="${PATH}" "${_run_params}" >> "${LOG}-${_rnm}"
                check_command_result $? "${_run_params}"
            fi
        fi
    else
        error "Specified an empty command to run()!"
    fi
    unset _rnm _run_show_stdout_progress _run_params
}


try () {
    if [ ! -z "$1" ]; then
        _try_params="$@"
        unset _try_show_stdout_progress
        echo "${_try_params}" | eval "${MATCH_FETCH_CMDS_GUARD}" && \
            _try_show_stdout_progress=YES
        _try_aname="$(lowercase "${DEF_NAME}${DEF_POSTFIX}")"
        debug "$(${DATE_BIN} +%s 2>/dev/null): try($(distinct d ${_try_params}), show_stdout_progress=$(distinct d "${_try_show_stdout_progress}")"
        if [ -z "${_try_aname}" ]; then
            if [ -z "${_try_show_stdout_progress}" ]; then
                eval PATH="${PATH}" "${_try_params}" >> "${LOG}" 2>> "${LOG}"
            else
                ${PRINTF_BIN} "${blue}"
                eval PATH="${PATH}" "${_try_params}" >> "${LOG}" # show progress on stderr
            fi
        else
            if [ -z "${_try_show_stdout_progress}" ]; then
                eval PATH="${PATH}" "${_try_params}" >> "${LOG}-${_try_aname}" 2>> "${LOG}-${_try_aname}"
            else
                ${PRINTF_BIN} "${blue}"
                eval PATH="${PATH}" "${_try_params}" >> "${LOG}-${_try_aname}"
            fi
        fi
    else
        error "Specified an empty command to try()!"
    fi
}


setup_default_branch () {
    # setting up definitions repository
    if [ -z "${BRANCH}" ]; then
        BRANCH="stable"
    fi
}


setup_default_repository () {
    if [ -z "${REPOSITORY}" ]; then
        REPOSITORY="https://verknowsys@bitbucket.org/verknowsys/sofin-definitions.git" # main sofin definitions repository
    fi
}
