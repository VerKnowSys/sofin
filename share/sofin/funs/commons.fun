#!/usr/bin/env sh

# Parse version string to list of 3 arguments.
# f.e.: parse_version "1.2.41" will return 1 2 41
parse_version () {
    _version="${1}"
    IFS=. read -r _major _minor _micro <<EOF
${_version##*-}
EOF
    printf "%b %b %b\n" \
        "${_major}" \
        "${_minor}" \
        "${_micro}" 2>/dev/null
}


check_result () {
    if [ "${1}" = "0" ]; then
        shift
        debug "$(distd "${SUCCESS_CHAR}" "${ColorGreen}") $(distd "${@}")"
        return 0
    else
        shift
        debug "$(distd "${FAIL_CHAR}" "${ColorRed}") $(distd "${@}")"
        return 1
    fi
}


check_definitions_availability () {
    if [ ! -d "${DEFINITIONS_DIR}" ]; then
        update_defs
    fi
}


# check_os () {
#     case "${SYSTEM_NAME}" in
#         FreeBSD)
#             ;;
#         OpenBSD)
#             ;;
#         NetBSD)
#             ;;
#         Darwin)
#             ;;
#         Minix)
#             ;;
#         Linux)
#             ;;
#         *)
#             error "Currently only FreeBSD, Minix, Darwin and some Linux hosts are supported."
#             ;;
#     esac
# }


file_size () {
    _file="${1}"
    if [ -z "${_file}" ]; then
        printf "%d\n" "0" 2>/dev/null
        unset _file
        return 0
    fi
    if [ ! -f "${_file}" ]; then
        printf "%d\n" "0" 2>/dev/null
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

    printf "%d\n" "${_size}" 2>/dev/null
    unset _file _size
}


capitalize () {
    printf "%b\n" "${@}" 2>/dev/null \
        | ${AWK_BIN} '{for(i=1;i<=NF;i++){ $i=toupper(substr($i,1,1)) substr($i,2) }}1' 2>/dev/null
}


lowercase () {
    printf "%b\n" "${@}" 2>/dev/null \
        | ${TR_BIN} '[A-Z]' '[a-z]' 2>/dev/null
}


# capitalize_abs => lowercase() + capitalize ()
capitalize_abs () {
    printf "%b\n" "${@}" 2>/dev/null \
        | ${TR_BIN} '[A-Z]' '[a-z]' 2>/dev/null \
        | ${AWK_BIN} '{for(i=1;i<=NF;i++){ $i=toupper(substr($i,1,1)) substr($i,2) }}1' 2>/dev/null
}



fill () {
    _char="${1}"
    if [ -z "${_char}" ]; then
        _char="${SEPARATOR_CHAR}"
    fi
    _times=${2}
    if [ -z "${_times}" ]; then
        _times=${CAP_TERM_MAX_COLUMNS:-80}
    fi
    unset _buf
    while [ "${_times}" -gt "0" ]; do
        _buf="${_buf}${_char}"
        _times="$(( ${_times} - 1 ))"
    done
    printf "%b\n" "${_buf}" 2>/dev/null
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
                printf "%b\n" "${_fafind_results}" 2>/dev/null
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
            _frmatcher="*"
        fi
        if [ -d "${_frpath}" ]; then
            _frfind_results="$(${FIND_BIN} "${_frpath}" \
                -maxdepth 2 \
                -mindepth 1 \
                -type "${_frtype}" \
                -name "${_frmatcher}" \
                -not -name "*.strip" \
                -not -name "*.log" \
                -not -name "*.help" \
                -exec "${STAT_BIN}" -f '%m %N' {} \; \
                2>> "${LOG}" | \
                ${SORT_BIN} -nr 2>/dev/null | \
                ${HEAD_BIN} -n "${MAX_OPEN_TAIL_LOGS}" 2>/dev/null | \
                ${CUT_BIN} -d' ' -f2 2>/dev/null)"
            # _frres_singleline="$(printf "%b\n" "${_frfind_results}" | eval "${NEWLINES_TO_SPACES_GUARD}")"
            # debug "Find results: $(distd "${_frres_singleline}")"
            if [ -n "${_frfind_results}" ]; then
                printf "%b\n" "${_frfind_results}" 2>/dev/null
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
    printf "%b\n" "${_text_input}" | ${SED_BIN} -e "s#${_text_match}##" 2>/dev/null
}


text_checksum () {
    _fcsmname="${1}"
    if [ -z "${_fcsmname}" ]; then
        error "Empty content string given for function: $(diste "text_checksum()")"
    fi
    case "${SYSTEM_NAME}" in
        Darwin|Linux)
            printf "%b\n" "${_fcsmname}" | ${SHA_BIN} 2>/dev/null | ${CUT_BIN} -d' ' -f1 2>/dev/null
            ;;

        FreeBSD|NetBSD|OpenBSD|Minix)
            printf "%b\n" "${_fcsmname}" | ${SHA_BIN} 2>/dev/null
            ;;
    esac
    unset _fcsmname
}


# First n chars of content in first argument
firstn () {
    _content="${1:-""}"
    _req_length=${2:-16}
    printf "%.${_req_length}s\n" \
        "${_content}"
}


file_checksum () {
    _fcsmname="${1}"
    if [ -z "${_fcsmname}" ]; then
        error "Empty file name given for function: $(diste "file_checksum()")"
    fi
    case "${SYSTEM_NAME}" in
        NetBSD|Minix)
            ${SHA_BIN} -n "${_fcsmname}" 2>/dev/null | ${CUT_BIN} -d' ' -f1 2>/dev/null
            ;;

        Darwin|Linux)
            ${SHA_BIN} "${_fcsmname}" 2>/dev/null | ${CUT_BIN} -d' ' -f1 2>/dev/null
            ;;

        FreeBSD|OpenBSD)
            ${SHA_BIN} -q "${_fcsmname}" 2>/dev/null
            ;;

    esac
    unset _fcsmname
}


# # give any input to pass it through bc:
# calculate_bc () {
#     printf "%b\n" "${@}" 2>/dev/null | ${BC_BIN} 2>/dev/null
# }


# print_rainbow () {
#     printf "${ColorReset}ColorReset${ColorRed}ColorRed${ColorGreen}ColorGreen${ColorYellow}ColorYellow${ColorBlue}ColorBlue${ColorMagenta}ColorMagenta${ColorCyan}ColorCyan${ColorGray}ColorGray${ColorWhite}ColorWhite"

#     for i in $(seq 0 $(${TPUT_BIN} colors)); do
#         printf "$(${TPUT_BIN} setaf ${i}):${i}:TEXT-COLORFUL${ColorReset}\t"
#     done
# }
