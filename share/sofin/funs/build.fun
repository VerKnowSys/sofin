#!/usr/bin/env sh

build_bundle () {
    _bsbname="${1}"
    _bsbelement="${2}"
    _bsversion="${3}"
    if [ -z "${_bsbname}" ]; then
        error "First argument with ${ColorDistinct}BundleName${ColorError} is required!"
    fi
    if [ -z "${_bsbelement}" ]; then
        error "Second argument with ${ColorDistinct}element-name${ColorError} is required!"
    fi
    if [ -z "${_bsversion}" ]; then
        error "Third argument with ${ColorDistinct}version-string${ColorError} is required!"
    fi
    debug "build_bundle: ${ColorDistinct}${_bsbname}${ColorDebug}, should be in: ${ColorDistinct}${SOFTWARE_DIR}/${_bsbname}${ColorDebug}, full-name: ${ColorDistinct}${_bsbelement}${ColorDebug}"
    if [ ! -d "${SOFTWARE_DIR}/${_bsbname}" ]; then
        create_software_dir "${_bsbname}"
        create_software_bundle_archive "${_bsbname}" "${_bsbelement}" "${_bsversion}"
    else
        if [ ! -f "${FILE_CACHE_DIR}${_bsbelement}" ]; then
            debug "Found incomplete or damaged bundle file. Rebuilding: ${ColorDistinct}${_bsbelement}${ColorDebug}"
            try "${RM_BIN} -f '${FILE_CACHE_DIR}${_bsbelement}'"
            create_software_bundle_archive "${_bsbname}" "${_bsbelement}" "${_bsversion}"
        else
            debug "Found already existing bundle stream in file-cache: ${ColorDistinct}${FILE_CACHE_DIR}${_bsbelement}${ColorDebug}"

            # NOTE: Let's move old one, make a shasum difference, if different => overwrite
            _cached_copy="${FILE_CACHE_DIR}${_bsbelement}${DEFAULT_CHKSUM_EXT}.old"
            try "${MV_BIN} -f '${FILE_CACHE_DIR}${_bsbelement}' '${FILE_CACHE_DIR}${_bsbelement}.old' ; ${MV_BIN} -f '${FILE_CACHE_DIR}${_bsbelement}${DEFAULT_CHKSUM_EXT}' '${_cached_copy}'" \
                && debug "Old bundle stream, was temporarely moved."
            create_software_bundle_archive "${_bsbname}" "${_bsbelement}" "${_bsversion}"
            if [ -f "${FILE_CACHE_DIR}${_bsbelement}" ]; then
                _newsum="$(file_checksum "${FILE_CACHE_DIR}${_bsbelement}")"
                _oldsum="$(${CAT_BIN} "${_cached_copy}" 2>/dev/null)"
                debug "Comparing shasum of most recent stream and one from previous stream. Old-sum: ${ColorDistinct}${_oldsum}${ColorDebug}, new-sum: ${ColorDistinct}${_newsum}${ColorDebug}"
                if [ "${_oldsum}" = "${_newsum}" ]; then
                    try "${MV_BIN} -f '${FILE_CACHE_DIR}${_bsbelement}.old' '${FILE_CACHE_DIR}${_bsbelement}' ; ${MV_BIN} -f '${_cached_copy}' '${FILE_CACHE_DIR}${_bsbelement}${DEFAULT_CHKSUM_EXT}'" \
                        && debug "Checksums match! Upload unnecessary! Previous cache stream file was restored."
                else
                    try "${RM_BIN} -f '${FILE_CACHE_DIR}${_bsbelement}.old' '${_cached_copy}'" \
                        && debug "Checksum didn't match. New stream will be used to upload bundle stream. Previous cache stream file was removed."
                fi
            fi
        fi
    fi
    unset _bsbname _bsbelement
}


push_binbuilds () {
    _push_bundles="${*}"
    if [ -z "${_push_bundles}" ]; then
        error "At least single argument with ${ColorDistinct}BundleName${ColorError} to push is required!"
    fi
    for _pbelement in $(to_iter "${_push_bundles}"); do
        _pblowercase_element="$(lowercase "${_pbelement}")"
        _pbelement="$(capitalize "${_pblowercase_element}")"
        if [ -z "${_pblowercase_element}" ]; then
            error "Lowercase bundle name is empty!"
        fi
        _pbinstall_indicator_file="${SOFTWARE_DIR}/${_pbelement}/${_pblowercase_element}${DEFAULT_INST_MARK_EXT}"
        _pbbversion_element="$(${CAT_BIN} "${_pbinstall_indicator_file}" 2>/dev/null)"
        debug "Push: ${_pblowercase_element} indicator: ${_pbinstall_indicator_file}, version: ${_pbbversion_element}"
        if [ ! -f "${_pbinstall_indicator_file}" ]; then
            error "Bundle install indicator: ${ColorDistinct}${_pbinstall_indicator_file}${ColorError} doesn't exist!"
        fi
        if [ -n "${_pbelement}" ] \
        && [ -d "${SOFTWARE_DIR}/${_pbelement}" ] \
        && [ -n "${_pbbversion_element}" ]; then
            debug "About to push: ${ColorDistinct}${_pbelement}${ColorDebug}, install-indicator: ${ColorDistinct}${_pbinstall_indicator_file}${ColorDebug}, soft-version: ${ColorDistinct}${_pbbversion_element}${ColorDebug}"
            push_to_all_mirrors "${_pbelement}" "${_pbbversion_element}"
        else
            error "Push validations failed for bundle: ${ColorDistinct}${_pbelement}${ColorError}! It might not be fully installed or broken."
        fi
    done
}



fetch_binbuild () {
    _fbb_bundname="${1}"
    _bb_archive="${2}"
    if [ -n "${USE_BINBUILD}" ]; then
        debug "Binary build check was skipped since USE_BINBUILD has a value: ${ColorDistinct}${USE_BINBUILD}${ColorDebug}"
    else
        if [ -z "${_fbb_bundname}" ]; then
            error "Cannot fetch binbuild! An empty ${ColorDistinct}BunndleName${ColorError} given!"
        fi
        if [ -z "${_bb_archive}" ]; then
            error "Cannot fetch binbuild! An empty ${ColorDistinct}file-archive-name${ColorError} given!"
        fi
        try "${MKDIR_BIN} -p '${FILE_CACHE_DIR}'"
        if [ ! -e "${FILE_CACHE_DIR}${_bb_archive}${DEFAULT_CHKSUM_EXT}" ]; then
            printf "%b" "${ColorBlue}" >&2
            eval "${FETCH_BIN} ${FETCH_OPTS} -o ${FILE_CACHE_DIR}${_bb_archive}${DEFAULT_CHKSUM_EXT} ${MAIN_BINARY_REPOSITORY}${OS_TRIPPLE}/${_bb_archive}${DEFAULT_CHKSUM_EXT}"
            if [ "${?}" = "0" ]; then
                eval "${FETCH_BIN} ${FETCH_OPTS} -o ${FILE_CACHE_DIR}${_bb_archive} ${MAIN_BINARY_REPOSITORY}${OS_TRIPPLE}/${_bb_archive}" \
                    || error "Failure fetching available binary build for: ${ColorDistinct}${_bb_archive}${ColorError}. Please check your network setup!"
            else
                permnote "No binary build available: ${ColorDistinct}${_bb_archive}${ColorNote}"
            fi
        fi

        if [ -e "${FILE_CACHE_DIR}${_bb_archive}" ]; then
            debug "BB-archive: ${ColorDistinct}${_bb_archive}${ColorDebug}. Expecting binbuild to be available in: ${ColorDistinct}${FILE_CACHE_DIR}${_bb_archive}${ColorDebug}"
            validate_archive_sha1 "${FILE_CACHE_DIR}${_bb_archive}" # NOTE: removes the archive if checksum doesn't match
        fi
        if [ -e "${FILE_CACHE_DIR}${_bb_archive}" ]; then
            install_software_from_binbuild "${_bb_archive}" "${_fbb_bundname}"
        else
            debug "Binary build unavailable for bundle: ${ColorDistinct}${_fbb_bundname}${ColorDebug}"
            if [ -n "${CAP_SYS_PRODUCTION}" ]; then
                warn "Prebuilt software bundle is not available for current system! Building from source is enabled only on Sofin build-hosts."
                finalize_complete_standard_task
            fi
        fi
    fi
    unset _fbb_bundname _fbb_bundname _bb_archive
}


