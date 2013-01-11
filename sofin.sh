#!/bin/sh
# @author: Daniel (dmilith) Dettlaff (dmilith@verknowsys.com)

# config settings
VERSION="0.32.0"

# load configuration from sofin.conf

CONF_FILE="/etc/sofin.conf.sh"
if [ -e "${CONF_FILE}" ]; then
    . "${CONF_FILE}"
    validate_env
else
    echo "FATAL: No configuration file found: ${CONF_FILE}"
    exit 1
fi

if [ "${TRACE}" = "true" ]; then
    set -x
fi


check_definition_dir () {
    if [ ! -d "${SOFTWARE_DIR}" ]; then
        note "No ${SOFTWARE_DIR} found. Creating one."
        "${MKDIR_BIN}" -p "${SOFTWARE_DIR}"
    fi
    if [ ! -d "${CACHE_DIR}" ]; then
        note "No cache folder found. Creating one at: ${CACHE_DIR}"
        "${MKDIR_BIN}" -p "${CACHE_DIR}"
    fi
}


check_requirements () {
    if [ "${APPLICATIONS}" = "" ]; then
        error "Empty applications list!"
        exit 1
    fi
    if [ "${SYSTEM_NAME}" != "Darwin" ]; then
        files="$(${FIND_BIN} /usr/local -type f | ${WC_BIN} -l | ${SED_BIN} -e 's/^ *//g;s/ *$//g' )"
        if [ "${files}" != "0" ]; then
            warn "/usr/local has been found, and contains ${files} file(s)"
        fi
    fi
}


set_c_compiler () {
    case $1 in
        GNU)
            BASE_COMPILER="/usr/bin"
            export CC="${BASE_COMPILER}/gcc ${APP_COMPILER_ARGS}"
            export CXX="${BASE_COMPILER}/g++ ${APP_COMPILER_ARGS}"
            export CPP="${BASE_COMPILER}/cpp"
            ;;

        CLANG)
            BASE_COMPILER="${SOFTWARE_DIR}Clang/exports"
            if [ ! -f "${BASE_COMPILER}/clang" ]; then
                export BASE_COMPILER="/usr/bin"
                if [ ! -x "${BASE_COMPILER}/clang" ]; then
                    set_c_compiler GNU # fallback to gcc on system without any clang version
                fi
            fi
            export CC="${BASE_COMPILER}/clang ${APP_COMPILER_ARGS}"
            export CXX="${BASE_COMPILER}/clang++ ${APP_COMPILER_ARGS}"
            export CPP="${BASE_COMPILER}/clang-cpp"
            if [ ! -x "${CPP}" ]; then # fallback for systems with clang without standalone preprocessor binary:
                export CPP="${BASE_COMPILER}/clang -E"
            fi
            ;;

    esac

}


update_definitions () { # accepts optional user uid param
    if [ "${DEVEL}" != "" ]; then
        warn "Devel mode enabled. Not updating definitions from repository: ${MAIN_SOURCE_REPOSITORY}"
        return
    fi
    tar_options="xf"
    rm_options="-rf"
    if [ "${DEBUG}" = "true" ]; then
        tar_options="${tar_options}v"
        rm_options="${rm_options}v"
    fi
    debug "Checking for destination directories existance…"
    for element in "${LISTS_DIR}" "${DEFINITIONS_DIR}"; do
        ${MKDIR_BIN} -p "${element}" > /dev/null
        if [ ! -z "${1}" ]; then # param with uid not given
            ${TOUCH_BIN} "${LOG}"
            if [ "$(${ID_BIN} -u)" = "0" ]; then
                if [ ! -z "${1}" ]; then
                    debug "Chowning ${element} for user: ${1}"
                    ${CHOWN_BIN} -R ${1} "${element}" >> "${LOG}"
                fi
            fi
        fi
        debug "Removing old definitions: ${element}"
        ${RM_BIN} ${rm_options} ${element} >> "${LOG}"
    done
    cd "${CACHE_DIR}"
    debug "Working in cache dir: ${CACHE_DIR}"
    note "${HEADER}"
    ${PRINTF_BIN} "${reset}\n"
    debug "Updating definitions snapshot from: ${MAIN_SOURCE_REPOSITORY}definitions/${DEFINITION_SNAPSHOT_FILE}"
    ${FETCH_BIN} "${MAIN_SOURCE_REPOSITORY}definitions/${DEFINITION_SNAPSHOT_FILE}" >> "${LOG}" 2>> "${LOG}"
    ${TAR_BIN} ${tar_options} "${DEFINITION_SNAPSHOT_FILE}" >> "${LOG}" 2>> "${LOG}"
    if [ "$(${ID_BIN} -u)" = "0" ]; then
        if [ ! -z "${1}" ]; then
            debug "Chowning definitions for user: ${1}"
            ${CHOWN_BIN} -R ${1} "${CACHE_DIR}" >> "${LOG}"
        fi
    fi
}


write_info_about_shell_configuration () {
    note
    warn "You'll need to restart Your shell before using installed software in order to update environment variables."
    warn "To get this done automatically, put these lines to Your /etc/zshrc :"
    ${PRINTF_BIN} "if [ \"\$\(/usr/bin/id -u\)\" = \"0\" ]; then\n"
    ${PRINTF_BIN} "    trap \"source /etc/profile_sofin\" USR2\n"
    ${PRINTF_BIN} "else\n"
    ${PRINTF_BIN} "    if [ -e \$HOME/.profile ]; then\n"
    ${PRINTF_BIN} "        . \$HOME/.profile\n"
    ${PRINTF_BIN} "    fi\n"
    ${PRINTF_BIN} "    trap \"source \$HOME/.profile\" USR2\n"
    ${PRINTF_BIN} "fi\n"
    ${PRINTF_BIN} "export SHELL_PID=\"\$\$\"\n"
}


