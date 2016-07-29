
build_bundle () {
    _bsbname="${1}"
    _bsbelement="${2}"
    _bsversion="${3}"
    if [ -z "${_bsbname}" ]; then
        error "First argument with $(distinct e "BundleName") is required!"
    fi
    if [ -z "${_bsbelement}" ]; then
        error "Second argument with $(distinct e "element-name") is required!"
    fi
    if [ -z "${_bsversion}" ]; then
        error "Third argument with $(distinct e "version-string") is required!"
    fi
    debug "build_bundle: $(distinct d "${_bsbname}"), should be in: $(distinct d "${SOFTWARE_DIR}${_bsbname}"), full-name: $(distinct d "${_bsbelement}")"
    if [ ! -d "${SOFTWARE_DIR}${_bsbname}" ]; then
        create_software_dir "${_bsbname}"
        create_software_bundle_archive "${_bsbname}" "${_bsbelement}" "${_bsversion}" && \
            note "Archived bundle: $(distinct n "${_bsbelement}") ready to deploy" && \
                return
        error "Failed to create bundle archives for: $(distinct e "${_bsbelement}")"
    else
        if [ ! -f "${FILE_CACHE_DIR}${_bsbelement}" ]; then
            debug "Found incomplete or damaged bundle file. Rebuilding: $(distinct d "${_bsbelement}")"
            try "${RM_BIN} -vf ${FILE_CACHE_DIR}${_bsbelement}"
            create_software_bundle_archive "${_bsbname}" "${_bsbelement}" "${_bsversion}" && \
                note "Archived bundle: $(distinct n "${_bsbelement}") ready to deploy"
        else
            note "Archived bundle: $(distinct n "${_bsbelement}") already exists, and will be reused to deploy"
        fi
    fi
    unset _bsbname _bsbelement
}


push_binbuilds () {
    _push_bundles="${*}"
    if [ -z "${_push_bundles}" ]; then
        error "At least single argument with $(distinct e "BundleName") to push is required!"
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
            error "Missing install indicator: $(distinct e "${_pbinstall_indicator_file}"). You can't push a binary build of uncomplete build!"
        fi
        debug "About to push: $(distinct d "${_pbelement}"), install-indicator: $(distinct d "${_pbinstall_indicator_file}"), soft-version: $(distinct d "${_pbbversion_element}")"
        if [ -n "${_pbelement}" -a \
             -d "${SOFTWARE_DIR}${_pbelement}" -a \
             -n "${_pbbversion_element}" ]; then
            push_to_all_mirrors "${_pbelement}" "${_pbbversion_element}"
        else
            error "Push validations failed for bundle: $(distinct e "${_pbelement}")! It might not be fully installed or broken."
        fi
    done
}


deploy_binbuild () {
    _dbbundles=${*}
    create_dirs
    load_defaults
    note "Requested to build and deploy bundle(s): $(distinct n "${_dbbundles}")"
    for _dbbundle in ${_dbbundles}; do
        USE_BINBUILD=NO
        build "${_dbbundle}"
    done
    push_binbuilds ${_dbbundles}
    note "Deployed successfully: $(distinct n "${_dbbundles}")"
    note "$(fill)"
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
        echo "${DEF_REQUIREMENTS}" | ${GREP_BIN} "${_a_dependency}" >/dev/null 2>&1
        if [ "$?" = "0" ]; then
            _idep="$(${BASENAME_BIN} "${_dep}" 2>/dev/null)"
            _irawname="$(${PRINTF_BIN} "${_idep}" | ${SED_BIN} "s/${DEFAULT_DEF_EXT}//g" 2>/dev/null)"
            _an_def_nam="$(capitalize "${_irawname}")"
            _those_to_rebuild="${_an_def_nam} ${_those_to_rebuild}"
        fi
    done

    note "Will rebuild, wipe and push these bundles: $(distinct n ${_those_to_rebuild})"
    for _reb_ap_bundle in ${_those_to_rebuild}; do
        if [ "${_reb_ap_bundle}" = "Git" -o "${_reb_ap_bundle}" = "Zsh" ]; then
            continue
        fi
        remove_bundles "${_reb_ap_bundle}"
        USE_BINBUILD=NO
        build "${_reb_ap_bundle}"
        USE_FORCE=YES
        wipe_remote_archives ${_reb_ap_bundle}
        push_binbuilds ${_reb_ap_bundle}
    done
    unset _reb_ap_bundle _those_to_rebuild _a_dependency _dep _alldefs_avail _idep _irawname _an_def_nam
}