load_pax_file () {
    if [ -n "${CAP_SYS_PRODUCTION}" ]; then
        _paxfile="${PREFIX}/.pax"
        if [ -f "${_paxfile}" ]; then
            debug "Loading .pax file: ${ColorDistinct}${_paxfile}${ColorDebug}"
            try ". ${_paxfile}"
        fi
        unset _paxfile
    fi
}


# NOTE: build() - bundle build
build () {
    _build_list="${*}"

    # set system performance to max values
    # unused since the arm64 build host is done via qemu where you get max performance OOTB
    # performance max

    # Update definitions and perform more checks
    if [ -n "${CAP_SYS_BUILDHOST}" ]; then
        load_sysctl_buildhost_hardening
        validate_kern_loaded_dtrace
    fi
    validate_sys_limits

    # store_security_state
    # disable_security_features

    debug "Sofin v${ColorDistinct}${SOFIN_VERSION}${ColorDebug}: New build started for bundles: ${ColorDistinct}${_build_list}${ColorDebug}"
    env_reset # NOTE: unset inherited variables (like CDPATH) before the first bundle is built
    for _bund_name in $(to_iter "${_build_list}"); do
        _bund_name="${(L)_bund_name}"
        _bund_name="${_bund_name%=*}" # cut the version if specified using Bundlename=1.2.3
        _bund_name_capit="${(U)_bund_name[1]}${_bund_name[2,-1]}"
        load_defaults
        load_defs "${_bund_name}"
        validate_loaded_def
        if [ "${CURRENT_DEFINITION_DISABLED}" = "YES" ]; then
            warn "Bundle: ${ColorDistinct}${_bund_name_capit}${ColorWarning} is disabled on: ${ColorDistinct}${OS_TRIPPLE}${ColorWarning}"
            destroy_software_dir "${_bund_name_capit}"
            continue
        else
            create_software_dir "${_bund_name_capit}"
            for _req_name in ${DEFINITIONS_DIR}/${_bund_name}${DEFAULT_DEF_EXT}; do
                unset CURRENT_DEFINITION_SKIP_BUILD_DO_EXPORTS
                # NOTE: the definition was loaded above already (load_defaults + load_defs)
                debug "Reading definition: ${ColorDistinct}${_req_name}${ColorDebug}"
                pretouch_logs "${DEF_REQUIREMENTS}"

                # NOTE: feature to specify custom version of bundle to install via: `s i Rust=1.31.1`:
                if [ -n "${CURRENT_DEFINITION_VERSION_OVERRIDE}" ]; then
                    DEF_VERSION="${CURRENT_DEFINITION_VERSION_OVERRIDE}"
                    debug "Bundle: ${ColorDistinct}${_bund_name_capit}${ColorDebug} version override: ${ColorDistinct}${DEF_VERSION}${ColorDebug}"
                fi

                # Note: this acutally may break definitions like ImageMagick..
                #_bund_lcase="$(lowercase "${DEF_NAME}${DEF_SUFFIX}")"
                _bund_lcase="${DEF_NAME}${DEF_SUFFIX}"
                _bundl_name="${(U)_bund_lcase[1]}${(L)_bund_lcase[2,-1]}"
                DEF_NAME="${_bundl_name}"

                # if definition requires root privileges, throw an "exception":
                if [ -n "${DEF_REQUIRE_ROOT_ACCESS}" ]; then
                    if [ "${USER}" != "root" ]; then
                        error "Definition requires superuser priviledges: ${ColorDistinct}${_bund_lcase}${ColorError}. Installation aborted."
                    fi
                fi

                # normally definition is NOT Sofin internal utility:
                if [ -z "${DEF_UTILITY_BUNDLE}" ]; then
                    PREFIX="${SOFTWARE_DIR}/${_bundl_name}"
                    SERVICE_DIR="${SERVICES_DIR}/${_bundl_name}"
                    BUILD_NAMESUM="$(firstn "$(text_checksum "${_bund_lcase}-${DEF_VERSION}")")"
                    BUILD_DIR="${PREFIX}/${DEFAULT_SRC_EXT}${BUILD_NAMESUM}"

                else # Sofin private utility build:
                    debug "Bundle: ${ColorDistinct}${_bundl_name}${ColorDebug} is to be built as Sofin private prefix: ${ColorDistinct}${PREFIX}${ColorDebug}!"
                fi

                # These values has to be exported because external build mechanisms
                # has to be able to reach these values to find dependencies and utilities
                export PREFIX
                export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig"
                export PATH="${DEFAULT_SHELL_EXPORTS}:${SERVICE_DIR}/bin:${PREFIX}/bin:${PREFIX}/sbin:${SERVICE_DIR}/sbin:${DEFAULT_PATH}"
                if [ -n "${DEF_USE_TOOLS}" ]; then
                    export PATH="${DEFAULT_SHELL_EXPORTS}:${SERVICE_DIR}/bin:${PREFIX}/bin:${PREFIX}/sbin:${SOFIN_UTILS_PATH}:${SERVICE_DIR}/sbin:${DEFAULT_PATH}"
                    debug "Using tools: ${ColorDistinct}yes${ColorDebug}. Path=${ColorDistinct}${PATH}${ColorDebug}"
                else
                    debug "Using tools: ${ColorRed:-${ColorDistinct}}no${ColorDebug}"
                fi

                if [ -z "${DEF_UTILITY_BUNDLE}" ]; then
                    # NOTE: standalone definition has own SERVICES_DIR/Bundlename/ prefix
                    if [ -n "${DEF_STANDALONE}" ]; then
                        debug "${ColorDistinct}try_fetch_service_dir()${ColorDebug} for bundle: ${ColorDistinct}${_bundl_name}${ColorDebug} v${ColorDistinct}${DEF_VERSION}${ColorDebug}"
                        try_fetch_service_dir "${_bundl_name}" "${DEF_VERSION}"
                        debug "${ColorDistinct}create_service_dataset()${ColorDebug} for bundle: ${ColorDistinct}${_bundl_name}${ColorDebug}"
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
                            debug "${ColorDistinct}${_bundl_name}${ColorDebug} bundle is installed with version: ${ColorDistinct}${_already_installed_version}${ColorDebug}"
                        else
                            error "${ColorDistinct}${_bundl_name}${ColorError} bundle is installed with version: ${ColorDistinct}${_already_installed_version}${ColorError}, different from found in definition: ${ColorDistinct}${DEF_VERSION}${ColorError}. Aborting!"
                        fi
                        CURRENT_DEFINITION_SKIP_BUILD_DO_EXPORTS=YES
                        unset _already_installed_version
                    fi

                    if [ -n "${CAP_SYS_PRODUCTION}" ]; then
                        debug "Production mode enabled. Software build skipped!"
                        CURRENT_DEFINITION_SKIP_BUILD_DO_EXPORTS=YES
                    fi
                fi

                if [ -z "${CURRENT_DEFINITION_SKIP_BUILD_DO_EXPORTS}" ]; then
                    # NOTE: It's necessary to create build dir *after* binbuild check (which may create dataset itself)
                    create_builddir "${_bundl_name}" "${BUILD_NAMESUM}"
                    if [ -z "${DEF_REQUIREMENTS}" ]; then
                        permnote "Details: ${ColorDistinct}${DEF_FULL_NAME:-${DEF_NAME}${DEF_SUFFIX}}${ColorNote}, version: ${ColorDistinct}${DEF_VERSION}${ColorNote}"
                    else
                        permnote "Details: ${ColorDistinct}${DEF_FULL_NAME:-${DEF_NAME}${DEF_SUFFIX}}${ColorNote}, version: ${ColorDistinct}${DEF_VERSION}${ColorNote}, with requirements: ${ColorDistinct}${DEF_REQUIREMENTS}${ColorNote}"
                    fi
                    _req_amount="$(printf "%b\n" "${DEF_REQUIREMENTS}" | ${AWK_BIN} '{print NF;}' 2>/dev/null)"
                    _req_amount=$(( ${_req_amount} + 1 ))
                    _req_all="${_req_amount}"
                    for _req in $(to_iter "${DEF_REQUIREMENTS}"); do
                        if [ -n "${DEF_USER_INFO}" ]; then
                            warn "NOTICE: ${DEF_USER_INFO}"
                        fi
                        if [ -z "${_req}" ]; then
                            note "No additional requirements defined"
                            break
                        else
                            permnote "  ${ColorDistinct}${_req}${ColorNote} (${ColorDistinct}${_req_amount}${ColorNote} of ${ColorDistinct}${_req_all}${ColorNote} remaining)"
                            if [ ! -f "${PREFIX}/${_req}${DEFAULT_INST_MARK_EXT}" ]; then
                                BUNDLE_REQ_MODIFIED=YES
                                process_flat "${_req}" "${PREFIX}"
                            fi
                        fi
                        _req_amount=$(( ${_req_amount} - 1 ))
                    done
                fi

                if [ -z "${CURRENT_DEFINITION_SKIP_BUILD_DO_EXPORTS}" ]; then
                    if [ -e "${PREFIX}/${_bund_lcase}${DEFAULT_INST_MARK_EXT}" ]; then
                        if [ "${BUNDLE_REQ_MODIFIED}" = "YES" ]; then
                            unset BUNDLE_REQ_MODIFIED
                            warn "  ${NOTE_CHAR} Modified requirements of defintion: ${ColorDistinct}${_bund_lcase}${ColorWarning}. Rebuilding${CHAR_DOTS}"
                            permnote "  ${ColorDistinct}${_bund_lcase}${ColorNote} (${ColorDistinct}1${ColorNote} of ${ColorDistinct}${_req_all}${ColorNote})"
                            process_flat "${_bund_lcase}" "${PREFIX}" \
                                && mark_installed "${DEF_NAME}${DEF_SUFFIX}" "${DEF_VERSION}" \
                                && show_done "${DEF_NAME}${DEF_SUFFIX}"
                        else
                            permnote "  ${ColorDistinct}${_bund_lcase}${ColorNote} (${ColorDistinct}1${ColorNote} of ${ColorDistinct}${_req_all}${ColorNote})"
                            show_done "${DEF_NAME}${DEF_SUFFIX}"
                        fi
                    else
                        permnote "  ${ColorDistinct}${_bund_lcase}${ColorNote} (${ColorDistinct}1${ColorNote} of ${ColorDistinct}${_req_all}${ColorNote})"
                        process_flat "${_bund_lcase}" "${PREFIX}" \
                            && mark_installed "${DEF_NAME}${DEF_SUFFIX}" "${DEF_VERSION}" \
                            && permnote "${ColorDistinct}${SUCCESS_CHAR}${ColorNote} ${ColorDistinct}${_bund_name_capit}${ColorNote} [${ColorCyan:-${ColorDistinct}}${DEF_VERSION}${ColorNote}]"
                    fi
                fi
            done
        fi

        export_binaries "${_bund_lcase}"
        load_pax_file

        if [ "Darwin" = "${SYSTEM_NAME}" ]; then
            if [ ! -f "/etc/sudoers.d/sofin" ]; then
                permnote "Clearing the quarantine flag from: ${ColorDistinct}${PREFIX}/*${ColorNote}"
            fi
            sudo xattr -r -d com.apple.quarantine "${PREFIX}/" 2>> "${LOG}-${DEF_NAME}${DEF_SUFFIX}"
        fi

        # NOTE: strip before after-export callback - stripping rewrites the binaries,
        #       which invalidates code signatures done in callbacks (f.e. entitlements on Darwin):
        if [ "YES" = "${CAP_SYS_BUILDHOST}" ] \
        && [ -z "${DEBUGBUILD}" ]; then
            strip_bundle "${_bund_name_capit}"
        fi

        try after_export_callback
        try after_export_snapshot

        if [ "YES" = "${CAP_SYS_BUILDHOST}" ]; then
            if [ -n "${DEF_UTILITY_BUNDLE}" ]; then
                try "${RM_BIN} -rf '${PREFIX}/include' '${PREFIX}/doc' ${PREFIX}/${DEFAULT_SRC_EXT}*"
                debug "Utility bundle: ${ColorDistinct}${_bund_name_capit}${ColorDebug} build completed!"
                link_utilities
            fi

            debug "Afterbuild for bundle: ${ColorDistinct}${_bund_name_capit}${ColorDebug}"
            finalize_afterbuild_tasks_for_bundle "${_bund_name_capit}"

            if [ -z "${DEBUGBUILD}" ]; then
                afterbuild_manage_files_of_bundle
            fi

            validate_pie_on_exports "${_bund_name_capit}"
            validate_bins_links "${_bund_name_capit}"
            validate_libs_links "${_bund_name_capit}"

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
                    printf "%b\n\n" '#!/bin/sh' > "${_paxfile}"
                    if [ "YES" = "${CAP_SYS_ZFS}" ]; then
                        _dataset_parent="${DEFAULT_ZPOOL}/Software/${SYSTEM_DATASET}"
                        _dataset="${_dataset_parent}/${_bund_name_capit}"

                        # NOTE: Make sure readonly is put down to the .pax file!
                        {
                            printf "%b\n" "${ZFS_BIN} set readonly=off '${_dataset_parent}'";
                            printf "%b\n" "${ZFS_BIN} inherit readonly '${_dataset}'";
                        } >> "${_paxfile}"
                    fi

                    debug "Write HardenedBSD feature override capability file: ${ColorDistinct}${_paxfile}${ColorDebug} with disabled features: ${ColorDistinct}${_disable}${ColorDebug}, for binaries: ${ColorDistinct}${DEF_APPLY_LOWER_SECURITY_ON}${ColorDebug}"
                    for _lower_security_binary in $(to_iter "${DEF_APPLY_LOWER_SECURITY_ON}"); do
                        for _feature in $(to_iter "${_disable}"); do
                            _files="$(${FIND_BIN} "${PREFIX}/" -name "${_lower_security_binary}" -type f 2>/dev/null)"
                            for _file in $(to_iter "${_files}"); do
                                if [ -x "${_file}" ]; then
                                    try "${FILE_BIN} '${_file}' | ${GREP_BIN} -F 'ELF 64-bit'"
                                    if [ "0" = "${?}" ]; then
                                        # Lower security on requested binary:
                                        try "${HBSDCONTROL_BIN} pax disable ${_feature} '${_file}'"
                                        # + Store copy of a command to "${PREFIX}/.pax" file - will be invoked on each boot:
                                        printf "%b\n" "${HBSDCONTROL_BIN} pax disable ${_feature} '${_file}'" >> "${_paxfile}"
                                    fi
                                fi
                            done
                        done
                    done

                    if [ "YES" = "${CAP_SYS_ZFS}" ]; then
                        printf "%b\n" "${ZFS_BIN} set readonly=on '${_dataset_parent}'" >> "${_paxfile}"
                    fi
                fi
            fi
        fi

        if [ "YES" = "${CAP_SYS_ZFS}" ]; then
            _dataset_parent="${DEFAULT_ZPOOL}/Software/${SYSTEM_DATASET}"
            _dataset="${_dataset_parent}/${_bund_name_capit}"

            debug "Creating post build '${ColorDistinct}@${ORIGIN_ZFS_SNAP_NAME}${ColorDebug}' snapshots${CHAR_DOTS}"
            create_origin_snaphots

            debug "Setting dataset: ${ColorDistinct}${_dataset}${ColorDebug} to inherit 'readonly' attribute from readonly parent: ${ColorDistinct}${_dataset_parent}${ColorDebug}"
            try "${ZFS_BIN} set readonly=off '${_dataset_parent}'"
            try "${ZFS_BIN} inherit readonly '${_dataset}'"
        else
            try "${RM_BIN} -rf ${SOFTWARE_DIR}/${_bund_name_capit}/${DEFAULT_SRC_EXT}*"
        fi

    done

    unset _build_list _bund_lcase _req_all _req _disable _feature _file _files _bund_name_capit _dataset
    env_reset
    return 0
}