usage_howto () {
    note "Built in tasks:"
    note
    note "install | add                        - installs software from list (example: $(${BASENAME_BIN} ${SCRIPT_NAME}) install languages)"
    note "upgrade                              - upgrades one of dependencies of installed definition (example: $(${BASENAME_BIN} ${SCRIPT_NAME}) upgrade iconv ruby - to upgrade iconv in Ruby bundle)"
    note "dependencies | deps | local          - installs software from list defined in '${DEPENDENCIES_FILE}' file in current directory"
    note "one | cherrypick | get               - installs one application from definition (example: $(${BASENAME_BIN} ${SCRIPT_NAME}) get ruby)"
    note "uninstall | remove | delete          - removes one application (example: $(${BASENAME_BIN} ${SCRIPT_NAME}) uninstall ruby)"
    note "list | installed                     - short list of installed software"
    note "fulllist | fullinstalled             - detailed lists with installed software including requirements"
    note "available                            - lists available software"
    note "export | exp | exportapp             - adds given command to application exports (example: $(${BASENAME_BIN} ${SCRIPT_NAME}) export rails ruby)"
    note "getshellvars | shellvars | vars      - returns shell variables for installed software"
    note "log                                  - shows and watches log file (for debug messages and verbose info)"
    note "reload | rehash                      - recreate shell vars and reload current shell"
    note "update                               - only update definitions from remote repository and exit"
    note "ver | version                        - shows $(${BASENAME_BIN} ${SCRIPT_NAME}) script version"
    exit
}


update_shell_vars () {
    USER_UID="$(${ID_BIN} ${ID_SVD})"
    if [ "$(${ID_BIN} -u)" = "0" ]; then
        debug "Updating ${SOFIN_PROFILE} settings…"
        ${PRINTF_BIN} "$(${SCRIPT_NAME} getshellvars)" > "${SOFIN_PROFILE}"
    else
        debug "Updating ${HOME_DIR}${USER_UID}/.profile settings…"
        ${PRINTF_BIN} "$(${SCRIPT_NAME} getshellvars ${USER_UID})" > "${HOME_DIR}${USER_UID}/.profile"
    fi
}


check_disabled () {
    # check requirement for disabled state:
    export ALLOW="1"
    if [ ! "$1" = "" ]; then
        for disabled in ${1}; do
            debug "Running system: ${SYSTEM_NAME}"
            debug "DisableOn element: ${disabled}"
            if [ "$SYSTEM_NAME" = "${disabled}" ]; then
                export ALLOW="0"
            fi
        done
    fi
}


# first part of checks
check_os
check_definition_dir


# unset conflicting environment variables
unset LDFLAGS
unset CFLAGS
unset CXXFLAGS
unset CPPFLAGS
unset PATH
unset LD_LIBRARY_PATH
unset LD_PRELOAD
unset DYLD_LIBRARY_PATH
unset PKG_CONFIG_PATH


