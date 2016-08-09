
build_bundle () {
    _bsbname="${1}"
    _bsbelement="${2}"
    _bsversion="${3}"
    if [ -z "${_bsbname}" ]; then
        error "First argument with $(diste "BundleName") is required!"
    fi
    if [ -z "${_bsbelement}" ]; then
        error "Second argument with $(diste "element-name") is required!"
    fi
    if [ -z "${_bsversion}" ]; then
        error "Third argument with $(diste "version-string") is required!"
    fi
    debug "build_bundle: $(distd "${_bsbname}"), should be in: $(distd "${SOFTWARE_DIR}${_bsbname}"), full-name: $(distd "${_bsbelement}")"
    if [ ! -d "${SOFTWARE_DIR}${_bsbname}" ]; then
        create_software_dir "${_bsbname}"
        create_software_bundle_archive "${_bsbname}" "${_bsbelement}" "${_bsversion}"
    else
        if [ ! -f "${FILE_CACHE_DIR}${_bsbelement}" ]; then
            debug "Found incomplete or damaged bundle file. Rebuilding: $(distd "${_bsbelement}")"
            try "${RM_BIN} -vf ${FILE_CACHE_DIR}${_bsbelement}"
            create_software_bundle_archive "${_bsbname}" "${_bsbelement}" "${_bsversion}"
        else
            debug "Found already existing bundle stream in file-cache: $(distd "${FILE_CACHE_DIR}${_bsbelement}")"

            # NOTE: Let's move old one, make a shasum difference, if different => overwrite
            try "${MV_BIN} -v ${FILE_CACHE_DIR}${_bsbelement} ${FILE_CACHE_DIR}${_bsbelement}.old ; ${MV_BIN} -v ${FILE_CACHE_DIR}${_bsbelement}${DEFAULT_CHKSUM_EXT} ${FILE_CACHE_DIR}${_bsbelement}${DEFAULT_CHKSUM_EXT}.old" && \
                debug "Old bundle stream, was temporarely moved."
            create_software_bundle_archive "${_bsbname}" "${_bsbelement}" "${_bsversion}"
            if [ -f "${FILE_CACHE_DIR}${_bsbelement}" ]; then
                _newsum="$(file_checksum "${FILE_CACHE_DIR}${_bsbelement}")"
                _oldsum="$(${CAT_BIN} "${FILE_CACHE_DIR}${_bsbelement}${DEFAULT_CHKSUM_EXT}.old" 2>/dev/null)"
                debug "Comparing shasum of most recent stream and one from previous stream. Old-sum: $(distd "${_oldsum}"), new-sum: $(distd "${_newsum}")"
                if [ "${_oldsum}" = "${_newsum}" ]; then
                    try "${MV_BIN} -fv ${FILE_CACHE_DIR}${_bsbelement}.old ${FILE_CACHE_DIR}${_bsbelement}.old ; ${MV_BIN} -fv ${FILE_CACHE_DIR}${_bsbelement}${DEFAULT_CHKSUM_EXT}.old ${FILE_CACHE_DIR}${_bsbelement}${DEFAULT_CHKSUM_EXT}" && \
                        debug "Checksums match! Upload unnecessary! Previous cache stream file was restored."
                else
                    try "${RM_BIN} -fv ${FILE_CACHE_DIR}${_bsbelement}.old ${FILE_CACHE_DIR}${_bsbelement}${DEFAULT_CHKSUM_EXT}.old" && \
                        debug "Checksum didn't match. New stream will be used to upload bundle stream. Previous cache stream file was removed."
                fi
            fi
        fi
    fi
    unset _bsbname _bsbelement
}


push_binbuilds () {
    _push_bundles=${*}
    if [ -z "${_push_bundles}" ]; then
        error "At least single argument with $(diste "BundleName") to push is required!"
    fi
    create_dirs
    for _pbelement in ${_push_bundles}; do
        _pblowercase_element="$(lowercase "${_pbelement}")"
        if [ -z "${_pblowercase_element}" ]; then
            error "Lowercase bundle name is empty!"
        fi
        _pbinstall_indicator_file="${SOFTWARE_DIR}${_pbelement}/${_pblowercase_element}${DEFAULT_INST_MARK_EXT}"
        _pbbversion_element="$(${CAT_BIN} "${_pbinstall_indicator_file}" 2>/dev/null)"
        if [ ! -f "${_pbinstall_indicator_file}" ]; then
            error "Bundle install indicator: $(diste "${_pbinstall_indicator_file}") doesn't exist!"
        fi
        if [ -n "${_pbelement}" -a \
             -d "${SOFTWARE_DIR}${_pbelement}" -a \
             -n "${_pbbversion_element}" ]; then
            debug "About to push: $(distd "${_pbelement}"), install-indicator: $(distd "${_pbinstall_indicator_file}"), soft-version: $(distd "${_pbbversion_element}")"
            push_to_all_mirrors "${_pbelement}" "${_pbbversion_element}"
        else
            error "Push validations failed for bundle: $(diste "${_pbelement}")! It might not be fully installed or broken."
        fi
    done
}