dump_debug_info () {
    debug "CPUS: (inUse/Total): (${ColorDistinct}${CPUS}${ColorDebug}/${ColorDistinct}${ALL_CPUS}${ColorDebug})"
    debug "PREFIX: '${ColorDistinct}${PREFIX}${ColorDebug},  PATH: '${ColorDistinct}${PATH}${ColorDebug}'"
    debug "SERVICE_DIR: '${ColorDistinct}${SERVICE_DIR}${ColorDebug},  CURRENT_DIR: '${ColorDistinct}$(${PWD_BIN} 2>/dev/null)${ColorDebug}'"
    debug "BUILD_DIR: '${ColorDistinct}${BUILD_DIR}${ColorDebug},  BUILD_NAMESUM: '${ColorDistinct}${BUILD_NAMESUM}${ColorDebug}'"
    debug "FETCH_BIN: '${ColorDistinct}${FETCH_BIN}${ColorDebug},  FETCH_OPTS: '${ColorDistinct}${FETCH_OPTS}${ColorDebug}'"
    if [ "Darwin" = "${SYSTEM_NAME}" ]; then
        debug "DYLD_LIBRARY_PATH: '${ColorDistinct}${DYLD_LIBRARY_PATH}${ColorDebug}',  LD_PRELOAD: '${ColorDistinct}${LD_PRELOAD}${ColorDebug}'"
    else
        debug "LD_LIBRARY_PATH: '${ColorDistinct}${LD_LIBRARY_PATH}${ColorDebug}',  LD_PRELOAD: '${ColorDistinct}${LD_PRELOAD}${ColorDebug}'"
    fi
    debug "CC: '${ColorDistinct}${CC}${ColorDebug},  CXX: '${ColorDistinct}${CXX}${ColorDebug},  CPP: '${ColorDistinct}${CPP}${ColorDebug}'"
    debug "LD: '${ColorDistinct}${LD}${ColorDebug},  NM: '${ColorDistinct}${NM}${ColorDebug},  AR: '${ColorDistinct}${AR}${ColorDebug}',  AS: '${ColorDistinct}${AS}${ColorDebug},  RANLIB: '${ColorDistinct}${RANLIB}${ColorDebug}'"
    debug "DEF_COMPILER_FLAGS: '${ColorDistinct}${DEF_COMPILER_FLAGS}${ColorDebug}'"
    debug "DEF_LINKER_FLAGS: '${ColorDistinct}${DEF_LINKER_FLAGS}${ColorDebug}'"
    debug "CFLAGS: '${ColorDistinct}${CFLAGS}${ColorDebug}'"
    debug "CXXFLAGS: '${ColorDistinct}${CXXFLAGS}${ColorDebug}'"
    debug "LDFLAGS: '${ColorDistinct}${LDFLAGS}${ColorDebug}'"
    debug "DEF_CONFIGURE_METHOD: '${ColorDistinct}${DEF_CONFIGURE_METHOD}${ColorDebug}',  DEF_CONFIGURE_ARGS: '${ColorDistinct}${DEF_CONFIGURE_ARGS}${ColorDebug}'"
    debug "DEF_MAKE_METHOD: '${ColorDistinct}${DEF_MAKE_METHOD}${ColorDebug}',  MAKE_OPTS: '${ColorDistinct}${MAKE_OPTS}${ColorDebug}'"
    debug "DEF_TEST_METHOD: '${ColorDistinct}${DEF_TEST_METHOD}${ColorDebug}'"
    debug "DEF_INSTALL_METHOD: '${ColorDistinct}${DEF_INSTALL_METHOD}${ColorDebug}'"

    if [ -n "${DEF_AFTER_UNPACK_METHOD}" ]; then
        debug "DEF_AFTER_UNPACK_METHOD: '${ColorDistinct}${DEF_AFTER_UNPACK_METHOD}${ColorDebug}'"
    fi
    if [ -n "${DEF_AFTER_PATCH_METHOD}" ]; then
        debug "DEF_AFTER_PATCH_METHOD: '${ColorDistinct}${DEF_AFTER_PATCH_METHOD}${ColorDebug}'"
    fi
    if [ -n "${DEF_AFTER_CONFIGURE_METHOD}" ]; then
        debug "DEF_AFTER_CONFIGURE_METHOD: '${ColorDistinct}${DEF_AFTER_CONFIGURE_METHOD}${ColorDebug}'"
    fi
    if [ -n "${DEF_AFTER_MAKE_METHOD}" ]; then
        debug "DEF_AFTER_MAKE_METHOD: '${ColorDistinct}${DEF_AFTER_MAKE_METHOD}${ColorDebug}'"
    fi
    if [ -n "${DEF_AFTER_INSTALL_METHOD}" ]; then
        debug "DEF_AFTER_INSTALL_METHOD: '${ColorDistinct}${DEF_AFTER_INSTALL_METHOD}${ColorDebug}'"
    fi
    if [ -n "${DEF_AFTER_EXPORT_METHOD}" ]; then
        debug "DEF_AFTER_EXPORT_METHOD: '${ColorDistinct}${DEF_AFTER_EXPORT_METHOD}${ColorDebug}'"
    fi
}