if [ ! "$1" = "" ]; then
    case $1 in


    ver|version)
        note "${HEADER}"
        exit
        ;;


    log)
        if [ -z "${2}" ]; then
            export LOG="${HOME_DIR}$(${ID_BIN} ${ID_SVD})/install.log"
            if [ "$(${ID_BIN} -u)" = "0" ]; then
                check_root
                export LOG="${CACHE_DIR}install.log"
            fi
        else
            export LOG="${HOME_DIR}${2}/install.log"
            if [ ! "$(${ID_BIN} ${ID_SVD})" = "${2}" ]; then
                check_root
            fi
        fi
        ${TAIL_BIN} -n "${LOG_LINES_AMOUNT}" -F "${LOG}"
        ;;


    installed|list)
        if [ -z "${2}" ]; then
            export SOFT_DIR="${HOME_DIR}$(${ID_BIN} ${ID_SVD})/${HOME_APPS_DIR}"
            if [ "$(${ID_BIN} -u)" = "0" ]; then
                check_root
                export SOFT_DIR="${SOFTWARE_DIR}"
            fi
        else
            export SOFT_DIR="${HOME_DIR}$2/${HOME_APPS_DIR}"
            if [ ! "$(${ID_BIN} ${ID_SVD})" = "${2}" ]; then
                check_root
            fi
        fi
        if [ -d ${SOFT_DIR} ]; then
            for app in $(${FIND_BIN} ${SOFT_DIR}/* -maxdepth 0 -type d); do
                echo "$(${BASENAME_BIN} ${app})"
            done
        fi
        exit
        ;;


    fullinstalled|fulllist)
        if [ -z "${2}" ]; then
            export SOFT_DIR="${HOME_DIR}$(${ID_BIN} ${ID_SVD})/${HOME_APPS_DIR}"
            if [ "$(${ID_BIN} -u)" = "0" ]; then
                check_root
                export SOFT_DIR="${SOFTWARE_DIR}"
            fi
        else
            export SOFT_DIR="${HOME_DIR}$2/${HOME_APPS_DIR}"
            if [ ! "$(${ID_BIN} ${ID_SVD})" = "${2}" ]; then
                check_root
            fi
        fi
        note "Installed applications:"
        note
        if [ -d ${SOFT_DIR} ]; then
            for app in ${SOFT_DIR}*; do
                app_name="$(${BASENAME_BIN} ${app})"
                note "Checking ${app_name}"
                for req in $(${FIND_BIN} ${app} -maxdepth 1 -name *${INSTALLED_MARK} | ${SORT_BIN}); do
                    pp="$(${PRINTF_BIN} "$(${BASENAME_BIN} ${req})" | ${SED_BIN} 's/\.installed//')"
                    note "  ${pp} [$(${CAT_BIN} ${req})]"
                done
                note "√ ${app_name}\n"
            done
        fi
        exit
        ;;


    getshellvars|shellvars|vars)

        # PATH:
        result="${DEFAULT_PATH}"
        process () {
            for app in ${1}*; do # SOFT_DIR
                exp="${app}/exports"
                if [ -e "${exp}" ]; then
                    result="${exp}:${result}"
                fi
            done
        }
        process ${SOFTWARE_DIR}
        if [ ! -z "$2" ]; then
            process ${HOME_DIR}${2}/${HOME_APPS_DIR}
        fi
        ${PRINTF_BIN} "# PATH:\n"
        ${PRINTF_BIN} "export PATH=${result}\n\n"

        # LD_LIBRARY_PATH, LDFLAGS, PKG_CONFIG_PATH:
        # ldresult="/lib:/usr/lib"
        # pkg_config_path="."
        export ldflags="${LDFLAGS} ${DEFAULT_LDFLAGS}"
        process () {
            for lib in ${1}*; do # LIB_DIR
                if [ -e "${lib}/lib" ]; then
                    ldresult="${lib}/lib:${ldresult}"
                    ldflags="-R${lib}/lib -L${lib}/lib ${ldflags}"
                fi
                if [ -e "${lib}/libexec" ]; then
                    ldresult="${lib}/libexec:${ldresult}"
                    ldflags="-R${lib}/libexec -L${lib}/libexec ${ldflags}"
                fi
                if [ -e "${lib}/pkgconfig" ]; then
                    pkg_config_path="${lib}/pkgconfig:${pkg_config_path}"
                fi
            done
        }
        process ${SOFTWARE_DIR}
        if [ ! -z "$2" ]; then
            process ${HOME_DIR}$2/${HOME_APPS_DIR}
        fi
        # ${PRINTF_BIN} "# LD_LIBRARY_PATH:\n"
        # ${PRINTF_BIN} "export LD_LIBRARY_PATH='${ldresult}'\n\n"
        ${PRINTF_BIN} "# LDFLAGS:\n"
        if [ "${SYSTEM_NAME}" = "Darwin" ]; then
            ${PRINTF_BIN} "export LDFLAGS='${ldflags}'\n\n"
            ${PRINTF_BIN} "# PKG_CONFIG_PATH:\n"
            ${PRINTF_BIN} "export PKG_CONFIG_PATH='${pkg_config_path}:/opt/X11/lib/pkgconfig'\n\n"
            # ${PRINTF_BIN} "export DYLD_LIBRARY_PATH='${ldresult}:/opt/X11/lib'\n\n"
        else
            ${PRINTF_BIN} "export LDFLAGS='${ldflags} -Wl,--enable-new-dtags'\n\n"
            ${PRINTF_BIN} "# PKG_CONFIG_PATH:\n"
            ${PRINTF_BIN} "export PKG_CONFIG_PATH='${pkg_config_path}'\n\n"
        fi

        # CFLAGS, CXXFLAGS:
        cflags="${CFLAGS} -fPIC ${DEFAULT_COMPILER_FLAGS}"
        process () {
            for app in ${1}*; do # SOFT_DIR
                exp="${app}/include"
                if [ -e "${exp}" ]; then
                    cflags="-I${exp} ${cflags}"
                fi
            done
        }
        process "${SOFTWARE_DIR}"
        if [ ! -z "$2" ]; then
            process "${HOME_DIR}${2}/${HOME_APPS_DIR}"
        fi
        cxxflags="${cflags}"
        ${PRINTF_BIN} "# CFLAGS:\n"
        ${PRINTF_BIN} "export CFLAGS='${cflags}'\n\n"
        ${PRINTF_BIN} "# CXXFLAGS:\n"
        ${PRINTF_BIN} "export CXXFLAGS='${cxxflags}'\n\n"

        # MANPATH
        manpath="${DEFAULT_MANPATH}"
        process () {
            for app in ${1}*; do # SOFT_DIR
                exp="${app}/man"
                if [ -e "${exp}" ]; then
                    manpath="${exp}:${manpath}"
                fi
            done
        }
        process "${SOFTWARE_DIR}"
        if [ ! -z "$2" ]; then
            process "${HOME_DIR}${2}/${HOME_APPS_DIR}"
        fi
        ${PRINTF_BIN} "# MANPATH:\n"
        ${PRINTF_BIN} "export MANPATH='${manpath}'\n\n"

        set_c_compiler CLANG
        ${PRINTF_BIN} "# CC:\n"
        ${PRINTF_BIN} "export CC='${CC}'\n\n"
        ${PRINTF_BIN} "# CXX:\n"
        ${PRINTF_BIN} "export CXX='${CXX}'\n\n"
        ${PRINTF_BIN} "# CPP:\n"
        ${PRINTF_BIN} "export CPP='${CPP}'\n\n"
        exit
        ;;


    upgrade)
        if [ "$2" = "" ]; then
            error "For application \"$1\", second argument with application requirement name is required!"
            exit 1
        fi
        if [ "$3" = "" ]; then
            error "For application \"$1\", third argument with application name is required!"
            exit 1
        fi
        export USER_UID="$(${ID_BIN} ${ID_SVD})"
        if [ "$(${ID_BIN} -u)" = "0" ]; then
            export SOFT_DIR="${SOFTWARE_DIR}"
        else
            export SOFT_DIR="${HOME_DIR}${USER_UID}/${HOME_APPS_DIR}"
            export LOG="${HOME_DIR}${USER_UID}/install.log"
        fi
        REQ="${2}"
        APP="$(${PRINTF_BIN} "${3}" | ${CUT_BIN} -c1 | ${TR_BIN} '[a-z]' '[A-Z]')$(${PRINTF_BIN} "${3}" | ${SED_BIN} 's/^[a-zA-Z]//')"
        if [ ! -e "${SOFT_DIR}${APP}" ]; then
            error "Bundle not found: ${APP}"
            exit 1
        fi
        note "Performing upgrade of requirement: ${REQ} in application bundle: ${APP}"
        REM="${SOFT_DIR}${APP}/${REQ}${INSTALLED_MARK}"
        if [ ! -e "${REM}" ]; then
            error "No requirement: ${REM} found of bundle: ${APP}"
            exit 1
        fi

        # getting list of file/ folders matching definition name
        files=""
        debug "Performing find in ${SOFT_DIR}${APP}"
        for old in $(${FIND_BIN} "${SOFT_DIR}${APP}" -name "*${REQ}*" -regex '.*\.[o\$\|so\|a\$\|la\$\|h\$\|hpp\$].*' -type f); do
            files="${files}${old} "
            ${RM_BIN} -f "${old}"
        done
        debug "Old files removed before doing upgrade: ${files}"
        debug "Removing install marker: ${REM}"
        ${RM_BIN} -f "${REM}"

        debug "Relaunching installation script once again…"
        ${SCRIPT_NAME} one ${3} ${USER_UID}
        exit
        ;;


    cherrypick|one|getone|get)
        if [ "$2" = "" ]; then
            error "For \"$1\" application installation mode, second argument with application definition name is required!"
            exit 1
        fi
        export USER_UID="$(${ID_BIN} ${ID_SVD})"
        if [ "$(${ID_BIN} -u)" = "0" ]; then
            unset USER_UID
        else
            export LOG="${HOME_DIR}${USER_UID}/install.log"
            export CACHE_DIR="${HOME_DIR}${USER_UID}/.cache/"
            export DEFINITIONS_DIR="${CACHE_DIR}definitions/"
            export LISTS_DIR="${CACHE_DIR}lists/"
            export DEFAULTS="${DEFINITIONS_DIR}defaults.def"
        fi
        update_definitions ${USER_UID}
        APP="$(${PRINTF_BIN} "${2}" | ${CUT_BIN} -c1 | ${TR_BIN} '[A-Z]' '[a-z]')$(${PRINTF_BIN} "${2}" | ${SED_BIN} 's/^[A-Za-z]//')"
        if [ ! -e "${DEFINITIONS_DIR}${APP}.def" ]; then
            error "Definition file not found: ${DEFINITIONS_DIR}${APP}.def !"
            exit 1
        fi
        export APPLICATIONS="${APP}"
        debug "Installing software: ${APPLICATIONS}"
        ;;


    deps|dependencies|local)
        LOCAL_DIR="$(${PWD_BIN})/"
        export USER_UID="$(${ID_BIN} ${ID_SVD})"
        if [ "$(${ID_BIN} -u)" = "0" ]; then
            warn "Installation of project dependencies as root is immoral."
            # exit 1
        else
            export LOG="${HOME_DIR}${USER_UID}/install.log"
            export CACHE_DIR="${HOME_DIR}${USER_UID}/.cache/"
            export DEFINITIONS_DIR="${CACHE_DIR}definitions/"
            export LISTS_DIR="${CACHE_DIR}lists/"
            export DEFAULTS="${DEFINITIONS_DIR}defaults.def"
        fi
        update_definitions ${USER_UID}
        cd "${LOCAL_DIR}"
        note "Looking for $(${PWD_BIN})/${DEPENDENCIES_FILE} file…"
        if [ ! -e "$(${PWD_BIN})/${DEPENDENCIES_FILE}" ]; then
            error "Dependencies file not found!"
            exit 1
        fi
        export APPLICATIONS="$(${CAT_BIN} ${LOCAL_DIR}${DEPENDENCIES_FILE} | ${TR_BIN} '\n' ' ')"
        note "Installing dependencies: ${APPLICATIONS}\n"
        ;;


    install|add)
        if [ "$2" = "" ]; then
            error "For \"$1\" application installation mode, second argument with application list is required!"
            exit 1
        fi
        export USER_UID="$(${ID_BIN} ${ID_SVD})"
        if [ "$(${ID_BIN} -u)" = "0" ]; then
            unset USER_UID
        else
            export LOG="${HOME_DIR}${USER_UID}/install.log"
            export CACHE_DIR="${HOME_DIR}${USER_UID}/.cache/"
            export DEFINITIONS_DIR="${CACHE_DIR}definitions/"
            export LISTS_DIR="${CACHE_DIR}lists/"
            export DEFAULTS="${DEFINITIONS_DIR}defaults.def"
        fi
        update_definitions ${USER_UID}
        if [ ! -e "${LISTS_DIR}$2" ]; then
            error "List not found: ${2}!"
            exit 1
        fi
        export APPLICATIONS="$(${CAT_BIN} ${LISTS_DIR}$2 | ${TR_BIN} '\n' ' ')"
        note "Installing software: ${APPLICATIONS}"
        ;;


    delete|remove|uninstall)
        if [ "$2" = "" ]; then
            error "For \"$1\" task, second argument with application name is required!"
            exit 1
        fi
        USER_UID="$(${ID_BIN} -u)"
        if [ "${USER_UID}" = "0" ]; then
            export SOFT_DIR="${SOFTWARE_DIR}"
        else
            export LOG="${HOME_DIR}$(${ID_BIN} ${ID_SVD})/install.log"
            export SOFT_DIR="${HOME_DIR}$(${ID_BIN} ${ID_SVD})/${HOME_APPS_DIR}"
        fi
        APP_NAME="$(${PRINTF_BIN} "${2}" | ${CUT_BIN} -c1 | ${TR_BIN} '[a-z]' '[A-Z]')$(${PRINTF_BIN} "${2}" | ${SED_BIN} 's/^[a-zA-Z]//')"
        if [ -d "${SOFT_DIR}${APP_NAME}" ]; then
            note "Removing application: ${APP_NAME}"
            if [ "${APP_NAME}" = "/" ]; then
                error "Czy Ty orzeszki?"
                exit 1
            fi
            debug "Removing software from: ${SOFT_DIR}${APP_NAME}"
            ${RM_BIN} -rfv "${SOFT_DIR}${APP_NAME}" >> "${LOG}"
            update_shell_vars ${USER_UID}
        else
            error "Application: ${APP_NAME} not installed."
            exit 1
        fi
        exit
        ;;


    reload|rehash)
        if [ ! -z "${SHELL_PID}" ]; then
            update_shell_vars
            note "Reloading configuration of $(${BASENAME_BIN} ${SHELL}) with pid: ${SHELL_PID}…"
            ${KILL_BIN} -SIGUSR2 ${SHELL_PID}
        else
            write_info_about_shell_configuration
        fi
        exit
        ;;


    update|updatedefs)
        USER_UID="$(${ID_BIN} -u)"
        if [ ! "${USER_UID}" = "0" ]; then
            export CACHE_DIR="${HOME_DIR}${USER_UID}/.cache/"
            export DEFINITIONS_DIR="${CACHE_DIR}definitions/"
            export LOG="${HOME_DIR}${USER_UID}/install.log"
        fi
        export LISTS_DIR="${CACHE_DIR}lists/"
        export DEFAULTS="${DEFINITIONS_DIR}defaults.def"
        update_definitions "${USER_UID}"
        note "Definitions were updated to latest version."
        exit
        ;;


    available)
        export USER_UID="$(${ID_BIN} ${ID_SVD})"
        if [ ! "$(${ID_BIN} -u)" = "0" ]; then
            export CACHE_DIR="${HOME_DIR}${USER_UID}/.cache/"
            export DEFINITIONS_DIR="${CACHE_DIR}definitions/"
        fi
        cd "${DEFINITIONS_DIR}"
        note "Available definitions:"
        ${LS_BIN} -m *def | ${SED_BIN} 's/\.def//g'
        note "Definitions count:"
        ${LS_BIN} -a *def | ${WC_BIN} -l
        exit
        ;;


    exportapp|export|exp)
        if [ "$2" = "" ]; then
            error "Missing second argument with export app is required!"
            exit 1
        fi
        if [ "$3" = "" ]; then
            error "Missing third argument with source app is required!"
            exit 1
        fi
        EXPORT="$2"
        APP="$(${PRINTF_BIN} "${3}" | ${CUT_BIN} -c1 | ${TR_BIN} '[a-z]' '[A-Z]')$(${PRINTF_BIN} "${3}" | ${SED_BIN} 's/^[a-zA-Z]//')"
        export SOFT_DIR="${SOFTWARE_DIR}"
        export userUID="$(${ID_BIN} ${ID_SVD})"
        if [ ! "$(${ID_BIN} -u)" = "0" ]; then
            export SOFT_DIR="${HOME_DIR}${userUID}/${HOME_APPS_DIR}"
            export LOG="${HOME_DIR}${userUID}/install.log"
        fi

        for dir in "/bin/" "/sbin/" "/libexec/"; do
            debug "Testing ${dir} looking into: ${SOFT_DIR}${APP}${dir}"
            if [ -e "${SOFT_DIR}${APP}${dir}${EXPORT}" ]; then
                note "Exporting binary: ${SOFT_DIR}${APP}${dir}${EXPORT}"
                ${LN_BIN} -vfs "${SOFT_DIR}${APP}${dir}${EXPORT}" "${SOFT_DIR}${APP}/exports/${EXPORT}" >> "$LOG"
            fi
        done
        exit
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

    application="$(${PRINTF_BIN} "${application}" | ${TR_BIN} '[A-Z]' '[a-z]')" # lowercase for case sensitive fs
    . "${DEFAULTS}"
    . "${DEFINITIONS_DIR}${application}.def" # prevent installation of requirements of disabled application:
    check_disabled "${DISABLE_ON}" # after which just check if it's not disabled
    if [ ! "${ALLOW}" = "1" ]; then
        warn "Requirement: ${APP_NAME} disabled on architecture: ${SYSTEM_NAME}.\n"
    else
        for definition in ${DEFINITIONS_DIR}${application}.def; do
            debug "Reading definition: ${definition}"
            . "${DEFAULTS}"
            . "${definition}"
            check_disabled "${DISABLE_ON}" # after which just check if it's not disabled

            # fancy old style Capitalize
            APP_NAME="$(${PRINTF_BIN} "${APP_NAME}" | ${CUT_BIN} -c1 | ${TR_BIN} '[a-z]' '[A-Z]')$(${PRINTF_BIN} "${APP_NAME}" | ${SED_BIN} 's/^[a-zA-Z]//')"

            # note "Preparing application: ${APP_NAME}${APP_POSTFIX} (${APP_FULL_NAME} v${APP_VERSION})"
            if [ "${USER_UID}" = "" ]; then
                debug "Normal build"
                export PREFIX="${SOFTWARE_DIR}${APP_NAME}"
            else
                debug "User build: ${USER_UID}"
                export PREFIX="${HOME_DIR}${USER_UID}/${HOME_APPS_DIR}${APP_NAME}"
                if [ ! -d "${HOME_DIR}${USER_UID}/${HOME_APPS_DIR}" ]; then
                    ${MKDIR_BIN} -p "${HOME_DIR}${USER_UID}/${HOME_APPS_DIR}"
                fi
            fi

            # append app postfix
            if [ ! -z "$APP_POSTFIX" ]; then
                export PREFIX="${PREFIX}${APP_POSTFIX}"
            fi


            run () {
                if [ ! -z "$1" ]; then
                    if [ ! -e "${LOG}" ]; then
                        ${TOUCH_BIN} "${LOG}"
                    fi
                    debug "Running '$@' @ $(${DATE_BIN})"
                    eval PATH="${PATH}" "$@" 1>> "${LOG}" 2>> "${LOG}"
                    check_command_result $?
                else
                    error "Empty command to run?"
                    exit
                fi
            }

            check_current () { # $1 => version, $2 => current version
                if [ ! "${1}" = "" ]; then
                    if [ ! "${2}" = "" ]; then
                        if [ ! "${1}" = "${2}" ]; then
                            warn "   → Found different remote version: ${2} vs ${1}."
                        else
                            note "   → Definition version is up to date: ${1}"
                        fi
                    fi
                fi
            }

            check_current_by_definition () {
                req_definition_file="${DEFINITIONS_DIR}${1}.def"
                . "${DEFAULTS}"
                . "${req_definition_file}"
                check_current "${APP_VERSION}" "${APP_CURRENT_VERSION}"
            }

            execute_process () {
                if [ -z "$1" ]; then
                    error "No param given for execute_process()!"
                    exit 1
                fi
                req_definition_file="${DEFINITIONS_DIR}${1}.def"
                debug "Checking requirement: $1 file: $req_definition_file"
                if [ ! -e "${req_definition_file}" ]; then
                    error "Cannot fetch definition ${req_definition_file}! Aborting!"
                    exit 1
                fi

                . "${DEFAULTS}" # load definition and check for current version
                . "${req_definition_file}"
                check_current "${APP_VERSION}" "${APP_CURRENT_VERSION}"
                check_disabled "${DISABLE_ON}" # check requirement for disabled state:

                if [ ! -z "${FORCE_GNU_COMPILER}" ]; then # force GNU compiler usage on definition side:
                    warn "   → GNU compiler set for: ${APP_NAME}"
                    set_c_compiler GNU
                else
                    set_c_compiler CLANG # look for bundled compiler:
                fi

                if [ "${APP_NO_CCACHE}" = "" ]; then # ccache is supported by default but it's optional
                    if [ -x "${CCACHE_BIN_OPTIONAL}" ]; then # check for CCACHE availability
                        export CC="${CCACHE_BIN_OPTIONAL} ${CC}"
                        export CXX="${CCACHE_BIN_OPTIONAL} ${CXX}"
                        export CPP="${CCACHE_BIN_OPTIONAL} ${CPP}"
                    fi
                fi
                # set rest of compiler/linker variables
                export PATH="${PREFIX}/bin:${PREFIX}/sbin:${DEFAULT_PATH}"
                export LD_LIBRARY_PATH="${PREFIX}/lib:${PREFIX}/libexec:/usr/lib:/lib"
                export CFLAGS="-I${PREFIX}/include ${APP_COMPILER_ARGS} ${DEFAULT_COMPILER_FLAGS}"
                export CXXFLAGS="-I${PREFIX}/include ${APP_COMPILER_ARGS} ${DEFAULT_COMPILER_FLAGS}"
                export LDFLAGS="-L${PREFIX}/lib ${APP_LINKER_ARGS} ${DEFAULT_LDFLAGS} -Wl,-rpath=${PREFIX}/lib,--enable-new-dtags"

                if [ "${SYSTEM_NAME}" = "Darwin" ]; then
                    export PATH="${PATH}:/opt/X11/bin" # NOTE: requires XQuartz installed!
                    export CFLAGS="${CFLAGS} -I/opt/X11/include" # NOTE: requires XQuartz installed!
                    export CXXFLAGS="${CXXFLAGS} -I/opt/X11/include" # NOTE: requires XQuartz installed!
                    export LDFLAGS="-L${PREFIX}/lib ${APP_LINKER_ARGS} ${DEFAULT_LDFLAGS} -L/opt/X11/lib" # NOTE: requires XQuartz installed!
                fi

                if [ "${ALLOW}" = "1" ]; then
                    if [ -z "${APP_HTTP_PATH}" ]; then
                        error "No source given for definition! Aborting"
                        exit 1
                    else
                        BUILD_DIR="${CACHE_DIR}cache/${APP_NAME}${APP_POSTFIX}-${APP_VERSION}/"
                        ${MKDIR_BIN} -p "${BUILD_DIR}"
                        CUR_DIR="$(${PWD_BIN})"
                        cd "${BUILD_DIR}"
                        for bd in ${BUILD_DIR}/*; do
                            if [ -d "${bd}" ]; then
                                debug "Unpacked source code found in build dir. Removing: ${bd}"
                                if [ "${bd}" != "/" ]; then # it's better to be safe than sorry
                                    ${RM_BIN} -rf "${bd}"
                                fi
                            fi
                        done
                        if [ ! -e ${BUILD_DIR}${APP_NAME}*${APP_HTTP_PATH##*.} ]; then
                            note "   → Fetching requirement source from: ${APP_HTTP_PATH}"
                            run "${FETCH_BIN} ${APP_HTTP_PATH}"
                        else
                            debug "Already fetched. Using tarball from cache"
                        fi

                        FIND_RESULT="${FIND_BIN} ${BUILD_DIR} -maxdepth 1 -type f"
                        debug "Build dir: ${BUILD_DIR}, find result: ${FIND_RESULT}"
                        file="$(${BASENAME_BIN} $(${FIND_RESULT}))"
                        if [ "${APP_SHA}" = "" ]; then
                            error "→ Missing SHA sum for source: ${file}."
                            exit
                        else
                            case "${SYSTEM_NAME}" in
                                Darwin|Linux)
                                    export cur="$(${SHA_BIN} ${file} | ${AWK_BIN} '{print $1}')"
                                    ;;

                                FreeBSD)
                                    export cur="$(${SHA_BIN} -q ${file})"
                                    ;;
                            esac
                            if [ "${cur}" = "${APP_SHA}" ]; then
                                debug "→ SHA sum match in file: ${file}"
                            else
                                error "→ ${cur} vs ${APP_SHA}"
                                error "→ SHA sum mismatch. Removing corrupted file from cache: ${file}, and retrying."
                                # remove corrupted file
                                $($FIND_BIN "${BUILD_DIR}" -maxdepth 1 -type f -name "${file}" | ${XARGS_BIN} ${RM_BIN})
                                # remove lock
                                if [ -e "${LOCK_FILE}" ]; then
                                    debug "Removing lock file: ${LOCK_FILE}"
                                    ${RM_BIN} -f "${LOCK_FILE}"
                                fi
                                # and restart script with same arguments:
                                ${SCRIPT_NAME} "${SCRIPT_ARGS}"
                                exit
                            fi
                        fi

                        debug "→ Unpacking source code of: ${APP_NAME}"
                        debug "Build dir: ${BUILD_DIR}"
                        APP_LOC="${BUILD_DIR}${APP_NAME}"
                        debug "Entrering ${APP_LOC}"
                        run "${TAR_BIN} xf ${APP_LOC}*"

                        buildDirCore="$(${FIND_BIN} ${BUILD_DIR}/* -maxdepth 0 -type d -name "*${APP_VERSION}*")"
                        debug "Build Dir Core before: '${buildDirCore}'"
                        if [ "${buildDirCore}" = "" ]; then
                            export buildDirCore=$(${FIND_BIN} ${BUILD_DIR}/* -maxdepth 0 -type d) # try any dir instead
                        fi
                        debug "Build Dir Core after: '${buildDirCore}'"
                        for dir in ${buildDirCore}; do
                            debug "Changing dir to: ${dir}/${APP_SOURCE_DIR_POSTFIX}"
                            cd "${dir}/${APP_SOURCE_DIR_POSTFIX}"
                            if [ ! -z "${APP_AFTER_UNPACK_CALLBACK}" ]; then
                                debug "Running after unpack callback"
                                run "${APP_AFTER_UNPACK_CALLBACK}"
                            fi

                            LIST_DIR="${DEFINITIONS_DIR}patches/$1"
                            if [ -d "${LIST_DIR}" ]; then
                                if [ "$1" = "${APP_NAME}" ]; then # apply patch only when application/requirement for which patch is designed for
                                    note "   → Applying patches for: ${APP_NAME}"
                                    patches_files="$(${FIND_BIN} ${LIST_DIR}/* -maxdepth 0 -type f)"
                                    for patch in ${patches_files}; do
                                        debug "Patching source code with patch: ${patch}"
                                        run "${PATCH_BIN} -i ${patch}"
                                    done
                                    pspatch_dir="${LIST_DIR}/${SYSTEM_NAME}"
                                    debug "Checking psp dir: ${pspatch_dir}"
                                    if [ -d "${pspatch_dir}" ]; then
                                        debug "Proceeding with Platform Specific Patches"
                                        for platform_specific_patch in ${pspatch_dir}/*; do
                                            debug "Patching source code with pspatch: ${platform_specific_patch}"
                                            run "${PATCH_BIN} -i ${platform_specific_patch}"
                                        done
                                    fi
                                fi
                            fi

                            if [ ! -z "${APP_AFTER_PATCH_CALLBACK}" ]; then
                                debug "Running after patch callback"
                                run "${APP_AFTER_PATCH_CALLBACK}"
                            fi

                            debug "-------------- PRE CONFIGURE SETTINGS DUMP --------------"
                            debug "Current DIR: $(${PWD_BIN})"
                            debug "PREFIX: ${PREFIX}"
                            debug "PATH: ${PATH}"
                            debug "CC: ${CC}"
                            debug "CXX: ${CXX}"
                            debug "CPP: ${CPP}"
                            debug "CXXFLAGS: ${CXXFLAGS}"
                            debug "CFLAGS: ${CFLAGS}"
                            debug "LDFLAGS: ${LDFLAGS}"
                            debug "LD_LIBRARY_PATH: ${LD_LIBRARY_PATH}"

                            note "   → Configuring: $1, version: ${APP_VERSION}"
                            case "${APP_CONFIGURE_SCRIPT}" in

                                ignore)
                                    note "   → Ignored configuration part $1"
                                    ;;

                                no-conf)
                                    note "   → Skipped configuration for $1"
                                    export APP_MAKE_METHOD="${APP_MAKE_METHOD} PREFIX=${PREFIX}"
                                    export APP_INSTALL_METHOD="${APP_INSTALL_METHOD} PREFIX=${PREFIX}"
                                    ;;

                                binary)
                                    note "   → Binary definition: $1"
                                    export APP_MAKE_METHOD="true"
                                    export APP_INSTALL_METHOD="true"
                                    ;;

                                alternate)
                                    run "./configure -prefix ${PREFIX} -cc $(${BASENAME_BIN} ${CC}) ${APP_CONFIGURE_ARGS}"
                                    ;;

                                cmake)
                                    run "${APP_CONFIGURE_SCRIPT} . -LH -DCMAKE_INSTALL_PREFIX=${PREFIX}"
                                    ;;

                                *)
                                    run "${APP_CONFIGURE_SCRIPT} ${APP_CONFIGURE_ARGS} --prefix=${PREFIX}"
                                    ;;

                            esac

                            if [ ! -z "${APP_AFTER_CONFIGURE_CALLBACK}" ]; then
                                debug "Running after configure callback"
                                run "${APP_AFTER_CONFIGURE_CALLBACK}"
                            fi

                            note "   → Building requirement: $1"
                            run "${APP_MAKE_METHOD}"
                            if [ ! -z "${APP_AFTER_MAKE_CALLBACK}" ]; then
                                debug "Running after make callback"
                                run "${APP_AFTER_MAKE_CALLBACK}"
                            fi

                            note "   → Installing requirement: $1"
                            run "${APP_INSTALL_METHOD}"
                            if [ ! "${APP_AFTER_INSTALL_CALLBACK}" = "" ]; then
                                debug "After install callback: ${APP_AFTER_INSTALL_CALLBACK}"
                                run "${APP_AFTER_INSTALL_CALLBACK}"
                            fi

                            debug "Marking as installed '$1' in: ${PREFIX}"
                            ${TOUCH_BIN} "${PREFIX}/$1${INSTALLED_MARK}"
                            debug "Writing version: ${APP_VERSION} of app: '${APP_NAME}' installed in: ${PREFIX}"
                            ${PRINTF_BIN} "${APP_VERSION}" > "${PREFIX}/$1${INSTALLED_MARK}"
                        done
                        cd "${CUR_DIR}"
                    fi
                else
                    warn "   → Requirement: ${APP_NAME} disabled on architecture: ${SYSTEM_NAME}."
                    if [ ! -d "${PREFIX}" ]; then # case when disabled requirement is first on list of dependencies
                        ${MKDIR_BIN} -p "${PREFIX}"
                    fi
                    ${TOUCH_BIN} "${PREFIX}/${req}${INSTALLED_MARK}"
                    ${PRINTF_BIN} "system-version" > "${PREFIX}/${req}${INSTALLED_MARK}"
                fi
            }

            if [ "${APP_REQUIREMENTS}" = "" ]; then
                note "Installing ${application}"
            else
                note "Installing ${application} with requirements: ${APP_REQUIREMENTS}"
            fi
            export req_amount="$(${PRINTF_BIN} "${APP_REQUIREMENTS}" | ${WC_BIN} -w | ${AWK_BIN} '{print $1}')"
            export req_amount="$(${PRINTF_BIN} "${req_amount} + 1\n" | ${BC_BIN})"
            export req_all="${req_amount}"
            for req in ${APP_REQUIREMENTS}; do
                if [ ! "${APP_USER_INFO}" = "" ]; then
                    warn "${APP_USER_INFO}"
                fi
                if [ -z "${req}" ]; then
                    note "  No requirements required."
                    break
                else
                    note "  ${req} (${req_amount} of ${req_all})"
                    if [ ! -e "${PREFIX}/${req}${INSTALLED_MARK}" ]; then
                        export CHANGED="true"
                        execute_process "${req}"
                    fi
                fi
                check_current_by_definition "${req}"
                export req_amount="$(${PRINTF_BIN} "${req_amount} - 1\n" | ${BC_BIN})"
            done

            mark () {
                debug "Marking definition: ${application} installed"
                ${TOUCH_BIN} "${PREFIX}/${application}${INSTALLED_MARK}"
                debug "Writing version: ${APP_VERSION} of app: '${application}' installed in: ${PREFIX}"
                ${PRINTF_BIN} "${APP_VERSION}" > "${PREFIX}/${application}${INSTALLED_MARK}"
            }

            strip_lib_bin () {
                if [ -z "${DEVEL}" ]; then
                    debug "→ Stripping all libraries…"
                    for elem in $(${FIND_BIN} ${PREFIX} -name '*.so' -o -name '*.dylib'); do
                        debug "Stripping: ${elem}"
                        "${STRIP_BIN}" -sv "${elem}" >> "${LOG}" 2>> "${LOG}"
                    done
                    debug "→ Stripping all binaries…"
                    for elem in "/bin/" "/sbin/" "/libexec/"; do
                        if [ -d "${PREFIX}${elem}" ]; then
                            for e in $(${FIND_BIN} ${PREFIX}${elem}); do
                                if [ -f "${e}" ]; then
                                    debug "Stripping: ${e}"
                                    "${STRIP_BIN}" -s "${e}" >> "${LOG}" 2>> "${LOG}"
                                fi
                            done
                        fi
                    done
                else
                    warn "Debug mode enabled. Omitting binary/library strip…"
                fi
            }

            show_done () {
                ver="$(${CAT_BIN} "${PREFIX}/${application}${INSTALLED_MARK}")"
                note "√ ${application} [${ver}]\n"
            }

            if [ -e "${PREFIX}/${application}${INSTALLED_MARK}" ]; then
                if [ "${CHANGED}" = "true" ]; then
                    note "  ${application} (1 of ${req_all})"
                    note "   → App dependencies changed. Rebuilding ${application}"
                    execute_process "${application}"
                    unset CHANGED
                    mark
                    strip_lib_bin
                    show_done
                else
                    note "  ${application} (1 of ${req_all})"
                    check_current_by_definition "${application}"
                    show_done
                    debug "√ ${application} current: ${ver}, definition: [${APP_VERSION}] Ok."
                fi
            else
                note "  ${application} (1 of ${req_all})"
                execute_process "${application}"
                mark
                strip_lib_bin
                note "√ ${application} [${APP_VERSION}]\n"
            fi

            . "${DEFINITIONS_DIR}${application}.def"
            ${MKDIR_BIN} -p "${PREFIX}/exports"
            EXPORT_LIST=""
            for exp in ${APP_EXPORTS}; do
                for dir in "/bin/" "/sbin/" "/libexec/"; do
                    debug "Testing ${dir} looking into: ${PREFIX}${dir}${exp}"
                    if [ -f "${PREFIX}${dir}${exp}" ]; then # a file
                        if [ -x "${PREFIX}${dir}${exp}" ]; then # and it's executable'
                            ${LN_BIN} -vfs "${PREFIX}${dir}${exp}" "${PREFIX}/exports/${exp}" >> "$LOG"
                            exp_elem="$(${BASENAME_BIN} ${PREFIX}${dir}${exp})"
                            EXPORT_LIST="${EXPORT_LIST} ${exp_elem}"
                        fi
                    fi
                done
            done
            debug "Exporting binaries:${EXPORT_LIST}"

            if [ ! -z "${USER_UID}" ]; then
                if [ "$(${ID_BIN} -u)" = "0" ]; then
                    debug "Setting owner of ${PREFIX} recursively to user: ${USER_UID}"
                    ${CHOWN_BIN} -R ${USER_UID} "${HOME_DIR}${USER_UID}" # NOTE: sanity check.
                fi
            fi

        done
    fi
done


update_shell_vars
if [ ! "${APP_JAVA_ANCESTOR}" = "" ]; then
    if [ ! "$(${ID_BIN} -u)" = "0" ]; then
        # if not root - cause no java ancestor required for root
        note "→ Setting up Java ancestor: ${APP_JAVA_ANCESTOR}"
        export JAVA_HOME_PROFILE="${HOME}/.profile_java" # profile with additional info about java
        case "${APP_JAVA_ANCESTOR}" in
            JDK6_32)
                ${PRINTF_BIN} "\nexport JAVA_HOME=\"${JDK6_32}\"\n" > "${JAVA_HOME_PROFILE}"
                ${PRINTF_BIN} "\nexport PATH=\"${JDK6_32}/exports:\$PATH\"\n" >> "${JAVA_HOME_PROFILE}"
                ;;

            JDK6_64)
                note "   64bit JDK 1.6 ancestor"
                ${PRINTF_BIN} "\nexport JAVA_HOME=\"${JDK6_64}\"\n" > "${JAVA_HOME_PROFILE}"
                ${PRINTF_BIN} "\nexport PATH=\"${JDK6_64}/exports:\$PATH\"\n" >> "${JAVA_HOME_PROFILE}"
                ;;

            JDK7_32)
                note "   32bit JDK 1.7 ancestor"
                ${PRINTF_BIN} "\nexport JAVA_HOME=\"${JDK7_32}\"\n" > "${JAVA_HOME_PROFILE}"
                ${PRINTF_BIN} "\nexport PATH=\"${JDK7_32}/exports:\$PATH\"\n" >> "${JAVA_HOME_PROFILE}"
                ;;

            JDK7_64)
                note "   64bit JDK 1.7 ancestor"
                ${PRINTF_BIN} "\nexport JAVA_HOME=\"${JDK7_64}\"\n" > "${JAVA_HOME_PROFILE}"
                ${PRINTF_BIN} "\nexport PATH=\"${JDK7_64}/exports:\$PATH\"\n" >> "${JAVA_HOME_PROFILE}"
                ;;

            *)
                note "Wrong JDK ancestor"
                ;;
        esac

        debug "Adding entry to $HOME/.profile to read from $HOME/.profile_java"
        ${CAT_BIN} "${HOME}/.profile_java" >> "${HOME}/.profile"
    fi
fi

if [ ! -z "${SHELL_PID}" ]; then
    note "All done. Reloading configuration of $(${BASENAME_BIN} ${SHELL}) with pid: ${SHELL_PID}…"
    ${KILL_BIN} -SIGUSR2 ${SHELL_PID}
else
    write_info_about_shell_configuration
fi


exit
