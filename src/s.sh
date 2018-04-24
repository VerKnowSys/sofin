#!/usr/bin/env sh
# @author: Daniel (dmilith) Dettlaff (dmilith at me dot com)


# publish core values:
SOFIN_PID="$$"
SOFIN_ROOT="${SOFIN_ROOT:-/Software/Sofin}"
. "${SOFIN_ROOT}/share/loader"


# divide arguments:
SOFIN_COMMAND="${1}"
if [ "${#}" -gt "0" ]; then
    shift
    SOFIN_ARGS="${*}"
    _args="  args[$(distd "${#}")]: $(distd "${SOFIN_ARGS}"),"
fi

debug "Sofin (CMD='$(distd "${SOFIN_COMMAND}")',${_args}  SOFIN_PID=$(distd "${SOFIN_PID}"),  SOFIN_PPID=$(distd "${PPID}"),  SOFIN_ROOT='$(distd "${SOFIN_ROOT}")')"

# NOTE: magic echo since we play with ANSI lines management bit too much ;)
echo

# Set explicit +e for Sofin shell:
env_forgivable
validate_env

# On supported systems make sure that ZFS /Software/root dataset is set writable
set_software_root_writable

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
    printf "Enabled trace mode\n"
fi

if [ -n "${SOFIN_VERBOSE}" ]; then
    if [ "YES" = "${CAP_TERM_ZSH}" ] || \
       [ "YES" = "${CAP_TERM_BASH}" ]; then
        set -o verbose
    else
        set -v
    fi
    printf "Enabled verbose mode\n"
fi

# this is internal version check for defaults.def
unset COMPLIANCE_CHECK

if [ -n "${SOFIN_COMMAND}" ]; then
    case ${SOFIN_COMMAND} in

        dev)
            develop "${SOFIN_ARGS}"
            ;;


        diffs|diff)
            show_diff "${SOFIN_ARGS}"
            ;;


        ver|version)
            sofin_header
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
                        _bundle="$(capitalize "${_in#+}")"
                        if [ -e "${SOFTWARE_DIR}/${_bundle}" ]; then
                            _bundles="${_bundle} ${_bundles}"
                        fi
                    done
                    if [ -z "${_bundles}" ]; then
                        return 0
                    fi
                    enable_sofin_env "${_bundles}"
                    note "Updated profile with new bundles: $(distn "${_bundles}")"
                    ;;

                -*) # remove N elements
                    unset _bundles
                    _all="${*}"
                    for _in in $(to_iter "${_all}"); do
                        _bundle="$(capitalize "${_in#-}")"
                        if [ -e "${SOFTWARE_DIR}/${_bundle}" ]; then
                            _bundles="${_bundle} ${_bundles}"
                        fi
                    done
                    if [ -z "${_bundles}" ]; then
                        return 0
                    fi
                    disable_sofin_env "${_bundles}"
                    note "Updated profile without bundles: $(distn "${_bundles}")"
                    ;;

                !|store|save) # save profile
                    shift
                    _fname="${SOFIN_ENV_ENABLED_INDICATOR_FILE}.${1}"
                    note "Storing new environment profile: $(distn "${_fname}")"
                    run "${INSTALL_BIN} ${SOFIN_ENV_ENABLED_INDICATOR_FILE} ${_fname}"
                    ;;

                ^|load|ld) # load profile
                    shift
                    _name="${1}"
                    _fname="${SOFIN_ENV_ENABLED_INDICATOR_FILE}.${_name}"
                    if [ -f "${_fname}" ]; then
                        note "Loading environment profile: $(distn "${_fname}")"
                        run "${INSTALL_BIN} ${_fname} ${SOFIN_ENV_ENABLED_INDICATOR_FILE}"
                    else
                        error "No such profile: $(diste "${_name}")"
                    fi
                    ;;

                @|show|h|s|S|stat|status) # all status
                    env_status
                    ;;

                reset)
                    note "Resetting Sofin envrionment"
                    ${RM_BIN} -f "${SOFIN_ENV_ENABLED_INDICATOR_FILE}"
                    ;;

                r|reload|rehash) # NOTE: always done implicitly later
                    ;;

                *)
                    _bundles="${*}"
                    if [ -z "${_bundles}" ]; then
                        printf "${REPLAY_PREVIOUS_LINE}"
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
                        _cfl="$(echo "${_cfl}" | ${SED_BIN} 's/ *$//g; s/  //g' 2>/dev/null)"
                        _cxxfl="$(echo "${_cxxfl}" | ${SED_BIN} 's/ *$//g; s/  //g' 2>/dev/null)"
                        _ldfl="$(echo "${_ldfl}" | ${SED_BIN} 's/ *$//g; s/  //g' 2>/dev/null)"
                        _pkgp="$(echo "${_pkgp}" | ${SED_BIN} 's/ *$//g; s/  //g' 2>/dev/null)"
                        printf "${REPLAY_PREVIOUS_LINE}%s\n" "export CFLAGS=\"${_cfl}\""
                        printf "%s\n" "export CXXFLAGS=\"${_cxxfl}\""
                        printf "%s\n" "export LDFLAGS=\"${_ldfl}\""
                        printf "%s\n" "export PKG_CONFIG_PATH=\"${_pkgp}\""
                        unset _pth _cfl _cxxfl _ldfl _pkgp _abundle

                        print_local_env_vars
                        return 0
                    fi
                    ;;
            esac

            # implicit reload:
            finalize_shell_reload
            ;;


        l|installed|list)
            list_bundles_alphabetic
            ;;


        f|fullinstalled|fulllist|full)
            list_bundles_full
            ;;


        # deprecated. Use: `s env` instead
        getshellvars|shellvars|vars)
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
                echo; ${CAT_BIN} /tmp/sofin.sync.log; \
                return 1; \
                ")" || error "Failed to sync archive: $(diste "${_archive_name}")"
            _version="$(echo "${_archive_name}" | ${SED_BIN} -e 's#^.*-##; s#\.t[agx][rz]\..*$##;' 2>/dev/null)"

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
                    _util="$(capitalize "${_util}")"
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
                    else
                        note "Linking prebuilt utility: $(distn "${_util}") for: $(distn "${OS_TRIPPLE}")"
                        link_utilities
                    fi
                done
                note "Installed utilities: $(distn "${_utils}")"
                finalize
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
            for _b in $(to_iter "${_pickd_bundls}"); do
                build "${_b}"
            done
            note "Installed: $(distn "${_pickd_bundls}")"
            unset _pickd_bundls _b
            finalize
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
            _bundls_amount="$(printf "%s\n" "${_pickd_bundls}" | eval "${WORDS_COUNT_GUARD}")"
            note "Dependencies list file found with $(distn "${_bundls_amount}") elements in order: $(distn "${_pickd_bundls}")"
            for _b in $(to_iter "${_pickd_bundls}"); do
                debug "Buiding software: $(distd "${_b}") for: $(distd "${OS_TRIPPLE}")"
                build "${_b}"
            done
            unset _pickd_bundls _bundls_amount
            finalize
            ;;


        p|push|binpush|send)
            initialize
            validate_reqs
            fail_on_bg_job "${SOFIN_ARGS}"
            for _bundle in $(to_iter "${SOFIN_ARGS}"); do

                PREFIX="${SOFTWARE_DIR}/${_bundle}"
                debug "Cleaning up src dirs of prefix: $(distd "${PREFIX}/${DEFAULT_SRC_EXT}*")"

                # NOTE: Load details from Sofin definitions:
                load_defaults

                _req_definition="${DEFINITIONS_DIR}/$(lowercase "${_bundle}")${DEFAULT_DEF_EXT}"
                if [ ! -e "${_req_definition}" ]; then
                    error "Cannot read definition file: $(diste "${_req_definition}")!"
                fi
                load_defs "${_req_definition}"

                _full_version="$(lowercase "${DEF_NAME}${DEF_SUFFIX}-${DEF_VERSION}")"
                BUILD_NAMESUM="$(firstn "$(text_checksum "${_full_version}")")"
                debug "Calling destroy on prefix=$(distd "${PREFIX##*/}") _full_version=$(distd "${_full_version}") BUILD_NAMESUM=$(distd "${BUILD_NAMESUM}")"
                destroy_builddir "${PREFIX##*/}" "${BUILD_NAMESUM}"
            done
            permnote "Push locally built binary build(s): $(distn "${SOFIN_ARGS}")"
            push_binbuilds "${SOFIN_ARGS}"
            finalize
            ;;


        b|build)
            initialize
            validate_reqs
            permnote "Build bundle(s): $(distn "${SOFIN_ARGS}")"
            fail_on_bg_job "${SOFIN_ARGS}"
            USE_UPDATE=NO
            USE_BINBUILD=NO
            for _b in $(to_iter "${SOFIN_ARGS}"); do
                build "${_b}"
            done
            unset _b
            finalize
            ;;


        d|deploy)
            initialize
            validate_reqs
            permnote "Deploy bundle(s): $(distn "${SOFIN_ARGS}")"
            fail_on_bg_job "${SOFIN_ARGS}"
            deploy_binbuild "${SOFIN_ARGS}"
            finalize
            ;;


        reset)
            initialize
            fail_on_bg_job "${SOFIN_ARGS}"
            reset_defs
            update_defs
            finalize
            ;;


        rebuild)
            initialize
            validate_reqs
            fail_on_bg_job "${SOFIN_ARGS}"
            rebuild_bundle "${SOFIN_ARGS}"
            finalize
            ;;


        wipe)
            wipe_remote_archives "${SOFIN_ARGS}"
            ;;


        delete|remove|uninstall|rm)
            initialize
            fail_on_bg_job "${SOFIN_ARGS}"
            for _arg in $(to_iter "${SOFIN_ARGS}"); do
                _caparg="$(capitalize "${_arg}")"
                if [ -z "${_caparg}" ]; then
                    error "No software bundle names given?"
                fi
            done
            remove_bundles "${SOFIN_ARGS}"
            note "Removed bundle(s): $(distn "${SOFIN_ARGS}")"
            finalize
            ;;


        # deprecated. Use: `s env reset`
        reload|rehash)
            finalize_shell_reload
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
            finalize
            ;;


        old|rusk)
            fail_on_bg_job "${SOFIN_ARGS}"
            show_outdated
            ;;

        out|outdated)
            fail_on_bg_job "${SOFIN_ARGS}"
            show_outdated RAW
            ;;


        *)
            usage_howto
            ;;
    esac
else
    usage_howto
fi

unset sofin_args_FULL SOFIN_ARGS SOFIN_COMMAND SOFIN_PID

exit
