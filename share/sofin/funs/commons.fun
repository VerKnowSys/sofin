check_command_result () {
    if [ -z "$1" ]; then
        error "Empty command given for: $(distinct e "check_command_result()")!"
    fi
    if [ "$1" = "0" ]; then
        shift
        debug "Command successful: $(distinct d "$*")"
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
            error "Currently only FreeBSD, Minix, Darwin and some Linux hosts are supported."
            ;;

    esac
}


retry () {
    _targets="${1}"
    _ammo="OOO"

    # check for commands that puts something important/intersting on stdout
    unset show_stdout_progress
    echo "${_targets}" | eval "${MATCH_FETCH_CMDS_GUARD}" && show_stdout_progress=YES

    debug "Show stdout progress show_stdout_progress=$(distinct d "${show_stdout_progress}")"
    while [ ! -z "${_ammo}" ]; do
        if [ ! -z "${_targets}" ]; then
            debug "${TIMESTAMP}: Invoking: retry($(distinct d "${_targets}")) [$(distinct d ${_ammo})]"
            if [ ! -f "${LOG}" -o \
                 ! -d "${LOGS_DIR}" ]; then
                ${MKDIR_BIN} -p "${LOGS_DIR}" >/dev/null 2>&1
            fi
            _gitroot="$(${BASENAME_BIN} $(${BASENAME_BIN} ${GIT_BIN} 2>/dev/null) 2>/dev/null)"
            if [ -z "${show_stdout_progress}" ]; then
                eval PATH="${_gitroot}/bin:${_gitroot}/libexec/git-core:${DEFAULT_PATH}" \
                    "${_targets}" >> "${LOG}" 2>> "${LOG}" && \
                    unset _gitroot _ammo _targets && \
                    return 0
            else
                ${PRINTF_BIN} "${blue}"
                eval PATH="${_gitroot}/bin:${_gitroot}/libexec/git-core:${DEFAULT_PATH}" \
                    "${_targets}" >> "${LOG}" && \
                    unset _gitroot _ammo _targets && \
                    return 0
            fi
        else
            error "retry(): Given an empty command to evaluate!"
        fi
        _ammo="$(echo "${_ammo}" | ${SED_BIN} 's/O//' 2>/dev/null)"
        debug "retry(): Remaining attempts: $(distinct d ${_ammo})"
    done
    error "All _ammo exhausted to invoke a command: $(distinct e "${_targets}")"
}


capitalize () {
    _name="$*"
    _head="$(${PRINTF_BIN} "${_name}" 2>/dev/null | ${CUT_BIN} -c1 2>/dev/null | ${TR_BIN} '[a-z]' '[A-Z]' 2>/dev/null)"
    _tail="$(${PRINTF_BIN} "${_name}" 2>/dev/null | ${SED_BIN} 's/^[a-zA-Z]//' 2>/dev/null)"
    ${PRINTF_BIN} "${_head}${_tail}"
    unset _head _tail _name
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


find_all () {
    _path="${1}"
    _matcher="${2}"
    _type="${3}"
    if [ -z "${_type}" ]; then
        _type='f' # look for files only by default
    fi
    if [ -z "${_path}" ]; then
        error "Empty path given to find_all()!"
    else
        if [ -z "${_matcher}" ]; then
            debug "Empty matcher given in find_all(), using wildcard."
            _matcher="*"
        fi
        if [ -d "${_path}" ]; then
            _find_results="$(${FIND_BIN} "${_path}" \
                -maxdepth 1 \
                -mindepth 1 \
                -type ${_type} \
                -name "${_matcher}" \
                2>/dev/null)"
            if [ -z "${_find_results}" ]; then
                ${PRINTF_BIN} "" 2>/dev/null
            else
                ${PRINTF_BIN} "${_find_results}" 2>/dev/null
            fi
        else
            error "Directory $(distinct e "${_path}") doesn't exists!"
        fi
    fi
    unset _path _matcher _type _find_results
}


find_most_recent () {
    _path="${1}"
    _matcher="${2}"
    _type="${3}"
    if [ -z "${_type}" ]; then
        _type='f' # look for files only by default
    fi
    if [ -z "${_path}" ]; then
        error "Empty path given to find_most_recent()!"
    else
        if [ -z "${_matcher}" ]; then
            debug "Empty matcher given in find_most_recent(), using wildcard."
            _matcher='*'
        fi
        _stat_param='-f' # BSD syntax
        case ${SYSTEM_NAME} in
            Linux)
                _stat_param='-c' # GNU syntax
                ;;
        esac
        if [ -d "${_path}" ]; then
            _find_results="$(${FIND_BIN} "${_path}" \
                -maxdepth 1 \
                -mindepth 1 \
                -type ${_type} \
                -name "${_matcher}" \
                -exec ${STAT_BIN} ${_stat_param} '%m %N' {} \; 2>/dev/null | \
                ${SORT_BIN} -nr 2>/dev/null | \
                ${HEAD_BIN} -n${MAX_OPEN_TAIL_LOGS} 2>/dev/null | \
                ${CUT_BIN} -d' ' -f2 2>/dev/null \
                )"
            if [ -z "${_find_results}" ]; then
                ${PRINTF_BIN} "" 2>/dev/null
            else
                ${PRINTF_BIN} "${_find_results}" 2>/dev/null
            fi
        else
            error "Directory $(distinct e "${_path}") doesn't exists!"
        fi
    fi
    unset _path _matcher _type _find_results _stat_param
}
