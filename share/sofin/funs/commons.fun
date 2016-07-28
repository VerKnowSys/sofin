check_result () {
    if [ "$1" = "0" ]; then
        shift
        debug "$(distinct ${ColorGreen} "${SUCCESS_CHAR}") $(distinct d "${*}")"
    else
        shift
        error "$(distinct ${ColorRed} "${FAIL_CHAR}") $(distinct e "${*}")"
    fi
}


def_error () {
    if [ -z "${2}" ]; then
        error "$(distinct ${ColorRed} "${FAIL_CHAR}") $(distinct e "${1}")"
    else
        error "$(distinct ${ColorGreen} "${SUCCESS_CHAR}") $(distinct e "${2}")"
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


file_size () {
    _file="${1}"
    if [ -z "${_file}" ]; then
        ${PRINTF_BIN} "0" 2>/dev/null
        unset _file
        return 0
    fi
    if [ ! -f "${_file}" ]; then
        ${PRINTF_BIN} "0" 2>/dev/null
        unset _file
        return 0
    fi
    case "${SYSTEM_NAME}" in
        Linux)
            _size=$(${STAT_BIN} -c%s "${_file}" 2>/dev/null)
            ;;

        *)
            _size=$(${STAT_BIN} -f%z "${_file}" 2>/dev/null)
            ;;
    esac

    ${PRINTF_BIN} "${_size}" 2>/dev/null
    unset _file _size
}


retry () {
    _targets="${*}"
    _ammo="OOO"

    touch_logsdir_and_logfile

    # check for commands that puts something important/intersting on stdout
    unset _rtry_show_stdout_progress
    echo "${_targets}" | eval "${MATCH_PRINT_STDOUT_GUARD}" && _rtry_show_stdout_progress=YES

    debug "Show stdout progress _rtry_show_stdout_progress=$(distinct d "${_rtry_show_stdout_progress}")"
    while [ -n "${_ammo}" ]; do
        if [ -n "${_targets}" ]; then
            debug "${TIMESTAMP}: Invoking: retry($(distinct d "${_targets}")) [$(distinct d ${_ammo})]"
            _gitroot="$(${BASENAME_BIN} $(${BASENAME_BIN} ${GIT_BIN} 2>/dev/null) 2>/dev/null)"
            if [ -z "${_rtry_show_stdout_progress}" ]; then
                eval "PATH=${_gitroot}/bin:${_gitroot}/libexec/git-core:${DEFAULT_PATH} ${_targets}" >> "${LOG}" 2>> "${LOG}" && \
                    unset _gitroot _ammo _targets && \
                    return 0
            else
                ${PRINTF_BIN} "${ColorBlue}"
                eval "PATH=${_gitroot}/bin:${_gitroot}/libexec/git-core:${DEFAULT_PATH} ${_targets}" >> "${LOG}" && \
                    unset _gitroot _ammo _targets && \
                    return 0
            fi
        else
            error "Given an empty command to evaluate!"
        fi
        _ammo="$(echo "${_ammo}" | ${SED_BIN} 's/O//' 2>/dev/null)"
        debug "Remaining attempts: $(distinct d "${_ammo}")"
    done
    debug "All _ammo exhausted to invoke a command: $(distinct e "${_targets}")"
    unset _ammo _targets
    return 1
}


capitalize () {
    _capi_name="${*}"
    _capi_head="$(${PRINTF_BIN} "${_capi_name}" 2>/dev/null | ${CUT_BIN} -c1 2>/dev/null | ${TR_BIN} '[a-z]' '[A-Z]' 2>/dev/null)"
    _capi_tail="$(${PRINTF_BIN} "${_capi_name}" 2>/dev/null | ${SED_BIN} 's/^[a-zA-Z]//' 2>/dev/null)"
    ${PRINTF_BIN} "${_capi_head}${_capi_tail}"
    unset _capi_head _capi_tail _capi_name
}


lowercase () {
    ${PRINTF_BIN} "${*}" | ${TR_BIN} '[A-Z]' '[a-z]' 2>/dev/null
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
    _fapath="${1}"
    _famatcher="${2}"
    _fatype="${3}"
    if [ -z "${_fatype}" ]; then
        _fatype='f' # look for files only by default
    fi
    if [ -z "${_fapath}" ]; then
        error "Empty path given to find_all()!"
    else
        if [ -z "${_famatcher}" ]; then
            debug "Empty matcher given in find_all(), using wildcard."
            _famatcher='*'
        fi
        if [ -d "${_fapath}" ]; then
            _fafind_results="$(${FIND_BIN} "${_fapath}" \
                -maxdepth 1 \
                -mindepth 1 \
                -type "${_fatype}" \
                -name "${_famatcher}" \
                2>/dev/null)"
            if [ -z "${_fafind_results}" ]; then
                ${PRINTF_BIN} "" 2>/dev/null
            else
                ${PRINTF_BIN} "${_fafind_results}" 2>/dev/null
            fi
        else
            error "Directory $(distinct e "${_fapath}") doesn't exists!"
        fi
    fi
    unset _fapath _famatcher _fatype _fafind_results
}


