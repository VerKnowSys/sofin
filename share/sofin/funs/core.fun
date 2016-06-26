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
        aname="$(echo "${DEF_NAME}${DEF_POSTFIX}" | ${TR_BIN} '[A-Z]' '[a-z]' 2>/dev/null)"
        if [ ! -z "${aname}" -a -d "${LOGS_DIR}" ]; then
            cecho "# $1" ${magenta} >> "${LOG}-${aname}" 2>> "${LOG}-${aname}"
        elif [ -z "${aname}" -a -d "${LOGS_DIR}" ]; then
            cecho "# $1" ${magenta} >> "${LOG}" 2>> "${LOG}"
        elif [ ! -d "${LOGS_DIR}" ]; then
            ${LOGGER_BIN} "# ${cyan} $1"
        fi
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
        _params="$@"
        unset show_stdout_progress
        echo "${_params}" | eval "${MATCH_FETCH_CMDS_GUARD}" && show_stdout_progress=YES
        _aname="$(lowercase "${DEF_NAME}${DEF_POSTFIX}")"
        debug "$(${DATE_BIN} +%s 2>/dev/null) run($(distinct d ${_params}))"
        if [ -z "${_aname}" ]; then
            if [ -z "${show_stdout_progress}" ]; then
                eval PATH="${PATH}" "${_params}" >> "${LOG}" 2>> "${LOG}"
                check_command_result $? "${_params}"
            else
                ${PRINTF_BIN} "${blue}"
                eval PATH="${PATH}" "${_params}" >> "${LOG}"
                check_command_result $? "${_params}"
            fi
        else
            if [ -z "${show_stdout_progress}" ]; then
                eval PATH="${PATH}" "${_params}" >> "${LOG}-${_aname}" 2>> "${LOG}-${_aname}"
                check_command_result $? "${_params}"
            else
                ${PRINTF_BIN} "${blue}"
                eval PATH="${PATH}" "${_params}" >> "${LOG}-${_aname}"
                check_command_result $? "${_params}"
            fi
        fi
    else
        error "Specified an empty command to run. Aborting."
    fi
}


try () {
    if [ ! -z "$1" ]; then
        _params="$@"
        unset _show_stdout_progress
        echo "${_params}" | eval "${MATCH_FETCH_CMDS_GUARD}" && \
            _show_stdout_progress=YES
        _aname="$(lowercase "${DEF_NAME}${DEF_POSTFIX}")"
        debug "$(${DATE_BIN} +%s 2>/dev/null): try($(distinct d ${_params}), show_stdout_progress=$(distinct d "${_show_stdout_progress}")"
        if [ -z "${_aname}" ]; then
            if [ -z "${_show_stdout_progress}" ]; then
                eval PATH="${PATH}" "${_params}" >> "${LOG}" 2>> "${LOG}"
            else
                ${PRINTF_BIN} "${blue}"
                eval PATH="${PATH}" "${_params}" >> "${LOG}" # show progress on stderr
            fi
        else
            if [ -z "${_show_stdout_progress}" ]; then
                eval PATH="${PATH}" "${_params}" >> "${LOG}-${_aname}" 2>> "${LOG}-${_aname}"
            else
                ${PRINTF_BIN} "${blue}"
                eval PATH="${PATH}" "${_params}" >> "${LOG}-${_aname}"
            fi
        fi
    else
        error "An empty command to run for: $(distinct e ${DEF_NAME}${DEF_POSTFIX})?"
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