fetch_binbuild () {
    _bbfull_name="${1}"
    _bbaname="${2}"
    _bb_archive="${3}"
    _bb_ver="${4}"
    if [ -n "${USE_BINBUILD}" ]; then
        debug "Binary build check was skipped"
    else
        _bbaname="$(lowercase "${_bbaname}")"
        if [ -z "${_bbaname}" ]; then
            error "Cannot fetch binbuild! An empty definition name given!"
        fi
        if [ -z "${_bb_archive}" ]; then
            error "Cannot fetch binbuild! An empty archive name given!"
        fi
        _bbfull_name="$(capitalize "${_bbfull_name}")"
        if [ ! -e "${FILE_CACHE_DIR}${_bb_archive}" ]; then
            try "${MKDIR_BIN} -p ${FILE_CACHE_DIR}"
            try "${FETCH_BIN} -o ${FILE_CACHE_DIR}${_bb_archive} ${FETCH_OPTS} '${MAIN_BINARY_REPOSITORY}${OS_TRIPPLE}/${_bb_archive}${DEFAULT_CHKSUM_EXT}'" || \
                try "${FETCH_BIN} -o ${FILE_CACHE_DIR}${_bb_archive} ${FETCH_OPTS} '${MAIN_BINARY_REPOSITORY}${OS_TRIPPLE}/${_bb_archive}${DEFAULT_CHKSUM_EXT}'"
            if [ "$?" = "0" ]; then
                try "${FETCH_BIN} -o ${FILE_CACHE_DIR}${_bb_archive} ${FETCH_OPTS} '${MAIN_BINARY_REPOSITORY}${OS_TRIPPLE}/${_bb_archive}'" || \
                    try "${FETCH_BIN} -o ${FILE_CACHE_DIR}${_bb_archive} ${FETCH_OPTS} '${MAIN_BINARY_REPOSITORY}${OS_TRIPPLE}/${_bb_archive}'" || \
                    try "${FETCH_BIN} -o ${FILE_CACHE_DIR}${_bb_archive} ${FETCH_OPTS} '${MAIN_BINARY_REPOSITORY}${OS_TRIPPLE}/${_bb_archive}'" || \
                    error "Failure fetching available binary build for: $(distinct e "${_bb_archive}"). Please check your DNS / Network setup!"
            else
                note "No binary build available for: $(distinct n "${OS_TRIPPLE}/${_full_name}-${_bb_ver}")"
            fi
        fi

        debug "_bb_archive: $(distinct d "${_bb_archive}"). Expecting binbuild to be available in: $(distinct d "${FILE_CACHE_DIR}${_bb_archive}")"

        # validate binary build:
        if [ -e "${FILE_CACHE_DIR}${_bb_archive}" ]; then
            validate_archive_sha1 "${FILE_CACHE_DIR}${_bb_archive}"
        fi

        # after sha1 validation we may continue with binary build if file still exists
        if [ -e "${FILE_CACHE_DIR}${_bb_archive}" ]; then
            install_software_from_binbuild "${_bb_archive}" "${_bbfull_name}" "${_bb_ver}"
        else
            debug "Binary build checksum doesn't match for: $(distinct d "${_bbfull_name}")"
        fi
    fi
    unset _bbfull_name _bbaname _bb_archive
}


