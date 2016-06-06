#!/bin/sh
# @author: Daniel (dmilith) Dettlaff (dmilith at me dot com)

. share/sofin/loader || . /usr/share/sofin/loader

SOFIN_ARGS_FULL="$*"
SOFIN_ARGS="$(echo ${SOFIN_ARGS_FULL} | ${CUT_BIN} -d' ' -f2- 2>/dev/null)"
SOFIN_COMMAND_ARG="${1}"

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
            exit
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
            ;;


        i|install|get|pick|choose|use|switch)
            create_cache_directories
            if [ "$2" = "" ]; then
                error "Second argument, with at least one application name (or list) is required!"
            fi
            # NOTE: trying a list first - it will have priority if file exists:
            if [ -f "${LISTS_DIR}${2}" ]; then
                export APPLICATIONS="$(${CAT_BIN} ${LISTS_DIR}${2} 2>/dev/null | ${TR_BIN} '\n' ' ' 2>/dev/null)"
                debug "Processing software: $(distinct d ${APPLICATIONS}) for architecture: $(distinct d ${SYSTEM_ARCH})"
            else
                export APPLICATIONS="${SOFIN_ARGS}"
                debug "Processing software: $(distinct d ${SOFIN_ARGS}) for architecture: $(distinct d ${SYSTEM_ARCH})"
            fi
            ;;


        deps|dependencies|local)
            create_cache_directories
            if [ "${USERNAME}" = "root" ]; then
                warn "Installation of project dependencies as root is immoral"
            fi
            note "Looking for a dependencies list file: $(distinct n ${DEPENDENCIES_FILE}) in current directory"
            if [ ! -e "./${DEPENDENCIES_FILE}" ]; then
                error "Dependencies file not found!"
            fi
            export APPLICATIONS="$(${CAT_BIN} ./${DEPENDENCIES_FILE} 2>/dev/null | ${TR_BIN} '\n' ' ' 2>/dev/null)"
            note "Installing dependencies: $(distinct n ${APPLICATIONS})"
            ;;


        p|push|binpush|send)
            push_binbuild
            ;;

        b|build)
            create_cache_directories
            shift
            dependencies=$*
            note "Software bundles to be built: $(distinct n ${dependencies})"
            fail_on_background_sofin_job ${dependencies}

            export USE_UPDATE=NO
            export USE_BINBUILD=NO
            export APPLICATIONS="${dependencies}"
            ;;


        d|deploy)
            deploy_binbuild $*
            ;;


        reset)
            reset_definitions
            ;;

        rebuild)
            rebuild_application $*
            ;;


        wipe)
            wipe_remote_archives $*
            ;;


        delete|remove|uninstall|rm)
            remove_application $*
            ;;


        reload|rehash)
            update_shell_vars
            reload_zsh_shells
            exit
            ;;


        update|updatedefs|up)
            update_definitions
            exit
            ;;


        avail|available)
            available_definitions
            ;;


        exportapp|export|exp)
            make_exports $*
            ;;


        old|out|outdated|rusk)
            show_outdated
            ;;


        *)
            usage_howto
            ;;
    esac
else
    usage_howto
fi


# Update definitions and perform more checks
check_requirements


PATH=${DEFAULT_PATH}

