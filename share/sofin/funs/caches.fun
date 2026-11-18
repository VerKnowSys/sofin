#!/usr/bin/env sh

less_logs () {
    ${LESS_BIN} ${DEFAULT_LESS_OPTIONS} ${LOGS_DIR}/${SOFIN_NAME}-*${1}* 2>/dev/null
    return 0
}


show_logs () {
    _logf_pattern="${1:-+}"
    debug "Show logs pattern: '${ColorDistinct}${_logf_pattern}${ColorDebug}'"
    create_sofin_dirs
    if [ "-" = "${_logf_pattern}" ] \
    || [ "${SOFIN_NAME}" = "${_logf_pattern}" ]; then
        ${TAIL_BIN} -n "${LOG_LINES_AMOUNT}" "${LOG}"

    elif [ "@" = "${_logf_pattern}" ]; then
        ${LW_BIN} "${LOGS_DIR}" 2>/dev/null \
            && return

        unset _all_files
        for _mr in $(${FIND_BIN} "${LOGS_DIR%/}" -name "${SOFIN_NAME}*" -not -name "*.result" -not -name "*.config" -not -name "*.strip" -type f 2>/dev/null); do
            _all_files="${_mr} ${_all_files}"
        done
        eval "${TAIL_BIN} -n1 -F ${_all_files}"

    elif [ "+" = "${_logf_pattern}" ]; then
        ${LW_BIN} "${LOGS_DIR}" 2>/dev/null \
            && return

        unset _all_files
        for _mr in $(find_most_recent "${LOGS_DIR%/}" "${SOFIN_NAME}*" | ${HEAD_BIN} -n "${LOG_LAST_FILES}" 2>/dev/null); do
            _all_files="${_mr} ${_all_files}"
        done
        eval "${TAIL_BIN} -n ${LOG_LINES_AMOUNT} -F ${_all_files}"

    else
        # NOTE: print last lines of logs matching the pattern (without following them):
        unset _all_files
        for _mr in $(${FIND_BIN} "${LOGS_DIR%/}" -name "${SOFIN_NAME}*${_logf_pattern}*" -not -name "*.result" -not -name "*.config" -not -name "*.strip" -type f 2>/dev/null); do
            _all_files="${_mr} ${_all_files}"
        done
        if [ -n "${_all_files}" ]; then
            eval "${TAIL_BIN} -n ${LOG_LINES_AMOUNT_ON_PATTERN} ${_all_files}"
        else
            permnote "No logs matching the pattern: ${ColorDistinct}${_logf_pattern}${ColorNote}"
            return 1
        fi
    fi
    unset _files_x_min _logf_minutes _logf_pattern _files_list _files_count _files_blist _mod_f_names _all_count
}


pretouch_logs () {
    _params="${*}"
    if [ -n "${CAP_SYS_BUILDHOST}" ]; then
        debug "Calling log-pretouch for: ${ColorDistinct}$(printf "%b\n" "${_params}" | ${AWK_BIN} '{print NF;}' 2>/dev/null)${ColorDebug} files${CHAR_DOTS}"
        unset _pret_list
        for _app in $(to_iter "${_params}"); do
            if [ -z "${_app}" ]; then
                debug "Empty app given out of params: ${ColorDistinct}${_params}${ColorDebug}?"
            else
                if [ -z "${_pret_list}" ]; then
                    _pret_list="${LOGS_DIR}${SOFIN_NAME}-${_app}"
                else
                    _pret_list="${LOGS_DIR}${SOFIN_NAME}-${_app} ${_pret_list}"
                fi
            fi
        done
        ${TOUCH_BIN} ${LOGS_DIR}${SOFIN_NAME} ${_pret_list} >/dev/null 2>&1
        unset _app _params
    fi
}


show_log_if_available () {
    if [ -f "${LOG}" ]; then
        ${TAIL_BIN} -n "${LOG_LINES_AMOUNT_ON_ERR}" "${LOG}" 2>/dev/null
    else
        permnote "No logs matching the pattern has been found."
    fi
}


