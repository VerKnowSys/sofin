#!/usr/bin/env zsh
# @author: Daniel (dmilith) Dettlaff (dmilith at me dot com)


# publish core values:
SOFIN_PID="$$"
case "$(uname)" in
    Darwin)
        SOFIN_ROOT="/Users/Shared/Software/Sofin"
        ;;
    *)
        SOFIN_ROOT="/Software/Sofin"
        ;;
esac

. "${SOFIN_ROOT}/share/loader"


# divide arguments:
SOFIN_COMMAND="${1}"
if [ "${#}" -gt "0" ]; then
    shift
    SOFIN_ARGS="${*}"
    _args="  args[$(distd "${#}")]: $(distd "${SOFIN_ARGS}"),"
fi

SOFIN_CMDLINE="${SOFIN_SHORT_NAME} ${SOFIN_COMMAND} ${SOFIN_ARGS}"
debug "Sofin (cmdline: $(distd "${SOFIN_CMDLINE}"),  SOFIN_PID=$(distd "${SOFIN_PID}"),  SOFIN_PPID=$(distd "${PPID}"),  SOFIN_ROOT=$(distd "${SOFIN_ROOT}"))"

# Set explicit +e for Sofin shell:
env_forgivable
validate_env


# Tracing of Sofin itself:
if [ -n "${SOFIN_TRACE}" ]; then
    # NOTE: may be useful later:
    #
    if [ "YES" = "${CAP_TERM_ZSH}" ]; then
        setopt sourcetrace
        setopt xtrace
    elif [ "YES" = "${CAP_TERM_BASH}" ]; then
        set -o xtrace
    else
        set -o xtrace
    fi
    set -x
    printf "%b\n" "Enabled trace mode"
fi

if [ -n "${SOFIN_VERBOSE}" ]; then
    if [ "YES" = "${CAP_TERM_ZSH}" ] \
    || [ "YES" = "${CAP_TERM_BASH}" ]; then
        set -o verbose
    else
        set -v
    fi
    printf "%b\n" "Enabled verbose mode"
fi

# this is internal version check for defaults.def
unset COMPLIANCE_CHECK


# deploy bundle helper function
deploy_bundle () {
    if [ -n "${CAP_SYS_PRODUCTION}" ]; then
        warn "Bundle deployments are disabled on production systems!"
        finalize_and_quit_gracefully_with_exitcode "${ERRORCODE_TASK_FAILURE}"
    fi

    validate_reqs
    permnote "Deploying: $(distn "$(capitalize "${SOFIN_ARGS}")")"
    fail_on_bg_job "${SOFIN_ARGS}"

    # build and remove useless files of each definition:
    for _bundle in $(to_iter "${SOFIN_ARGS}"); do
        export USE_BINBUILD=NO \
            && build "${_bundle}" \
            && afterbuild_manage_files_of_bundle \
            && push_binbuilds "${_bundle}" \
            && continue

        error "Process failed for bundle: $(diste "${_bundle}")!"
    done
    unset _bundle
}


# delete bundle helper function, since we use it in several places
delete_bundle () {
    fail_on_bg_job "${SOFIN_ARGS}"
    for _arg in $(to_iter "${SOFIN_ARGS}"); do
        _caparg="$(capitalize_abs "${_arg}")"
        if [ -z "${_caparg}" ]; then
            error "No software bundle name(s) given?"
        fi
    done
    remove_bundles "${SOFIN_ARGS}"
    permnote "Removed bundle(s): $(distn "$(capitalize_abs "${SOFIN_ARGS}")")"
    unset _arg _caparg
}


if [ -n "${SOFIN_COMMAND}" ]; then
    case ${SOFIN_COMMAND} in
        dump|defaults|compiler-defaults|dump-defaults|dmp|build-defaults)
            _definition="${1:-defaults}"
            case "${_definition}" in
                defaults)
                    permnote "Loading definition-defaults: $(distn "${CHAR_DOTS}/${DEFINITIONS_DEFAULTS##*/}")"
                    load_defaults
                    compiler_setup

                    permnote "\n\n### Default compiler-settings:"
                    DEBUG=1 dump_compiler_setup
                    ;;

                *)
                    _def2dump="${DEFINITIONS_DIR}/${_definition}${DEFAULT_DEF_EXT}"
                    debug "Checking existence of definition file: $(distd "${_def2dump}")"
                    if [ -f "${_def2dump}" ]; then
                        permnote "Loading definitions: $(distn "${CHAR_DOTS}/${DEFINITIONS_DEFAULTS##*/}") + $(distn "${CHAR_DOTS}/${_definition}${DEFAULT_DEF_EXT}")"
                        load_defaults
                        load_defs "${_definition}"
                        compiler_setup

                        permnote "\n\n### Definition specific compiler-settings:"
                        DEBUG=1 dump_compiler_setup
                    else
                        error "No such definition file: $(distw "${_def2dump}")!"
                    fi
                    ;;
            esac

            permnote "\n\n### System capabilities:"
            DEBUG=1 dump_system_capabilities

            permnote "\n\n### Current user shell-environment settings:"
            print_env_status
            print_shell_vars

            _local_vars="$(print_local_env_vars)"
            if [ -n "${_local_vars}" ]; then
                permnote "\n\n### Loaded local-environment file"
                printf "%b\n" "${_local_vars}"
            else
                permnote "\n\n### No local-environment file"
            fi
            unset _local_vars

            ;;

        dev)
            develop "${SOFIN_ARGS}"
            ;;


        diffs|diff)
            show_diff "${SOFIN_ARGS}"
            ;;


        info|ver|version)
            sofin_header
            ;;


        origins|origin)
            show_new_origin_updates "${SOFIN_ARGS}"
            ;;


        log)
            show_logs "${SOFIN_ARGS%${SOFIN_COMMAND}}"
            ;;


        less|les|show)
            less_logs "${SOFIN_ARGS%${SOFIN_COMMAND}}"
            ;;


        clean)
            perform_clean
            ;;


        distclean)
            initialize
            perform_clean dist
            update_defs
            ;;


        performance|perf)
            permnote "Setting performance: $(distn "${SOFIN_ARGS}")"
            performance "${SOFIN_ARGS}"
            ;;

        purge)
            initialize
            perform_clean purge
            update_defs
            ;;


        e|env)
            case "${1}" in

                +*) # add N elements
                    unset _bundles
                    _all="${*}"
                    for _in in $(to_iter "${_all}"); do
                        _bundle="$(capitalize_abs "${_in#+}")"
                        if [ -e "${SOFTWARE_DIR}/${_bundle}" ]; then
                            if [ -z "${_bundles}" ]; then
                                _bundles="${_bundle}"
                            else
                                _bundles="${_bundle} ${_bundles}"
                            fi
                        fi
                    done
                    if [ -z "${_bundles}" ]; then
                        return 0
                    fi
                    enable_sofin_env "${_bundles}"
                    permnote "Bundles: $(distn "${_bundles}") added to the environment."
                    ;;

                -*) # remove N elements
                    unset _bundles
                    _all="${*}"
                    for _in in $(to_iter "${_all}"); do
                        _bundle="$(capitalize_abs "${_in#-}")"
                        if [ -e "${SOFTWARE_DIR}/${_bundle}" ]; then
                            if [ -z "${_bundles}" ]; then
                                _bundles="${_bundle}"
                            else
                                _bundles="${_bundle} ${_bundles}"
                            fi
                        fi
                    done
                    if [ -z "${_bundles}" ]; then
                        return 0
                    fi
                    disable_sofin_env "${_bundles}"
                    permnote "Bundles: $(distn "${_bundles}") removed from the environment."
                    ;;

                !|store|save) # save profile
                    shift
                    _fname="${SOFIN_ENV_ENABLED_INDICATOR_FILE}.${1}"
                    run "${INSTALL_BIN} ${SOFIN_ENV_ENABLED_INDICATOR_FILE} ${_fname}" \
                        && permnote "Saved new environment profile: $(distn "${_fname}")"
                    ;;

                ^|load|ld) # load profile
                    shift
                    _name="${1}"
                    _fname="${SOFIN_ENV_ENABLED_INDICATOR_FILE}.${_name}"
                    if [ -f "${_fname}" ]; then
                        run "${INSTALL_BIN} ${_fname} ${SOFIN_ENV_ENABLED_INDICATOR_FILE}" \
                            && permnote "Loaded environment profile: $(distn "${_fname}")."
                    else
                        error "No such profile: $(diste "${_name}")"
                    fi
                    ;;

                @|show|h|s|S|stat|status) # all status
                    env_status
                    ;;

                reset)
                    ${RM_BIN} -f "${SOFIN_ENV_ENABLED_INDICATOR_FILE}" \
                        && permnote "Sofin environment is now: $(distn "dynamic")"
                    ;;

                r|reload|rehash) # NOTE: always done implicitly later
                    ;;

                *)
                    _bundles="${*}"
                    if [ -z "${_bundles}" ]; then
                        print_env_status
                        print_shell_vars
                        print_local_env_vars
                    else
                        _pkgp="."
                        _ldfl="${DEFAULT_LINKER_FLAGS}"
                        _cfl="${DEFAULT_COMPILER_FLAGS}"
                        _cxxfl="${CXX11_CXXFLAGS} ${_cfl}"
                        _pth="${DEFAULT_PATH}"
                        for _abundle in $(to_iter "${_bundles}"); do
                            if [ -d "${SOFTWARE_DIR}/${_abundle}/exports" ]; then
                                _pth="${SOFTWARE_DIR}/${_abundle}/exports:${_pth}"
                            fi
                            if [ -d "${SOFTWARE_DIR}/${_abundle}/include" ]; then
                                _cfl="-I${SOFTWARE_DIR}/${_abundle}/include ${_cfl}"
                            fi
                            if [ -d "${SOFTWARE_DIR}/${_abundle}/include" ]; then
                                _cxxfl="-I${SOFTWARE_DIR}/${_abundle}/include ${_cxxfl}"
                            fi
                            if [ -d "${SOFTWARE_DIR}/${_abundle}/lib" ]; then
                                _ldfl="-L${SOFTWARE_DIR}/${_abundle}/lib ${_ldfl}"
                            fi
                            if [ -d "${SOFTWARE_DIR}/${_abundle}/lib/pkgconfig" ]; then
                                _pkgp="${SOFTWARE_DIR}/${_abundle}/lib/pkgconfig:${_pkgp}"
                            fi
                        done
                        _cfl="$(printf "%b\n" "${_cfl}" | ${SED_BIN} 's/ *$//g; s/  //g' 2>/dev/null)"
                        _cxxfl="$(printf "%b\n" "${_cxxfl}" | ${SED_BIN} 's/ *$//g; s/  //g' 2>/dev/null)"
                        _ldfl="$(printf "%b\n" "${_ldfl}" | ${SED_BIN} 's/ *$//g; s/  //g' 2>/dev/null)"
                        _pkgp="$(printf "%b\n" "${_pkgp}" | ${SED_BIN} 's/ *$//g; s/  //g' 2>/dev/null)"
                        printf "%b\n" "export CFLAGS=\"${_cfl}\""
                        printf "%b\n" "export CXXFLAGS=\"${_cxxfl}\""
                        printf "%b\n" "export LDFLAGS=\"${_ldfl}\""
                        printf "%b\n" "export PKG_CONFIG_PATH=\"${_pkgp}\""
                        unset _pth _cfl _cxxfl _ldfl _pkgp _abundle

                        print_local_env_vars
                        return 0
                    fi
                    ;;
            esac

            # implicit reload:
            finalize_with_shell_reload
            ;;


        l|installed|list)
            list_bundles_alphabetic
            ;;


        f|fullinstalled|fulllist|full)
            list_bundles_full
            ;;


        # deprecated. Use: `s env` instead
        getshellvars|shellvars|vars)
            print_env_status
            print_shell_vars
            print_local_env_vars
            ;;


        upgrade|ug)
            _definition="${1}"
            _url="${2}"
            _archive_name="${_url##*/}"

            case "${SYSTEM_NAME}" in
                FreeBSD)
                    _sha="sha1 -q ${_archive_name} 2>/dev/null"
                    ;;
                *)
                    _sha="openssl sha1 ${_archive_name} 2>/dev/null | ${AWK_BIN} '{print \$2;}' 2>/dev/null"
                    ;;
            esac

            debug "Synchronizing archive: $(distd "${_archive_name}") to: $(distd "${MAIN_SOFTWARE_ADDRESS}")"
            _new_sha="$(${SSH_BIN} -p "${SOFIN_SSH_PORT}" "${SOFIN_NAME}@${MAIN_SOFTWARE_ADDRESS}" " \
                cd ${MAIN_SOURCE_PREFIX} \
                && test -f ${_archive_name} || curl -4 --progress-bar -C - -k -L -O '${_url}' > /tmp/sofin.sync.log 2>&1 \
                && ${_sha} \
                && return 0; \
                ${CAT_BIN} /tmp/sofin.sync.log; \
                return 1; \
                ")" || error "Failed to sync archive: $(diste "${_archive_name}")"
            _version="$(printf "%b\n" "${_archive_name}" | ${SED_BIN} -e 's#^.*-##; s#\.t[agx][rz]\..*$##;' 2>/dev/null)"

            note "Url archive of: $(distn "${_definition}") version: $(distn "${_version}") synchronized: $(distn "${_url}") ($(distn "${_new_sha}"))"

            debug "Updating local definition: $(distd "${_definition}") with version: $(distd "${_version}")"
            ${SED_BIN} -i '' -e "s#^DEF_VERSION=.*\$#DEF_VERSION=\"${_version}\"#" "${DEFINITIONS_DIR}/${_definition}${DEFAULT_DEF_EXT}"
            ${SED_BIN} -i '' -e "s#^DEF_SHA=.*\$#DEF_SHA=\"${_new_sha}\"#" "${DEFINITIONS_DIR}/${_definition}${DEFAULT_DEF_EXT}"

            _local="/Projects/Sofin-definitions/definitions" # XXX: hardcoded.
            if [ -d "${_local}" ]; then
                debug "Projects definition: $(distd "${_definition}") with version: $(distd "${_version}")"
                ${SED_BIN} -i '' -e "s#^DEF_VERSION=.*\$#DEF_VERSION=\"${_version}\"#" "${_local}/${_definition}${DEFAULT_DEF_EXT}"
                ${SED_BIN} -i '' -e "s#^DEF_SHA=.*\$#DEF_SHA=\"${_new_sha}\"#" "${_local}/${_definition}${DEFAULT_DEF_EXT}"
            fi
            ;;


        tool|mkutil|util) # `s tool`
            _utils="${*}"
            unset CAP_SYS_ZFS

            if [ -n "${_utils}" ]; then
                initialize
                validate_reqs

                for _util in $(to_iter "${_utils}"); do
                    _util="$(capitalize_abs "${_util}")"
                    debug "Starting utility build: $(distd "${_util}")"

                    export SOFTWARE_DIR="${SERVICES_DIR}/${SOFIN_BUNDLE_NAME}/${_util}"
                    export SERVICE_DIR="${SOFTWARE_DIR}"
                    export PREFIX="${SOFTWARE_DIR}"
                    export DEF_UTILITY_BUNDLE=YES
                    export USE_BINBUILD=NO

                    load_sofin # yea, reload from 0 after altering the core parts
                    load_defaults
                    load_defs "$(lowercase "${_util}")"

                    BUILD_NAMESUM="$(firstn "$(text_checksum "${_util}-${DEF_VERSION}")")"
                    BUILD_DIR="${PREFIX}/${DEFAULT_SRC_EXT}${BUILD_NAMESUM}"
                    try "${MKDIR_BIN} -p ${BUILD_DIR}"

                    if [ ! -f "${PREFIX}/${_util}${DEFAULT_INST_MARK_EXT}" ]; then
                        note "Buiding an utility: $(distn "${_util}") for: $(distn "${OS_TRIPPLE}")"
                        build "${_util}"
                    fi
                    note "Linking prebuilt utility: $(distn "${_util}") for: $(distn "${OS_TRIPPLE}")"
                    link_utilities
                    disallow_util_being_found
                done
                permnote "Installed utilities: $(distn "${_utils}")"
                finalize_complete_standard_task
            fi
            ;;


        i|install|get|pick|choose|use|switch)
            initialize
            validate_reqs
            _list_maybe="$(lowercase "${1}")"
            if [ -z "${_list_maybe}" ]; then
                error "Second argument, with at least one application (or list) name is required!"
            fi
            fail_on_bg_job "${SOFIN_ARGS}"
            # NOTE: trying a list first - it will have priority if file exists:
            if [ -f "${DEFINITIONS_LISTS_DIR}${_list_maybe}" ]; then
                _pickd_bundls="$(${CAT_BIN} "${DEFINITIONS_LISTS_DIR}${_list_maybe}" 2>/dev/null | eval "${NEWLINES_TO_SPACES_GUARD}")"
            else
                _pickd_bundls="${SOFIN_ARGS}"
            fi
            unset _instld_bundls
            for _buname in $(to_iter "${_pickd_bundls}"); do
                unset CURRENT_DEFINITION_VERSION_OVERRIDE
                _buname_sh_escaped="$(echo "${_buname}" | ${SED_BIN} -E 's/[-+%]/_/g' 2>/dev/null)"
                _specified_version_with_name="$(eval "echo \"\$${_buname_sh_escaped}\"" | ${SED_BIN} -E 's/=//;' 2>/dev/null)"
                if [ -n "${_specified_version_with_name}" ]; then
                    debug "Definition version is overriden to: '$(distd "${_specified_version_with_name}")'"
                    CURRENT_DEFINITION_VERSION_OVERRIDE="${_specified_version_with_name}"
                else
                    debug "No version override. Using most recent bundle version"
                fi

                _buname="$(capitalize_abs "${_buname%=*}")"
                build "${_buname}" \
                    && _instld_bundls="${_instld_bundls} ${_buname}"
                if [ "${USER}" != "root" ]; then
                    try "${CHOWN_BIN} -R ${USER} '${SOFTWARE_DIR}/${_buname}'" \
                        && debug "OK: $(distd "chown -R ${USER} '${SOFTWARE_DIR}/${_buname}'")."
                    try "${CHOWN_BIN} -R ${USER} '${SERVICES_DIR}/${_buname}'" \
                        && debug "OK: $(distd "chown -R ${USER} '${SERVICES_DIR}/${_buname}'")."
                fi
            done
            permnote "Installed bundles:$(distn "${_instld_bundls}")"
            unset _list_maybe _pickd_bundls _buname _specified_version_with_name _instld_bundls
            finalize_complete_standard_task
            ;;


        deps|dependencies|local)
            initialize
            validate_reqs
            if [ "${USER}" = "root" ]; then
                warn "Installation of project dependencies as root is immoral"
            fi
            fail_on_bg_job "${SOFIN_ARGS}"
            if [ ! -f "${DEFAULT_PROJECT_DEPS_LIST_FILE}" ]; then
                error "Dependencies file not found! Expected file: $(diste "${DEFAULT_PROJECT_DEPS_LIST_FILE}") in current directory!"
            fi
            _pickd_bundls="$(${CAT_BIN} "${DEFAULT_PROJECT_DEPS_LIST_FILE}" 2>/dev/null | eval "${NEWLINES_TO_SPACES_GUARD}")"
            _bundls_amount="$(printf "%b\n" "${_pickd_bundls}" | eval "${WORDS_COUNT_GUARD}")"

            permnote "Installing $(distn "${_bundls_amount}") bundle dependencies: $(distn "${_pickd_bundls}")"
            for _dep_bundle in $(to_iter "${_pickd_bundls}"); do
                build "${_dep_bundle}"
            done

            permnote "Building environment from local dependencies: $(distn "${_pickd_bundls}")"
            eval "${SOFIN_SHORT_NAME} env +${_pickd_bundls}"

            permnote "NOTE: You can return to default environment with: $(distn "${SOFIN_SHORT_NAME} env reset")"
            unset _pickd_bundls _bundls_amount
            finalize_complete_standard_task
            ;;


        b|build)
            if [ -n "${CAP_SYS_PRODUCTION}" ]; then
                warn "Bundle builds are disabled on production systems!"
                finalize_and_quit_gracefully_with_exitcode "${ERRORCODE_TASK_FAILURE}"
            fi
            initialize
            validate_reqs
            permnote "Requested Build of: $(distn "${SOFIN_ARGS}")"
            fail_on_bg_job "${SOFIN_ARGS}"
            USE_UPDATE=NO
            USE_BINBUILD=NO
            for _bundle in $(to_iter "${SOFIN_ARGS}"); do
                build "${_bundle}"
            done
            unset _bundle
            finalize_complete_standard_task
            ;;


        d|deploy|p|push|send)
            initialize
            deploy_bundle
            finalize_complete_standard_task
            ;;


        reset)
            initialize
            fail_on_bg_job "${SOFIN_ARGS}"
            reset_defs
            update_defs
            finalize_complete_standard_task
            ;;


        wipe)
            wipe_remote_archives "${SOFIN_ARGS}"
            ;;


        delete|destroy|remove|uninstall|rm)
            delete_bundle
            finalize_complete_standard_task
            ;;


        # deprecated. Use: `s env reset`
        reload|rehash)
            finalize_with_shell_reload
            ;;


        update|updatedefs|up)
            update_defs
            ;;


        avail|available)
            available_definitions
            ;;


        exportapp|export|exp)
            initialize
            make_exports "${1}" "${2}"
            finalize_complete_standard_task
            ;;


        sv|vs|vers|versions)
            show_available_versions_of_bundles "${SOFIN_ARGS}"
            ;;


        old|rusk)
            fail_on_bg_job "${SOFIN_ARGS}"
            show_outdated
            ;;

        out|outdated)
            fail_on_bg_job "${SOFIN_ARGS}"
            show_outdated RAW
            ;;

        srccheck)
            validate_sources
            ;;

        bundlelist|bundles)
            available_bundles
            ;;

        oldsrc)
            list_unused_sources
            ;;

        service-dir|serv-dir|sdir)
            _svc_dir="${SERVICES_DIR}/$(capitalize "${1}")"
            if [ -d "${_svc_dir}" ]; then
                printf "%b\n" "${_svc_dir}"
            fi
            ;;

        software-dir|soft-dir|dir)
            _soft_dir="${SOFTWARE_DIR}/$(capitalize "${1}")"
            if [ -d "${_soft_dir}" ]; then
                printf "%b\n" "${_soft_dir}"
            fi
            ;;

        utils-path|upath)
            if [ -d "${SOFIN_UTILS_DIR}" ]; then
                printf "%b\n" "${SOFIN_UTILS_DIR}/exports"
            fi
            ;;

        *)
            usage_howto
            ;;
    esac
else
    usage_howto
fi

unset sofin_args_FULL SOFIN_ARGS SOFIN_COMMAND SOFIN_PID

debug "${0}: Exit: $(distd "${ERRORCODE_NORMAL_EXIT}"). Pid: $(distd "${SOFIN_PID}")"
exit "${ERRORCODE_NORMAL_EXIT}"
