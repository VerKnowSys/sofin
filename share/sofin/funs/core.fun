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
        aname="$(echo "${APP_NAME}${APP_POSTFIX}" | ${TR_BIN} '[A-Z]' '[a-z]' 2>/dev/null)"
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
    warn "\n${NOTE_CHAR2} I'm very serious about software development and it's quality, hence if"
    warn "  while using Sofin, you encounter, a problem similar to scenarios like:"
    warn "  ${WARN_CHAR} $(distinct w "*found-design-problem*"),"
    warn "  ${WARN_CHAR} $(distinct w "*feature-bug*"),"
    warn "  ${WARN_CHAR} $(distinct w "*stucked-in-some-undefined-behaviour*"),"
    warn "  ${WARN_CHAR} $(distinct w "*caused-data-loss*"),"
    warn "  ${WARN_CHAR} $(distinct w "*found-regressions*"),"
    warn "  ${WARN_CHAR} $(distinct w "*caused-a-crash*"),"
    warn "                          - please don't hesitate to report an issue(s)!"
    warn "$(fill)\n"
    warn "${NOTE_CHAR2} Sofin lacks real-world documentation, mostly because it's not required,"
    warn "  since this software was designed and written with simplicity in mind ($(distinct w KISS))"
    warn "  ${WARN_CHAR} $(distinct w "https://github.com/VerKnowSys/sofin")"
    warn "  ${WARN_CHAR} $(distinct w "https://github.com/VerKnowSys/sofin/wiki/Sofin,-the-software-installer")"
    warn "                - written for: $(distinct w "https://bsdmag.org"), release: $(distinct w "BSD_06_2013.pdf")"
    warn "$(fill)\n"
    warn "${NOTE_CHAR2} Sofin issue trackers:"
    warn "  ${WARN_CHAR} Bitbucket: $(distinct w "${DEFAULT_ISSUE_REPORT_SITE}")"
    warn "  ${WARN_CHAR} Github: $(distinct w "${DEFAULT_ISSUE_REPORT_SITE_ALT}")"
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
        ${MKDIR_BIN} -p "${LOGS_DIR}"
        aname="$(lowercase ${APP_NAME}${APP_POSTFIX})"
        debug "tStamp: $(${DATE_BIN} +%s 2>/dev/null)\
            Launching action: '$(distinct d $@)')"
        if [ -z "${aname}" ]; then
            eval PATH="${PATH}" "$@" >> "${LOG}" 2>> "${LOG}"
            check_command_result $? "$@"
        else
            eval PATH="${PATH}" "$@" >> "${LOG}-${aname}" 2>> "${LOG}-${aname}"
            check_command_result $? "$@"
        fi
    else
        error "Specified an empty command to run. Aborting."
    fi
}


try () {
    if [ ! -z "$1" ]; then
        ${MKDIR_BIN} -p "${LOGS_DIR}"
        aname="$(lowercase ${APP_NAME}${APP_POSTFIX})"
        debug "$(${DATE_BIN} +%s 2>/dev/null) try('$(distinct d $@)')"
        if [ -z "${aname}" ]; then
            eval PATH="${PATH}" "$@" >> "${LOG}" 2>> "${LOG}"
        else
            eval PATH="${PATH}" "$@" >> "${LOG}-${aname}" 2>> "${LOG}-${aname}"
        fi
    else
        error "An empty command to run for: $(distinct e ${APP_NAME})?"
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