find_most_recent () {
    _frpath="${1}"
    _frmatcher="${2}"
    _frtype="${3}"
    if [ -z "${_frtype}" ]; then
        _frtype="f" # look for files only by default
    fi
    if [ -z "${_frpath}" ]; then
        error "Empty path given to find_most_recent()!"
    elif [ "${SYSTEM_NAME}" = "Linux" ]; then
        error "This function does bad things with GNU find. Fix it if you want.."
    else
        if [ -z "${_frmatcher}" ]; then
            debug "Empty matcher given in find_most_recent(), using wildcard."
            _frmatcher="*"
        else
            debug "Specified matcher: $(distinct d ${_frmatcher})"
        fi
        if [ -d "${_frpath}" ]; then
            debug "Find _frpath: $(distinct d "${_frpath}")"
            _frfind_results="$(${FIND_BIN} "${_frpath}" \
                -maxdepth 2 \
                -mindepth 1 \
                -type "${_frtype}" \
                -name "${_frmatcher}" \
                -not -name "*.strip" \
                -exec ${STAT_BIN} -f '%m %N' {} \; \
                2>> ${LOG} | \
                ${SORT_BIN} -nr 2>/dev/null | \
                ${HEAD_BIN} -n${MAX_OPEN_TAIL_LOGS} 2>/dev/null | \
                ${CUT_BIN} -d' ' -f2 2>/dev/null)"
            _frres_singleline="$(echo "${_frfind_results}" | eval "${NEWLINES_TO_SPACES_GUARD}")"
            debug "Find results: $(distinct d "${_frres_singleline}")"
            if [ -z "${_frfind_results}" ]; then
                ${PRINTF_BIN} "" 2>/dev/null
            else
                ${PRINTF_BIN} "${_frfind_results}" 2>/dev/null
            fi
        else
            error "Directory $(distinct e "${_frpath}") doesn't exists!"
        fi
    fi
    unset _frpath _frmatcher _frtype _frfind_results _frres_singleline
}


difftext () {
    _text_input="${1}"
    _text_match="${2}"
    ${PRINTF_BIN} "$(${PRINTF_BIN} "${_text_input}" | ${SED_BIN} -e "s#${_text_match}##" 2>/dev/null)"
}


text_checksum () {
    _fcsmname="$1"
    if [ -z "${_fcsmname}" ]; then
        error "Empty content string given for function: $(distinct e "text_checksum()")"
    fi
    case ${SYSTEM_NAME} in
        Minix|Darwin|Linux)
            ${PRINTF_BIN} "${_fcsmname}" | ${SHA_BIN} 2>/dev/null | ${CUT_BIN} -d' ' -f1 2>/dev/null
            ;;

        FreeBSD)
            ${PRINTF_BIN} "${_fcsmname}" | ${SHA_BIN} 2>/dev/null
            ;;
    esac
    unset _fcsmname
}


file_checksum () {
    _fcsmname="$1"
    if [ -z "${_fcsmname}" ]; then
        error "Empty file name given for function: $(distinct e "file_checksum()")"
    fi
    case ${SYSTEM_NAME} in
        Minix|Darwin|Linux)
            ${PRINTF_BIN} "$(${SHA_BIN} "${_fcsmname}" 2>/dev/null | ${CUT_BIN} -d' ' -f1 2>/dev/null)"
            ;;

        FreeBSD)
            ${PRINTF_BIN} "$(${SHA_BIN} -q "${_fcsmname}" 2>/dev/null)"
            ;;
    esac
    unset _fcsmname
}


print_rainbow () {
    ${PRINTF_BIN} "${ColorReset}ColorReset${ColorRed}ColorRed${ColorGreen}ColorGreen${ColorYellow}ColorYellow${ColorBlue}ColorBlue${ColorMagenta}ColorMagenta${ColorCyan}ColorCyan${ColorGray}ColorGray${ColorWhite}ColorWhite"

    for i in $(seq 0 $(${TPUT_BIN} colors)); do
        ${PRINTF_BIN} "$(${TPUT_BIN} setaf ${i}):${i}:TEXT-COLORFUL${ColorReset}\t"
    done
}
