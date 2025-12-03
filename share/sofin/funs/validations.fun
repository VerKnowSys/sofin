#!/usr/bin/env sh

check_version () { # $1 => installed version, $2 => available version
    if [ -n "${1}" ]; then
        if [ -n "${2}" ]; then
            if [ "${1}" != "${2}" ]; then
                if [ -z "${4}" ]; then
                    warn "Bundle: $(distw "$(capitalize_abs "${3}")"), version: $(distw "${2}") is definied, but installed version is: $(distw "${1}")"
                else
                    printf "%b\n" "$(capitalize_abs "${3}")"
                fi
                FOUND_OUTDATED=YES
            fi
        fi
    fi
}


# validate environment availability or crash
validate_env () {
    if [ -z "${SKIP_ENV_VALIDATION}" ]; then
        for _envvar in $(set | ${GREP_BIN} -EI "^[A-Z]+_BIN=" 2>/dev/null)
        do
            _var_value="${_envvar#*=}"
            if [ ! -x "${_var_value}" ]; then
                error "Required binary is unavailable: $(diste "${_envvar}")"
            fi
        done \
            || finalize_and_quit_gracefully_with_exitcode "${ERRORCODE_VALIDATE_ENV_FAILURE}"
        unset _var_value _envvar
    else
        debug "ENV validation skipped!"
    fi
}


fail_on_bg_job () {
    _deps="${*}"
    if [ -n "${_deps}" ]; then
        debug "fail_on_bg_job() => $(distd "$(printf "%b\n" "${_deps}" | eval "${NEWLINES_TO_SPACES_GUARD}")")"
        acquire_lock_for "${_deps}"
    fi
    unset _deps
}


fail_any_bg_jobs () {
    # Traverse through locks, make sure that every pid from lock is dead before cleaning can continue
    for _a_lock in $(${FIND_BIN} "${LOCKS_DIR}" -type f -name "*${DEFAULT_LOCK_EXT}" -print 2>/dev/null); do
        _bundle_name="${_a_lock##*/}"
        _lock_pid="$(${CAT_BIN} "${_a_lock}" 2>/dev/null)"
        if [ -n "${_lock_pid}" ]; then
            try "${KILL_BIN} -0 ${_lock_pid}"
            if [ "${?}" = "0" ]; then
                error "Bundle: $(diste "${_bundle_name}") is currently locked by pid: $(diste "${_lock_pid}"). Other Sofin instance is still running in background!"
            fi
        fi
    done
    unset _bundle_name _lock_pid _a_lock
}



validate_loaded_def () {
    if [ "${DEF_TYPE}" = "meta" ]; then
        return 0 # Skip validations for "not real definition":
    fi

    # Perform several sanity checks here..
    for _required_field in  "DEF_NAME=${DEF_NAME}" \
                            "DEF_NAME_DEF_SUFFIX=${DEF_NAME}${DEF_SUFFIX}" \
                            "DEF_VERSION=${DEF_VERSION}" \
                            "DEF_SHA_OR_DEF_GIT_CHECKOUT=${DEF_SHA}${DEF_GIT_CHECKOUT}" \
                            "DEF_COMPLIANCE=${DEF_COMPLIANCE}" \
                            "DEF_SOURCE_PATH=${DEF_SOURCE_PATH}" \
                            "SYSTEM_VERSION=${SYSTEM_VERSION}" \
                            "OS_TRIPPLE=${OS_TRIPPLE}" \
                            "SYS_SPECIFIC_BINARY_REMOTE=${SYS_SPECIFIC_BINARY_REMOTE}";
        do
            unset _valid_checks
            for _check in   "DEF_NAME" \
                            "DEF_NAME_DEF_SUFFIX" \
                            "DEF_VERSION" \
                            "DEF_SHA_OR_DEF_GIT_CHECKOUT" \
                            "DEF_COMPLIANCE" \
                            "DEF_SOURCE_PATH" \
                            "SYSTEM_VERSION" \
                            "OS_TRIPPLE" \
                            "SYS_SPECIFIC_BINARY_REMOTE";
                do
                    if [ "${_check}=" = "${_required_field}" ] \
                    || [ "${_check}=." = "${_required_field}" ] \
                    || [ "${_check}=${DEFAULT_DEF_EXT}" = "${_required_field}" ]; then
                        error "ASSERTION FAILURE: Empty or invalid value in required field: $(diste "${_check}"). Failed definition of bundle: $(diste "${DEF_NAME}${DEF_SUFFIX}")"
                    else
                        # gather passed checks, but print it only once..
                        if [ -z "${_valid_checks}" ]; then
                            _valid_checks="${_check}"
                        else
                            _valid_checks="${_check}, ${_valid_checks}"
                        fi
                    fi
                done
        done

    if [ -z "${SYSTEM_DATASET}" ]; then
        error "ASSERTION FAILURE: No SYSTEM_DATASET is set! Either HOST=${HOST} or USER=${USER} is not set!"
    fi

    debug "Necessary values were validated: $(distd "${_valid_checks}")"
    unset _def _check _required_field _valid_checks
}


