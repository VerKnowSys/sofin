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
    ${PRINTF_BIN} "Enabled trace mode\n"
fi

if [ -n "${SOFIN_VERBOSE}" ]; then
    if [ "YES" = "${CAP_TERM_ZSH}" ] || \
       [ "YES" = "${CAP_TERM_BASH}" ]; then
        set -o verbose
    else
        set -v
    fi
    ${PRINTF_BIN} "Enabled verbose mode\n"
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

                +) # add
                    shift
                    _bundles="${*}"
                    note "Added bundles: $(distn "${_bundles}") to current profile."
                    enable_sofin_env "${_bundles}"
                    ;;

                -) # remove
                    shift
                    _bundles="${*}"
                    note "Removed bundles: $(distn "${_bundles}") from current profile."
                    disable_sofin_env "${_bundles}"
                    ;;

                !) # save
                    shift
                    _fname="${SOFIN_ENV_ENABLED_INDICATOR_FILE}.${1}"
                    note "Storing new environment profile: $(distn "${_fname}")"
                    run "${INSTALL_BIN} ${SOFIN_ENV_ENABLED_INDICATOR_FILE} ${_fname}"
                    ;;

                ^) # load
                    shift
                    _name="${1}"
                    _fname="${SOFIN_ENV_ENABLED_INDICATOR_FILE}.${_name}"
                    if [ -f "${_fname}" ]; then
                        note "Loading environment profile: $(distn "${_fname}")"
                        run "${INSTALL_BIN} ${_fname} ${SOFIN_ENV_ENABLED_INDICATOR_FILE}"
                        update_shell_vars
                        reload_shell
                    else
                        error "No such profile: $(diste "${_name}")"
                    fi
                    ;;

                @|show|h|s|S|stat|status) # all status
                    env_status
                    ;;

                r|reload|rehash)
                    finalize_shell_reload
                    ;;

                *)
                    _bundles="${*}"
                    if [ -z "${_bundles}" ]; then
                        ${PRINTF_BIN} "${REPLAY_PREVIOUS_LINE}"
                        print_shell_vars
                        print_local_env_vars
                    else
                        _pkgp="."
                        _ldfl="${DEFAULT_LINKER_FLAGS}"
                        _cfl="${DEFAULT_COMPILER_FLAGS}"
                        _cxxfl="-std=c++11 ${_cfl}"
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
                        ${PRINTF_BIN} "${REPLAY_PREVIOUS_LINE}%s\n" "export CFLAGS=\"${_cfl}\""
                        ${PRINTF_BIN} "%s\n" "export CXXFLAGS=\"${_cxxfl}\""
                        ${PRINTF_BIN} "%s\n" "export LDFLAGS=\"${_ldfl}\""
                        ${PRINTF_BIN} "%s\n" "export PKG_CONFIG_PATH=\"${_pkgp}\""
                        unset _pth _cfl _cxxfl _ldfl _pkgp _abundle

                        print_local_env_vars
                    fi
                    ;;
            esac
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


        i|install|get|pick|choose|use|switch)
            initialize
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
            unset _pickd_bundls _b
            finalize
            ;;


        deps|dependencies|local)
            initialize
            if [ "${USER}" = "root" ]; then
                warn "Installation of project dependencies as root is immoral"
            fi
            fail_on_bg_job "${SOFIN_ARGS}"
            if [ ! -f "${DEFAULT_PROJECT_DEPS_LIST_FILE}" ]; then
                error "Dependencies file not found! Expected file: $(diste "${DEFAULT_PROJECT_DEPS_LIST_FILE}") in current directory!"
            fi
            _pickd_bundls="$(${CAT_BIN} "${DEFAULT_PROJECT_DEPS_LIST_FILE}" 2>/dev/null | eval "${NEWLINES_TO_SPACES_GUARD}")"
            _bundls_amount="$(${PRINTF_BIN} '%s\n' "${_pickd_bundls}" | eval "${WORDS_COUNT_GUARD}")"
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
            fail_on_bg_job "${SOFIN_ARGS}"
            debug "Removing any dangling src dirs of prefix: $(distd "${PREFIX}/${DEFAULT_SRC_EXT}*")"
            try "${RM_BIN} -fr ${PREFIX}/${DEFAULT_SRC_EXT}*"
            note "Pushing local binary builds: $(distn "${SOFIN_ARGS}")"
            push_binbuilds "${SOFIN_ARGS}"
            finalize
            ;;


        b|build)
            initialize
            permnote "Requested build of bundle(s): $(distn "${SOFIN_ARGS}")"
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
            permnote "Requested build of bundle(s): $(distn "${SOFIN_ARGS}")"
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
            remove_bundles "${SOFIN_ARGS}"
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


        old|out|outdated|rusk)
            fail_on_bg_job "${SOFIN_ARGS}"
            show_outdated
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