build () {
    _build_list=${*}

    # Update definitions and perform more checks
    validate_reqs

    store_security_state
    disable_security_features

    PATH="${DEFAULT_PATH}"
    for _bund_name in ${_build_list}; do
        _specified="${_bund_name}" # store original value of user input
        _bund_name="$(lowercase "${_bund_name}")"
        load_defaults
        load_defs "${_bund_name}"
        _pref_base="$(${BASENAME_BIN} "${PREFIX}" 2>/dev/null)"
        if [ "${DEF_DISABLED}" = "YES" ]; then
            _anm="$(capitalize "${_bund_name}")"
            warn "Bundle: $(distinct w "${_anm}") is disabled on: $(distinct w "${OS_TRIPPLE}")"
            try "${RM_BIN} -rf ${PREFIX}"
            unset _pref_base
        else
            unset _pref_base
            for _req_name in ${DEFINITIONS_DIR}${_bund_name}${DEFAULT_DEF_EXT}; do
                unset DONT_BUILD_BUT_DO_EXPORTS
                debug "Reading definition: $(distinct d ${_req_name})"
                load_defaults
                load_defs "${_req_name}"
                if [ -z "${DEF_REQUIREMENTS}" ]; then
                    debug "No app requirements"
                else
                    pretouch_logs ${DEF_REQUIREMENTS}
                fi

                # Note: this acutally may break definitions like ImageMagick..
                #_common_lowercase="$(lowercase "${DEF_NAME}${DEF_POSTFIX}")"
                _common_lowercase="${DEF_NAME}${DEF_POSTFIX}"
                DEF_NAME="$(capitalize "${_common_lowercase}")"

                # if definition requires root privileges, throw an "exception":
                if [ -n "${DEF_REQUIRE_ROOT_ACCESS}" ]; then
                    if [ "${USER}" != "root" ]; then
                        error "Definition requires superuser priviledges: $(distinct e ${_common_lowercase}). Installation aborted."
                    fi
                fi

                _bundl_name="$(capitalize "${_common_lowercase}")"
                PREFIX="${SOFTWARE_DIR}${_bundl_name}"
                SERVICE_DIR="${SERVICES_DIR}${_bundl_name}"
                BUILD_NAMESUM="$(text_checksum "${DEF_NAME}${DEF_POSTFIX}-${DEF_VERSION}")"
                BUILD_DIR="${PREFIX}/${DEFAULT_SRC_EXT}${BUILD_NAMESUM}"
                create_builddir "${_bundl_name}" "${BUILD_NAMESUM}"

                # These values has to be exported because external build mechanisms
                # has to be able to reach these values to find dependencies and utilities
                export PATH="${PREFIX}/bin:${PREFIX}/sbin:${DEFAULT_PATH}"
                export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig"

                # NOTE: standalone definition has own SERVICES_DIR/Bundlename/ prefix
                if [ -n "${DEF_STANDALONE}" ]; then
                    create_service_dir "${_bundl_name}"
                fi

                # binary build of whole software bundle
                _full_bund_name="${_common_lowercase}-${DEF_VERSION}"
                try "${MKDIR_BIN} -p ${FILE_CACHE_DIR}"

                _an_archive="$(capitalize "${_common_lowercase}")-${DEF_VERSION}${DEFAULT_ARCHIVE_EXT}"
                _installed_indicator="${PREFIX}/${_common_lowercase}${DEFAULT_INST_MARK_EXT}"
                if [ ! -e "${_installed_indicator}" ]; then
                    fetch_binbuild "${_full_bund_name}" "${_common_lowercase}" "${_an_archive}" "${DEF_VERSION}"
                else
                    _already_installed_version="$(${CAT_BIN} ${_installed_indicator} 2>/dev/null)"
                    if [ "${DEF_VERSION}" = "${_already_installed_version}" ]; then
                        debug "$(distinct d ${_common_lowercase}) bundle is installed with version: $(distinct d "${_already_installed_version}")"
                    else
                        warn "$(distinct w "${_common_lowercase}") bundle is installed with version: $(distinct w "${_already_installed_version}"), different from defined: $(distinct w "${DEF_VERSION}")"
                    fi
                    DONT_BUILD_BUT_DO_EXPORTS=YES
                    unset _already_installed_version
                fi

                if [ -z "${DONT_BUILD_BUT_DO_EXPORTS}" ]; then
                    if [ -z "${DEF_REQUIREMENTS}" ]; then
                        note "Installing: $(distinct n "${DEF_FULL_NAME}"), version: $(distinct n "${DEF_VERSION}")"
                    else
                        note "Installing: $(distinct n "${DEF_FULL_NAME}"), version: $(distinct n "${DEF_VERSION}"), with requirements: $(distinct n "${DEF_REQUIREMENTS}")"
                    fi
                    _req_amount="$(${PRINTF_BIN} "${DEF_REQUIREMENTS}" | ${WC_BIN} -w 2>/dev/null | ${AWK_BIN} '{print $1;}' 2>/dev/null)"
                    _req_amount="$(${PRINTF_BIN} "${_req_amount} + 1\n" | ${BC_BIN} 2>/dev/null)"
                    _req_all="${_req_amount}"
                    for _req in ${DEF_REQUIREMENTS}; do
                        if [ -n "${DEF_USER_INFO}" ]; then
                            warn "${DEF_USER_INFO}"
                        fi
                        if [ -z "${_req}" ]; then
                            note "No additional requirements defined"
                            break
                        else
                            note "  ${_req} ($(distinct n "${_req_amount}") of $(distinct n "${_req_all}") remaining)"
                            if [ ! -e "${PREFIX}/${_req}${DEFAULT_INST_MARK_EXT}" ]; then
                                CHANGED=YES
                                process "${_req}"
                            fi
                        fi
                        _req_amount="$(${PRINTF_BIN} "${_req_amount} - 1\n" | ${BC_BIN} 2>/dev/null)"
                    done
                fi

                if [ -z "${DONT_BUILD_BUT_DO_EXPORTS}" ]; then
                    if [ -e "${PREFIX}/${_common_lowercase}${DEFAULT_INST_MARK_EXT}" ]; then
                        if [ "${CHANGED}" = "YES" ]; then
                            note "  ${_common_lowercase} ($(distinct n 1) of $(distinct n "${_req_all}"))"
                            note "   ${NOTE_CHAR} App dependencies changed. Rebuilding: $(distinct n ${_common_lowercase})"
                            process "${_common_lowercase}"
                            unset CHANGED
                            mark_installed "${DEF_NAME}${DEF_POSTFIX}" "${DEF_VERSION}"
                            show_done "${DEF_NAME}${DEF_POSTFIX}"
                        else
                            note "  ${_common_lowercase} ($(distinct n 1) of $(distinct n ${_req_all}))"
                            show_done "${DEF_NAME}${DEF_POSTFIX}"
                            debug "${SUCCESS_CHAR} $(distinct d ${_common_lowercase}) current: $(distinct d ${_version_element}), definition: [$(distinct d ${DEF_VERSION})] Ok."
                        fi
                    else
                        note "  ${_common_lowercase} ($(distinct n 1) of $(distinct n ${_req_all}))"
                        debug "Right before process call: ${_common_lowercase}"
                        process "${_common_lowercase}"
                        mark_installed "${DEF_NAME}${DEF_POSTFIX}" "${DEF_VERSION}"
                        note "${SUCCESS_CHAR} ${_common_lowercase} [$(distinct n ${DEF_VERSION})]\n"
                    fi
                fi

                export_binaries "${_common_lowercase}"
            done

            after_export_callback

            clean_useless
            strip_bundle "${_common_lowercase}"
            create_apple_bundle_if_necessary

        fi
    done

    # Cleanup build dirs..
    if [ -z "${DEVEL}" ]; then
        if [ -n "${PREFIX}" -a \
             -d "${PREFIX}" ]; then
            if [ -n "${BUILD_NAMESUM}" ]; then
                destroy_builddir "$(${BASENAME_BIN} "${PREFIX}" 2>/dev/null)" "${BUILD_NAMESUM}"
            else
                # shouldn't happen..
                warn "No BUILD_NAMESUM set! Can't identift build-dir!"
            fi
        else
            debug "Empty prefix. No build-dir to destroy"
        fi
    else
        # TODO: dump srcdir? here?
        debug "No-Op - not yet implemented"
    fi
    update_shell_vars
    debug "Build successfull: $(distinct d "${_build_list}")"
    unset _build_list _common_lowercase _req_all _req
}


