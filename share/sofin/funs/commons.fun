check_command_result () {
    if [ -z "$1" ]; then
        error "Empty command given for: $(distinct e "check_command_result()")!"
    fi
    if [ "$1" = "0" ]; then
        shift
        debug "Command successful: '$(distinct d "$*")'"
    else
        shift
        error "Action failed: '$(distinct e "$*")'.
Might try this: $(distinct e $(${BASENAME_BIN} ${SOFIN_BIN} 2>/dev/null) log defname), to see what went wrong"
    fi
}


def_error () {
    if [ -z "${2}" ]; then
        error "Failed action for: $(distinct e $1). Report it if necessary on: $(distinct e "${DEFAULT_ISSUE_REPORT_SITE}") or fix definition please!"
    else
        error "${2}. Report it if necessary on: $(distinct e "${DEFAULT_ISSUE_REPORT_SITE}") or fix definition please!"
    fi
}


os_tripple () {
    ${PRINTF_BIN} "${SYSTEM_NAME}-${FULL_SYSTEM_VERSION}-${SYSTEM_ARCH}"
}


check_os () {
    case "${SYSTEM_NAME}" in
        FreeBSD)
            ;;

        Darwin)
            ;;

        Linux)
            ;;

        Minix)
            ;;

        *)
            error "Currently only FreeBSD, Minix, Darwin and Debian hosts are supported."
            exit
            ;;

    esac
}




retry () {
    retries="***"
    while [ ! -z "${retries}" ]; do
        if [ ! -z "$1" ]; then
            debug "$(${DATE_BIN} +%H%M%S-%s 2>/dev/null) Retry('$@')[${retries}];"
            if [ ! -f "${LOG}" -o ! -d "${LOGS_DIR}" ]; then
                ${MKDIR_BIN} -p "${LOGS_DIR}"
            fi
            gitroot="$(${BASENAME_BIN} $(${BASENAME_BIN} ${GIT_BIN} 2>/dev/null) 2>/dev/null)"
            eval PATH="/bin:/usr/bin:${gitroot}/bin:${gitroot}/libexec/git-core" "$@" >> "${LOG}" 2>> "${LOG}" && \
            return 0
        else
            error "An empty command to retry?"
        fi
        retries="$(echo "${retries}" | ${SED_BIN} 's/\*//' 2>/dev/null)"
        debug "Retries left: ${retries}"
    done
    error "All retries exhausted for launch command: '$@'"
}


capitalize () {
    name="$1"
    if [ -z "${name}" ]; then
        error "Empty application name given for function: $(distinct e "capitalize()")"
    fi
    _head="$(${PRINTF_BIN} "${name}" 2>/dev/null | ${CUT_BIN} -c1 2>/dev/null | ${TR_BIN} '[a-z]' '[A-Z]' 2>/dev/null)"
    _tail="$(${PRINTF_BIN} "${name}" 2>/dev/null | ${SED_BIN} 's/^[a-zA-Z]//' 2>/dev/null)"
    ${PRINTF_BIN} "${_head}${_tail}"
    unset _head _tail
}


lowercase () {
    name="$1"
    if [ -z "${name}" ]; then
        error "Empty application name given for function: $(distinct e "lowercase()")"
    fi
    ${PRINTF_BIN} "${name}" 2>/dev/null | ${TR_BIN} '[A-Z]' '[a-z]' 2>/dev/null
}


fill () {
    _char="${1}"
    if [ -z "${_char}" ]; then
        _char="${SEPARATOR_CHAR}"
    fi
    _times=${2}
    if [ -z "${_times}" ]; then
        _times=80
    fi
    _buf=""
    for i in $(${SEQ_BIN} 1 ${_times} 2>/dev/null); do
        _buf="${_buf}${_char}"
    done
    ${PRINTF_BIN} "${_buf}"
    unset _times _buf
}
