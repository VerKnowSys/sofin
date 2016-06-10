#!/bin/sh
# @author: Daniel (dmilith) Dettlaff (dmilith at me dot com)

. /usr/share/sofin/loader

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
            ;;


        purge)
            fail_on_background_sofin_job ${SOFIN_ARGS}
            perform_clean purge
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


        cont|continue)
            create_cache_directories
            shift
            a_bundle_name="$1"
            if [ -z "${a_bundle_name}" ]; then
                error "No bundle name given to continue build. Aborted!"
            fi
            fail_on_background_sofin_job ${SOFIN_ARGS}
            if [ "${SYSTEM_NAME}" = "Linux" ]; then # GNU guys have to be the unicorns..
                export MOST_RECENT_DIR="$(${FIND_BIN} ${CACHE_DIR}cache/ -mindepth 2 -maxdepth 2 -type d -iname "*${a_bundle_name}*" -printf '%T@ %p\n' 2>/dev/null | eval ${OLDEST_BUILD_DIR_GUARD})"
            else
                export MOST_RECENT_DIR="$(${FIND_BIN} ${CACHE_DIR}cache/ -mindepth 2 -maxdepth 2 -type d -iname "*${a_bundle_name}*" -print 2>/dev/null | ${XARGS_BIN} ${STAT_BIN} -f"%m %N" 2>/dev/null | eval ${OLDEST_BUILD_DIR_GUARD})"
            fi
            if [ ! -d "${MOST_RECENT_DIR}" ]; then
                error "No build dir: '${MOST_RECENT_DIR}' found to continue bundle build of: '${a_bundle_name}'"
            fi
            a_build_dir="$(${BASENAME_BIN} ${MOST_RECENT_DIR} 2>/dev/null)"
            note "Found most recent build dir: $(distinct n ${a_build_dir}) for bundle: $(distinct n ${a_bundle_name})"
            note "Resuming interrupted build.."
            export APPLICATIONS="${a_bundle_name}"
            export PREVIOUS_BUILD_DIR="${MOST_RECENT_DIR}"
            export SOFIN_CONTINUE_BUILD=YES
            build_all
            ;;


        i|install|get|pick|choose|use|switch)
            create_cache_directories
            if [ "$2" = "" ]; then
                error "Second argument, with at least one application name (or list) is required!"
            fi
            fail_on_background_sofin_job ${SOFIN_ARGS}
            # NOTE: trying a list first - it will have priority if file exists:
            if [ -f "${LISTS_DIR}${2}" ]; then
                export APPLICATIONS="$(${CAT_BIN} ${LISTS_DIR}${2} 2>/dev/null | ${TR_BIN} '\n' ' ' 2>/dev/null)"
                debug "Processing software: $(distinct d ${APPLICATIONS}) for architecture: $(distinct d ${SYSTEM_ARCH})"
            else
                export APPLICATIONS="${SOFIN_ARGS}"
                debug "Processing software: $(distinct d ${SOFIN_ARGS}) for architecture: $(distinct d ${SYSTEM_ARCH})"
            fi
            build_all
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
            export APPLICATIONS="$(${CAT_BIN} ./${DEPENDENCIES_FILE} 2>/dev/null | ${TR_BIN} '\n' ' ' 2>/dev/null)"
            note "Installing dependencies: $(distinct n ${APPLICATIONS})"
            build_all
            ;;


        p|push|binpush|send)
            fail_on_background_sofin_job ${SOFIN_ARGS}
            push_binbuild
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
            ;;


        d|deploy)
            fail_on_background_sofin_job ${SOFIN_ARGS}
            deploy_binbuild $*
            ;;


        reset)
            fail_on_background_sofin_job ${SOFIN_ARGS}
            reset_definitions
            ;;

        rebuild)
            fail_on_background_sofin_job ${SOFIN_ARGS}
            rebuild_application $*
            ;;


        wipe)
            wipe_remote_archives $*
            ;;


        delete|remove|uninstall|rm)
            fail_on_background_sofin_job ${SOFIN_ARGS}
            remove_application $*
            ;;


        reload|rehash)
            update_shell_vars
            reload_zsh_shells
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
