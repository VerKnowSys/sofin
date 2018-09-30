
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
    debug "build_bundle: $(distd "${_bsbname}"), should be in: $(distd "${SOFTWARE_DIR}/${_bsbname}"), full-name: $(distd "${_bsbelement}")"
    if [ ! -d "${SOFTWARE_DIR}/${_bsbname}" ]; then
        create_software_dir "${_bsbname}"
        create_software_bundle_archive "${_bsbname}" "${_bsbelement}" "${_bsversion}"
    else
        if [ ! -f "${FILE_CACHE_DIR}${_bsbelement}" ]; then
            debug "Found incomplete or damaged bundle file. Rebuilding: $(distd "${_bsbelement}")"
            try "${RM_BIN} -f ${FILE_CACHE_DIR}${_bsbelement}"
            create_software_bundle_archive "${_bsbname}" "${_bsbelement}" "${_bsversion}"
        else
            debug "Found already existing bundle stream in file-cache: $(distd "${FILE_CACHE_DIR}${_bsbelement}")"

            # NOTE: Let's move old one, make a shasum difference, if different => overwrite
            try "${MV_BIN} ${FILE_CACHE_DIR}${_bsbelement} ${FILE_CACHE_DIR}${_bsbelement}.old ; ${MV_BIN} ${FILE_CACHE_DIR}${_bsbelement}${DEFAULT_CHKSUM_EXT} ${FILE_CACHE_DIR}${_bsbelement}${DEFAULT_CHKSUM_EXT}.old" && \
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
                    try "${RM_BIN} -f ${FILE_CACHE_DIR}${_bsbelement}.old ${FILE_CACHE_DIR}${_bsbelement}${DEFAULT_CHKSUM_EXT}.old" && \
                        debug "Checksum didn't match. New stream will be used to upload bundle stream. Previous cache stream file was removed."
                fi
            fi
        fi
    fi
    unset _bsbname _bsbelement
}


push_binbuilds () {
    _push_bundles="${*}"
    if [ -z "${_push_bundles}" ]; then
        error "At least single argument with $(diste "BundleName") to push is required!"
    fi
    for _pbelement in $(to_iter "${_push_bundles}"); do
        _pblowercase_element="$(lowercase "${_pbelement}")"
        if [ -z "${_pblowercase_element}" ]; then
            error "Lowercase bundle name is empty!"
        fi
        _pbinstall_indicator_file="${SOFTWARE_DIR}/${_pbelement}/${_pblowercase_element}${DEFAULT_INST_MARK_EXT}"
        _pbbversion_element="$(${CAT_BIN} "${_pbinstall_indicator_file}" 2>/dev/null)"
        debug "Push: ${_pblowercase_element} indicator: ${_pbinstall_indicator_file}, version: ${_pbbversion_element}"
        if [ ! -f "${_pbinstall_indicator_file}" ]; then
            error "Bundle install indicator: $(diste "${_pbinstall_indicator_file}") doesn't exist!"
        fi
        if [ -n "${_pbelement}" ] && \
           [ -d "${SOFTWARE_DIR}/${_pbelement}" ] && \
           [ -n "${_pbbversion_element}" ]; then
            debug "About to push: $(distd "${_pbelement}"), install-indicator: $(distd "${_pbinstall_indicator_file}"), soft-version: $(distd "${_pbbversion_element}")"
            push_to_all_mirrors "${_pbelement}" "${_pbbversion_element}"
        else
            error "Push validations failed for bundle: $(diste "${_pbelement}")! It might not be fully installed or broken."
        fi
    done
}


deploy_binbuild () {
    _dbbundles="${*}"
    for _dbbundle in $(to_iter "${_dbbundles}"); do
        USE_BINBUILD=NO
        build "${_dbbundle}"
        push_binbuilds "${_dbbundle}"
    done
    unset _dbbundles _dbbundle
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

        if [ -e "${FILE_CACHE_DIR}${_bb_archive}" ]; then
            debug "BB-archive: $(distd "${_bb_archive}"). Expecting binbuild to be available in: $(distd "${FILE_CACHE_DIR}${_bb_archive}")"
            validate_archive_sha1 "${FILE_CACHE_DIR}${_bb_archive}"
            install_software_from_binbuild "${_bb_archive}" "${_fbb_bundname}"
        else
            debug "Binary build unavailable for bundle: $(distd "${_fbb_bundname}")"
            if [ -n "${CAP_SYS_PRODUCTION}" ]; then
                permnote "Software build from source disabled on production hosts!"
                finalize
            fi
        fi
    fi
    unset _fbb_bundname _fbb_bundname _bb_archive
}


load_pax_file () {
    if [ -n "${CAP_SYS_PRODUCTION}" ]; then
        _paxfile="${PREFIX}/.pax"
        if [ -f "${_paxfile}" ]; then
            debug "Loading .pax file: $(distd "${_paxfile}")"
            try ". ${_paxfile}"
        fi
        unset _paxfile
    fi
}