process_flat () {
    _definition_name="${(L)1}"
    _prefix="${2}"
    _bundlnm="${(U)_definition_name[1]}${_definition_name[2,-1]}"
    if [ -z "${_definition_name}" ]; then
        error "First argument with ${ColorDistinct}requirement-name${ColorError} is required!"
    fi
    if [ -z "${_prefix}" ]; then
        error "Second argument with ${ColorDistinct}/Software/PrefixDir${ColorError} is required!"
    fi
    if [ -z "${_bundlnm}" ]; then
        error "Third argument with ${ColorDistinct}BundleName${ColorError} is required!"
    fi
    _req_definition="${DEFINITIONS_DIR}/${_definition_name}${DEFAULT_DEF_EXT}"
    if [ ! -e "${_req_definition}" ]; then
        error "Cannot read definition file: ${ColorDistinct}${_req_definition}${ColorError}!"
    fi
    _req_defname="${${_req_definition##*/}%%.*}"
    debug "Process requirement: ${ColorDistinct}${_req_defname}${ColorDebug} from definition: ${ColorDistinct}${_req_definition}${ColorDebug} for bundle with PREFIX: ${ColorDistinct}${_prefix}${ColorDebug}"

    # XXX: FIXME: OPTIMIZE: Each definition read twice... log bloat & shit
    # NOTE: Because compiler_setup() uses DEF_* from definition file to
    #       setup correct environment for build process..
    load_defaults
    load_defs "${_req_definition}"
    validate_loaded_def

    # Setup compiler features and options for given definition
    compiler_setup

    # NOTE: ..load definition again, because each definition can also alter
    #       it's build environment values (flexibility, KISS)
    load_defs "${_req_definition}"

    PATH="${DEFAULT_SHELL_EXPORTS}:${SERVICE_DIR}/bin:${SERVICE_DIR}/sbin:${_prefix}/bin:${_prefix}/sbin:${DEFAULT_PATH}"
    if [ -n "${DEF_USE_TOOLS}" ]; then
        debug "Suffixing path: ${ColorDistinct}${SOFIN_UTILS_PATH}${ColorDebug} to local build path!"
        PATH="${DEFAULT_SHELL_EXPORTS}:${SERVICE_DIR}/bin:${SERVICE_DIR}/sbin:${_prefix}/bin:${_prefix}/sbin:${SOFIN_UTILS_PATH}:${DEFAULT_PATH}"
        if [ "Darwin" = "${SYSTEM_NAME}" ]; then
            # XXX: use Rust from local installation on workstations
            if [ -d "${HOME}/.cargo/bin" ]; then
                PATH="${PATH}:${HOME}/.cargo/bin"
            fi
        fi
    fi

    if [ -n "${CAP_SYS_BUILDHOST}" ]; then
        debug "Printing system capabilities:"
        dump_system_capabilities
    fi

    if [ -z "${CURRENT_DEFINITION_DISABLED}" ]; then
        if [ "${DEF_TYPE}" = "meta" ]; then
            note "   ${NOTE_CHAR2} Meta bundle with version: ${ColorDistinct}${DEF_VERSION}${ColorNote}"

            debug "Build type: ${ColorDistinct}meta${ColorDebug}"
            try after_install_callback
            try after_install_snapshot
        else
            (
                if [ -n "${BUILD_DIR}" ] \
                && [ -n "${BUILD_NAMESUM}" ]; then
                    if [ -n "${CAP_SYS_BUILDHOST}" ]; then
                        dump_debug_info
                        dump_compiler_setup
                    fi

                    cd "${BUILD_DIR}"
                    if [ -z "${DEF_GIT_CHECKOUT}" ]; then # Standard "fetch source archive" method
                        _base="${DEF_SOURCE_PATH##*/}"
                        _dest_file="${FILE_CACHE_DIR}${_base}"
                        # TODO: implement auto picking fetch method based on DEF_SOURCE_PATH contents
                        if [ ! -e "${_dest_file}" ]; then
                            retry "${FETCH_BIN} ${FETCH_OPTS} -o ${_dest_file} '${DEF_SOURCE_PATH}'" \
                                || error "Failed to fetch source: ${ColorDistinct}${DEF_SOURCE_PATH}${ColorError}"
                            debug "Source fetched: ${ColorDistinct}${_base}${ColorDebug}"
                        fi
                        if [ -z "${DEF_SHA}" ]; then
                            error "Missing SHA sum for source: ${ColorDistinct}${_dest_file}${ColorError}!"
                        else
                            _a_file_checksum="$(file_checksum "${_dest_file}")"
                            if [ "${_a_file_checksum}" = "${DEF_SHA}" ]; then
                                debug "${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorDebug}: ${ColorDistinct}${_base}${ColorDebug}: checksum matches: ${ColorDistinct}${DEF_SHA}${ColorDebug}"
                            else
                                try "${RM_BIN} -f ${_dest_file}" \
                                    && debug "Removed corrupted partial file: ${ColorDistinct}${_dest_file}${ColorDebug}"
                                error "Source tarball checksum mismatch: '${ColorDistinct}${_a_file_checksum}${ColorError}' vs '${ColorDistinct}${DEF_SHA}${ColorError}' for prefix: ${ColorDistinct}${_prefix} == ${PREFIX}${ColorError}"
                            fi
                            unset _bname _a_file_checksum
                        fi

                        case "${SYSTEM_NAME}" in
                            OpenBSD)
                                ${MKDIR_BIN} -p "${BUILD_DIR}"
                                ;;

                            *)
                                # NOTE: plain -tf listing works the same for BSD and GNU tar:
                                _possible_old_build_dir="$(${TAR_BIN} -tf "${_dest_file}" 2>/dev/null | ${HEAD_BIN} -n1 2>/dev/null)"
                                _possible_old_build_dir="${_possible_old_build_dir#./}"
                                _possible_old_build_dir="${_possible_old_build_dir%%/*}" # top level dir of the archive
                                if [ -n "${_possible_old_build_dir}" ] \
                                && [ -d "${BUILD_DIR}/${_possible_old_build_dir}" ]; then
                                    try "${RM_BIN} -rf '${BUILD_DIR}/${_possible_old_build_dir}'" \
                                        && debug "Previous dependency build dir was removed to avoid conflicts: ${ColorDistinct}${BUILD_DIR}/${_possible_old_build_dir}${ColorDebug}"
                                fi
                                ;;
                        esac

                        try "${TAR_BIN} -xf ${_dest_file} ${TAR_DIRECTORY_ARG} ${BUILD_DIR}" \
                            || try "${TAR_BIN} -xzf ${_dest_file} ${TAR_DIRECTORY_ARG} ${BUILD_DIR}" \
                            || try "${TAR_BIN} -xjf ${_dest_file} ${TAR_DIRECTORY_ARG} ${BUILD_DIR}" \
                            || run "${TAR_BIN} -xJf ${_dest_file} ${TAR_DIRECTORY_ARG} ${BUILD_DIR}"

                        debug "Unpacked source for: ${ColorDistinct}${DEF_NAME}${DEF_SUFFIX}${ColorDebug}, version: ${ColorDistinct}${DEF_VERSION}${ColorDebug} into build-dir: ${ColorDistinct}${BUILD_DIR}${ColorDebug}"
                    else
                        # git method:
                        # .cache/git-cache => git bare repos
                        # NOTE: if DEF_GIT_CHECKOUT is unset, use DEF_VERSION:
                        clone_or_fetch_git_bare_repo "${DEF_SOURCE_PATH}" "${DEF_NAME}${DEF_SUFFIX}-bare" "${DEF_GIT_CHECKOUT:-${DEF_VERSION}}" "${BUILD_DIR}"
                    fi

                    unset _fd
                    _prm_nolib="${_definition_name/lib/}"
                    _prm_no_undrlne_and_minus="${_definition_name%%[-_]*}"
                    # debug "Requirement: ${_definition_name} short: ${_prm_nolib}, nafter-: ${_prm_no_undrlne_and_minus}, DEF_NAME: ${DEF_NAME}, BUILD_DIR: ${BUILD_DIR}"
                    # NOTE: patterns sorted by safety
                    for _pati in    "*${_definition_name}*${DEF_VERSION}" \
                                    "*${_prm_no_undrlne_and_minus}*${DEF_VERSION}" \
                                    "*${_prm_nolib}*${DEF_VERSION}" \
                                    "*${DEF_NAME}*${DEF_VERSION}" \
                                    "*${_definition_name}*" \
                                    "*${_prm_no_undrlne_and_minus}*" \
                                    "*${_prm_nolib}*" \
                                    "*${DEF_NAME}*";
                    do
                        _fd="$(${FIND_BIN} "${BUILD_DIR}" -maxdepth 1 -mindepth 1 -type d -iname "${_pati}" 2>/dev/null | ${HEAD_BIN} -n1 2>/dev/null)"
                        if [ -n "${_fd}" ]; then
                            debug "Found build dir: ${ColorDistinct}${_fd}${ColorDebug}, for definition: ${ColorDistinct}${DEF_NAME}${ColorDebug}"
                            break
                        fi
                    done
                    if [ -z "${_fd}" ]; then
                        # NOTE: Handle one more case - inherited definitions, and there might be several of these..
                        # TODO: add support for recursive check through inherited definitions
                        # XXX: hardcoded name of function inherit() - which might be used in any definition file:
                        _inherited="$(${GREP_BIN} 'inherit' "${_req_definition}" 2>/dev/null | ${SED_BIN} 's/inherit[ ]*//g' 2>/dev/null)"
                        if [ -z "${_inherited}" ]; then
                            error "No source dir found for definition: ${ColorDistinct}${_definition_name}${ColorError}?"
                        else
                            for _inh in $(to_iter "${_inherited}"); do
                                debug "Trying inherited value: ${ColorDistinct}${_inh}${ColorDebug}"
                                _fd="$(${FIND_BIN} "${BUILD_DIR}" -maxdepth 1 -mindepth 1 -type d -iname "*${_inh}*${DEF_VERSION}*" 2>/dev/null | ${HEAD_BIN} -n1 2>/dev/null)"
                                if [ -n "${_fd}" ]; then
                                    debug "Found inherited build dir: ${ColorDistinct}${_fd}${ColorDebug}, for definition: ${ColorDistinct}${DEF_NAME}${ColorDebug}"
                                    break
                                fi
                            done
                            # If nothing helps..
                            if [ -z "${_fd}" ]; then
                                error "No inherited source dir found for definition: ${ColorDistinct}${_definition_name}${ColorError}?"
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
                    try after_unpack_snapshot

                    cd "${_pwd}"
                    apply_definition_patches "${DEF_NAME}${DEF_SUFFIX}"

                    cd "${_pwd}"
                    try after_patch_callback
                    cd "${_pwd}"
                    try after_patch_snapshot
                    cd "${_pwd}"

                    # configuration log:
                    _configure_log="config.log"
                    _cmake_out_log="CMakeFiles/CMakeOutput.log"
                    _cmake_error_log="CMakeFiles/CMakeError.log"
                    _configure_options_log="${LOGS_DIR}${(L):-${SOFIN_NAME}-${DEF_NAME}${DEF_SUFFIX}.config}"
                    _configuration_result="${_configure_options_log}.result"
                    _cmake_configuration_result="${LOGS_DIR}${(L):-${SOFIN_NAME}-${DEF_NAME}${DEF_SUFFIX}.cmake.result.log}"

                    case "${DEF_CONFIGURE_METHOD}" in

                        ignore)
                            debug "Build type: ${ColorDistinct}ignore${ColorDebug}"
                            note "   ${NOTE_CHAR} Configuration skipped for definition: ${ColorDistinct}${_definition_name}${ColorNote}"
                            ;;

                        no-conf)
                            debug "Build type: ${ColorDistinct}no-conf${ColorDebug}"
                            note "   ${NOTE_CHAR} No configuration for definition: ${ColorDistinct}${_definition_name}${ColorNote}"
                            DEF_MAKE_METHOD="${DEF_MAKE_METHOD} PREFIX=${_prefix} CFLAGS='${CFLAGS}' CXXFLAGS='${CXXFLAGS}' LDFLAGS='${LDFLAGS}'"
                            DEF_INSTALL_METHOD="${DEF_INSTALL_METHOD} PREFIX=${_prefix} CFLAGS='${CFLAGS}' CXXFLAGS='${CXXFLAGS}' LDFLAGS='${LDFLAGS}'"
                            ;;

                        binary)
                            debug "Build type: ${ColorDistinct}binary${ColorDebug}"
                            note "   ${NOTE_CHAR} Prebuilt definition of: ${ColorDistinct}${_definition_name}${ColorNote}"
                            DEF_MAKE_METHOD="true"
                            DEF_INSTALL_METHOD="true"
                            ;;

                        posix)
                            debug "Build type: ${ColorDistinct}posix${ColorDebug}"
                            dump_software_build_configuration_options "${_configure_options_log}"

                            note "   ${NOTE_CHAR} Configuring: ${ColorDistinct}${_definition_name}${ColorNote}, version: ${ColorDistinct}${DEF_VERSION}${ColorNote}"
                            try "./configure -prefix ${_prefix} -cc '${CC_NAME} ${CFLAGS}' -libs '-L${PREFIX}/lib ${LDFLAGS}' -mandir ${PREFIX}/share/man -libdir ${PREFIX}/lib -aspp '${CC_NAME} ${CFLAGS} -c' ${DEF_CONFIGURE_ARGS} 2>> ${LOG}-${DEF_NAME}${DEF_SUFFIX}" \
                                || try "./configure -prefix ${_prefix} -cc '${CC_NAME} ${CFLAGS}' -libs '-L${PREFIX}/lib ${LDFLAGS}' -libdir ${PREFIX}/lib -aspp '${CC_NAME} ${CFLAGS} -c' ${DEF_CONFIGURE_ARGS} 2>> ${LOG}-${DEF_NAME}${DEF_SUFFIX}" \
                                    || run "./configure -prefix ${_prefix} -cc '${CC_NAME} ${CFLAGS}' -libs '-L${PREFIX}/lib ${LDFLAGS}' -aspp '${CC_NAME} ${CFLAGS} -c' ${DEF_CONFIGURE_ARGS}"

                            try "${INSTALL_BIN} '${_configure_log}' '${_configuration_result}'"
                            ;;

                        meson) # new player each year ;)
                            debug "Build type: ${ColorDistinct}meson${ColorDebug}"
                            dump_software_build_configuration_options "${_configure_options_log}"
                            note "   ${NOTE_CHAR} Configuring: ${ColorDistinct}${_definition_name}${ColorNote}, version: ${ColorDistinct}${DEF_VERSION}${ColorNote}"

                            run "${DEF_CONFIGURE_METHOD} setup build -Dprefix=${PREFIX} -Dsysconfdir=${SERVICE_DIR}/etc -Dlocalstatedir=${SERVICE_DIR}/var ${DEF_CONFIGURE_ARGS} 2>> ${LOG}-${DEF_NAME}${DEF_SUFFIX}"

                            DEF_MAKE_METHOD="ninja -C build -j${CPUS}"
                            DEF_INSTALL_METHOD="ninja -C build install"
                            ;;

                        build2)
                            debug "Build type: ${ColorDistinct}build2${ColorDebug}"
                            note "   ${NOTE_CHAR} Configuring: ${ColorDistinct}${_definition_name}${ColorNote}, version: ${ColorDistinct}${DEF_VERSION}${ColorNote}"
                            DEF_MAKE_METHOD="b configure ${DEF_CONFIGURE_ARGS} config.cxx=clang++ config.cxx.coptions='${CXXFLAGS}' 2>> ${LOG}-${DEF_NAME}${DEF_SUFFIX}"
                            DEF_INSTALL_METHOD="b install config.install.root=${PREFIX} 2>> ${LOG}-${DEF_NAME}${DEF_SUFFIX}"
                            ;;

                        cmake)
                            debug "Build type: ${ColorDistinct}cmake${ColorDebug}"
                            note "   ${NOTE_CHAR} Configuring: ${ColorDistinct}${_definition_name}${ColorNote}, version: ${ColorDistinct}${DEF_VERSION}${ColorNote}"

                            try "${RM_BIN} -r build"
                            try "${MKDIR_BIN} -p build"
                            _pwd="${_pwd}/build"
                            cd "${_pwd}"
                            _cmake_cmdline="${DEF_CONFIGURE_METHOD} ../ -LH -DCMAKE_BUILD_RPATH=\"${PREFIX}/lib\" -DCMAKE_INSTALL_RPATH=\"${_prefix}/lib;${_prefix}/libexec\" -DCMAKE_INSTALL_PREFIX=${_prefix} -DCMAKE_BUILD_TYPE=Release -DSYSCONFDIR=${SERVICE_DIR}/etc -DMAN_INSTALLDIR=${_prefix}/share/man -DDOCDIR=${_prefix}/share/doc -DJOB_POOL_COMPILE=${CPUS} -DJOB_POOL_LINK=${CPUS} -DCMAKE_C_FLAGS=\"${CFLAGS}\" -DCMAKE_CXX_FLAGS=\"${CXXFLAGS}\" ${DEF_CONFIGURE_ARGS}"

                            # Makefile case: Use what's found in definition or set default calls:
                            run "${RM_BIN} -f CMakeCache.txt; ${_cmake_cmdline} -G'Ninja'"
                            DEF_MAKE_METHOD="ninja install"
                            DEF_INSTALL_METHOD="true"
                            unset _cmake_cmdline
                            ;;

                        cmake-make)
                            debug "Build type: ${ColorDistinct}cmake-make${ColorDebug}"
                            note "   ${NOTE_CHAR} Configuring: ${ColorDistinct}${_definition_name}${ColorNote}, version: ${ColorDistinct}${DEF_VERSION}${ColorNote}"

                            try "${RM_BIN} -r build"
                            try "${MKDIR_BIN} -p build"
                            _pwd="${_pwd}/build"
                            cd "${_pwd}"
                            _cmake_cmdline="${DEF_CONFIGURE_METHOD%-make} ../ -LH -DCMAKE_BUILD_RPATH=\"${PREFIX}/lib\" -DCMAKE_INSTALL_RPATH=\"${_prefix}/lib;${_prefix}/libexec\" -DCMAKE_INSTALL_PREFIX=${_prefix} -DCMAKE_BUILD_TYPE=Release -DSYSCONFDIR=${SERVICE_DIR}/etc -DMAN_INSTALLDIR=${_prefix}/share/man -DDOCDIR=${_prefix}/share/doc -DJOB_POOL_COMPILE=${CPUS} -DJOB_POOL_LINK=${CPUS} -DCMAKE_C_FLAGS=\"${CFLAGS}\" -DCMAKE_CXX_FLAGS=\"${CXXFLAGS}\" ${DEF_CONFIGURE_ARGS}"

                            # Makefile case: Use what's found in definition or set default calls:
                            run "${RM_BIN} -f CMakeCache.txt; ${_cmake_cmdline}"
                            DEF_MAKE_METHOD="make install"
                            DEF_INSTALL_METHOD="true"
                            unset _cmake_cmdline
                            ;;

                        *)
                            debug "Build type: ${ColorDistinct}autotools${ColorDebug} (default)"
                            unset _pic_optional
                            if [ "${SYSTEM_NAME}" != "Darwin" ]; then
                                _pic_optional="--with-pic"
                            fi
                            _addon="CFLAGS='${CFLAGS}' CXXFLAGS='${CXXFLAGS}' LDFLAGS='${LDFLAGS}'"

                            dump_software_build_configuration_options "${_configure_options_log}"
                            note "   ${NOTE_CHAR} Configuring: ${ColorDistinct}${_definition_name}${ColorNote}, version: ${ColorDistinct}${DEF_VERSION}${ColorNote}"

                            if [ "${SYSTEM_NAME}" = "Linux" ]; then
                                # NOTE: No /Services feature implemented for Linux.
                                printf "%b\n" "${DEF_CONFIGURE_METHOD}" | ${GREP_BIN} -F 'configure' >/dev/null 2>&1
                                if [ "${?}" = "0" ]; then
                                    # NOTE: by defaultautoconf configure accepts influencing variables as configure script params
                                    try "${DEF_CONFIGURE_METHOD} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix} ${_pic_optional} ${_addon} 2>> ${LOG}-${DEF_NAME}${DEF_SUFFIX}" \
                                        || try "${_addon} ${DEF_CONFIGURE_METHOD} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix} ${_pic_optional} 2>> ${LOG}-${DEF_NAME}${DEF_SUFFIX}" \
                                            || try "${DEF_CONFIGURE_METHOD} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix} ${_addon} 2>> ${LOG}-${DEF_NAME}${DEF_SUFFIX}" \
                                                || run "${_addon} ${DEF_CONFIGURE_METHOD} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix}"
                                else
                                    try "${DEF_CONFIGURE_METHOD} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix} ${_addon} 2>> ${LOG}-${DEF_NAME}${DEF_SUFFIX}" \
                                        || try "${_addon} ${DEF_CONFIGURE_METHOD} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix} 2>> ${LOG}-${DEF_NAME}${DEF_SUFFIX}" \
                                            || try "${DEF_CONFIGURE_METHOD} ${DEF_CONFIGURE_ARGS} ${_addon} 2>> ${LOG}-${DEF_NAME}${DEF_SUFFIX}" \
                                                || run "${_addon} ${DEF_CONFIGURE_METHOD} ${DEF_CONFIGURE_ARGS}" # Trust definition
                                fi
                            else
                                # do a simple check for "configure" in DEF_CONFIGURE_METHOD definition
                                # this way we can tell if we want to put configure options as params
                                printf "%b\n" "${DEF_CONFIGURE_METHOD}" | ${GREP_BIN} -F 'configure' >/dev/null 2>&1
                                if [ "${?}" = "0" ]; then
                                    # TODO: add --docdir=${_prefix}/docs
                                    # NOTE: By default try to configure software with these options:
                                    #   --sysconfdir=${SERVICE_DIR}/etc
                                    #   --localstatedir=${SERVICE_DIR}/var
                                    #   --runstatedir=${SERVICE_DIR}/run
                                    #   --with-pic
                                    # NOTE: Ask configure which of the standard options it supports, then run it once.
                                    #       Retrying every option permutation ran a failing configure up to 12 times.
                                    _configure_help="$(eval "${DEF_CONFIGURE_METHOD} --help" 2>/dev/null)"
                                    if [ -z "${_configure_help}" ]; then
                                        debug "No --help output from: ${ColorDistinct}${DEF_CONFIGURE_METHOD}${ColorDebug}. Configuring with --prefix only."
                                        run "${_addon} ${DEF_CONFIGURE_METHOD} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix}"
                                    else
                                        _configure_opts="--prefix=${_prefix}"
                                        case "${_configure_help}" in
                                            *--sysconfdir*)
                                                _configure_opts="${_configure_opts} --sysconfdir=${SERVICE_DIR}/etc"
                                                ;;
                                        esac
                                        case "${_configure_help}" in
                                            *--localstatedir*)
                                                _configure_opts="${_configure_opts} --localstatedir=${SERVICE_DIR}/var"
                                                ;;
                                        esac
                                        if [ -n "${_pic_optional}" ]; then
                                            case "${_configure_help}" in
                                                *--with-pic*)
                                                    _configure_opts="${_configure_opts} ${_pic_optional}"
                                                    ;;
                                            esac
                                        fi
                                        # NOTE: Autoconf scripts list CFLAGS among "influential environment variables"
                                        #       and accept them as arguments. Hand-written ones (RHash) may mention CFLAGS
                                        #       but reject it as an argument: they get it in the environment.
                                        #       If configure still fails, fall back to the definition's own options only.
                                        case "${_configure_help}" in
                                            *"influential environment variables"*)
                                                try "${DEF_CONFIGURE_METHOD} ${DEF_CONFIGURE_ARGS} ${_configure_opts} ${_addon} 2>> ${LOG}-${DEF_NAME}${DEF_SUFFIX}" \
                                                    || run "${_addon} ${DEF_CONFIGURE_METHOD} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix} 2>> ${LOG}-${DEF_NAME}${DEF_SUFFIX}"
                                                ;;
                                            *)
                                                try "${_addon} ${DEF_CONFIGURE_METHOD} ${DEF_CONFIGURE_ARGS} ${_configure_opts} 2>> ${LOG}-${DEF_NAME}${DEF_SUFFIX}" \
                                                    || run "${_addon} ${DEF_CONFIGURE_METHOD} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix} 2>> ${LOG}-${DEF_NAME}${DEF_SUFFIX}"
                                                ;;
                                        esac
                                    fi
                                    unset _configure_help _configure_opts

                                else # fallback again:
                                    # NOTE: First - try to specify GNU prefix,
                                    # then trust prefix given in software definition.
                                    try "${DEF_CONFIGURE_METHOD} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix} ${_addon} 2>> ${LOG}-${DEF_NAME}${DEF_SUFFIX}" \
                                        || try "${_addon} ${DEF_CONFIGURE_METHOD} ${DEF_CONFIGURE_ARGS} --prefix=${_prefix} 2>> ${LOG}-${DEF_NAME}${DEF_SUFFIX}" \
                                            || try "${DEF_CONFIGURE_METHOD} ${DEF_CONFIGURE_ARGS} ${_addon} 2>> ${LOG}-${DEF_NAME}${DEF_SUFFIX}" \
                                                || run "${_addon} ${DEF_CONFIGURE_METHOD} ${DEF_CONFIGURE_ARGS}"
                                fi
                            fi
                            ;;
                    esac

                    debug "Gathering configuration output logs${CHAR_DOTS}"
                    try "test -f '${_configure_log}' && ${INSTALL_BIN} '${_configure_log}' '${_configuration_result}'" \
                        || try "test -f '${_cmake_out_log}' && ${INSTALL_BIN} '${_cmake_out_log}' '${_cmake_configuration_result}.stdout'; test -f '${_cmake_error_log}' && ${INSTALL_BIN} '${_cmake_error_log}' '${_cmake_configuration_result}.stderr'" \
                                || debug "No configuration results!"

                    cd "${_pwd}"
                    try after_configure_callback
                    cd "${_pwd}"
                    try after_configure_snapshot
                else
                    error "These values cannot be empty: BUILD_DIR, BUILD_NAMESUM"
                fi

                # and common part between normal and continue modes:
                cd "${_pwd}"
                note "   ${NOTE_CHAR} Building requirement: ${ColorDistinct}${_definition_name}${ColorNote}, version: ${ColorDistinct}${DEF_VERSION}${ColorNote}"
                run "${DEF_MAKE_METHOD}"

                cd "${_pwd}"
                try after_make_callback
                cd "${_pwd}"
                try after_make_snapshot

                if [ -n "${_prefix}" ]; then
                    _whole_list=""
                    debug "Cleaning PREFIX man dir from previous dependencies, we want to install man pages that belong to LAST requirement which is app bundle itself"
                    for _stuff_of_other_defs in $(to_iter "share/man" "share/info" "share/doc" "share/docs" "docs" "share/html"); do # "man"
                        if [ -d "${_prefix}/${_stuff_of_other_defs}" ]; then
                            if [ -z "${_whole_list}" ]; then
                                _whole_list="'${_prefix}/${_stuff_of_other_defs}'"
                            else
                                _whole_list="${_whole_list} ${_prefix}/${_stuff_of_other_defs}"
                            fi
                        fi
                    done

                    if [ -n "${_whole_list}" ]; then
                        debug "Prepared list of unwanted files: ${ColorDistinct}${_whole_list}${ColorDebug}, from bundle with software PREFIX: ${ColorDistinct}${_prefix}${ColorDebug}."
                        try "${RM_BIN} -fr ${_whole_list}"  \
                            && debug "Unwanted files were destroyed."
                    else
                        debug "No known files from previous definitions installed for software PREFIX: ${ColorDistinct}${_prefix}${ColorDebug}"
                    fi

                    # NOTE: this thing is a real trouble for some definitions that crashes after "make install" without these directories in _prefix: <facepalm>
                    try "${MKDIR_BIN} -p ${_prefix}/man ${_prefix}/docs"
                else
                    error "Sofin-Assertion-Failed: EMPTY _prefix?! Undefined behavior is always a BUG! Please report this!"
                fi

                cd "${_pwd}"
                note "   ${NOTE_CHAR} Installing requirement: ${ColorDistinct}${_definition_name}${ColorNote}, version: ${ColorDistinct}${DEF_VERSION}${ColorNote}"
                run "${DEF_INSTALL_METHOD}"

                cd "${_pwd}"
                try after_install_callback
                cd "${_pwd}"
                try after_install_snapshot

                # OTE: after successful make, invoke DEF_TEST_METHOD of the definition:
                if [ -n "${DEF_TEST_METHOD}" ]; then
                    note "   ${NOTE_CHAR} Testing requirement: ${ColorDistinct}${_definition_name}${ColorNote}, version: ${ColorDistinct}${DEF_VERSION}${ColorNote}"
                    cd "${_pwd}"

                    # NOTE: mandatory on production machines:
                    test_and_rate_def "${_definition_name}" "${DEF_TEST_METHOD}"
                else
                    note "   ${WARN_CHAR} Skipped testing for: ${ColorDistinct}${_definition_name}${ColorNote}"
                fi
                cd "${_pwd}"
                try after_test_callback
                cd "${_pwd}"
                try after_test_snapshot

                cd "${_pwd}"
                printf "%b\n" "${DEF_VERSION}" > "${_prefix}/${_definition_name}${DEFAULT_INST_MARK_EXT}" \
                    && debug "Commited version: ${ColorDistinct}${DEF_VERSION}${ColorDebug} of software bundle: ${ColorDistinct}${DEF_NAME}${DEF_SUFFIX}${ColorDebug}. Bundle prefix: ${ColorDistinct}${_prefix}${ColorDebug}"
            )
            unset _pwd _addon _dsname _bund
        fi
    else

        note "   ${WARN_CHAR} Requirement preinstalled: ${ColorDistinct}${_req_defname}${ColorNote} on: ${ColorDistinct}${SYSTEM_NAME}${ColorNote} platforms"
        if [ ! -d "${_prefix}" ]; then # case when disabled requirement is first on list of dependencies
            create_software_dir "${_prefix##*/}"
        fi
        _dis_def="${_prefix}/${_req_defname}${DEFAULT_INST_MARK_EXT}"
        printf "%b\n" "${DEFAULT_REQ_OS_PROVIDED}" > "${_dis_def}"
    fi
    unset _current_branch _dis_def _req_defname _app_param _prefix _bundlnm _definition_name

    # TODO: reset env here?
}