for application in ${APPLICATIONS}; do
    specified="${application}" # store original value of user input
    application="$(lowercase ${application})"
    load_defaults
    validate_alternatives "${application}"
    load_defs "${application}" # prevent installation of requirements of disabled application:
    check_disabled "${DISABLE_ON}" # after which just check if it's not disabled
    if [ ! "${ALLOW}" = "1" ]; then
        warn "Bundle: $(distinct w ${application}) disabled on architecture: $(distinct w $(os_tripple))"
        ${FIND_BIN} ${PREFIX} -delete >> ${LOG} 2>> ${LOG}
    else
        for definition in ${DEFINITIONS_DIR}${application}.def; do
            unset DONT_BUILD_BUT_DO_EXPORTS
            debug "Reading definition: $(distinct d ${definition})"
            load_defaults
            load_defs "${definition}"
            check_disabled "${DISABLE_ON}" # after which just check if it's not disabled

            APP_LOWER="${APP_NAME}${APP_POSTFIX}"
            APP_NAME="$(capitalize ${APP_NAME})"
            # some additional convention check:
            if [ "${APP_NAME}" != "${specified}" -a \
                 "${APP_NAME}${APP_POSTFIX}" != "${specified}" ]; then
                warn "You specified lowercase name of bundle: $(distinct w ${specified}), which is in contradiction to Sofin's convention (bundle - capitalized: f.e. 'Rust', dependencies and definitions - lowercase: f.e. 'yaml')."
            fi
            # if definition requires root privileges, throw an "exception":
            if [ ! -z "${REQUIRE_ROOT_ACCESS}" ]; then
                if [ "${USERNAME}" != "root" ]; then
                    warn "Definition requires superuser priviledges: $(distinct w ${APP_NAME}). Installation aborted."
                    break
                fi
            fi

            export PREFIX="${SOFTWARE_DIR}${APP_NAME}${APP_POSTFIX}"
            export SERVICE_DIR="${SERVICES_DIR}${APP_NAME}${APP_POSTFIX}"
            if [ ! -z "${APP_STANDALONE}" ]; then
                ${MKDIR_BIN} -p "${SERVICE_DIR}"
                ${CHMOD_BIN} 0710 "${SERVICE_DIR}"
            fi


            # binary build of whole software bundle
            ABSNAME="${APP_NAME}${APP_POSTFIX}-${APP_VERSION}"
            ${MKDIR_BIN} -p "${BINBUILDS_CACHE_DIR}${ABSNAME}"

            ARCHIVE_NAME="${APP_NAME}${APP_POSTFIX}-${APP_VERSION}${DEFAULT_ARCHIVE_EXT}"
            INSTALLED_INDICATOR="${PREFIX}/${APP_LOWER}${INSTALLED_MARK}"

            if [ "${SOFIN_CONTINUE_BUILD}" = "YES" ]; then # normal build by default
                note "Continuing build in: $(distinct n ${PREVIOUS_BUILD_DIR})"
                cd "${PREVIOUS_BUILD_DIR}"
            else
                if [ ! -e "${INSTALLED_INDICATOR}" ]; then
                    try_fetch_binbuild
                else
                    already_installed_version="$(${CAT_BIN} ${INSTALLED_INDICATOR} 2>/dev/null)"
                    if [ "${APP_VERSION}" = "${already_installed_version}" ]; then
                        note "$(distinct n ${APP_NAME}${APP_POSTFIX}) bundle is installed with version: $(distinct n ${already_installed_version})"
                    else
                        warn "$(distinct w ${APP_NAME}${APP_POSTFIX}) bundle is installed with version: $(distinct w ${already_installed_version}), but newer version is defined: $(distinct w "${APP_VERSION}")"
                    fi
                    export DONT_BUILD_BUT_DO_EXPORTS=YES
                fi
            fi

            if [ -z "${DONT_BUILD_BUT_DO_EXPORTS}" ]; then
                if [ -z "${APP_REQUIREMENTS}" ]; then
                    note "Installing: $(distinct n ${APP_FULL_NAME}), version: $(distinct n ${APP_VERSION})"
                else
                    note "Installing: $(distinct n ${APP_FULL_NAME}), version: $(distinct n ${APP_VERSION}), with requirements: $(distinct n ${APP_REQUIREMENTS})"
                fi
                export req_amount="$(${PRINTF_BIN} "${APP_REQUIREMENTS}" | ${WC_BIN} -w 2>/dev/null | ${AWK_BIN} '{print $1;}' 2>/dev/null)"
                export req_amount="$(${PRINTF_BIN} "${req_amount} + 1\n" | ${BC_BIN} 2>/dev/null)"
                export req_all="${req_amount}"
                for req in ${APP_REQUIREMENTS}; do
                    if [ ! -z "${APP_USER_INFO}" ]; then
                        warn "${APP_USER_INFO}"
                    fi
                    if [ -z "${req}" ]; then
                        note "No additional requirements defined"
                        break
                    else
                        note "  ${req} ($(distinct n ${req_amount}) of $(distinct n ${req_all}) remaining)"
                        if [ ! -e "${PREFIX}/${req}${INSTALLED_MARK}" ]; then
                            export CHANGED=YES
                            execute_process "${req}"
                        fi
                    fi
                    export req_amount="$(${PRINTF_BIN} "${req_amount} - 1\n" | ${BC_BIN} 2>/dev/null)"
                done
            fi

            if [ -z "${DONT_BUILD_BUT_DO_EXPORTS}" ]; then
                if [ -e "${PREFIX}/${application}${INSTALLED_MARK}" ]; then
                    if [ "${CHANGED}" = "YES" ]; then
                        note "  ${application} ($(distinct n 1) of $(distinct n ${req_all}))"
                        note "   ${NOTE_CHAR} App dependencies changed. Rebuilding: $(distinct n ${application})"
                        execute_process "${application}"
                        unset CHANGED
                        mark
                        show_done
                    else
                        note "  ${application} ($(distinct n 1) of $(distinct n ${req_all}))"
                        show_done
                        debug "${SUCCESS_CHAR} $(distinct d ${application}) current: $(distinct d ${ver}), definition: [$(distinct d ${APP_VERSION})] Ok."
                    fi
                else
                    note "  ${application} ($(distinct n 1) of $(distinct n ${req_all}))"
                    execute_process "${application}"
                    mark
                    note "${SUCCESS_CHAR} ${application} [$(distinct n ${APP_VERSION})]\n"
                fi
            fi

            conflict_resolve
            load_defs "${application}"
            export_binaries
        done

        after_export_callback

        clean_useless
        strip_bundle_files
        manage_datasets
        create_apple_bundle_if_necessary
    fi
done

update_shell_vars
reload_zsh_shells

exit