deploy_binbuild () {
    _dbbundles=${*}
    create_dirs
    load_defaults
    note "Requested to build and deploy bundle(s): $(distn "${_dbbundles}")"
    for _dbbundle in ${_dbbundles}; do
        USE_BINBUILD=NO
        build "${_dbbundle}"
    done
    push_binbuilds ${_dbbundles}
    note "Deployed successfully: $(distn "${_dbbundles}")"
    unset _dbbundles _dbbundle
}


rebuild_bundle () {
    create_dirs
    _a_dependency="$(lowercase "${1}")"
    if [ -z "${_a_dependency}" ]; then
        error "Missing second argument with library/software name."
    fi
    # go to definitions dir, and gather software list that include given _a_dependency:
    _alldefs_avail="$(${FIND_BIN} ${DEFINITIONS_DIR} -maxdepth 1 -type f -name "*${DEFAULT_DEF_EXT}" 2>/dev/null)"
    _those_to_rebuild=""
    for _dep in ${_alldefs_avail}; do
        load_defaults
        . "${_dep}"
        ${PRINTF_BIN} '%s\n' "${DEF_REQUIREMENTS}" 2>/dev/null | ${GREP_BIN} "${_a_dependency}" >/dev/null 2>&1
        if [ "${?}" = "0" ]; then
            _idep="$(${BASENAME_BIN} "${_dep}" 2>/dev/null)"
            _irawname="$(${PRINTF_BIN} '%s' "${_idep}" | ${SED_BIN} "s/${DEFAULT_DEF_EXT}//g" 2>/dev/null)"
            _an_def_nam="$(capitalize "${_irawname}")"
            _those_to_rebuild="${_an_def_nam} ${_those_to_rebuild}"
        fi
    done

    note "Will rebuild, wipe and push these bundles: $(distn "${_those_to_rebuild}")"
    for _reb_ap_bundle in ${_those_to_rebuild}; do
        if [ "${_reb_ap_bundle}" = "Git" -o "${_reb_ap_bundle}" = "Zsh" ]; then
            continue
        fi
        remove_bundles "${_reb_ap_bundle}"
        USE_BINBUILD=NO
        build "${_reb_ap_bundle}"
        USE_FORCE=YES
        wipe_remote_archives "${_reb_ap_bundle}"
        push_binbuilds "${_reb_ap_bundle}"
    done
    unset _reb_ap_bundle _those_to_rebuild _a_dependency _dep _alldefs_avail _idep _irawname _an_def_nam
}


fetch_binbuild () {
    _fbb_bundname="${1}"
    _bb_archive="${2}"
    if [ -n "${USE_BINBUILD}" ]; then
        debug "Binary build check was skipped since USE_BINBUILD has a value: $(distd ${USE_BINBUILD})"
    else
        if [ -z "${_fbb_bundname}" ]; then
            error "Cannot fetch binbuild! An empty $(diste "BunndleName") given!"
        fi
        if [ -z "${_bb_archive}" ]; then
            error "Cannot fetch binbuild! An empty $(diste "file-archive-name") given!"
        fi
        try "${MKDIR_BIN} -p ${FILE_CACHE_DIR}"
        # If sha1 of bundle file exists locally..
        if [ ! -e "${FILE_CACHE_DIR}${_bb_archive}${DEFAULT_CHKSUM_EXT}" ]; then
            try "${FETCH_BIN} -o ${FILE_CACHE_DIR}${_bb_archive}${DEFAULT_CHKSUM_EXT} ${FETCH_OPTS} '${MAIN_BINARY_REPOSITORY}${OS_TRIPPLE}/${_bb_archive}${DEFAULT_CHKSUM_EXT}'" || \
                try "${FETCH_BIN} -o ${FILE_CACHE_DIR}${_bb_archive}${DEFAULT_CHKSUM_EXT} ${FETCH_OPTS} '${MAIN_BINARY_REPOSITORY}${OS_TRIPPLE}/${_bb_archive}${DEFAULT_CHKSUM_EXT}'"
            if [ "${?}" = "0" ]; then
                try "${FETCH_BIN} -o ${FILE_CACHE_DIR}${_bb_archive} ${FETCH_OPTS} '${MAIN_BINARY_REPOSITORY}${OS_TRIPPLE}/${_bb_archive}'" || \
                    try "${FETCH_BIN} -o ${FILE_CACHE_DIR}${_bb_archive} ${FETCH_OPTS} '${MAIN_BINARY_REPOSITORY}${OS_TRIPPLE}/${_bb_archive}'" || \
                        try "${FETCH_BIN} -o ${FILE_CACHE_DIR}${_bb_archive} ${FETCH_OPTS} '${MAIN_BINARY_REPOSITORY}${OS_TRIPPLE}/${_bb_archive}'" || \
                            error "Failure fetching available binary build for: $(diste "${_bb_archive}"). Please check your network setup!"
            else
                note "No binary build file available: $(distn "${_bb_archive}")"
            fi
        fi

        debug "BB-archive: $(distd "${_bb_archive}"). Expecting binbuild to be available in: $(distd "${FILE_CACHE_DIR}${_bb_archive}")"
        if [ -e "${FILE_CACHE_DIR}${_bb_archive}" ]; then
            validate_archive_sha1 "${FILE_CACHE_DIR}${_bb_archive}"
            install_software_from_binbuild "${_bb_archive}" "${_fbb_bundname}"
        else
            debug "Binary build unavailable for bundle: $(distd "${_fbb_bundname}")"
        fi
    fi
    unset _fbb_bundname _fbb_bundname _bb_archive
}