# NOTE: build() works incorrectly now - when specified multiple arguments the post tasks fail
build () {
    _build_list="${*}"

    # Update definitions and perform more checks
    security_set_build
    validate_kern_loaded_dtrace
    validate_sys_limits

    # store_security_state
    # disable_security_features

    debug "Sofin v$(distd "${SOFIN_VERSION}"): New build started for bundles: $(distd "${_build_list}")"
    for _bund_name in $(to_iter "${_build_list}"); do
        _bund_name="$(lowercase "${_bund_name}")"
        _anm="$(capitalize "${_bund_name}")"
        load_defaults
        load_defs "${_bund_name}"
        if [ "${DEF_DISABLED_ON}" = "YES" ]; then
            warn "Bundle: $(distw "${_anm}") is disabled on: $(distw "${OS_TRIPPLE}")"
            destroy_software_dir "${_anm}"
        else
            create_software_dir "${_anm}"
            for _req_name in ${DEFINITIONS_DIR}/${_bund_name}${DEFAULT_DEF_EXT}; do
                unset DONT_BUILD_BUT_DO_EXPORTS
                debug "Reading definition: $(distd "${_req_name}")"
                load_defaults
                load_defs "${_req_name}"
                pretouch_logs "${DEF_REQUIREMENTS}"

                # Note: this acutally may break definitions like ImageMagick..
                #_bund_lcase="$(lowercase "${DEF_NAME}${DEF_SUFFIX}")"
                _bund_lcase="${DEF_NAME}${DEF_SUFFIX}"
                _bundl_name="$(capitalize "${_bund_lcase}")"
                DEF_NAME="${_bundl_name}"

                # if definition requires root privileges, throw an "exception":
                if [ -n "${DEF_REQUIRE_ROOT_ACCESS}" ]; then
                    if [ "${USER}" != "root" ]; then
                        error "Definition requires superuser priviledges: $(diste "${_bund_lcase}"). Installation aborted."
                    fi
                fi

                # normally definition is NOT Sofin internal utility:
                if [ -z "${DEF_UTILITY_BUNDLE}" ]; then
                    PREFIX="${SOFTWARE_DIR}/${_bundl_name}"
                    SERVICE_DIR="${SERVICES_DIR}/${_bundl_name}"
                    BUILD_NAMESUM="$(firstn "$(text_checksum "${_bund_lcase}-${DEF_VERSION}")")"
                    BUILD_DIR="${PREFIX}/${DEFAULT_SRC_EXT}${BUILD_NAMESUM}"

                else # Sofin private utility build:
                    debug "Bundle: $(distd "${_bundl_name}") is to be built as Sofin private prefix: $(distd "${PREFIX}")!"
                fi

                # These values has to be exported because external build mechanisms
                # has to be able to reach these values to find dependencies and utilities
                export PREFIX
                export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig"
                export PATH="${DEFAULT_SHELL_EXPORTS}:${SERVICE_DIR}/bin:${PREFIX}/bin:${PREFIX}/sbin:${SERVICE_DIR}/sbin:${DEFAULT_PATH}"
                if [ -n "${DEF_USE_TOOLS}" ]; then
                    export PATH="${DEFAULT_SHELL_EXPORTS}:${SERVICE_DIR}/bin:${PREFIX}/bin:${PREFIX}/sbin:${SOFIN_UTILS_PATH}:${SERVICE_DIR}/sbin:${DEFAULT_PATH}"
                    debug "Using tools: $(distd "yes"). Path=$(distd "${PATH}")"
                else
                    debug "Using tools: $(distd "no" "${ColorRed}")"
                fi

                if [ -z "${DEF_UTILITY_BUNDLE}" ]; then
                    # NOTE: standalone definition has own SERVICES_DIR/Bundlename/ prefix
                    if [ -n "${DEF_STANDALONE}" ]; then
                        debug "$(distd "try_fetch_service_dir()") for bundle: $(distd "${_bundl_name}") v$(distd "${DEF_VERSION}")"
                        try_fetch_service_dir "${_bundl_name}" "${DEF_VERSION}"
                        debug "$(distd "create_service_dataset()") for bundle: $(distd "${_bundl_name}")"
                        create_service_dataset "${_bundl_name}"
                    fi

                    try "${MKDIR_BIN} -p ${FILE_CACHE_DIR}"
                    _an_archive="${_bundl_name}-${DEF_VERSION}-${OS_TRIPPLE}${DEFAULT_ARCHIVE_EXT}"
                    _installed_indicator="${PREFIX}/${_bund_lcase}${DEFAULT_INST_MARK_EXT}"
                    if [ ! -e "${_installed_indicator}" ]; then
                        fetch_binbuild "${_bundl_name}" "${_an_archive}"
                    else
                        _already_installed_version="$(${CAT_BIN} "${_installed_indicator}" 2>/dev/null)"
                        if [ "${DEF_VERSION}" = "${_already_installed_version}" ]; then
                            debug "$(capitalize "$(distd "${_bund_lcase}")") bundle is installed with version: $(distd "${_already_installed_version}")"
                        else
                            error "$(capitalize "$(diste "${_bund_lcase}")") bundle is installed with version: $(diste "${_already_installed_version}"), different from found in definition: $(diste "${DEF_VERSION}"). Aborting!"
                        fi
                        DONT_BUILD_BUT_DO_EXPORTS=YES
                        unset _already_installed_version
                    fi

                    if [ -n "${CAP_SYS_PRODUCTION}" ]; then
                        debug "Production mode enabled. Software build skipped!"
                        DONT_BUILD_BUT_DO_EXPORTS=YES
                    fi
                fi

                if [ -z "${DONT_BUILD_BUT_DO_EXPORTS}" ]; then
                    # NOTE: It's necessary to create build dir *after* binbuild check (which may create dataset itself)
                    create_builddir "${_bundl_name}" "${BUILD_NAMESUM}"
                    if [ -z "${DEF_REQUIREMENTS}" ]; then
                        permnote "Installing: $(distn "${DEF_FULL_NAME:-${DEF_NAME}${DEF_SUFFIX}}"), version: $(distn "${DEF_VERSION}")"
                    else
                        permnote "Installing: $(distn "${DEF_FULL_NAME:-${DEF_NAME}${DEF_SUFFIX}}"), version: $(distn "${DEF_VERSION}"), with requirements: $(distn "${DEF_REQUIREMENTS}")"
                    fi
                    _req_amount="$(printf "%s\n" "${DEF_REQUIREMENTS}" | ${WC_BIN} -w 2>/dev/null | ${AWK_BIN} '{print $1;}' 2>/dev/null)"
                    _req_amount="$(calculate_bc "${_req_amount} + 1")"
                    _req_all="${_req_amount}"
                    for _req in $(to_iter "${DEF_REQUIREMENTS}"); do
                        if [ -n "${DEF_USER_INFO}" ]; then
                            warn "${DEF_USER_INFO}"
                        fi
                        if [ -z "${_req}" ]; then
                            note "No additional requirements defined"
                            break
                        else
                            permnote "  $(distn "${_req}") ($(distn "${_req_amount}") of $(distn "${_req_all}") remaining)"
                            if [ ! -f "${PREFIX}/${_req}${DEFAULT_INST_MARK_EXT}" ]; then
                                CHANGED=YES
                                process_flat "${_req}" "${PREFIX}"
                            fi
                        fi
                        _req_amount="$(calculate_bc "${_req_amount} - 1")"
                    done
                fi

                if [ -z "${DONT_BUILD_BUT_DO_EXPORTS}" ]; then
                    if [ -e "${PREFIX}/${_bund_lcase}${DEFAULT_INST_MARK_EXT}" ]; then
                        if [ "${CHANGED}" = "YES" ]; then
                            permnote "  $(distn "${_bund_lcase}") ($(distn 1) of $(distn "${_req_all}"))"
                            note "   ${NOTE_CHAR} Definition dependencies has changed. Rebuilding: $(distn "${_bund_lcase}")"
                            process_flat "${_bund_lcase}" "${PREFIX}"
                            unset CHANGED
                            mark_installed "${DEF_NAME}${DEF_SUFFIX}" "${DEF_VERSION}"
                            show_done "${DEF_NAME}${DEF_SUFFIX}"
                        else
                            permnote "  $(distn "${_bund_lcase}") ($(distn 1) of $(distn "${_req_all}"))"
                            show_done "${DEF_NAME}${DEF_SUFFIX}"
                        fi
                    else
                        permnote "  $(distn "${_bund_lcase}") ($(distn 1) of $(distn "${_req_all}"))"
                        process_flat "${_bund_lcase}" "${PREFIX}"
                        mark_installed "${DEF_NAME}${DEF_SUFFIX}" "${DEF_VERSION}"
                        permnote "$(distn "${SUCCESS_CHAR}") $(distn "${_anm}") [$(distn "${DEF_VERSION}" "${ColorCyan}")]"
                    fi
                fi
            done
        fi

        if [ "YES" = "${CAP_SYS_ZFS}" ]; then
            _dataset_parent="${DEFAULT_ZPOOL}/Software/${SYSTEM_DATASET}"
            _dataset="${_dataset_parent}/${_anm}"
            debug "Setting dataset: $(distd "${_dataset}") to inherit 'readonly' attribute from readonly parent: $(distd "${_dataset_parent}")"
            try "${ZFS_BIN} set readonly=off '${_dataset_parent}'"
            try "${ZFS_BIN} inherit readonly '${_dataset}'"
        fi

        export_binaries "${_bund_lcase}"
        load_pax_file
        try after_export_callback
        after_export_snapshot
        validate_pie_on_exports "${_build_list}"

        if [ -z "${CAP_SYS_PRODUCTION}" ]; then
            if [ -n "${DEF_UTILITY_BUNDLE}" ]; then
                try "${RM_BIN} -rf '${PREFIX}/include' '${PREFIX}/doc' ${PREFIX}/${DEFAULT_SRC_EXT}*"
                debug "Utility bundle: $(distd "${_anm}") build completed!"
                link_utilities
            fi

            debug "Afterbuild for bundle: $(distd "${_anm}")"
            finalize_afterbuild "${_anm}"

            debug "Non production mode, hence tracking useful/useless files, stripping bundles and creating bundle snapshot!"
            track_useful_and_useless_files
            strip_bundle "${_anm}"

            if [ "YES" = "${CAP_SYS_HARDENED}" ]; then
                _disable=""
                if [ -n "${DEF_NO_ASLR}" ]; then
                    _disable="${_disable}aslr "
                fi
                if [ -n "${DEF_NO_PAGEEXEC}" ]; then
                    _disable="${_disable}pageexec "
                fi
                if [ -n "${DEF_NO_SEGVGUARD}" ]; then
                    _disable="${_disable}segvguard "
                fi
                if [ -n "${DEF_NO_DISALLOW_MAP32BIT}" ]; then
                    _disable="${_disable}disallow_map32bit "
                fi
                if [ -n "${DEF_NO_MPROTECT}" ]; then
                    _disable="${_disable}mprotect "
                fi
                if [ -n "${DEF_NO_SHLIBRANDOM}" ]; then
                    _disable="${_disable}shlibrandom "
                fi

                if [ -n "${_disable}" ]; then
                    # Write .pax file:
                    _paxfile="${PREFIX}/.pax"
                    printf "%s\n\n" '#!/bin/sh' > "${_paxfile}"
                    if [ "YES" = "${CAP_SYS_ZFS}" ]; then
                        _dataset_parent="${DEFAULT_ZPOOL}/Software/${SYSTEM_DATASET}"
                        _dataset="${_dataset_parent}/${_anm}"

                        # NOTE: Make sure readonly is put down to the .pax file!
                        {
                            echo "${ZFS_BIN} set readonly=off '${_dataset_parent}'";
                            echo "${ZFS_BIN} inherit readonly '${_dataset}'";
                        } >> "${_paxfile}"
                    fi

                    debug "Write HardenedBSD feature override capability file: $(distd "${_paxfile}") with disabled features: $(distd "${_disable}"), for binaries: $(distd "${DEF_APPLY_LOWER_SECURITY_ON}")"
                    for _lower_security_binary in $(to_iter "${DEF_APPLY_LOWER_SECURITY_ON}"); do
                        for _feature in $(to_iter "${_disable}"); do
                            _files="$(${FIND_BIN} "${PREFIX}/" -name "${_lower_security_binary}" -type f 2>/dev/null)"
                            for _file in $(to_iter "${_files}"); do
                                if [ -x "${_file}" ]; then
                                    ${FILE_BIN} "${_file}" 2>/dev/null | ${GREP_BIN} -F 'ELF 64-bit' >/dev/null 2>&1
                                    if [ "0" = "${?}" ]; then
                                        try "sh \"${SOFIN_HBSDCONTROL_BIN}\" system \"${_feature}\" disable \"${_file}\"" && \
                                            debug "Lowered security on requested binary: $(distd "${_file}")"
                                        # Storing command to .pax file to be sure to apply on each boot:
                                        echo "sh \"${SOFIN_HBSDCONTROL_BIN}\" system \"${_feature}\" disable \"${_file}\"" >> "${_paxfile}"
                                    fi
                                fi
                            done
                        done
                    done

                    if [ "YES" = "${CAP_SYS_ZFS}" ]; then
                        echo "${ZFS_BIN} set readonly=on '${_dataset_parent}'" >> "${_paxfile}"
                    fi
                fi
            fi

            if [ -n "${CAP_SYS_ZFS}" ]; then
                debug "Creating post build '$(distd "@${ORIGIN_ZFS_SNAP_NAME}")' snapshots…"
                create_origin_snaphots
            fi
        fi

    done

    unset _build_list _bund_lcase _req_all _req _disable _feature _file _files _anm _dataset
    env_reset
    return 0
}