test_and_rate_def () {
    _name="${1}"
    shift
    _cmdline="${*}"
    if [ -z "${_name}" ]; then
        return 0
    fi

    case "${_cmdline}" in
        ""|:|true|false|disable|disabled|skip|no|NO|off|OFF)
            debug "Tests skipped since the DEF_TEST_METHOD is empty for definition: ${_name}"
            return 0
            ;;

        *)
            _test_result_log="${PREFIX}/${_name}.test.output"
            _sofin_log="${LOG}-${DEF_NAME}${DEF_SUFFIX}"
            debug "Initializing test for: ${ColorDistinct}${_name}${ColorDebug}, output to log: ${ColorDistinct}${_test_result_log}${ColorDebug}"
            local_test_env_dispatch () {
                _start_time="$(${DATE_BIN} +%F-%H%M-%s 2>/dev/null)"

                printf "%b:\n%b\n" "$(capitalize "${_name}")" "Test started at: ${_start_time}" > "${_test_result_log}"
                eval "\
                    PATH=${PREFIX}/bin:${PREFIX}/sbin:${PREFIX}/libexec:${PATH} \
                    TEST_JOBS=${CPUS} \
                    TEST_ENV=${DEF_TEST_ENV:-test} \
                        ${_cmdline}" >> "${_test_result_log}" 2>&1
                _result="${?}"
                if [ "0" != "${_result}" ]; then
                    # NOTE: lines that usually tell what was wanted and what was given:
                    unset _test_failures
                    for _test_line in "${(@f)$(${GREP_BIN} -n -i -E "${TEST_FAILURE_PATTERN}" "${_test_result_log}" 2>/dev/null | ${TAIL_BIN} -n "${LOG_LINES_AMOUNT_ON_ERR}" 2>/dev/null)}"; do
                        if [ -n "${_test_line}" ]; then
                            _test_failures="${_test_failures}\n      ${_test_line[1,240]}"
                        fi
                    done
                    if [ -n "${_test_failures}" ]; then
                        _test_failures="\n\n    Failure lines of the test output (line: text):${_test_failures}"
                    fi

                    _end_time="$(${DATE_BIN} +%F-%H%M-%s 2>/dev/null)"
                    printf "%b\n" "Test failed at: ${_end_time} (exit code: ${_result})" >> "${_test_result_log}"

                    # NOTE: keep the whole test output in the definition log, so the crash
                    #       log tail and "s log" show it:
                    ${CAT_BIN} "${_test_result_log}" >> "${_sofin_log}"

                    error "Test failed for: ${ColorDistinct}${DEF_NAME}${DEF_SUFFIX}${ColorError} (exit code: ${ColorDistinct}${_result}${ColorError}). Installation aborted.\n    Test command: ${ColorDistinct}${_cmdline}${ColorError}\n    Full test output: ${ColorDistinct}${_test_result_log}${ColorError}${_test_failures}"
                fi
                _end_time="$(${DATE_BIN} +%F-%H%M-%s 2>/dev/null)"
                ${CAT_BIN} "${_test_result_log}" >> "${_sofin_log}"
                printf "%b\n" "Test finished at: ${_end_time}" >> "${_test_result_log}"

                unset _test_command _end_time _start_time _test_result_log _cmdline _result
                return 0
            }
            ;;
    esac

    debug "Invoking software check/test: ${ColorDistinct}${_name}${ColorDebug} [DEF_TEST_METHOD='${ColorDistinct}${_cmdline}${ColorDebug}']"
    local_test_env_dispatch \
        && try "${TOUCH_BIN} ${PREFIX}/${_name}.test.passed; ${RM_BIN} -f ${PREFIX}/${_name}.test.failed" \
        && return 0

    try "${TOUCH_BIN} ${PREFIX}/${_name}.test.failed; ${RM_BIN} -f ${PREFIX}/${_name}.test.passed"
    return 1
}