build () {
    _build_list=${*}

    # Update definitions and perform more checks
    validate_reqs

    store_security_state
    disable_security_features

    debug "Sofin v$(distd ${SOFIN_VERSION}): New build started for bundles: $(distd ${_build_list})"
    PATH="${DEFAULT_PATH}"
    for _bund_name in ${_build_list}; do
        _specified="${_bund_name}" # store original value of user input
        _bund_name="$(lowercase "${_bund_name}")"
        load_defaults
        load_defs "${_bund_name}"
        if [ "${DEF_DISABLED_ON}" = "YES" ]; then
            _anm="$(capitalize "${_bund_name}")"
            warn "Bundle: $(distw "${_anm}") is disabled on: $(distw "${OS_TRIPPLE}")"
            destroy_software_dir "${_anm}"
        else
            for _req_name in ${DEFINITIONS_DIR}${_bund_name}${DEFAULT_DEF_EXT}; do
                unset DONT_BUILD_BUT_DO_EXPORTS
                debug "Reading definition: $(distd "${_req_name}")"
                load_defaults
                load_defs "${_req_name}"
                if [ -z "${DEF_REQUIREMENTS}" ]; then
                    debug "No app requirements"
                else
                    pretouch_logs "${DEF_REQUIREMENTS}"
                fi

                # Note: this acutally may break definitions like ImageMagick..
                #_bund_lcase="$(lowercase "${DEF_NAME}${DEF_POSTFIX}")"
                _bund_lcase="${DEF_NAME}${DEF_POSTFIX}"
                _bundl_name="$(capitalize "${_bund_lcase}")"
                DEF_NAME="${_bundl_name}"

                # if definition requires root privileges, throw an "exception":
                if [ -n "${DEF_REQUIRE_ROOT_ACCESS}" ]; then
                    if [ "${USER}" != "root" ]; then
                        error "Definition requires superuser priviledges: $(diste "${_bund_lcase}"). Installation aborted."
                    fi
                fi

                PREFIX="${SOFTWARE_DIR}${_bundl_name}"
                SERVICE_DIR="${SERVICES_DIR}${_bundl_name}"
                BUILD_NAMESUM="$(text_checksum "${_bund_lcase}-${DEF_VERSION}")"
                BUILD_DIR="${PREFIX}/${DEFAULT_SRC_EXT}${BUILD_NAMESUM}"

                # These values has to be exported because external build mechanisms
                # has to be able to reach these values to find dependencies and utilities
                export PATH="${PREFIX}/bin:${PREFIX}/sbin:${DEFAULT_PATH}"
                export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig"
                export PREFIX

                # NOTE: standalone definition has own SERVICES_DIR/Bundlename/ prefix
                if [ -n "${DEF_STANDALONE}" ]; then
                    create_service_dir "${_bundl_name}"
                fi

                try "${MKDIR_BIN} -p ${FILE_CACHE_DIR}"
                _an_archive="${_bundl_name}-${DEF_VERSION}-${OS_TRIPPLE}${DEFAULT_ARCHIVE_EXT}"
                _installed_indicator="${PREFIX}/${_bund_lcase}${DEFAULT_INST_MARK_EXT}"
                if [ ! -e "${_installed_indicator}" ]; then
                    fetch_binbuild "${_bundl_name}" "${_an_archive}"
                else
                    _already_installed_version="$(${CAT_BIN} ${_installed_indicator} 2>/dev/null)"
                    if [ "${DEF_VERSION}" = "${_already_installed_version}" ]; then
                        debug "$(distd "${_bund_lcase}") bundle is installed with version: $(distd "${_already_installed_version}")"
                    else
                        warn "$(distw "${_bund_lcase}") bundle is installed with version: $(distw "${_already_installed_version}"), different from defined: $(distw "${DEF_VERSION}")"
                    fi
                    DONT_BUILD_BUT_DO_EXPORTS=YES
                    unset _already_installed_version
                fi

                # NOTE: It's necessary to create build dir *after* binbuild check (which may create dataset itself)
                create_builddir "${_bundl_name}" "${BUILD_NAMESUM}"

                if [ -z "${DONT_BUILD_BUT_DO_EXPORTS}" ]; then
                    if [ -z "${DEF_REQUIREMENTS}" ]; then
                        note "Installing: $(distn "${DEF_FULL_NAME}"), version: $(distn "${DEF_VERSION}")"
                    else
                        note "Installing: $(distn "${DEF_FULL_NAME}"), version: $(distn "${DEF_VERSION}"), with requirements: $(distn "${DEF_REQUIREMENTS}")"
                    fi
                    _req_amount="$(${PRINTF_BIN} '%s\n' "${DEF_REQUIREMENTS}" | ${WC_BIN} -w 2>/dev/null | ${AWK_BIN} '{print $1;}' 2>/dev/null)"
                    _req_amount="$(${PRINTF_BIN} '%s\n' "${_req_amount} + 1" | ${BC_BIN} 2>/dev/null)"
                    _req_all="${_req_amount}"
                    for _req in ${DEF_REQUIREMENTS}; do
                        if [ -n "${DEF_USER_INFO}" ]; then
                            warn "${DEF_USER_INFO}"
                        fi
                        if [ -z "${_req}" ]; then
                            note "No additional requirements defined"
                            break
                        else
                            note "  $(distn "${_req}") ($(distn "${_req_amount}") of $(distn "${_req_all}") remaining)"
                            if [ ! -f "${PREFIX}/${_req}${DEFAULT_INST_MARK_EXT}" ]; then
                                CHANGED=YES
                                process_flat "${_req}" "${PREFIX}" "${_bund_name}"
                            fi
                        fi
                        _req_amount="$(${PRINTF_BIN} '%s\n' "${_req_amount} - 1" | ${BC_BIN} 2>/dev/null)"
                    done
                fi

                if [ -z "${DONT_BUILD_BUT_DO_EXPORTS}" ]; then
                    if [ -e "${PREFIX}/${_bund_lcase}${DEFAULT_INST_MARK_EXT}" ]; then
                        if [ "${CHANGED}" = "YES" ]; then
                            note "  $(distn "${_bund_lcase}") ($(distn 1) of $(distn "${_req_all}"))"
                            note "   ${NOTE_CHAR} Definition dependencies has changed. Rebuilding: $(distn "${_bund_lcase}")"
                            process_flat "${_bund_lcase}" "${PREFIX}" "${_bund_name}"
                            unset CHANGED
                            mark_installed "${DEF_NAME}${DEF_POSTFIX}" "${DEF_VERSION}"
                            show_done "${DEF_NAME}${DEF_POSTFIX}"
                        else
                            note "  $(distn "${_bund_lcase}") ($(distn 1) of $(distn "${_req_all}"))"
                            show_done "${DEF_NAME}${DEF_POSTFIX}"
                            debug "${SUCCESS_CHAR} $(distd "${_bund_lcase}") current: $(distd "${_version_element}"), definition: [$(distd "${DEF_VERSION}")] Ok."
                        fi
                    else
                        note "  $(distn "${_bund_lcase}") ($(distn 1) of $(distn "${_req_all}"))"
                        process_flat "${_bund_lcase}" "${PREFIX}" "${_bund_name}"
                        mark_installed "${DEF_NAME}${DEF_POSTFIX}" "${DEF_VERSION}"
                        note "$(distn "${SUCCESS_CHAR}") $(distn "${_bund_lcase}") [$(distn "${DEF_VERSION}")]"
                    fi
                fi

                strip_bundle "${_bund_lcase}"
                export_binaries "${_bund_lcase}"
                after_export_callback
            done

            clean_useless
            create_apple_bundle_if_necessary
        fi

        finalize_afterbuild "${_bund_name}"
    done

    validate_pie_on_exports "${_build_list}"

    note "Build successfull: $(distn "${_build_list}")"
    unset _build_list _bund_lcase _req_all _req

    env_reset
}