dump_debug_info () {
    debug "Build settings dump:"
    debug "CPUS: (inUse/Total): ($(distd "${CPUS}")/$(distd "${ALL_CPUS}"))"
    debug "PREFIX: '$(distd "${PREFIX}"),  PATH: '$(distd "${PATH}")'"
    debug "SERVICE_DIR: '$(distd "${SERVICE_DIR}"),  CURRENT_DIR: '$(distd "$(${PWD_BIN} 2>/dev/null)")'"
    debug "BUILD_DIR: '$(distd "${BUILD_DIR}"),  BUILD_NAMESUM: '$(distd "${BUILD_NAMESUM}")'"
    debug "FETCH_BIN: '$(distd "${FETCH_BIN}"),  FETCH_OPTS: '$(distd "${FETCH_OPTS}")'"
    if [ "Darwin" = "${SYSTEM_NAME}" ]; then
        debug "DYLD_LIBRARY_PATH: '$(distd "${DYLD_LIBRARY_PATH}")',  LD_PRELOAD: '$(distd "${LD_PRELOAD}")'"
    else
        debug "LD_LIBRARY_PATH: '$(distd "${LD_LIBRARY_PATH}")',  LD_PRELOAD: '$(distd "${LD_PRELOAD}")'"
    fi
    debug "CC: '$(distd "${CC}"),  CXX: '$(distd "${CXX}"),  CPP: '$(distd "${CPP}")'"
    debug "LD: '$(distd "${LD}"),  NM: '$(distd "${NM}"),  AR: '$(distd "${AR}")',  AS: '$(distd "${AS}"),  RANLIB: '$(distd "${RANLIB}")'"
    debug "DEF_COMPILER_FLAGS: '$(distd "${DEF_COMPILER_FLAGS}")'"
    debug "DEF_LINKER_FLAGS: '$(distd "${DEF_LINKER_FLAGS}")'"
    debug "CFLAGS: '$(distd "${CFLAGS}")'"
    debug "CXXFLAGS: '$(distd "${CXXFLAGS}")'"
    debug "LDFLAGS: '$(distd "${LDFLAGS}")'"
    debug "DEF_CONFIGURE_METHOD: '$(distd "${DEF_CONFIGURE_METHOD}")',  DEF_CONFIGURE_ARGS: '$(distd "${DEF_CONFIGURE_ARGS}")'"
    debug "DEF_MAKE_METHOD: '$(distd "${DEF_MAKE_METHOD}")',  MAKE_OPTS: '$(distd "${MAKE_OPTS}")'"
    debug "DEF_TEST_METHOD: '$(distd "${DEF_TEST_METHOD}")'"
    debug "DEF_INSTALL_METHOD: '$(distd "${DEF_INSTALL_METHOD}")'"

    if [ -n "${DEF_AFTER_UNPACK_METHOD}" ]; then
        debug "DEF_AFTER_UNPACK_METHOD: '$(distd "${DEF_AFTER_UNPACK_METHOD}")'"
    fi
    if [ -n "${DEF_AFTER_PATCH_METHOD}" ]; then
        debug "DEF_AFTER_PATCH_METHOD: '$(distd "${DEF_AFTER_PATCH_METHOD}")'"
    fi
    if [ -n "${DEF_AFTER_CONFIGURE_METHOD}" ]; then
        debug "DEF_AFTER_CONFIGURE_METHOD: '$(distd "${DEF_AFTER_CONFIGURE_METHOD}")'"
    fi
    if [ -n "${DEF_AFTER_MAKE_METHOD}" ]; then
        debug "DEF_AFTER_MAKE_METHOD: '$(distd "${DEF_AFTER_MAKE_METHOD}")'"
    fi
    if [ -n "${DEF_AFTER_INSTALL_METHOD}" ]; then
        debug "DEF_AFTER_INSTALL_METHOD: '$(distd "${DEF_AFTER_INSTALL_METHOD}")'"
    fi
    if [ -n "${DEF_AFTER_EXPORT_METHOD}" ]; then
        debug "DEF_AFTER_EXPORT_METHOD: '$(distd "${DEF_AFTER_EXPORT_METHOD}")'"
    fi
    debug "Build settings dump eof"
}


