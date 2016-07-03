#!/usr/bin/env -S -P/Software/Zsh/exports:/bin sh
# @author: Daniel (dmilith) Dettlaff (dmilith at me dot com)

. /usr/share/sofin/loader

# this is internal version check for defaults.def
unset COMPLIANCE_CHECK

SOFIN_ARGS_FULL="$*"
SOFIN_ARGS="$(echo ${SOFIN_ARGS_FULL} | ${CUT_BIN} -d' ' -f2- 2>/dev/null)"
SOFIN_COMMAND_ARG="${1}"
SOFIN_PID="$$"

env_reset
if [ ! -z "${SOFIN_COMMAND_ARG}" ]; then
    case ${SOFIN_COMMAND_ARG} in

        dev)
            develop ${SOFIN_ARGS}
            ;;


        hack|h)
            hack_definition ${SOFIN_ARGS}
            ;;


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
            perform_clean dist
            update_defs
            ;;


        purge)
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
            create_cache_directories
            _list_maybe="$(lowercase "${2}")"
            if [ -z "${_list_maybe}" ]; then
                error "Second argument, with at least one application (or list) name is required!"
            fi
            fail_on_bg_job ${SOFIN_ARGS}
            # NOTE: trying a list first - it will have priority if file exists:
            if [ -f "${LISTS_DIR}${_list_maybe}" ]; then
                _pickd_bundls="$(${CAT_BIN} "${LISTS_DIR}${_list_maybe}" 2>/dev/null | eval ${NEWLINES_TO_SPACES_GUARD})"
            else
                _pickd_bundls="${SOFIN_ARGS}"
            fi
            debug "Processing software: $(distinct d "${_pickd_bundls}") for: $(distinct d ${OS_TRIPPLE})"
            build_all "${_pickd_bundls}"
            unset _pickd_bundls
            cleanup_after_tasks
            ;;


        deps|dependencies|local)
            create_cache_directories
            if [ "${USER}" = "root" ]; then
                warn "Installation of project dependencies as root is immoral"
            fi
            fail_on_bg_job ${SOFIN_ARGS}
            note "Looking for a dependencies list file: $(distinct n ${DEPENDENCIES_FILE}) in current directory"
            if [ ! -e "./${DEPENDENCIES_FILE}" ]; then
                error "Dependencies file not found!"
            fi
            _pickd_bundls="$(${CAT_BIN} ./${DEPENDENCIES_FILE} 2>/dev/null | eval ${NEWLINES_TO_SPACES_GUARD})"
            note "Installing dependencies: $(distinct n ${_pickd_bundls})"
            build_all "${_pickd_bundls}"
            unset _pickd_bundls
            cleanup_after_tasks
            ;;


        p|push|binpush|send)
            fail_on_bg_job ${SOFIN_ARGS}
            push_binbuild ${SOFIN_ARGS}
            cleanup_after_tasks
            ;;


        b|build)
            create_cache_directories
            _to_be_built="${SOFIN_ARGS}"
            note "Software bundles to be built: $(distinct n ${_to_be_built})"
            fail_on_bg_job ${_to_be_built}
            USE_UPDATE=NO
            USE_BINBUILD=NO
            build_all "${_to_be_built}"
            unset _to_be_built
            cleanup_after_tasks
            ;;


        d|deploy)
            fail_on_bg_job ${SOFIN_ARGS}
            deploy_binbuild ${SOFIN_ARGS}
            cleanup_after_tasks
            ;;


        reset)
            fail_on_bg_job ${SOFIN_ARGS}
            reset_definitions
            cleanup_after_tasks
            ;;


        rebuild)
            fail_on_bg_job ${SOFIN_ARGS}
            rebuild_bundle ${SOFIN_ARGS}
            cleanup_after_tasks
            ;;


        wipe)
            wipe_remote_archives ${SOFIN_ARGS}
            ;;


        delete|remove|uninstall|rm)
            fail_on_bg_job ${SOFIN_ARGS}
            remove_bundles ${SOFIN_ARGS}
            cleanup_after_tasks
            ;;


        reload|rehash)
            cleanup_after_tasks
            ;;


        update|updatedefs|up)
            update_defs
            ;;


        avail|available)
            available_definitions
            ;;


        exportapp|export|exp)
            fail_on_bg_job ${SOFIN_ARGS}
            make_exports ${SOFIN_ARGS}
            cleanup_after_tasks
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

exit
