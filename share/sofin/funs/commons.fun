check_command_result () {
    if [ -z "$1" ]; then
        error "Empty command given for: $(distinct e "check_command_result()")!"
    fi
    if [ "$1" = "0" ]; then
        shift
        debug "Command successful: '$(distinct d "$*")'"
    else
        shift
        error "Command failed: $(distinct e "$*")"
    fi
}


def_error () {
    if [ -z "${2}" ]; then
        error "Failed action for: $(distinct e $1)"
    else
        error "${2}"
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
            ;;

    esac
}


retry () {
    ammo="***"
    targets="$@"

    # check for commands that puts something important/intersting on stdout
    unset show_stdout_progress
    echo "${targets}" | eval "${MATCH_FETCH_CMDS_GUARD}" && show_stdout_progress=YES

    debug "Show stdout progress show_stdout_progress=$(distinct d "${show_stdout_progress}")"
    while [ ! -z "${ammo}" ]; do
        if [ ! -z "${targets}" ]; then
            debug "${TIMESTAMP}: Invoking: retry($(distinct d "${targets}")[$(distinct d ${ammo})]"
            if [ ! -f "${LOG}" -o \
                 ! -d "${LOGS_DIR}" ]; then
                ${MKDIR_BIN} -p "${LOGS_DIR}"
            fi
            gitroot="$(${BASENAME_BIN} $(${BASENAME_BIN} ${GIT_BIN} 2>/dev/null) 2>/dev/null)"
            if [ -z "${show_stdout_progress}" ]; then
                eval PATH="${gitroot}/bin:${gitroot}/libexec/git-core:${DEFAULT_PATH}" \
                    "${targets}" >> "${LOG}" 2>> "${LOG}" && \
                    unset gitroot ammo targets && \
                    return 0
            else
                ${PRINTF_BIN} "${green}"
                eval PATH="${gitroot}/bin:${gitroot}/libexec/git-core:${DEFAULT_PATH}" \
                    "${targets}" >> "${LOG}" && \
                    unset gitroot ammo targets && \
                    return 0
            fi
        else
            error "retry(): Given an empty command to evaluate!"
        fi
        ammo="$(echo "${ammo}" | ${SED_BIN} 's/\*//' 2>/dev/null)"
        debug "retry(): Remaining attempts: $(distinct d ${ammo})"
    done
    error "All ammo exhausted to invoke a command: $(distinct e "${targets}")"
}


capitalize () {
    name="$*"
    _head="$(${PRINTF_BIN} "${name}" 2>/dev/null | ${CUT_BIN} -c1 2>/dev/null | ${TR_BIN} '[a-z]' '[A-Z]' 2>/dev/null)"
    _tail="$(${PRINTF_BIN} "${name}" 2>/dev/null | ${SED_BIN} 's/^[a-zA-Z]//' 2>/dev/null)"
    ${PRINTF_BIN} "${_head}${_tail}"
    unset _head _tail name
}


lowercase () {
    ${PRINTF_BIN} "$*" | ${TR_BIN} '[A-Z]' '[a-z]' 2>/dev/null
}


fill () {
    _char="${1}"
    if [ -z "${_char}" ]; then
        _char="${SEPARATOR_CHAR}"
    fi
    _times=${2}
    if [ -z "${_times}" ]; then
        _times="${MAX_COLS}"
    fi
    _buf=""
    for i in $(${SEQ_BIN} 1 ${_times} 2>/dev/null); do
        _buf="${_buf}${_char}"
    done
    ${PRINTF_BIN} "${_buf}"
    unset _times _buf _char
}