process_flat () {
    _app_param="${1}"
    _prefix="${2}"
    _bundlnm="$(capitalize "${_app_param}")"
    if [ -z "${_app_param}" ]; then
        error "First argument with $(diste "requirement-name") is required!"
    fi
    if [ -z "${_prefix}" ]; then
        error "Second argument with $(diste "/Software/PrefixDir") is required!"
    fi
    if [ -z "${_bundlnm}" ]; then
        error "Third argument with $(diste "BundleName") is required!"
    fi
    _req_definition="${DEFINITIONS_DIR}/$(lowercase "${_app_param}")${DEFAULT_DEF_EXT}"
    if [ ! -e "${_req_definition}" ]; then
        error "Cannot read definition file: $(diste "${_req_definition}")!"
    fi
    _req_defname="$(printf "%s\n" "${_req_definition##*/}" | ${SED_BIN} -e 's/\..*$//g' 2>/dev/null)"
    debug "Bundle: $(distd "${_bundlnm}"), requirement: $(distd "${_app_param}"), PREFIX: $(distd "${_prefix}") file: $(distd "${_req_definition}"), req-name: $(distd "${_req_defname}")"

    # XXX: FIXME: OPTIMIZE: Each definition read twice... log bloat & shit
    # NOTE: Because compiler_setup() uses DEF_* from definition file to
    #       setup correct environment for build process..
    load_defaults
    load_defs "${_req_definition}"

    # Setup compiler features and options for given definition
    compiler_setup

    # NOTE: ..load definition again, because each definition can also alter
    #       it's build environment values (flexibility, KISS)
    load_defs "${_req_definition}"

    PATH="${DEFAULT_SHELL_EXPORTS}:${SERVICE_DIR}/bin:${SERVICE_DIR}/sbin:${_prefix}/bin:${_prefix}/sbin:${DEFAULT_PATH}"
    if [ -n "${DEF_USE_TOOLS}" ]; then
        debug "Suffixing path: $(distd "${SOFIN_UTILS_PATH}") to local build path!"
        PATH="${DEFAULT_SHELL_EXPORTS}:${SERVICE_DIR}/bin:${SERVICE_DIR}/sbin:${_prefix}/bin:${_prefix}/sbin:${SOFIN_UTILS_PATH}:${DEFAULT_PATH}"
    fi

    dump_system_capabilities
    dump_debug_info
    dump_compiler_setup

    if [ -z "${DEF_DISABLED_ON}" ]; then
        if [ "${DEF_TYPE}" = "meta" ]; then
            note "   ${NOTE_CHAR2} Meta bundle detected."
        else
            _cwd="$(${PWD_BIN} 2>/dev/null)"
            if [ -n "${BUILD_DIR}" ] && [ -n "${BUILD_NAMESUM}" ]; then
                cd "${BUILD_DIR}"
                if [ -z "${DEF_GIT_CHECKOUT}" ]; then # Standard "fetch source archive" method
                    _base="${DEF_SOURCE_PATH##*/}"
                    # debug "DEF_SOURCE_PATH: $(distd "${DEF_SOURCE_PATH}") base: $(distd "${_base}")"
                    _dest_file="${FILE_CACHE_DIR}${_base}"
                    # TODO: implement auto picking fetch method based on DEF_SOURCE_PATH contents
                    if [ ! -e "${_dest_file}" ]; then
                        retry "${FETCH_BIN} -o ${_dest_file} ${FETCH_OPTS} '${DEF_SOURCE_PATH}'" || \
                            error "Failed to fetch source: $(diste "${DEF_SOURCE_PATH}")"
                        note "   ${NOTE_CHAR} Source fetched: $(distn "${_base}")"
                    fi
                    # debug "Build root: $(distd "${BUILD_DIR}"), file: $(distd "${_dest_file}")"
                    if [ -z "${DEF_SHA}" ]; then
                        error "Missing SHA sum for source: $(diste "${_dest_file}")!"
                    else
                        _a_file_checksum="$(file_checksum "${_dest_file}")"
                        if [ "${_a_file_checksum}" = "${DEF_SHA}" ]; then
                            debug "$(distd "${SUCCESS_CHAR}" "${ColorGreen}"): $(distd "${_base}"): checksum matches: $(distd "${DEF_SHA}")"
                        else
                            warn "   ${WARN_CHAR} Source checksum mismatch: '$(distw "${_a_file_checksum}")' vs '$(distw "${DEF_SHA}")'"
                            _bname="${_dest_file##*/}"
                            try "${RM_BIN} -f ${_dest_file}" && \
                                debug "Removed corrupted cache file: $(distd "${_bname}") and retrying.."
                            process_flat "${_app_param}" "${_prefix}"
                        fi
                        unset _bname _a_file_checksum
                    fi

                    note "   ${NOTE_CHAR} Unpacking source of: $(distn "${DEF_NAME}${DEF_SUFFIX}"), version: $(distn "${DEF_VERSION}")"

                    _possible_old_build_dir="$(${TAR_BIN} -t --list --file "${_dest_file}" 2>/dev/null | ${HEAD_BIN} -n1 2>/dev/null | ${AWK_BIN} '{print $9;}' 2>/dev/null)"
                    _pbd_basename="${_possible_old_build_dir##*/}"
                    if [ "${_pbd_basename}" != "${_possible_old_build_dir}" ]; then # more than one path element?
                        _possible_old_build_dir="${_possible_old_build_dir%%/${_pbd_basename}}"
                    fi
                    if [ -d "${BUILD_DIR}/${_possible_old_build_dir%/}" ]; then
                        try "${RM_BIN} -rf '${BUILD_DIR}/${_possible_old_build_dir%/}'" && \
                            debug "Previous dependency build dir was removed to avoid conflicts: $(distd "${BUILD_DIR}/${_possible_old_build_dir%/}")"
                    fi

                    debug "Unpacking $(distd "${_dest_file}") to: $(distd "${BUILD_DIR}")"
                    try "${TAR_BIN} -xf ${_dest_file} --directory ${BUILD_DIR}" || \
                        try "${TAR_BIN} -xjf ${_dest_file} --directory ${BUILD_DIR}" || \
                            run "${TAR_BIN} -xJf ${_dest_file} --directory ${BUILD_DIR}"
                else
                    # git method:
                    # .cache/git-cache => git bare repos
                    # NOTE: if DEF_GIT_CHECKOUT is unset, use DEF_VERSION:
                    clone_or_fetch_git_bare_repo "${DEF_SOURCE_PATH}" "${DEF_NAME}${DEF_SUFFIX}-bare" "${DEF_GIT_CHECKOUT:-${DEF_VERSION}}" "${BUILD_DIR}"
                fi

                unset _fd
                _prm_nolib="$(printf "%s\n" "${_app_param}" | ${SED_BIN} 's/lib//' 2>/dev/null)"
                _prm_no_undrlne_and_minus="$(printf "%s\n" "${_app_param}" | ${SED_BIN} 's/[-_].*$//' 2>/dev/null)"
                # debug "Requirement: ${_app_param} short: ${_prm_nolib}, nafter-: ${_prm_no_undrlne_and_minus}, DEF_NAME: ${DEF_NAME}, BUILD_DIR: ${BUILD_DIR}"
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
                        for _inh in $(to_iter "${_inherited}"); do
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
                _pwd="${_fd}"

                # Handle DEF_BUILD_DIR_SUFFIX here
                if [ -n "${DEF_BUILD_DIR_SUFFIX}" ]; then
                    ${MKDIR_BIN} -p "${_fd}/${DEF_BUILD_DIR_SUFFIX}"
                    _pwd="${_fd}/${DEF_BUILD_DIR_SUFFIX}"
                fi

                cd "${_pwd}"
                try after_unpack_callback
                cd "${_pwd}"
                after_unpack_snapshot

                cd "${_pwd}"
                apply_definition_patches "${DEF_NAME}${DEF_SUFFIX}"

                cd "${_pwd}"
                try after_patch_callback
                cd "${_pwd}"
                after_patch_snapshot
                cd "${_pwd}"

                # configuration log:
                _configure_log="config.log"
                _cmake_out_log="CMakeFiles/CMakeOutput.log"
                _cmake_error_log="CMakeFiles/CMakeError.log"
                _cmake_config_log="${LOGS_DIR}${SOFIN_NAME}-${DEF_NAME}${DEF_SUFFIX}.cmake.log"
                _configure_options_log="${LOGS_DIR}${SOFIN_NAME}-${DEF_NAME}${DEF_SUFFIX}.config.help"
                _configure_status_log="${LOGS_DIR}${SOFIN_NAME}-${DEF_NAME}${DEF_SUFFIX}.${_configure_log}"

                note "   ${NOTE_CHAR} Configuring: $(distn "${_app_param}"), version: $(distn "${DEF_VERSION}")"
                case "${DEF_CONFIGURE_METHOD}" in

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
                        cache_conf_scrpt_hlp_opts "${_configure_options_log}"
                        try "./configure -prefix ${_prefix} -cc '${CC_NAME} ${CFLAGS}' -libs '-L${PREFIX}/lib ${LDFLAGS}' -mandir ${PREFIX}/share/man -libdir ${PREFIX}/lib -aspp '${CC_NAME} ${CFLAGS} -c' ${DEF_CONFIGURE_ARGS}" || \
                        try "./configure -prefix ${_prefix} -cc '${CC_NAME} ${CFLAGS}' -libs '-L${PREFIX}/lib ${LDFLAGS}' -libdir ${PREFIX}/lib -aspp '${CC_NAME} ${CFLAGS} -c' ${DEF_CONFIGURE_ARGS}" || \
                        run "./configure -prefix ${_prefix} -cc '${CC_NAME} ${CFLAGS}' -libs '-L${PREFIX}/lib ${LDFLAGS}' -aspp '${CC_NAME} ${CFLAGS} -c' ${DEF_CONFIGURE_ARGS}"

                        try "${INSTALL_BIN} \"${_configure_log}\" \"${_configure_status_log}\" >/dev/null"
                        ;;

                    cmake)
                        try "${RM_BIN} -rf build; ${MKDIR_BIN} -p build"
                        _pwd="${_pwd}/build"
                        cd "${_pwd}"
                        _cmake_cmdline="${DEF_CONFIGURE_METHOD} ../ -LH -DCMAKE_INSTALL_RPATH=\"${_prefix}/lib;${_prefix}/libexec\" -DCMAKE_INSTALL_PREFIX=${_prefix} -DCMAKE_BUILD_TYPE=Release -DSYSCONFDIR=${SERVICE_DIR}/etc -DMAN_INSTALLDIR=${_prefix}/share/man -DDOCDIR=${_prefix}/share/doc -DJOB_POOL_COMPILE=${CPUS} -DJOB_POOL_LINK=${CPUS} -DCMAKE_C_FLAGS=\"${CFLAGS}\" -DCMAKE_CXX_FLAGS=\"${CXXFLAGS}\" ${DEF_CONFIGURE_ARGS}"

                        if [ -x "${PREFIX}/bin/ninja" ]; then
                            run "${RM_BIN} -f CMakeCache.txt; ${_cmake_cmdline} -G\"Ninja\""
                            DEF_MAKE_METHOD="ninja -j${CPUS}"
                            DEF_INSTALL_METHOD="ninja install"

                        else # Makefiles:
                            run "${RM_BIN} -f CMakeCache.txt; ${_cmake_cmdline} -G\"Unix Makefiles\""
                            DEF_MAKE_METHOD="make -j${CPUS}"
                            DEF_INSTALL_METHOD="make install"

                        fi
                        unset _cmake_cmdline
                        ;;

                    *)
                        unset _pic_optional
                        if [ "${SYSTEM_NAME}" != "Darwin" ]; then
                            _pic_optional="--with-pic"
                        fi
                        _addon="CFLAGS='${CFLAGS}' CXXFLAGS='${CXXFLAGS}' LDFLAGS='${LDFLAGS}'"

                        # NOTE: Store `configure --help` outputs per definition (useful):
                        cache_conf_scrpt_hlp_opts "${_configure_options_log}"

                        if [ "${SYSTEM_NAME}" = "Linux" ]; then
                            # NOTE: No /Services feature implemented for Linux.
                            try "printf "%s\n" \"${DEF_CONFIGURE_METHOD}\" | ${GREP_BIN} \"configure\" >/dev/null 2>&1"
                            if [ "${?}" = "0" ]; then
                                # NOTE: by defaultautoconf configure accepts influencing variables as configure script params
                                try "${DEF_CONFIGURE_METHOD} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix} ${_pic_optional} ${_addon}" || \
                                try "${_addon} ${DEF_CONFIGURE_METHOD} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix} ${_pic_optional}" || \
                                try "${DEF_CONFIGURE_METHOD} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix} ${_addon}" || \
                                run "${_addon} ${DEF_CONFIGURE_METHOD} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix}"
                            else
                                try "${DEF_CONFIGURE_METHOD} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix} ${_addon}" || \
                                try "${_addon} ${DEF_CONFIGURE_METHOD} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix}" || \
                                try "${DEF_CONFIGURE_METHOD} ${DEF_CONFIGURE_ARGS} ${_addon}" || \
                                run "${_addon} ${DEF_CONFIGURE_METHOD} ${DEF_CONFIGURE_ARGS}" # Trust definition
                            fi
                        else
                            # do a simple check for "configure" in DEF_CONFIGURE_METHOD definition
                            # this way we can tell if we want to put configure options as params
                            printf "%s\n" "${DEF_CONFIGURE_METHOD}" | ${GREP_BIN} "configure" >/dev/null 2>&1
                            if [ "${?}" = "0" ]; then
                                # TODO: add --docdir=${_prefix}/docs
                                # NOTE: By default try to configure software with these options:
                                #   --sysconfdir=${SERVICE_DIR}/etc
                                #   --localstatedir=${SERVICE_DIR}/var
                                #   --runstatedir=${SERVICE_DIR}/run
                                #   --with-pic
                                # OPTIMIZE: TODO: XXX: use ./configure --help | grep option to
                                #      build configure options quickly
                                # try "${DEF_CONFIGURE_METHOD} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix} --sysconfdir=${SERVICE_DIR}/etc --localstatedir=${SERVICE_DIR}/var --runstatedir=${SERVICE_DIR}/run ${_pic_optional} ${_addon}" || \
                                # try "${_addon} ${DEF_CONFIGURE_METHOD} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix} --sysconfdir=${SERVICE_DIR}/etc --localstatedir=${SERVICE_DIR}/var --runstatedir=${SERVICE_DIR}/run ${_pic_optional}" || \
                                try "${DEF_CONFIGURE_METHOD} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix} --sysconfdir=${SERVICE_DIR}/etc --localstatedir=${SERVICE_DIR}/var ${_pic_optional} ${_addon}" || \
                                try "${_addon} ${DEF_CONFIGURE_METHOD} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix} --sysconfdir=${SERVICE_DIR}/etc --localstatedir=${SERVICE_DIR}/var ${_pic_optional}" || \
                                try "${DEF_CONFIGURE_METHOD} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix} --sysconfdir=${SERVICE_DIR}/etc --localstatedir=${SERVICE_DIR}/var ${_addon}" || \
                                try "${_addon} ${DEF_CONFIGURE_METHOD} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix} --sysconfdir=${SERVICE_DIR}/etc --localstatedir=${SERVICE_DIR}/var" || \
                                try "${DEF_CONFIGURE_METHOD} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix} --sysconfdir=${SERVICE_DIR}/etc ${_pic_optional} ${_addon}" || \
                                try "${_addon} ${DEF_CONFIGURE_METHOD} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix} --sysconfdir=${SERVICE_DIR}/etc ${_pic_optional}" || \
                                try "${DEF_CONFIGURE_METHOD} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix} --sysconfdir=${SERVICE_DIR}/etc ${_addon}" || \
                                try "${_addon} ${DEF_CONFIGURE_METHOD} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix} --sysconfdir=${SERVICE_DIR}/etc" || \
                                try "${DEF_CONFIGURE_METHOD} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix} ${_pic_optional} ${_addon}" || \
                                try "${_addon} ${DEF_CONFIGURE_METHOD} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix} ${_pic_optional}" || \
                                try "${DEF_CONFIGURE_METHOD} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix} ${_addon}" || \
                                run "${_addon} ${DEF_CONFIGURE_METHOD} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix}" # last two - only as a fallback

                            else # fallback again:
                                # NOTE: First - try to specify GNU prefix,
                                # then trust prefix given in software definition.
                                try "${DEF_CONFIGURE_METHOD} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix} ${_addon}" || \
                                try "${_addon} ${DEF_CONFIGURE_METHOD} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix}" || \
                                try "${DEF_CONFIGURE_METHOD} ${DEF_CONFIGURE_ARGS} ${_addon}" || \
                                run "${_addon} ${DEF_CONFIGURE_METHOD} ${DEF_CONFIGURE_ARGS}"
                            fi
                        fi
                        ;;
                esac

                debug "Gathering configuration output logs…"
                try "${INSTALL_BIN} \"${_configure_log}\" \"${_configure_status_log}\" >/dev/null"
                try "${INSTALL_BIN} \"${_cmake_out_log}\" \"${_cmake_config_log}\" >/dev/null"
                try "${INSTALL_BIN} \"${_cmake_error_log}\" \"${_cmake_config_log}.error\" >/dev/null"

                cd "${_pwd}"
                try after_configure_callback
                cd "${_pwd}"
                after_configure_snapshot
            else
                error "These values cannot be empty: BUILD_DIR, BUILD_NAMESUM"
            fi

            # and common part between normal and continue modes:
            cd "${_pwd}"
            note "   ${NOTE_CHAR} Building requirement: $(distn "${_app_param}"), version: $(distn "${DEF_VERSION}")"
            run "${DEF_MAKE_METHOD}"

            cd "${_pwd}"
            try after_make_callback
            cd "${_pwd}"
            after_make_snapshot


            # OTE: after successful make, invoke "make test" by default:
            unset _this_test_skipped
            if [ -n "${DEF_SKIPPED_DEFINITION_TEST}" ]; then
                debug "Defined DEF_SKIPPED_DEFINITION_TEST: $(distd "${DEF_SKIPPED_DEFINITION_TEST}")"
                printf "%s\n" " ${DEF_SKIPPED_DEFINITION_TEST} " 2>/dev/null | ${EGREP_BIN} " ${_app_param} " >/dev/null 2>/dev/null && \
                    note "   ${NOTE_CHAR} Skipped tests for definition of: $(distn "${_app_param}")" && \
                        _this_test_skipped=1
            fi

            if [ -z "${USE_NO_TEST}" ] && [ -z "${_this_test_skipped}" ]; then
                note "   ${NOTE_CHAR} Testing requirement: $(distn "${_app_param}"), version: $(distn "${DEF_VERSION}")"
                cd "${_pwd}"

                # NOTE: mandatory on production machines:
                test_and_rate_def "${_app_param}" "${DEF_TEST_METHOD}"
            else
                note "   ${WARN_CHAR} Tests for definition: $(distn "${_app_param}") skipped on demand"
            fi
            cd "${_pwd}"
            try after_test_callback
            cd "${_pwd}"
            after_test_snapshot

            debug "Cleaning man dir from previous dependencies, we want to install man pages that belong to LAST requirement which is app bundle itself"
            for place in man share/man share/info share/doc share/docs; do
                if [ -e "${_prefix}/${place}" ]; then
                    try "${RM_BIN} -rf '${_prefix}/${place}'"
                fi
            done

            cd "${_pwd}"
            note "   ${NOTE_CHAR} Installing requirement: $(distn "${_app_param}"), version: $(distn "${DEF_VERSION}")"
            run "${DEF_INSTALL_METHOD}"

            cd "${_pwd}"
            try after_install_callback
            cd "${_pwd}"
            after_install_snapshot

            cd "${_pwd}"
            run "printf '%s' \"${DEF_VERSION}\" > ${_prefix}/${_app_param}${DEFAULT_INST_MARK_EXT}" && \
                debug "Stored version: $(distd "${DEF_VERSION}") of software: $(distd "${DEF_NAME}") installed in: $(distd "${_prefix}")"

            cd "${_cwd}" 2>/dev/null
            unset _cwd _addon _dsname _bund
        fi
    else

        note "   ${WARN_CHAR} Requirement preinstalled: $(distn "${_req_defname}") on: $(distn "${SYSTEM_NAME}") platforms"
        if [ ! -d "${_prefix}" ]; then # case when disabled requirement is first on list of dependencies
            create_software_dir "${_prefix##*/}"
        fi
        _dis_def="${_prefix}/${_req_defname}${DEFAULT_INST_MARK_EXT}"
        run "printf '%s' \"${DEFAULT_REQ_OS_PROVIDED}\" > ${_dis_def}"
    fi
    unset _current_branch _dis_def _req_defname _app_param _prefix _bundlnm

    # TODO: reset env here?
}


