
less_logs () {
    ${LESS_BIN} ${DEFAULT_LESS_OPTIONS} ${LOGS_DIR}/${SOFIN_NAME}-*${1}* 2>/dev/null
    return 0
}


show_logs () {
    _logf_pattern="${1:-+}"
    debug "Show logs pattern: '$(distd "${_logf_pattern}")'"
    touch_logsdir_and_logfile
    if [ "-" = "${_logf_pattern}" ] \
    || [ "${SOFIN_NAME}" = "${_logf_pattern}" ]; then
        ${TAIL_BIN} -n "${LOG_LINES_AMOUNT}" "${LOG}"

    elif [ "@" = "${_logf_pattern}" ]; then
        unset _all_files
        for _mr in $(${FIND_BIN} "${LOGS_DIR%/}" -name "${SOFIN_NAME}*" -not -name "*.log" -not -name "*.help" -not -name "*.strip" -type f 2>/dev/null); do
            _all_files="${_mr} ${_all_files}"
        done
        eval "${TAIL_BIN} -n1 -F ${_all_files}"

    elif [ "+" = "${_logf_pattern}" ]; then
        unset _all_files
        for _mr in $(find_most_recent "${LOGS_DIR%/}" "${SOFIN_NAME}*" | ${HEAD_BIN} -n "${LOG_LAST_FILES}" 2>/dev/null); do
            _all_files="${_mr} ${_all_files}"
        done
        eval "${TAIL_BIN} -n ${LOG_LINES_AMOUNT} -F ${_all_files}"

    else
        unset _all_files
        for _mr in $(${FIND_BIN} "${LOGS_DIR%/}" -name "${SOFIN_NAME}*${_logf_pattern}*" -not -name "*.log" -not -name "*.help" -not -name "*.strip" -type f 2>/dev/null); do
            _all_files="${_mr} ${_all_files}"
        done
        if [ -n "${_all_files}" ]; then
            _2x_more_lines=$(( ${LOG_LINES_AMOUNT} * 2 ))
            eval "${TAIL_BIN} -F -n ${_2x_more_lines} ${_all_files}"
        else
            return 1
        fi
    fi
    unset _files_x_min _logf_minutes _logf_pattern _files_list _files_count _files_blist _mod_f_names _all_count
}


pretouch_logs () {
    _params="${*}"
    if [ -z "${CAP_SYS_PRODUCTION}" ]; then
        debug "Calling log-pretouch for: $(distd "$(printf "%b\n" "${_params}" | ${WC_BIN} -w 2>/dev/null)") files…"
        unset _pret_list
        for _app in $(to_iter "${_params}"); do
            if [ -z "${_app}" ]; then
                debug "Empty app given out of params: $(distd "${_params}")?"
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
        permnote "$(fill)"
        ${TAIL_BIN} -n "${LOG_LINES_AMOUNT_ON_ERR}" \
            "${LOG}" \
            "${LOG}-${DEF_NAME}" \
            "${LOG}-${DEF_NAME}${DEF_SUFFIX}" \
                2>/dev/null
        permnote "$(fill)"
    else
        permnote "No logs matching the pattern has been found."
    fi
}


touch_logsdir_and_logfile () {
    if [ ! -d "${LOGS_DIR}" ] \
    || [ ! -f "${LOG}" ]; then
        ${MKDIR_BIN} -p "${LOGS_DIR}" >/dev/null 2>&1
        ${TOUCH_BIN} "${LOG}" >/dev/null 2>&1
    fi
}


checksum_filecache_element () {
    _file_to_checksum="${1}"
    if [ -z "${_file_to_checksum}" ]; then
        error "First argument with $(diste "file-name-to-chksum") is required!"
    fi
    _file_chksum="$(file_checksum "${FILE_CACHE_DIR}${_file_to_checksum}")"
    if [ -z "${_file_chksum}" ]; then
        error "Empty checksum of file: $(diste "${FILE_CACHE_DIR}${_file_to_checksum}")"
    elif [ ! -f "${FILE_CACHE_DIR}${_file_to_checksum}" ]; then
        error "No such file found in file-cache: $(diste "${FILE_CACHE_DIR}${_file_to_checksum}")"
    else
        _chksum_file="${FILE_CACHE_DIR}${_file_to_checksum}${DEFAULT_CHKSUM_EXT}"
        printf "%b\n" "${_file_chksum}" > "${_chksum_file}" \
            && debug "Stored chksum: $(distd "${_file_chksum}") of file: $(distd "${_file_to_checksum}") in path: $(distd "${FILE_CACHE_DIR}${_file_to_checksum}")"
    fi
    unset _file_chksum _file_to_checksum _chksum_file
}


dump_software_build_configuration_options () {
    _config_log="${1}"
    if [ "YES" = "${CAP_SYS_BUILDHOST}" ]; then
        ${MKDIR_BIN} -p "$(${DIRNAME_BIN} "${_config_log}" 2>/dev/null)"
        eval "${DEF_CONFIGURE_METHOD} -h | ${TEE_BIN} ${_config_log}" >/dev/null 2>&1
        _configuration_opts_rendered="$(${CAT_BIN} "${_config_log}" 2>/dev/null | ${GREP_BIN} -E '\-\-\s*' 2>/dev/null)"

        printf "\t\t\t\t\r\r\n%b%b%b: %b\n" \
            "${ColorDistinct}" \
            "\t\t\t\t\t\t${ANSI_ONE_LINE_UP}    complete list of build-features: " \
            "$(distn "${_config_log}" "${ColorExample}")" \
            "${ColorReset}"

        if [ -n "${DEBUG}" ]; then # display detailed options  for each dependency... not too amusing ;)
            printf "\n\n%b%b%b\n\n" "${ColorBlue}" "${_configuration_opts_rendered}" "${ColorReset}"
        fi
    fi
    return 0
}
