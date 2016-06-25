#!/bin/sh
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
            develop $*
            ;;


        hack|h)
            hack_definition $*
            ;;


        diffs|diff)
            show_diff $*
            ;;


        ver|version)
            note "$(sofin_header)"
            ;;


        log)
            show_logs $*
            ;;


        clean)
            perform_clean
            ;;


        distclean)
            perform_clean dist
            update_definitions
            ;;


        purge)
            perform_clean purge
            update_definitions
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
            if [ "$2" = "" ]; then
                error "Second argument, with at least one application name (or list) is required!"
            fi
            fail_on_background_sofin_job ${SOFIN_ARGS}
            # NOTE: trying a list first - it will have priority if file exists:
            if [ -f "${LISTS_DIR}${2}" ]; then
                export APPLICATIONS="$(${CAT_BIN} ${LISTS_DIR}${2} 2>/dev/null | eval ${NEWLINES_TO_SPACES_GUARD})"
                debug "Processing software: $(distinct d ${APPLICATIONS}) for architecture: $(distinct d ${SYSTEM_ARCH})"
            else
                export APPLICATIONS="${SOFIN_ARGS}"
                debug "Processing software: $(distinct d ${SOFIN_ARGS}) for architecture: $(distinct d ${SYSTEM_ARCH})"
            fi
            build_all
            cleanup_after_tasks
            ;;


        deps|dependencies|local)
            create_cache_directories
            if [ "${USERNAME}" = "root" ]; then
                warn "Installation of project dependencies as root is immoral"
            fi
            fail_on_background_sofin_job ${SOFIN_ARGS}
            note "Looking for a dependencies list file: $(distinct n ${DEPENDENCIES_FILE}) in current directory"
            if [ ! -e "./${DEPENDENCIES_FILE}" ]; then
                error "Dependencies file not found!"
            fi
            export APPLICATIONS="$(${CAT_BIN} ./${DEPENDENCIES_FILE} 2>/dev/null | eval ${NEWLINES_TO_SPACES_GUARD})"
            note "Installing dependencies: $(distinct n ${APPLICATIONS})"
            build_all
            cleanup_after_tasks
            ;;


        p|push|binpush|send)
            fail_on_background_sofin_job ${SOFIN_ARGS}
            push_binbuild
            cleanup_after_tasks
            ;;


        b|build)
            create_cache_directories
            dependencies="${SOFIN_ARGS}"
            note "Software bundles to be built: $(distinct n ${dependencies})"
            fail_on_background_sofin_job ${dependencies}

            export USE_UPDATE=NO
            export USE_BINBUILD=NO
            export APPLICATIONS="${dependencies}"
            build_all
            cleanup_after_tasks
            ;;


        d|deploy)
            fail_on_background_sofin_job ${SOFIN_ARGS}
            deploy_binbuild $*
            cleanup_after_tasks
            ;;


        reset)
            fail_on_background_sofin_job ${SOFIN_ARGS}
            reset_definitions
            cleanup_after_tasks
            ;;


        rebuild)
            fail_on_background_sofin_job ${SOFIN_ARGS}
            rebuild_application $*
            cleanup_after_tasks
            ;;


        wipe)
            wipe_remote_archives $*
            ;;


        delete|remove|uninstall|rm)
            fail_on_background_sofin_job ${SOFIN_ARGS}
            remove_application $*
            cleanup_after_tasks
            ;;


        reload|rehash)
            cleanup_after_tasks
            ;;


        update|updatedefs|up)
            update_definitions
            ;;


        avail|available)
            available_definitions
            ;;


        exportapp|export|exp)
            fail_on_background_sofin_job ${SOFIN_ARGS}
            make_exports $*
            cleanup_after_tasks
            ;;


        old|out|outdated|rusk)
            fail_on_background_sofin_job ${SOFIN_ARGS}
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