test_and_rate_def () {
    # $1 => name of definition
    _name="${1}"
    shift
    _cmdline="${*}"

    case "${_cmdline}" in
        :|true|false|disable|disabled|skip|no|NO|off|OFF)
            return 0
            ;;

        *)
            if [ -z "${_name}" ]; then
                return 0
            fi

            debug "Initializing test for: $(distd "${_name}")"
            local_test_result () {
                case "${1}" in
                    passed)
                        run "${TOUCH_BIN} '${PREFIX}/${_name}.test.passed' && ${RM_BIN} -f '${PREFIX}/${_name}.test.failed'"
                        ;;

                    *)
                        run "${TOUCH_BIN} '${PREFIX}/${_name}.test.failed' && ${RM_BIN} -f '${PREFIX}/${_name}.test.passed'"
                        ;;
                esac
            }

            local_test_env_dispatch () {
                _start_time="$(${DATE_BIN} +%F-%H%M-%s 2>/dev/null)"
                printf "%s\n" \
                    "Test for ${_name} started at: ${TIMESTAMP}" >> "${PREFIX}/${_name}.test.log" 2>> "${PREFIX}/${_name}.test.log"
                run_tests () {
                    eval "\
                        TEST_JOBS=\"${CPUS:-6}\" \
                        TEST_ENV=\"${DEF_TEST_ENV:-test}\" \
                        PATH=\"${SERVICE_DIR}/bin:${PREFIX}/bin:${PREFIX}/sbin:${SERVICE_DIR}/bin:${SERVICE_DIR}/sbin:${PREFIX}/libexec:${SOFIN_UTILS_PATH}:/bin:/usr/bin\" \
                        LD_LIBRARY_PATH=\"${PREFIX}/lib:${PREFIX}/libexec:${SERVICE_DIR}/lib\" \
                        DYLD_LIBRARY_PATH=\"${PREFIX}/lib:${PREFIX}/libexec:${SERVICE_DIR}/lib\" \
                        ${_cmdline}" \
                            >> "${PREFIX}/${_name}.test.log" \
                            2>> "${PREFIX}/${_name}.test.log"
                }

                run_tests
                _tests_result_errcode="${?}"

                _end_time="$(${DATE_BIN} +%F-%H%M-%s 2>/dev/null)"
                printf "%s\n" \
                    "Test for ${_name} finished at: ${_end_time}" >> "${PREFIX}/${_name}.test.log" 2>> "${PREFIX}/${_name}.test.log"

                unset _test_command _end_time _start_time
                return ${_result}
            }
            ;;
    esac

    debug "Invoking software check/test: $(distd "${_name}") [DEF_TEST_METHOD='$(distd "${_cmdline}")']"
    local_test_env_dispatch \
        && local_test_result passed \
        && return 0

    local_test_result failed
    return 1
}