dump_debug_info () {
    debug "-------------- PRE CONFIGURE SETTINGS DUMP --------------"
    debug "CPUS (used): $(distinct d ${CPUS})"
    debug "ALL_CPUS: $(distinct d ${ALL_CPUS})"
    debug "MAKE_OPTS: $(distinct d ${MAKE_OPTS})"
    debug "FETCH_OPTS: $(distinct d ${FETCH_OPTS})"
    debug "PREFIX: $(distinct d ${PREFIX})"
    debug "SERVICE_DIR: $(distinct d ${SERVICE_DIR})"
    debug "CURRENT_DIR: $(distinct d $(${PWD_BIN} 2>/dev/null))"
    debug "BUILD_NAMESUM: $(distinct d ${BUILD_NAMESUM})"
    debug "BUILD_DIR: $(distinct d ${BUILD_DIR})"
    debug "PATH: $(distinct d ${PATH})"
    debug "CC: $(distinct d ${CC})"
    debug "CXX: $(distinct d ${CXX})"
    debug "CPP: $(distinct d ${CPP})"
    debug "CXXFLAGS: $(distinct d ${CXXFLAGS})"
    debug "CFLAGS: $(distinct d ${CFLAGS})"
    debug "LDFLAGS: $(distinct d ${LDFLAGS})"
    if [ "Darwin" = "${SYSTEM_NAME}" ]; then
        debug "DYLD_LIBRARY_PATH: $(distinct d ${DYLD_LIBRARY_PATH})"
    else
        debug "LD_LIBRARY_PATH: $(distinct d ${LD_LIBRARY_PATH})"
    fi
    debug "-------------- PRE CONFIGURE SETTINGS DUMP ENDS ---------"
}


