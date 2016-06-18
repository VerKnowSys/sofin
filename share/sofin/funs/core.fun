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
            cecho "# $1" ${magenta} >> "${LOG}-${aname}" 2>&1
        elif [ -z "${aname}" -a -d "${LOGS_DIR}" ]; then
            cecho "# $1" ${magenta} >> "${LOG}" 2>&1
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
    cecho "${ERROR_CHAR} $1" ${red}
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
            eval PATH="${PATH}" "$@" >> "${LOG}" 2>&1
            check_command_result $? "$@"
        else
            eval PATH="${PATH}" "$@" >> "${LOG}-${aname}" 2>&1
            check_command_result $? "$@"
        fi
    else
        error "An empty command to run?"
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
