#!/usr/bin/env sh
# @author: Daniel (dmilith) Dettlaff (dmilith at me dot com)

SOFIN_PID="$$"
SOFIN_ARGS_FULL="${@}"
SOFIN_ROOT="${SOFIN_ROOT:-/Software/Sofin}"

. "${SOFIN_ROOT}/share/loader"

SOFIN_COMMAND_ARG="${1}"
SOFIN_ARGS="$(${PRINTF_BIN} '%s\n' "${SOFIN_ARGS_FULL}" | ${CUT_BIN} -d' ' -f2- 2>/dev/null)"

debug "Sofin args: $(distd "${SOFIN_ARGS_FULL}"), sub_args: $(distd "${SOFIN_ARGS}")"
echo

# publish core values:

export SOFIN_PID SOFIN_ROOT SOFIN_ARGS SOFIN_ARGS_FULL SOFIN_COMMAND_ARG

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

if [ -n "${SOFIN_COMMAND_ARG}" ]; then
    case ${SOFIN_COMMAND_ARG} in

        dev)
            develop "${SOFIN_ARGS}"
            ;;


        # TODO: re-enable this feature
        # hack|h)
        #     hack_def "${SOFIN_ARGS}"
        #     ;;


        diffs|diff)
            show_diff "${SOFIN_ARGS}"
            ;;


        ver|version)
            sofin_header
            ;;


        log)
            show_logs "${SOFIN_ARGS%${SOFIN_COMMAND_ARG}}"
            ;;


        less|les|show)
            less_logs "${SOFIN_ARGS%${SOFIN_COMMAND_ARG}}"
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


        enable)
            shift
            _bundles="${*}"
            debug "Enabling Sofin env for bundles: $(distd "${_bundles}")"
            enable_sofin_env "${_bundles}"
            finalize_shell_reload
            ;;


        disable)
            shift
            _bundles="${*}"
            debug "Disabling Sofin env for bundles: $(distd "${_bundles}")"
            disable_sofin_env "${_bundles}"
            finalize_shell_reload
            ;;


        env)
            shift
            debug "Sofin-env mode: $(distd "${env}")"
            case "${1}" in

                +) # add
                    shift
                    _bundles="${*}"
                    note "Enabling bundles: $(distn "${_bundles}")"
                    enable_sofin_env "${_bundles}"
                    ;;

                -) # remove
                    shift
                    _bundles="${*}"
                    note "Disabling bundles: $(distn "${_bundles}")"
                    disable_sofin_env "${_bundles}"
                    ;;

                !) # save
                    shift
                    _fname="${SOFIN_ENV_ENABLED_INDICATOR_FILE}.${1}"
                    note "Storing new environment profile: $(distn "${_fname}")"
                    run "${INSTALL_BIN} -v ${SOFIN_ENV_ENABLED_INDICATOR_FILE} ${_fname}"
                    ;;

                @) # load
                    shift
                    _name="${1}"
                    _fname="${SOFIN_ENV_ENABLED_INDICATOR_FILE}.${_name}"
                    if [ -f "${_fname}" ]; then
                        note "Loading environment profile: $(distn "${_fname}")"
                        run "${INSTALL_BIN} -v ${_fname} ${SOFIN_ENV_ENABLED_INDICATOR_FILE}"
                    else
                        error "No such profile: $(diste "${_name}")"
                    fi
                    ;;

                *)
                    shift

                    env_status
                    ;;
            esac
            ;;


        l|installed|list)
            list_bundles_alphabetic
            ;;


        f|fullinstalled|fulllist|full)
            list_bundles_full
            ;;


        getshellvars|shellvars|vars)
            get_shell_vars
            ;;


        i|install|get|pick|choose|use|switch)
            initialize
            _list_maybe="$(lowercase "${2}")"
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
            for _b in $(echo "${_pickd_bundls}" | ${TR_BIN} ' ' '\n' 2>/dev/null); do
                debug "Buiding software: $(distd "${_b}") for: $(distd "${OS_TRIPPLE}")"
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
            for _b in $(echo "${_pickd_bundls}" | ${TR_BIN} ' ' '\n' 2>/dev/null); do
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
            eval "${RM_BIN} -vfr ${PREFIX}/${DEFAULT_SRC_EXT}*" >> "${LOG}" 2>> "${LOG}"
            note "Pushing local binary builds: $(distn "${SOFIN_ARGS}")"
            push_binbuilds "${SOFIN_ARGS}"
            finalize
            ;;


        b|build)
            initialize
            _to_be_built="${SOFIN_ARGS}"
            note "Requested build of: $(distn "${_to_be_built}")"
            fail_on_bg_job "${_to_be_built}"
            USE_UPDATE=NO
            USE_BINBUILD=NO
            for _b in $(echo "${_to_be_built}" | ${TR_BIN} ' ' '\n' 2>/dev/null); do
                build "${_b}"
            done
            unset _to_be_built _b
            finalize
            ;;


        d|deploy)
            initialize
            fail_on_bg_job "${SOFIN_ARGS}"
            deploy_binbuild "${SOFIN_ARGS}"
            finalize
            ;;


        reset)
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
            make_exports "${2}" "${3}"
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

unset SOFIN_ARGS_FULL SOFIN_ARGS SOFIN_COMMAND_ARG SOFIN_PID

exit