process () {
    _app_param="$1"
    if [ -z "${_app_param}" ]; then
        error "No param given for process()!"
    fi
    _req_definition="${DEFINITIONS_DIR}$(lowercase "${_app_param}")${DEFAULT_DEF_EXT}"
    if [ ! -e "${_req_definition}" ]; then
        error "Cannot fetch definition: $(distinct e ${_req_definition})! Aborting!"
    fi
    _req_defname="$(echo "$(${BASENAME_BIN} "${_req_definition}" 2>/dev/null)" | ${SED_BIN} -e 's/\..*$//g' 2>/dev/null)"
    debug "Requirement: $(distinct d "${_app_param}") file: $(distinct d "${_req_definition}"), req-name: $(distinct d "${_req_defname}")"

    load_defaults
    load_defs "${_req_definition}"

    compiler_setup
    dump_debug_info

    if [ -z "${PREFIX}" ]; then
        PATH="${DEFAULT_PATH}"
    else
        PATH="${PREFIX}/bin:${PREFIX}/sbin:${DEFAULT_PATH}"
    fi
    if [ -z "${DEF_DISABLED}" ]; then
        if [ -z "${DEF_SOURCE_PATH}" ]; then
            note "   ${NOTE_CHAR2} $(distinct n "DEF_SOURCE_PATH=\"\"") is undefined for: $(distinct n "${_req_defname}")."
            note "NOTE: It's only valid for meta bundles. You may consider setting: $(distinct n "DEF_CONFIGURE=\"meta\"") in bundle definition file. Type: $(distinct n "s dev ${_req_defname}"))"
        else
            _cwd="$(${PWD_BIN} 2>/dev/null)"
            if [ -n "${BUILD_DIR}" -a \
                 -n "${BUILD_NAMESUM}" ]; then
                create_builddir "$(${BASENAME_BIN} "${PREFIX}" 2>/dev/null)" "${BUILD_NAMESUM}"
                cd "${BUILD_DIR}"
                if [ -z "${DEF_GIT_MODE}" ]; then # Standard "fetch source archive" method
                    _base="$(${BASENAME_BIN} "${DEF_SOURCE_PATH}" 2>/dev/null)"
                    debug "DEF_SOURCE_PATH: $(distinct d "${DEF_SOURCE_PATH}") base: $(distinct d "${_base}")"
                    _dest_file="${FILE_CACHE_DIR}${_base}"
                    # TODO: implement auto picking fetch method based on DEF_SOURCE_PATH contents
                    if [ ! -e "${_dest_file}" ]; then
                        retry "${FETCH_BIN} -o ${_dest_file} ${FETCH_OPTS} '${DEF_SOURCE_PATH}'" || \
                            def_error "${DEF_NAME}${DEF_POSTFIX}" "Failed source fetch: $(distinct e "${DEF_SOURCE_PATH}${_base}")"
                        note "   ${NOTE_CHAR} Source fetched for: $(distinct n "${_base}")"
                    fi
                    debug "Build root: $(distinct d ${BUILD_DIR}), file: $(distinct d "${_dest_file}")"
                    if [ -z "${DEF_SHA}" ]; then
                        error "Missing SHA sum for source: $(distinct e "${_dest_file}")!"
                    else
                        _a_file_checksum="$(file_checksum "${_dest_file}")"
                        if [ "${_a_file_checksum}" = "${DEF_SHA}" ]; then
                            debug "Source checksum is fine"
                        else
                            warn "${WARN_CHAR} Source checksum mismatch: $(distinct w "${_a_file_checksum}") vs $(distinct w "${DEF_SHA}")"
                            _bname="$(${BASENAME_BIN} "${_dest_file}" 2>/dev/null)"
                            warn "${WARN_CHAR} Removing file from cache: $(distinct w "${_bname}") and retrying.."
                            # remove corrupted file
                            try "${RM_BIN} -vf ${_dest_file}"
                            # and restart script with same arguments:
                            debug "Evaluating again: $(distinct d "process(${_app_param})")"
                            process "${_app_param}"
                        fi
                        unset _bname _a_file_checksum
                    fi

                    _might_be_dir="${BUILD_DIR}/${DEF_NAME}${DEF_POSTFIX}"
                    try "${MV_BIN} ${_might_be_dir} ${_might_be_dir}-${TIMESTAMP}.old" && \
                        debug "Moved previous build dir to: $(distinct d "${_might_be_dir}-${TIMESTAMP}.old")"

                    note "   ${NOTE_CHAR} Unpacking source of: $(distinct n "${DEF_NAME}${DEF_POSTFIX}")"
                    debug "Build dir: $(distinct d "${BUILD_DIR}")"
                    try "${TAR_BIN} --directory ${BUILD_DIR} -xf ${_dest_file}" || \
                        try "${TAR_BIN} --directory ${BUILD_DIR} -xfj ${_dest_file}" || \
                            run "${TAR_BIN} --directory ${BUILD_DIR} -xfJ ${_dest_file}"
                else
                    # git method:
                    # .cache/git-cache => git bare repos
                    clone_or_fetch_git_bare_repo "${DEF_SOURCE_PATH}" "${DEF_NAME}-${DEF_VERSION}" "${DEF_GIT_CHECKOUT}" "${BUILD_DIR}"
                fi

                unset _fd _might_be_dir
                _prm_nolib="$(echo "${_app_param}" | ${SED_BIN} 's/lib//' 2>/dev/null)"
                _prm_no_undrlne_and_minus="$(echo "${_app_param}" | ${SED_BIN} 's/[-_].*$//' 2>/dev/null)"
                debug "_app_param: ${_app_param} short: ${_prm_nolib}, nafter-: ${_prm_no_undrlne_and_minus}, DEF_NAME: ${DEF_NAME}, BUILD_DIR: ${BUILD_DIR}"
                # NOTE: patterns sorted by safety
                for _pati in    "*${_app_param}*${DEF_VERSION}*" \
                                "*${_prm_no_undrlne_and_minus}*${DEF_VERSION}*" \
                                "*${_prm_nolib}*${DEF_VERSION}*" \
                                "*${DEF_NAME}*${DEF_VERSION}*" \
                                "*${_app_param}*" \
                                "*${_prm_no_undrlne_and_minus}*" \
                                "*${_prm_nolib}*" \
                                "*${DEF_NAME}*";
                do
                    _fd="$(${FIND_BIN} "${BUILD_DIR}" -maxdepth 1 -mindepth 1 -type d -iname "${_pati}" 2>/dev/null)"
                    if [ -n "${_fd}" ]; then
                        debug "Found build dir: $(distinct d "${_fd}"), for definition: $(distinct d "${DEF_NAME}")"
                        break
                    fi
                done
                if [ -z "${_fd}" ]; then
                    error "No source dir found for definition: $(distinct e "${_app_param}")?"
                fi
                cd "${_fd}"

                # Handle DEF_BUILD_DIR_POSTFIX here
                if [ -n "${_fd}/${DEF_BUILD_DIR_POSTFIX}" ]; then
                    try "${MKDIR_BIN} -p ${_fd}/${DEF_BUILD_DIR_POSTFIX}"
                    cd "${_fd}/${DEF_BUILD_DIR_POSTFIX}"
                fi
                _pwd="$(${PWD_BIN} 2>/dev/null)"
                debug "Switched to build dir root: $(distinct d "${_pwd}")"

                if [ -n "${DEF_GIT_CHECKOUT}" -a \
                     "master" != "${DEF_GIT_CHECKOUT}" ]; then
                    debug "   ${NOTE_CHAR} Definition branch: $(distinct n "${DEF_GIT_CHECKOUT}")"
                    _current_branch="$(${GIT_BIN} rev-parse --abbrev-ref HEAD 2>/dev/null)"
                    if [ "${_current_branch}" != "${DEF_GIT_CHECKOUT}" ]; then
                        try "${GIT_BIN} checkout ${DEFAULT_GIT_OPTS} -b ${DEF_GIT_CHECKOUT}"
                    fi
                    try "${GIT_BIN} checkout ${DEFAULT_GIT_OPTS} ${DEF_GIT_CHECKOUT}"
                    unset _current_branch
                fi

                after_update_callback

                apply_definition_patches "${DEF_NAME}${DEF_POSTFIX}"
                after_patch_callback

                note "   ${NOTE_CHAR} Configuring: $(distinct n "${_app_param}"), version: $(distinct n "${DEF_VERSION}")"
                case "${DEF_CONFIGURE}" in

                    ignore)
                        note "   ${NOTE_CHAR} Configuration skipped for definition: $(distinct n "${_app_param}")"
                        ;;

                    no-conf)
                        note "   ${NOTE_CHAR} No configuration for definition: $(distinct n "${_app_param}")"
                        DEF_MAKE_METHOD="${DEF_MAKE_METHOD} PREFIX=${PREFIX}"
                        DEF_INSTALL_METHOD="${DEF_INSTALL_METHOD} PREFIX=${PREFIX}"
                        ;;

                    binary)
                        note "   ${NOTE_CHAR} Prebuilt definition of: $(distinct n "${_app_param}")"
                        DEF_MAKE_METHOD="true"
                        DEF_INSTALL_METHOD="true"
                        ;;

                    posix)
                        run "./configure -prefix ${PREFIX} -cc $(${BASENAME_BIN} ${CC} 2>/dev/null) ${DEF_CONFIGURE_ARGS}"
                        ;;

                    cmake)
                        ${TEST_BIN} -z "${DEF_CMAKE_BUILD_DIR}" && DEF_CMAKE_BUILD_DIR="." # default - cwd
                        run "${DEF_CONFIGURE} ${DEF_CMAKE_BUILD_DIR} -LH -DCMAKE_INSTALL_RPATH=\"${PREFIX}/lib;${PREFIX}/libexec\" -DCMAKE_INSTALL_PREFIX=${PREFIX} -DCMAKE_BUILD_TYPE=Release -DSYSCONFDIR=${SERVICE_DIR}/etc -DDOCDIR=${SERVICE_DIR}/share/doc -DJOB_POOL_COMPILE=${CPUS} -DJOB_POOL_LINK=${CPUS} -DCMAKE_C_FLAGS=\"${CFLAGS}\" -DCMAKE_CXX_FLAGS=\"${CXXFLAGS}\" ${DEF_CONFIGURE_ARGS}"
                        ;;

                    void|meta|empty|none)
                        DEF_MAKE_METHOD="true"
                        DEF_INSTALL_METHOD="true"
                        ;;

                    *)
                        unset _pic_optional
                        if [ "${SYSTEM_NAME}" != "Darwin" ]; then
                            _pic_optional="--with-pic"
                        fi
                        if [ "${SYSTEM_NAME}" = "Linux" ]; then
                            # NOTE: No /Services feature implemented for Linux.
                            echo "${DEF_CONFIGURE}" | ${GREP_BIN} "configure" >/dev/null 2>&1
                            if [ "$?" = "0" ]; then
                                try "${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS} --prefix=${PREFIX} ${_pic_optional}" || \
                                run "${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS} --prefix=${PREFIX}" # fallback
                            else
                                try "${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS} --prefix=${PREFIX}" || \
                                run "${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS}" # Trust definition
                            fi
                        else
                            # do a simple check for "configure" in DEF_CONFIGURE definition
                            # this way we can tell if we want to put configure options as params
                            echo "${DEF_CONFIGURE}" | ${GREP_BIN} "configure" >/dev/null 2>&1
                            if [ "$?" = "0" ]; then
                                # TODO: add --docdir=${PREFIX}/docs
                                # NOTE: By default try to configure software with these options:
                                #   --sysconfdir=${SERVICE_DIR}/etc
                                #   --localstatedir=${SERVICE_DIR}/var
                                #   --runstatedir=${SERVICE_DIR}/run
                                #   --with-pic
                                # OPTIMIZE: TODO: XXX: use ./configure --help | grep option to
                                #      build configure options quickly
                                try "${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS} --prefix=${PREFIX} --sysconfdir=${SERVICE_DIR}/etc --localstatedir=${SERVICE_DIR}/var --runstatedir=${SERVICE_DIR}/run ${_pic_optional}" || \
                                try "${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS} --prefix=${PREFIX} --sysconfdir=${SERVICE_DIR}/etc --localstatedir=${SERVICE_DIR}/var ${_pic_optional}" || \
                                try "${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS} --prefix=${PREFIX} --sysconfdir=${SERVICE_DIR}/etc --localstatedir=${SERVICE_DIR}/var" || \
                                try "${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS} --prefix=${PREFIX} --sysconfdir=${SERVICE_DIR}/etc ${_pic_optional}" || \
                                try "${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS} --prefix=${PREFIX} --sysconfdir=${SERVICE_DIR}/etc" || \
                                try "${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS} --prefix=${PREFIX} ${_pic_optional}" || \
                                run "${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS} --prefix=${PREFIX}" # last two - only as a fallback

                            else # fallback again:
                                # NOTE: First - try to specify GNU prefix,
                                # then trust prefix given in software definition.
                                try "${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS} --prefix=${PREFIX}" || \
                                run "${DEF_CONFIGURE} ${DEF_CONFIGURE_ARGS}"
                            fi
                        fi
                        ;;

                esac

                after_configure_callback
            else
                error "These values cannot be empty: BUILD_DIR, BUILD_NAMESUM"
            fi

            # and common part between normal and continue modes:
            note "   ${NOTE_CHAR} Building requirement: $(distinct n "${_app_param}")"
            try "${DEF_MAKE_METHOD}" || \
            run "${DEF_MAKE_METHOD}"
            after_make_callback

            debug "Cleaning man dir from previous dependencies, we want to install man pages that belong to LAST requirement which is app bundle itself"
            for place in man share/man share/info share/doc share/docs; do
                ${FIND_BIN} "${PREFIX}/${place}" -delete 2>/dev/null
            done

            note "   ${NOTE_CHAR} Installing requirement: $(distinct n "${_app_param}")"
            run "${DEF_INSTALL_METHOD}"
            after_install_callback

            debug "Marking $(distinct d "${_app_param}") as installed in: $(distinct d "${PREFIX}")"
            ${TOUCH_BIN} "${PREFIX}/${_app_param}${DEFAULT_INST_MARK_EXT}"
            debug "Writing version: $(distinct d "${DEF_VERSION}") of software: $(distinct d "${DEF_NAME}") installed in: $(distinct d "${PREFIX}")"
            ${PRINTF_BIN} "${DEF_VERSION}" > "${PREFIX}/${_app_param}${DEFAULT_INST_MARK_EXT}"
            cd "${_cwd}" 2>/dev/null
            unset _cwd
        fi
    else
        note "   ${WARN_CHAR} Requirement: $(distinct n "${_req_defname}") skipped for: $(distinct n "${SYSTEM_NAME}")"
        if [ -n "${PREFIX}" -a \
             ! -d "${PREFIX}" ]; then # case when disabled requirement is first on list of dependencies
            create_software_dir "$(${BASENAME_BIN} "${PREFIX}" 2>/dev/null)"
        fi
        _dis_def="${PREFIX}/${_req_defname}${DEFAULT_INST_MARK_EXT}"
        debug "Disabled requirement: $(distinct d "${_req_defname}"), writing '${DEFAULT_REQ_OS_PROVIDED}' to: $(distinct d "${_dis_def}")"
        run "${PRINTF_BIN} \"${DEFAULT_REQ_OS_PROVIDED}\" > ${_dis_def}"
    fi
    unset _current_branch _dis_def _req_defname
}