show_bundle_log_if_available () {
    if [ -f "${LOG}-${DEF_NAME}${DEF_SUFFIX}" ]; then
        ${TAIL_BIN} -n "${LOG_LINES_AMOUNT_ON_ERR}" "${LOG}-${DEF_NAME}${DEF_SUFFIX}" 2>/dev/null
    elif [ -f "${LOG}-${DEF_NAME}" ]; then
        ${TAIL_BIN} -n "${LOG_LINES_AMOUNT_ON_ERR}" "${LOG}-${DEF_NAME}" 2>/dev/null
    elif [ -f "${LOG}" ]; then
        ${TAIL_BIN} -n "${LOG_LINES_AMOUNT_ON_ERR}" "${LOG}" 2>/dev/null
    else
        permnote "No log for bundle: ${ColorDistinct}${DEF_NAME}${DEF_SUFFIX}${ColorNote}"
    fi
}


checksum_filecache_element () {
    _file_to_checksum="${1}"
    if [ -z "${_file_to_checksum}" ]; then
        error "First argument with ${ColorDistinct}file-name-to-chksum${ColorError} is required!"
    fi
    _file_chksum="$(file_checksum "${FILE_CACHE_DIR}${_file_to_checksum}")"
    if [ -z "${_file_chksum}" ]; then
        error "Empty checksum of file: ${ColorDistinct}${FILE_CACHE_DIR}${_file_to_checksum}${ColorError}"
    elif [ ! -f "${FILE_CACHE_DIR}${_file_to_checksum}" ]; then
        error "No such file found in file-cache: ${ColorDistinct}${FILE_CACHE_DIR}${_file_to_checksum}${ColorError}"
    else
        _chksum_file="${FILE_CACHE_DIR}${_file_to_checksum}${DEFAULT_CHKSUM_EXT}"
        printf "%b\n" "${_file_chksum}" > "${_chksum_file}" \
            && debug "Stored chksum: ${ColorDistinct}${_file_chksum}${ColorDebug} of file: ${ColorDistinct}${_file_to_checksum}${ColorDebug} in path: ${ColorDistinct}${FILE_CACHE_DIR}${_file_to_checksum}${ColorDebug}"
    fi
    unset _file_chksum _file_to_checksum _chksum_file
}


dump_software_build_configuration_options () {
    _config_log="${1}"
    _config_args="${2:-"-h"}" # ANYCONFIG -h => Help (usually)
    _config_result="${_config_log}.result"
    if [ "YES" = "${CAP_SYS_BUILDHOST}" ]; then
        ${MKDIR_BIN} -p "$(${DIRNAME_BIN} "${_config_log}" 2>/dev/null)"
        eval "${DEF_CONFIGURE_METHOD} ${_config_args} | ${TEE_BIN} ${_config_log}" >/dev/null 2>&1
        _configuration_opts_rendered="$(${CAT_BIN} "${_config_log}" 2>/dev/null | ${GREP_BIN} -E '\-\-\s*' 2>/dev/null)"

        printf "\t\t\t\t\r\r\n%b%b%b%b%b %b\n" \
            "${ColorDistinct}" \
            "\t\t\t\t\t\t${ANSI_ONE_LINE_UP}     ${ColorDark}${NOTE_CHAR} config:${ColorReset} "    \
            "${ColorExample:-${ColorDistinct}}${_config_log}${ColorNote}" \
            "${ColorDark} -> " \
            "${ColorExample:-${ColorDistinct}}${_config_result}${ColorNote}" \
            "${ColorReset}"

        if [ -n "${DEBUG}" ]; then # display detailed options  for each dependency... not too amusing ;)
            printf "\n\n%b%b%b\n\n" "${ColorBlue}" "${_configuration_opts_rendered}" "${ColorReset}"
        fi
    fi
    return 0
}
