#!/usr/bin/env sh
# @author: Daniel (dmilith) Dettlaff (dmilith at me dot com)

. /usr/share/sofin/loader

# this is internal version check for defaults.def
unset COMPLIANCE_CHECK

# performance counts:
SOFIN_START="${SOFIN_START:-$(${SOFIN_MICROSECONDS_UTILITY_BIN})}"

SOFIN_ARGS_FULL=${*}
SOFIN_COMMAND_ARG="${1}"
SOFIN_ARGS="$(${PRINTF_BIN} '%s\n' "${SOFIN_ARGS_FULL}" | ${CUT_BIN} -d' ' -f2- 2>/dev/null)"
SOFIN_PID="${SOFIN_PID:-$$}"


env_reset
if [ -n "${SOFIN_COMMAND_ARG}" ]; then
    case ${SOFIN_COMMAND_ARG} in

        dev)
            develop ${SOFIN_ARGS}
            ;;


        # TODO: re-enable this feature
        # hack|h)
        #     hack_def ${SOFIN_ARGS}
        #     ;;


        diffs|diff)
            show_diff ${SOFIN_ARGS}
            ;;


        ver|version)
            note "$(sofin_header)"
            ;;


        log)
            show_logs ${SOFIN_ARGS}
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
            enable_sofin_env
            ;;


        disable)
            disable_sofin_env
            ;;


        stat|status)
            sofin_status
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
            create_dirs
            _list_maybe="$(lowercase "${2}")"
            if [ -z "${_list_maybe}" ]; then
                error "Second argument, with at least one application (or list) name is required!"
            fi
            fail_on_bg_job ${SOFIN_ARGS}
            # NOTE: trying a list first - it will have priority if file exists:
            if [ -f "${DEFINITIONS_LISTS_DIR}${_list_maybe}" ]; then
                _pickd_bundls="$(${CAT_BIN} "${DEFINITIONS_LISTS_DIR}${_list_maybe}" 2>/dev/null | eval "${NEWLINES_TO_SPACES_GUARD}")"
            else
                _pickd_bundls=${SOFIN_ARGS}
            fi
            debug "Processing software: $(distd "${_pickd_bundls}") for: $(distd "${OS_TRIPPLE}")"
            build "${_pickd_bundls}"
            unset _pickd_bundls
            finalize
            ;;


        deps|dependencies|local)
            initialize
            create_dirs
            if [ "${USER}" = "root" ]; then
                warn "Installation of project dependencies as root is immoral"
            fi
            fail_on_bg_job ${SOFIN_ARGS}
            if [ ! -f "${DEFAULT_PROJECT_DEPS_LIST_FILE}" ]; then
                error "Dependencies file not found! Expected file: $(diste "${DEFAULT_PROJECT_DEPS_LIST_FILE}") in current directory!"
            fi
            _pickd_bundls="$(${CAT_BIN} "${DEFAULT_PROJECT_DEPS_LIST_FILE}" 2>/dev/null | eval "${NEWLINES_TO_SPACES_GUARD}")"
            _bundls_amount="$(${PRINTF_BIN} '%s\n' "${_pickd_bundls}" | eval "${WORDS_COUNT_GUARD}")"
            note "Dependencies list file found with $(distn "${_bundls_amount}") elements in order: $(distn "${_pickd_bundls}")"
            build "${_pickd_bundls}"
            unset _pickd_bundls _bundls_amount
            finalize
            ;;


        p|push|binpush|send)
            initialize
            fail_on_bg_job ${SOFIN_ARGS}
            push_binbuilds ${SOFIN_ARGS}
            finalize
            ;;


        b|build)
            initialize
            create_dirs
            _to_be_built=${SOFIN_ARGS}
            note "Requested build of: $(distn "${_to_be_built}")"
            fail_on_bg_job "${_to_be_built}"
            USE_UPDATE=NO
            USE_BINBUILD=NO
            build "${_to_be_built}"
            unset _to_be_built
            finalize
            ;;


        d|deploy)
            initialize
            fail_on_bg_job ${SOFIN_ARGS}
            deploy_binbuild ${SOFIN_ARGS}
            finalize
            ;;


        reset)
            fail_on_bg_job ${SOFIN_ARGS}
            reset_defs
            finalize
            ;;


        rebuild)
            initialize
            fail_on_bg_job ${SOFIN_ARGS}
            rebuild_bundle ${SOFIN_ARGS}
            finalize
            ;;


        wipe)
            wipe_remote_archives ${SOFIN_ARGS}
            ;;


        delete|remove|uninstall|rm)
            initialize
            fail_on_bg_job ${SOFIN_ARGS}
            remove_bundles ${SOFIN_ARGS}
            finalize
            ;;


        reload|rehash)
            finalize
            ;;


        update|updatedefs|up)
            update_defs
            ;;


        avail|available)
            available_definitions
            ;;


        exportapp|export|exp)
            initialize
            fail_on_bg_job ${SOFIN_ARGS}
            make_exports ${SOFIN_ARGS}
            finalize
            ;;


        old|out|outdated|rusk)
            fail_on_bg_job ${SOFIN_ARGS}
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