dump_debug_info () {
    # TODO: add DEF_ insight
    debug "-------------- PRE CONFIGURE SETTINGS DUMP --------------"
    debug "CPUS (used): $(distd "${CPUS}")"
    debug "ALL_CPUS: $(distd "${ALL_CPUS}")"
    debug "MAKE_OPTS: $(distd "${MAKE_OPTS}")"
    debug "FETCH_OPTS: $(distd "${FETCH_OPTS}")"
    debug "PREFIX: $(distd "${PREFIX}")"
    debug "SERVICE_DIR: $(distd "${SERVICE_DIR}")"
    debug "CURRENT_DIR: $(distd $(${PWD_BIN} 2>/dev/null))"
    debug "BUILD_NAMESUM: $(distd "${BUILD_NAMESUM}")"
    debug "BUILD_DIR: $(distd "${BUILD_DIR}")"
    debug "PATH: $(distd "${PATH}")"
    debug "CXXFLAGS: $(distd "${CXXFLAGS}")"
    debug "CFLAGS: $(distd "${CFLAGS}")"
    debug "LDFLAGS: $(distd "${LDFLAGS}")"
    debug "CC: $(distd "${CC}")"
    debug "CXX: $(distd "${CXX}")"
    debug "CPP: $(distd "${CPP}")"
    debug "LD: $(distd "${LD}")"
    debug "NM: $(distd "${NM}")"
    debug "RANLIB: $(distd "${RANLIB}")"
    debug "AR: $(distd "${AR}")"
    debug "AS: $(distd "${AS}")"
    if [ "Darwin" = "${SYSTEM_NAME}" ]; then
        debug "DYLD_LIBRARY_PATH: $(distd "${DYLD_LIBRARY_PATH}")"
    else
        debug "LD_LIBRARY_PATH: $(distd "${LD_LIBRARY_PATH}")"
    fi
    debug "-------------- PRE CONFIGURE SETTINGS DUMP ENDS ---------"
}