validate_reqs () {
    if [ "${SYSTEM_NAME}" != "Darwin" ]; then
        if [ -n "${CAP_SYS_BUILDHOST}" ]; then
            if [ -d "/usr/local/lib" ]; then
                # NOTE: tolerate libpkg under /usr/local/lib
                _unwanted_files="$(
                    ${FIND_BIN} \
                        /usr/local/lib \
                        -name '*.so' \
                        -or -name '*.o' \
                        -or -name '*.la' \
                        -or -name '*.a' \
                        -maxdepth 5 \
                        -type f \
                        2>/dev/null \
                            | ${GREP_BIN} -vE 'libpkg.(a|so)' \
                            | ${GREP_BIN} -c '' \
                            2>/dev/null \
                )"
                if [ "${_unwanted_files}" != "0" ]; then
                    warn "$(distw "/usr/local/lib") has been found with: $(distw "${_unwanted_files}+") $(distw "possibly unfriendly") libraries!"
                fi
            fi
        fi
        unset _unwanted_files _pstfix
    fi
    if [ -n "${DEBUGBUILD}" ]; then
        warn "Debug build is enabled."
    fi
}


validate_archive_sha1 () {
    _archive_name="${1}"
    if [ ! -f "${_archive_name}" ] \
    || [ -z "${_archive_name}" ]; then
         error "Specified empty $(diste archive_name), or file doesn't exist: $(diste "${_archive_name}")"
    fi
    # checking archive sha1 checksum
    if [ -e "${_archive_name}" ]; then
        _current_archive_sha1="$(file_checksum "${_archive_name}")"
        debug "current_archive_sha1: $(distd "${_current_archive_sha1}")"
    else
        error "No bundle archive found?"
    fi
    _current_sha_file="${_archive_name}${DEFAULT_CHKSUM_EXT}"
    _sha1_value="$(${CAT_BIN} "${_current_sha_file}" 2>/dev/null)"
    if [ ! -f "${_current_sha_file}" ] \
    || [ -z "${_sha1_value}" ]; then
        debug "No sha1 file available for archive, or sha1 value is empty! Removing local binary build(s) of: $(distd "${_archive_name}")"
        try "${RM_BIN} -f ${_archive_name} ${_current_sha_file}"
    fi
    if [ "${_current_archive_sha1}" != "${_sha1_value}" ]; then
        debug "Bundle archive checksum doesn't match (is: $(distd "${_current_archive_sha1}") but got: $(distd "${_sha1_value}"), removing binary builds and proceeding into build phase"
        try "${RM_BIN} -f ${_archive_name} ${_current_sha_file}"
    else
        permnote "Received software bundle: $(distn "${_archive_name##*/}")"
    fi
    unset _sha1_value _current_sha_file _current_archive_sha1 _archive_name
}


validate_def_suffix () {
    _arg1="${1%${DEFAULT_DEF_EXT}}" # <- cut extension
    _defname="$(lowercase "${2}")"
    _def_bundle_name="$(capitalize "${_defname}")"
    _defmatch="$(lowercase "${_arg1##*/}")" # <- basename

    if [ -n "${DEF_SUFFIX}" ]; then
        unset _defname _arg1 _arg2
        debug "validate_def_suffix(): Definition value of $(distd "DEF_SUFFIX=${DEF_SUFFIX}"). Final name: $(distd "${_def_bundle_name}${DEF_SUFFIX}")"
        return 0
    fi

    # handle case when DEF_SUFFIX was ommited => use definition file name difference as SUFFIX:
    if [ "${#_defname}" -gt "${#_defmatch}" ]; then
        _defdiff="$(difftext "${_defname}" "${_defmatch}")"
    fi
    if [ "${#_defmatch}" -gt "${#_defname}" ] \
    || [ "${#_defname}" = "${#_defmatch}" ]; then
        _defdiff="$(difftext "${_defmatch}" "${_defname}")"
    fi

    # assume, that length of a diff shouldn't match length of both specified names:
    if [ "$(( ${#_defdiff} + ${#_defdiff} ))" = "$(( ${#_defmatch} + ${#_defname}))" ]; then
        unset _defdiff # unset value, since we wish to ignore malformed diff
        debug "validate_def_suffix(): Concatenated values, setting diff to be empty for definition: $(distd "${_def_bundle_name}")."
    fi

    # finally if diff looks reasonable, let's guess DEF_SUFFIX:
    if [ -n "${_defdiff}" ]; then
        DEF_SUFFIX="${_defdiff}"
        debug "validate_def_suffix(): Inferred: $(distd "DEF_SUFFIX=${DEF_SUFFIX}") => $(distd "${_def_bundle_name}${DEF_SUFFIX}"), 1: $(distd "${_defmatch}"), 2: $(distd "${_defname}"), DIFF: '$(distd "${_defdiff}")'"
    fi

    unset _defname _defmatch _defdiff _arg1 _arg2 _def_bundle_name
}


validate_definition_disabled () {
    # check requirement for disabled state:
    for _def_disable_on in $(to_iter "${DEF_DISABLE_ON}"); do
        if [ "${SYSTEM_NAME}" = "${_def_disable_on}" ] \
        || [ "${SYSTEM_NAME}-${SYSTEM_VERSION}" = "${_def_disable_on}" ] \
        || [ "${SYSTEM_NAME}-${SYSTEM_VERSION%.*}" = "${_def_disable_on}" ] \
        || [ "${SYSTEM_NAME}-${SYSTEM_ARCH}" = "${_def_disable_on}" ] \
        || [ "${SYSTEM_NAME}-${SYSTEM_ARCH}-${SYSTEM_VERSION}" = "${_def_disable_on}" ] \
        || [ "${SYSTEM_NAME}-${SYSTEM_ARCH}-${SYSTEM_VERSION%.*}" = "${_def_disable_on}" ] \
        ; then
            debug "Disabled: $(distd "${_def_disable_on}") on $(distd "${SYSTEM_NAME}")"
            CURRENT_DEFINITION_DISABLED=YES
        fi
    done
    unset _def_disable_on
}


validate_util_availability () {
    _req_name="$(lowercase "${1}")"
    _req_bundle_name="$(capitalize "${_req_name}")"
    _req_util_indicator="${SOFIN_UTILS_DIR}/${_req_bundle_name}/${_req_name}${DEFAULT_INST_MARK_EXT}"
    if [ -f "${_req_util_indicator}" ]; then
        debug "Utility available for: $(distd "${_req_name}"). Skipping requirement build. Will attempt to use utility."
        CURRENT_DEFINITION_DISABLED=YES
    fi
    unset _req_name _req_bundle_name _req_util_indicator
}


validate_pie_on_exports () {
    _bundz="${*}"
    if [ -z "${_bundz}" ]; then
        error "At least single bundle name has to be specified for pie validation."
    fi
    if [ "YES" = "${CAP_SYS_HARDENED}" ]; then
        debug "Checking PIE on exports: $(distd "${_bundz}")"
        for _bun in $(to_iter "${_bundz}"); do
            _bun="${_bun%=*}"
            if [ -d "${SOFTWARE_DIR}/${_bun}/exports" ]; then
                _a_dir="${SOFTWARE_DIR}/${_bun}/exports"
            elif [ -d "${SOFTWARE_DIR}/${_bun}/exports-disabled" ]; then
                _a_dir="${SOFTWARE_DIR}/${_bun}/exports-disabled"
            else
                debug "No exports of bundle: $(distd "${_bun}"). PIE validation skipped."
                return 0
            fi
            _pie_indicator="${SOFTWARE_DIR}/${_bun}/$(lowercase "${_bun}")${DEFAULT_PIE_MARK_EXT}"
            if [ -f "${_pie_indicator}" ]; then
                debug "PIE exports were checked already for bundle: $(distd "${_bun}")"
                continue
            else
                for _bin in $(${FIND_BIN} "${_a_dir}" -mindepth 1 -maxdepth 1 -type l 2>/dev/null | ${XARGS_BIN} "${READLINK_BIN}" -f 2>/dev/null); do
                    try "${FILE_BIN} \"${_bin}\" | ${GREP_BIN} -F 'ELF'"
                    if [ "${?}" = "0" ]; then # it's ELF binary/library:
                        big_fat_warn () {
                            warn "Security - Exported ELF binary: $(distw "${_bin}"), is not a $(distw "${PIE_TYPE_ENTRY}") (not-PIE)!"
                            printf "SECURITY: ELF binary: '%b', is not a '%b' (not-PIE)!\n" "${_bin}" "${PIE_TYPE_ENTRY}" >> "${_pie_indicator}.warn"
                        }
                        try "${FILE_BIN} '${_bin}' | ${GREP_BIN} -F 'ELF' | ${EGREP_BIN} -F '${PIE_TYPE_ENTRY}'" \
                            || big_fat_warn
                    else
                        debug "Executable, but not an ELF: $(distd "${_bin}")"
                    fi
                done
                run "${TOUCH_BIN} '${_pie_indicator}'" \
                    && debug "PIE check done for bundle: $(distd "${_bun}")"
            fi
        done

    else
        debug "Nothing required."
    fi
    unset _bin _a_dir _pie_indicator _bun _bundz
}


validate_kern_loaded_dtrace () {
    if [ -n "${CAP_SYS_DTRACE}" ]; then
        case "${SYSTEM_NAME}" in
            FreeBSD)
                debug "Making sure dtrace kernel module is loaded"
                ${KLDSTAT_BIN} 2>/dev/null | ${GREP_BIN} -F 'dtraceall' >/dev/null 2>&1 \
                    || try "${KLDLOAD_BIN} dtraceall"
                ;;
        esac
    fi
}


validate_sys_limits () {
    # Limits for production CAP_SYS_HARDENED environment:
    _ulimit_core="0"
    _ulimit_nofile="6000"
    _ulimit_stackkb="131070"
    _ulimit_up_max_ps="512"

    if [ "YES" = "${CAP_SYS_WORKSTATION}" ]; then
        _ulimit_nofile="6000"
        _ulimit_stackkb="16384"
        _ulimit_up_max_ps="1024"
        debug "Initialized limits for Darwin workstation"
    fi

    ulimit -n "${_ulimit_nofile}" >/dev/null 2>&1 \
        || warn "Sofin has failed to set reasonable environment limit of open files: $(distw "${_ulimit_nofile}"). Local limit is: "$(ulimit -n 2>/dev/null)". Troubles may follow!"

    ulimit -s "${_ulimit_stackkb}" >/dev/null 2>&1 \
        || warn "Sofin has failed to set reasonable environment limit of stack (in kb) to value: $(distw "${_ulimit_stackkb}"). Local limit is: "$(ulimit -s 2>/dev/null)". Troubles may follow!"

    ulimit -c "${_ulimit_core}" >/dev/null 2>&1 \
        || warn "Sofin has failed to set core size limit to: $(distw "${_ulimit_core}"). Local limit is: "$(ulimit -c 2>/dev/null)".!"

    # try "ulimit -u ${_ulimit_up_max_ps}" \
    #     || warn "Sofin has failed to set reasonable environment limit of running processes to: $(distw "${_ulimit_up_max_ps}"). Local limit is: "$(ulimit -u 2>/dev/null)". Troubles may follow!"
    return 0
}


crash_if_mission_critical () {
    if [ -n "${DEF_CRITICAL}" ]; then
        error "Bundle: $(diste "${1}") is marked as $(diste "Mission-Critical") and cannot be destroyed automatically. It has to be done manually."
    fi
}

validate_bins_links () {
    _bundz="${*}"
    if [ -z "${_bundz}" ]; then
        error "At least single bundle name has to be specified."
    fi
    #Make sure LIBRARY_PATH is unset, else binaries without RUNPATH will report correct links on PREFIX/lib despite reporting them as not found later
    unset LD_LIBRARY_PATH
    unset DYLD_LIBRARY_PATH
    debug "Validating links on exports: $(distd "${_bundz}")"
    for _bun in $(to_iter "${_bundz}"); do
        _bun="$(capitalize_abs "${_bun%=*}")"
        if [ -d "${SOFTWARE_DIR}/${_bun}/exports" ]; then
            _a_dir="${SOFTWARE_DIR}/${_bun}/exports"
        elif [ -d "${SOFTWARE_DIR}/${_bun}/exports-disabled" ]; then
            _a_dir="${SOFTWARE_DIR}/${_bun}/exports-disabled"
        else
            debug "No exports of bundle: $(distd "${_bun}"). Link validation skipped."
            return 0
        fi

        for _bin in $(${FIND_BIN} "${_a_dir}" -mindepth 1 -maxdepth 1 -type l 2>/dev/null); do
            if ${FILE_BIN} -L "${_bin}" | ${CUT_BIN} -d' ' -f2- | ${GREP_BIN} -E '(text|script|statically)' >/dev/null 2>&1; then
                debug "$(distd "${_bin}") is statically linked or a script, skipping validation"
            elif ${FILE_BIN} -L "${_bin}" | ${CUT_BIN} -d' ' -f2- | ${GREP_BIN} -E '(LSB shared object|LSB pie executable|LSB executable|Mach-O 64-bit)' >/dev/null 2>&1; then
                if [ "${SYSTEM_NAME}" = "Darwin" ]; then
                        # _linked="$(${OTOOL_BIN} -L "${_bin}" | ${GREP_BIN} -Ev "(\s${SOFTWARE_DIR}/${_bun}(/|/bin/../)lib/)|(\s/usr/lib/)|(\s/lib/)|(\s/System/Library/Frameworks/)|(@rpath/)|([a-zA-Z]*dylib)"  2>/dev/null)"
                        # TODO: XXX: RPATH is a complicated thing on Darwin…
                        _linked="${_bin}:"
                else
                        _bin="$(${READLINK_BIN} -f ${_bin})"
                        _linked="$(${LDD_BIN} "${_bin}" 2>> ${LOG} | ${GREP_BIN} -Ev "( /usr/lib/)|( ${SOFTWARE_DIR}/${_bun}(/|/bin/../)lib/)|( /lib/)"  2>/dev/null)"
                fi

                if [ "${_linked}" != "${_bin}:" ]; then
                    error "Invalid links for binary: $(diste "${_bin}")! See: \n $(diste "${_linked}")"
                fi
            else
                error "$(diste "${_bin}") is not a proper executable or script!"
            fi
        done

        debug "OK"
    done

    unset _bundz _bun _a_dir _bin _linked
    return 0
}

validate_libs_links () {
    _bundz="${*}"
    if [ -z "${_bundz}" ]; then
        error "At least single bundle name has to be specified."
    fi
    debug "Validating libraries: $(distd "${_bundz}")"
    for _bun in $(to_iter "${_bundz}"); do
        _bun="$(capitalize_abs "${_bun%=*}")"
        if [ -d "${SOFTWARE_DIR}/${_bun}/lib" ]; then
            _a_dir="${SOFTWARE_DIR}/${_bun}/lib"
        else
            debug "Libraries dir not found, skipping"
        fi

        if [ "${SYSTEM_NAME}" = "Darwin" ]; then
            _libext="dylib"
        else
            _libext="so"
        fi

        for _lib in $(${FIND_BIN} "${_a_dir}" \( -name "*.${_libext}" -or -name "*.${_libext}.*" \) -mindepth 1 -type f 2>/dev/null); do
            if ${FILE_BIN} -L "${_lib}" | ${CUT_BIN} -d' ' -f2- | ${GREP_BIN} -E '(text|script|statically)' >/dev/null 2>&1; then
                debug "$(distd "${_lib}") is statically linked or a script, skipping validation"
            elif ${FILE_BIN} -L "${_lib}" | ${CUT_BIN} -d' ' -f2- | ${GREP_BIN} -E '(LSB shared object|Mach-O 64-bit)' >/dev/null 2>&1; then
                _libname="$(echo ${_lib} | ${AWK_BIN} -F/ '{print $NF}' | ${SED_BIN} -E 's/([^[:alnum:]])/\\\1/g')"
                if [ "${SYSTEM_NAME}" = "Darwin" ]; then
                    # _linked="$(${OTOOL_BIN} -L "${_lib}" | ${GREP_BIN} -Ev "(\s${SOFTWARE_DIR}/${_bun}(/|/bin/../)lib/)|(\s/usr/lib/)|(\s/lib/)|(\s/System/Library/Frameworks/)|(\s${_libname})|(\s@rpath)|(\s@executable_path)"  2>/dev/null)"
                    # TODO: XXX: RPATH is a complicated thing on Darwin…
                    _linked="${_lib}:"
                else
                    _lib="$(${READLINK_BIN} -f ${_lib})"
                    _linked="$(${LDD_BIN} "${_lib}" 2>> ${LOG} | ${GREP_BIN} -Ev "( /usr/lib/)|( ${SOFTWARE_DIR}/${_bun}(/|/bin/../)lib/)|( /lib/)|( ${_libname})"  2>/dev/null)"
                fi

                if [ "${_linked}" != "${_lib}:" ]; then
                    error "Invalid links for library: $(diste "${_lib}")! See: \n $(diste "${_linked}")"
                fi
            else
                error "$(diste "${_lib}") is not a proper library or script!"
            fi
        done

        debug "OK"
    done

    unset _bundz _bun _a_dir _lib _linked _libext _libname
    return 0
}

validate_sources () {
    if [ -n "${CAP_SYS_BUILDHOST}" ]; then
        if [ -z "${CURL_BIN}" ]; then
            error "Curl binary not found - required to run this validation"
        fi

        permnote "Validating sources for all definitions"
        _alldefs="$(${FIND_BIN} "${DEFINITIONS_DIR}" -mindepth 1 -maxdepth 1 -type f -name "*${DEFAULT_DEF_EXT}" 2>/dev/null)"

        for _def in $(to_iter "${_alldefs}"); do
            load_defaults
            . "${_def}"
            if [ "${DEF_TYPE}" = "meta" ] || [ "${_def}" = "${DEFINITIONS_DEFAULTS}" ]; then
                # Skip validations for "not real definition":
                continue
            elif [ -n "${DEF_GIT_MODE}" ] || [ -n "${DEF_GIT_CHECKOUT}" ]; then
                "${GIT_BIN}" ls-remote -h "${DEF_SOURCE_PATH}" >/dev/null 2>&1 \
                    || warn "Failed to access repository: $(distw "${DEF_SOURCE_PATH}") for $(distw "${_def}")"
            else
                _curlres="$("${CURL_BIN}" -s -o /dev/null -L -I -w "%{http_code}" "${DEF_SOURCE_PATH}")"
                if [ "0" != "${?}" ]; then
                    warn "Not an URL: $(distw "${DEF_SOURCE_PATH}") in $(distw "${_def}")"
                elif [ "${_curlres}" != "200" ]; then
                    warn "Response code $(distw "${_curlres}") for URL $(distw "${DEF_SOURCE_PATH}") in $(distw "${_def}")"
                fi
            fi
        done

        permnote "Done"
        load_defaults
        unset _alldefs _def _curlres
    else
        permnote "This is a buildhost-specific task, refusing to run on a production system"
    fi
}
