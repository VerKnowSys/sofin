check_result () {
    if [ "${1}" = "0" ]; then
        shift
        debug "$(distd "${SUCCESS_CHAR}" "${ColorGreen}") $(distd "${*}")"
    else
        shift
        error "$(diste "${FAIL_CHAR}" "${ColorRed}") $(diste "${*}")"
    fi
}


check_os () {
    case "${SYSTEM_NAME}" in
        FreeBSD)
            ;;

        OpenBSD)
            ;;

        NetBSD)
            ;;

        Darwin)
            ;;

        Minix)
            ;;

        Linux)
            ;;

        *)
            error "Currently only FreeBSD, Minix, Darwin and some Linux hosts are supported."
            ;;

    esac
}


file_size () {
    _file="${1}"
    if [ -z "${_file}" ]; then
        ${PRINTF_BIN} '%d' "0" 2>/dev/null
        unset _file
        return 0
    fi
    if [ ! -f "${_file}" ]; then
        ${PRINTF_BIN} '%d' "0" 2>/dev/null
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

    ${PRINTF_BIN} '%d' "${_size}" 2>/dev/null
    unset _file _size
}


capitalize () {
    ${PRINTF_BIN} '%s' "${*}" 2>/dev/null | ${AWK_BIN} '{for(i=1;i<=NF;i++){ $i=toupper(substr($i,1,1)) substr($i,2) }}1' 2>/dev/null
}


lowercase () {
    ${PRINTF_BIN} '%s' "${*}" 2>/dev/null | ${TR_BIN} '[A-Z]' '[a-z]' 2>/dev/null
}


fill () {
    _char="${1}"
    if [ -z "${_char}" ]; then
        _char="${SEPARATOR_CHAR}"
    fi
    _times=${2}
    if [ -z "${_times}" ]; then
        _times=${MAX_COLS}
    fi
    unset _buf
    for i in $(${SEQ_BIN} 1 "${_times}" 2>/dev/null); do
        _buf="${_buf}${_char}"
    done
    ${PRINTF_BIN} '%s' "${_buf}" 2>/dev/null
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
            if [ -n "${_fafind_results}" ]; then
                ${PRINTF_BIN} '%s\n' "${_fafind_results}" 2>/dev/null
            fi
        else
            error "Directory $(diste "${_fapath}") doesn't exist!"
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
            debug "Specified matcher: $(distd "${_frmatcher}")"
        fi
        if [ -d "${_frpath}" ]; then
            debug "Find _frpath: $(distd "${_frpath}")"
            _frfind_results="$(${FIND_BIN} "${_frpath}" \
                -maxdepth 2 \
                -mindepth 1 \
                -type "${_frtype}" \
                -name "${_frmatcher}" \
                -not -name "*.strip" \
                -exec "${STAT_BIN}" -f '%m %N' {} \; \
                2>> "${LOG}" | \
                ${SORT_BIN} -nr 2>/dev/null | \
                ${HEAD_BIN} -n "${MAX_OPEN_TAIL_LOGS}" 2>/dev/null | \
                ${CUT_BIN} -d' ' -f2 2>/dev/null)"
            _frres_singleline="$(${PRINTF_BIN} '%s\n' "${_frfind_results}" | eval "${NEWLINES_TO_SPACES_GUARD}")"
            # debug "Find results: $(distd "${_frres_singleline}")"
            if [ -n "${_frfind_results}" ]; then
                ${PRINTF_BIN} '%s' "${_frfind_results}" 2>/dev/null
            fi
        else
            error "Directory $(diste "${_frpath}") doesn't exist!"
        fi
    fi
    unset _frpath _frmatcher _frtype _frfind_results _frres_singleline
}


difftext () {
    _text_input="${1}"
    _text_match="${2}"
    ${PRINTF_BIN} '%s' "$(${PRINTF_BIN} '%s' "${_text_input}" | ${SED_BIN} -e "s#${_text_match}##" 2>/dev/null)"
}


text_checksum () {
    _fcsmname="${1}"
    if [ -z "${_fcsmname}" ]; then
        error "Empty content string given for function: $(diste "text_checksum()")"
    fi
    case ${SYSTEM_NAME} in
        Minix|Darwin|Linux)
            ${PRINTF_BIN} '%s' "${_fcsmname}" | ${SHA_BIN} 2>/dev/null | ${CUT_BIN} -d' ' -f1 2>/dev/null
            ;;

        FreeBSD)
            ${PRINTF_BIN} '%s' "${_fcsmname}" | ${SHA_BIN} 2>/dev/null
            ;;
    esac
    unset _fcsmname
}


# First n chars of content in first argument
firstn () {
    _contents=${1:-""}
    _length=${2:-16}
    ${PRINTF_BIN} \
        "%.${_length}s" \
        "${_contents}"
}


file_checksum () {
    _fcsmname="${1}"
    if [ -z "${_fcsmname}" ]; then
        error "Empty file name given for function: $(diste "file_checksum()")"
    fi
    case ${SYSTEM_NAME} in
        Minix|Darwin|Linux)
            ${PRINTF_BIN} '%s' "$(${SHA_BIN} "${_fcsmname}" 2>/dev/null | ${CUT_BIN} -d' ' -f1 2>/dev/null)" 2>> "${LOG}"
            ;;

        FreeBSD)
            ${PRINTF_BIN} '%s' "$(${SHA_BIN} -q "${_fcsmname}" 2>/dev/null)" 2>> "${LOG}"
            ;;
    esac
    unset _fcsmname
}


# give any input to pass it through bc:
calculate_bc () {
    ${PRINTF_BIN} '%s\n' "${*}" 2>/dev/null | ${BC_BIN} 2>/dev/null
}


print_rainbow () {
    ${PRINTF_BIN} "${ColorReset}ColorReset${ColorRed}ColorRed${ColorGreen}ColorGreen${ColorYellow}ColorYellow${ColorBlue}ColorBlue${ColorMagenta}ColorMagenta${ColorCyan}ColorCyan${ColorGray}ColorGray${ColorWhite}ColorWhite"

    for i in $(seq 0 $(${TPUT_BIN} colors)); do
        ${PRINTF_BIN} "$(${TPUT_BIN} setaf ${i}):${i}:TEXT-COLORFUL${ColorReset}\t"
    done
}