process_flat () {
    _app_param="${1}"
    _prefix="${2}"
    _bundlnm="${3}"
    if [ -z "${_app_param}" ]; then
        error "First argument with $(diste "requirement-name") is required!"
    fi
    if [ -z "${_prefix}" ]; then
        error "Second argument with $(diste "/Software/PrefixDir") is required!"
    fi
    if [ -z "${_bundlnm}" ]; then
        error "Third argument with $(diste "BundleName") is required!"
    fi
    _req_definition="${DEFINITIONS_DIR}$(lowercase "${_app_param}")${DEFAULT_DEF_EXT}"
    if [ ! -e "${_req_definition}" ]; then
        error "Cannot read definition file: $(diste "${_req_definition}")!"
    fi
    _req_defname="$(${PRINTF_BIN} '%s\n' "$(${BASENAME_BIN} "${_req_definition}" 2>/dev/null)" | ${SED_BIN} -e 's/\..*$//g' 2>/dev/null)"
    debug "Bundle: $(distd "${_bundlnm}"), requirement: $(distd "${_app_param}"), PREFIX: $(distd "${_prefix}") file: $(distd "${_req_definition}"), req-name: $(distd "${_req_defname}")"

    load_defaults
    load_defs "${_req_definition}"

    compiler_setup
    dump_debug_info

    PATH="${_prefix}/bin:${_prefix}/sbin:${DEFAULT_PATH}"
    if [ -z "${DEF_DISABLED_ON}" ]; then
        if [ "${DEF_TYPE}" = "meta" ]; then
            note "   ${NOTE_CHAR2} Meta bundle detected."
        else
            _cwd="$(${PWD_BIN} 2>/dev/null)"
            if [ -n "${BUILD_DIR}" -a \
                 -n "${BUILD_NAMESUM}" ]; then
                cd "${BUILD_DIR}"
                if [ -z "${DEF_GIT_MODE}" ]; then # Standard "fetch source archive" method
                    _base="$(${BASENAME_BIN} "${DEF_SOURCE_PATH}" 2>/dev/null)"
                    debug "DEF_SOURCE_PATH: $(distd "${DEF_SOURCE_PATH}") base: $(distd "${_base}")"
                    _dest_file="${FILE_CACHE_DIR}${_base}"
                    # TODO: implement auto picking fetch method based on DEF_SOURCE_PATH contents
                    if [ ! -e "${_dest_file}" ]; then
                        retry "${FETCH_BIN} -o ${_dest_file} ${FETCH_OPTS} '${DEF_SOURCE_PATH}'" || \
                            error "Failed to fetch source: $(diste "${DEF_SOURCE_PATH}")"
                        note "   ${NOTE_CHAR} Source fetched: $(distn "${_base}")"
                    fi
                    debug "Build root: $(distd "${BUILD_DIR}"), file: $(distd "${_dest_file}")"
                    if [ -z "${DEF_SHA}" ]; then
                        error "Missing SHA sum for source: $(diste "${_dest_file}")!"
                    else
                        _a_file_checksum="$(file_checksum "${_dest_file}")"
                        if [ "${_a_file_checksum}" = "${DEF_SHA}" ]; then
                            debug "Source checksum is fine"
                        else
                            warn "${WARN_CHAR} Source checksum mismatch: $(distw "${_a_file_checksum}") vs $(distw "${DEF_SHA}")"
                            _bname="$(${BASENAME_BIN} "${_dest_file}" 2>/dev/null)"
                            try "${RM_BIN} -vf ${_dest_file}" && \
                                warn "${WARN_CHAR} Removed corrupted cache file: $(distw "${_bname}") and retrying.."
                            process_flat "${_app_param}" "${_prefix}" "${_bundlnm}"
                        fi
                        unset _bname _a_file_checksum
                    fi

                    note "   ${NOTE_CHAR} Unpacking source of: $(distn "${DEF_NAME}${DEF_POSTFIX}")"
                    debug "Build dir: $(distd "${BUILD_DIR}")"
                    try "${TAR_BIN} -xf ${_dest_file} --directory ${BUILD_DIR}" || \
                        try "${TAR_BIN} -xjf ${_dest_file} --directory ${BUILD_DIR}" || \
                            run "${TAR_BIN} -xJf ${_dest_file} --directory ${BUILD_DIR}"
                else
                    # git method:
                    # .cache/git-cache => git bare repos
                    # NOTE: if DEF_GIT_CHECKOUT is unset, use DEF_VERSION:
                    clone_or_fetch_git_bare_repo "${DEF_SOURCE_PATH}" "${DEF_NAME}${DEF_POSTFIX}-master" "${DEF_GIT_CHECKOUT:-${DEF_VERSION}}" "${BUILD_DIR}"
                fi

                unset _fd
                _prm_nolib="$(${PRINTF_BIN} '%s\n' "${_app_param}" | ${SED_BIN} 's/lib//' 2>/dev/null)"
                _prm_no_undrlne_and_minus="$(${PRINTF_BIN} '%s\n' "${_app_param}" | ${SED_BIN} 's/[-_].*$//' 2>/dev/null)"
                debug "Requirement: ${_app_param} short: ${_prm_nolib}, nafter-: ${_prm_no_undrlne_and_minus}, DEF_NAME: ${DEF_NAME}, BUILD_DIR: ${BUILD_DIR}"
                # NOTE: patterns sorted by safety
                for _pati in    "*${_app_param}*${DEF_VERSION}" \
                                "*${_prm_no_undrlne_and_minus}*${DEF_VERSION}" \
                                "*${_prm_nolib}*${DEF_VERSION}" \
                                "*${DEF_NAME}*${DEF_VERSION}" \
                                "*${_app_param}*" \
                                "*${_prm_no_undrlne_and_minus}*" \
                                "*${_prm_nolib}*" \
                                "*${DEF_NAME}*";
                do
                    _fd="$(${FIND_BIN} "${BUILD_DIR}" -maxdepth 1 -mindepth 1 -type d -iname "${_pati}" 2>/dev/null | ${HEAD_BIN} -n1 2>/dev/null)"
                    if [ -n "${_fd}" ]; then
                        debug "Found build dir: $(distd "${_fd}"), for definition: $(distd "${DEF_NAME}")"
                        break
                    fi
                done
                if [ -z "${_fd}" ]; then
                    # NOTE: Handle one more case - inherited definitions, and there might be several of these..
                    # TODO: add support for recursive check through inherited definitions
                    # XXX: hardcoded name of function inherit() - which might be used in any definition file:
                    _inherited="$(${GREP_BIN} 'inherit' "${_req_definition}" 2>/dev/null | ${SED_BIN} 's/inherit[ ]*//g' 2>/dev/null)"
                    if [ -z "${_inherited}" ]; then
                        error "No source dir found for definition: $(diste "${_app_param}")?"
                    else
                        for _inh in ${_inherited}; do
                            debug "Trying inherited value: $(distd "${_inh}")"
                            _fd="$(${FIND_BIN} "${BUILD_DIR}" -maxdepth 1 -mindepth 1 -type d -iname "*${_inh}*${DEF_VERSION}*" 2>/dev/null | ${HEAD_BIN} -n1 2>/dev/null)"
                            if [ -n "${_fd}" ]; then
                                debug "Found inherited build dir: $(distd "${_fd}"), for definition: $(distd "${DEF_NAME}")"
                                break
                            fi
                        done
                        # If nothing helps..
                        if [ -z "${_fd}" ]; then
                            error "No inherited source dir found for definition: $(diste "${_app_param}")?"
                        fi
                    fi
                fi
                cd "${_fd}"

                # Handle DEF_BUILD_DIR_POSTFIX here
                if [ -n "${_fd}/${DEF_BUILD_DIR_POSTFIX}" ]; then
                    try "${MKDIR_BIN} -p ${_fd}/${DEF_BUILD_DIR_POSTFIX}"
                    cd "${_fd}/${DEF_BUILD_DIR_POSTFIX}"
                fi
                _pwd="$(${PWD_BIN} 2>/dev/null)"
                debug "Switched to build dir root: $(distd "${_pwd}")"

                # if [ -n "${DEF_GIT_CHECKOUT}" -a \
                #      "master" != "${DEF_GIT_CHECKOUT}" ]; then
                #     debug "   ${NOTE_CHAR} Definition branch: $(distn "${DEF_GIT_CHECKOUT}")"
                #     _current_branch="$(${GIT_BIN} rev-parse --abbrev-ref HEAD 2>/dev/null)"
                #     if [ "${_current_branch}" != "${DEF_GIT_CHECKOUT}" ]; then
                #         try "${GIT_BIN} checkout ${DEFAULT_GIT_OPTS} -b ${DEF_GIT_CHECKOUT}"
                #     fi
                #     try "${GIT_BIN} checkout ${DEFAULT_GIT_OPTS} ${DEF_GIT_CHECKOUT}"
                #     unset _current_branch
                # fi

                after_unpack_callback

                apply_definition_patches "${DEF_NAME}${DEF_POSTFIX}"
                after_patch_callback

                note "   ${NOTE_CHAR} Configuring: $(distn "${_app_param}"), version: $(distn "${DEF_VERSION}")"
                case "${DEF_CONFIGURE}" in

                    ignore)
                        note "   ${NOTE_CHAR} Configuration skipped for definition: $(distn "${_app_param}")"
                        ;;

                    no-conf)
                        note "   ${NOTE_CHAR} No configuration for definition: $(distn "${_app_param}")"
                        DEF_MAKE_METHOD="${DEF_MAKE_METHOD} PREFIX=${_prefix} CFLAGS='${CFLAGS}' CXXFLAGS='${CXXFLAGS}' LDFLAGS='${LDFLAGS}'"
                        DEF_INSTALL_METHOD="${DEF_INSTALL_METHOD} PREFIX=${_prefix} CFLAGS='${CFLAGS}' CXXFLAGS='${CXXFLAGS}' LDFLAGS='${LDFLAGS}'"
                        ;;

                    binary)
                        note "   ${NOTE_CHAR} Prebuilt definition of: $(distn "${_app_param}")"
                        DEF_MAKE_METHOD="true"
                        DEF_INSTALL_METHOD="true"
                        ;;

                    posix)
                        try "./configure -prefix ${_prefix} -cc '${C_COMPILER_NAME} ${CFLAGS}' -libs '-L${PREFIX}/lib ${LDFLAGS}' -mandir ${PREFIX}/share/man -libdir ${PREFIX}/lib -aspp '${C_COMPILER_NAME} ${CFLAGS} -c' ${DEF_CONFIGURE_ARGS}" || \
                        try "./configure -prefix ${_prefix} -cc '${C_COMPILER_NAME} ${CFLAGS}' -libs '-L${PREFIX}/lib ${LDFLAGS}' -libdir ${PREFIX}/lib -aspp '${C_COMPILER_NAME} ${CFLAGS} -c' ${DEF_CONFIGURE_ARGS}" || \
                        run "./configure -prefix ${_prefix} -cc '${C_COMPILER_NAME} ${CFLAGS}' -libs '-L${PREFIX}/lib ${LDFLAGS}' -aspp '${C_COMPILER_NAME} ${CFLAGS} -c' ${DEF_CONFIGURE_ARGS}"
                        ;;

                    cmake)
                        run "${DEF_CONFIGURE} ${DEF_CMAKE_BUILD_DIR} -LH -DCMAKE_INSTALL_RPATH=\"${_prefix}/lib;${_prefix}/libexec\" -DCMAKE_INSTALL_PREFIX=${_prefix} -DCMAKE_BUILD_TYPE=Release -DSYSCONFDIR=${SERVICE_DIR}/etc -DMAN_INSTALLDIR=${_prefix}/share/man -DDOCDIR=${_prefix}/share/doc -DJOB_POOL_COMPILE=${CPUS} -DJOB_POOL_LINK=${CPUS} -DCMAKE_C_FLAGS=\"${CFLAGS}\" -DCMAKE_CXX_FLAGS=\"${CXXFLAGS}\" ${DEF_CONFIGURE_ARGS}"
                        ;;

                    *)
                        unset _pic_optional
                        if [ "${SYSTEM_NAME}" != "Darwin" ]; then
                            _pic_optional="--with-pic"
                        fi
                        _addon="CFLAGS='${CFLAGS}' CXXFLAGS='${CXXFLAGS}' LDFLAGS='${LDFLAGS}'"
                        if [ "${SYSTEM_NAME}" = "Linux" ]; then
                            # NOTE: No /Services feature implemented for Linux.
                            ${PRINTF_BIN} '%s\n' "${DEF_CONFIGURE}" | ${GREP_BIN} "configure" >/dev/null 2>&1
                            if [ "${?}" = "0" ]; then
                                # NOTE: by defaultautoconf configure accepts influencing variables as configure script params
                                try "${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix} ${_pic_optional} ${_addon}" || \
                                try "${_addon} ${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix} ${_pic_optional}" || \
                                try "${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix} ${_addon}" || \
                                run "${_addon} ${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix}"
                            else
                                try "${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix} ${_addon}" || \
                                try "${_addon} ${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix}" || \
                                try "${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS} ${_addon}" || \
                                run "${_addon} ${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS}" # Trust definition
                            fi
                        else
                            # do a simple check for "configure" in DEF_CONFIGURE definition
                            # this way we can tell if we want to put configure options as params
                            ${PRINTF_BIN} '%s\n' "${DEF_CONFIGURE}" | ${GREP_BIN} "configure" >/dev/null 2>&1
                            if [ "${?}" = "0" ]; then
                                # TODO: add --docdir=${_prefix}/docs
                                # NOTE: By default try to configure software with these options:
                                #   --sysconfdir=${SERVICE_DIR}/etc
                                #   --localstatedir=${SERVICE_DIR}/var
                                #   --runstatedir=${SERVICE_DIR}/run
                                #   --with-pic
                                # OPTIMIZE: TODO: XXX: use ./configure --help | grep option to
                                #      build configure options quickly
                                try "${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix} --sysconfdir=${SERVICE_DIR}/etc --localstatedir=${SERVICE_DIR}/var --runstatedir=${SERVICE_DIR}/run ${_pic_optional} ${_addon}" || \
                                try "${_addon} ${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix} --sysconfdir=${SERVICE_DIR}/etc --localstatedir=${SERVICE_DIR}/var --runstatedir=${SERVICE_DIR}/run ${_pic_optional}" || \
                                try "${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix} --sysconfdir=${SERVICE_DIR}/etc --localstatedir=${SERVICE_DIR}/var ${_pic_optional} ${_addon}" || \
                                try "${_addon} ${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix} --sysconfdir=${SERVICE_DIR}/etc --localstatedir=${SERVICE_DIR}/var ${_pic_optional}" || \
                                try "${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix} --sysconfdir=${SERVICE_DIR}/etc --localstatedir=${SERVICE_DIR}/var ${_addon}" || \
                                try "${_addon} ${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix} --sysconfdir=${SERVICE_DIR}/etc --localstatedir=${SERVICE_DIR}/var" || \
                                try "${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix} --sysconfdir=${SERVICE_DIR}/etc ${_pic_optional} ${_addon}" || \
                                try "${_addon} ${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix} --sysconfdir=${SERVICE_DIR}/etc ${_pic_optional}" || \
                                try "${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix} --sysconfdir=${SERVICE_DIR}/etc ${_addon}" || \
                                try "${_addon} ${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix} --sysconfdir=${SERVICE_DIR}/etc" || \
                                try "${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix} ${_pic_optional} ${_addon}" || \
                                try "${_addon} ${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix} ${_pic_optional}" || \
                                try "${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix} ${_addon}" || \
                                run "${_addon} ${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix}" # last two - only as a fallback

                            else # fallback again:
                                # NOTE: First - try to specify GNU prefix,
                                # then trust prefix given in software definition.
                                try "${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix} ${_addon}" || \
                                try "${_addon} ${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix}" || \
                                try "${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS} ${_addon}" || \
                                run "${_addon} ${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS}"
                            fi
                        fi
                        unset _addon
                        ;;

                esac

                after_configure_callback
            else
                error "These values cannot be empty: BUILD_DIR, BUILD_NAMESUM"
            fi

            # and common part between normal and continue modes:
            note "   ${NOTE_CHAR} Building requirement: $(distn "${_app_param}")"
            try "${DEF_MAKE_METHOD}" || \
            run "${DEF_MAKE_METHOD}"
            after_make_callback

            # OTE: after successful make, invoke "make test" by default:
            note "   ${NOTE_CHAR} Testing requirement: $(distn "${_app_param}")"
            run "${DEF_TEST_METHOD}"
            after_test_callback

            debug "Cleaning man dir from previous dependencies, we want to install man pages that belong to LAST requirement which is app bundle itself"
            for place in man share/man share/info share/doc share/docs; do
                if [ -e "${_prefix}/${place}" ]; then
                    try "${FIND_BIN} ${_prefix}/${place} -delete"
                fi
            done

            note "   ${NOTE_CHAR} Installing requirement: $(distn "${_app_param}")"
            run "${DEF_INSTALL_METHOD}"
            after_install_callback

            run "${PRINTF_BIN} '%s' \"${DEF_VERSION}\" > ${_prefix}/${_app_param}${DEFAULT_INST_MARK_EXT}" && \
                debug "Stored version: $(distd "${DEF_VERSION}") of software: $(distd "${DEF_NAME}") installed in: $(distd "${_prefix}")"
            cd "${_cwd}" 2>/dev/null
            unset _cwd
        fi
    else
        note "   ${WARN_CHAR} Requirement: $(distn "${_req_defname}") is provided by base system."
        if [ ! -d "${_prefix}" ]; then # case when disabled requirement is first on list of dependencies
            create_software_dir "$(${BASENAME_BIN} "${_prefix}" 2>/dev/null)"
        fi
        _dis_def="${_prefix}/${_req_defname}${DEFAULT_INST_MARK_EXT}"
        debug "Disabled requirement: $(distd "${_req_defname}"), writing '${DEFAULT_REQ_OS_PROVIDED}' to: $(distd "${_dis_def}")"
        run "${PRINTF_BIN} '%s' \"${DEFAULT_REQ_OS_PROVIDED}\" > ${_dis_def}"
    fi
    unset _current_branch _dis_def _req_defname _app_param _prefix _bundlnm

    # TODO: reset env here?
}
