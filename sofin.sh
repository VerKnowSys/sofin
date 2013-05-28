#!/bin/sh
# @author: Daniel (dmilith) Dettlaff (dmilith@verknowsys.com)

# config settings
readonly VERSION="0.47.6"

# load configuration from sofin.conf
readonly CONF_FILE="/etc/sofin.conf.sh"
if [ -e "${CONF_FILE}" ]; then
    . "${CONF_FILE}"
    validate_env
else
    echo "FATAL: No configuration file found: ${CONF_FILE}. Sofin isn't installed properly."
    exit 1
fi

if [ "${TRACE}" = "true" ]; then
    set -x
fi

SOFIN_ARGS=$*
readonly SOFIN_ARGS="$(echo ${SOFIN_ARGS} | ${CUT_BIN} -d' ' -f2-)"

# create runtime sha
# RUNTIME_SHA="$(${DATE_BIN} | ${SHA_BIN})" # TODO: NYI

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
                    return
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
        ${MKDIR_BIN} -p "${element}" > "${LOG}"
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
}


write_info_about_shell_configuration () {
    note
    warn "SHELL_PID is not set. It means that Sofin isn't properly configured or wasn't installed."
}


usage_howto () {
    note "Built in tasks:"
    note
    note "install | get                        - installs software from list or from definition (example: $(${BASENAME_BIN} ${SCRIPT_NAME}) install ruby)"
    note "upgrade                              - upgrades one of dependencies of installed definition (example: $(${BASENAME_BIN} ${SCRIPT_NAME}) upgrade iconv ruby - to upgrade iconv in Ruby bundle)"
    note "dependencies | deps | local          - installs software from list defined in '${DEPENDENCIES_FILE}' file in current directory"
    note "uninstall | remove | delete          - removes an application or list (example: $(${BASENAME_BIN} ${SCRIPT_NAME}) uninstall ruby)"
    note "list | installed                     - short list of installed software"
    note "fulllist | fullinstalled             - detailed lists with installed software including requirements"
    note "available                            - lists available software"
    note "export | exp | exportapp             - adds given command to application exports (example: $(${BASENAME_BIN} ${SCRIPT_NAME}) export rails ruby)"
    note "getshellvars | shellvars | vars      - returns shell variables for installed software"
    note "log                                  - shows and watches log file (for debug messages and verbose info)"
    note "reload | rehash                      - recreate shell vars and reload current shell"
    note "update                               - only update definitions from remote repository and exit"
    note "ver | version                        - shows $(${BASENAME_BIN} ${SCRIPT_NAME}) script version"
    note "clean                                - cleans install cache, downloaded content and logs"
    note "outdated                             - lists outdated software"
    exit
}


update_shell_vars () {
    if [ "${USERNAME}" = "root" ]; then
        debug "Updating ${SOFIN_PROFILE} settings…"
        ${PRINTF_BIN} "$(${SCRIPT_NAME} getshellvars)" > "${SOFIN_PROFILE}"
    else
        debug "Updating ${HOME}/.profile settings…"
        ${PRINTF_BIN} "$(${SCRIPT_NAME} getshellvars ${USERNAME})" > "${HOME}/.profile"
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
        ${TAIL_BIN} -n "${LOG_LINES_AMOUNT}" -F "${LOG}"
        ;;


    clean)
        note "Performing cleanup of ${CACHE_DIR}cache"
        ${RM_BIN} -rf "${CACHE_DIR}cache"
        note "Removing ${LOG}"
        ${RM_BIN} -rf "${LOG}"
        exit
        ;;


    installed|list)
        debug "Listing software from ${SOFTWARE_DIR}"
        if [ -d ${SOFTWARE_DIR} ]; then
            ${FIND_BIN} ${SOFTWARE_DIR} -maxdepth 1 -mindepth 1 -type d  -not -name ".*" -exec ${BASENAME_BIN} {} \;
        fi
        exit
        ;;


    fullinstalled|fulllist)
        note "Installed applications:"
        note
        if [ -d ${SOFTWARE_DIR} ]; then
            for app in ${SOFTWARE_DIR}*; do
                app_name="$(${BASENAME_BIN} ${app})"
                note "Checking ${app_name}"
                for req in $(${FIND_BIN} ${app} -maxdepth 1 -name *${INSTALLED_MARK} | ${SORT_BIN}); do
                    pp="$(${PRINTF_BIN} "$(${BASENAME_BIN} ${req})" | ${SED_BIN} 's/\.installed//')"
                    note "  ${pp} [$(${CAT_BIN} ${req})]"
                done
                note "${SUCCESS_CHAR} ${app_name}\n"
            done
        fi
        exit
        ;;


    getshellvars|shellvars|vars)

        # PATH:
        result="${DEFAULT_PATH}"
        process () {
            for app in ${1}*; do
                exp="${app}/exports"
                if [ -e "${exp}" ]; then
                    result="${exp}:${result}"
                fi
            done
        }
        process ${SOFTWARE_ROOT_DIR}
        if [ "${USERNAME}" != "root" ]; then
            process ${SOFTWARE_DIR}
        fi
        ${PRINTF_BIN} "# PATH:\n"
        ${PRINTF_BIN} "export PATH=${result}\n\n"

        # LD_LIBRARY_PATH, LDFLAGS, PKG_CONFIG_PATH:
        # ldresult="/lib:/usr/lib"
        # pkg_config_path="."
        export ldflags="${LDFLAGS} ${DEFAULT_LDFLAGS}"
        process () {
            for app in ${1}*; do # LIB_DIR
                if [ -e "${app}/lib" ]; then
                    ldresult="${app}/lib:${ldresult}"
                    ldflags="-R${app}/lib -L${app}/lib ${ldflags}"
                fi
                if [ -e "${app}/libexec" ]; then
                    ldresult="${app}/libexec:${ldresult}"
                    ldflags="-R${app}/libexec -L${app}/libexec ${ldflags}"
                fi
                if [ -e "${app}/lib/pkgconfig" ]; then
                    pkg_config_path="${app}/lib/pkgconfig:${pkg_config_path}"
                fi
            done
        }
        process ${SOFTWARE_ROOT_DIR}
        if [ "${USERNAME}" != "root" ]; then
            process ${SOFTWARE_DIR}
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
            for app in ${1}*; do
                exp="${app}/include"
                if [ -e "${exp}" ]; then
                    cflags="-I${exp} ${cflags}"
                fi
            done
        }
        process ${SOFTWARE_ROOT_DIR}
        if [ "${USERNAME}" != "root" ]; then
            process ${SOFTWARE_DIR}
        fi
        cxxflags="${cflags}"
        ${PRINTF_BIN} "# CFLAGS:\n"
        ${PRINTF_BIN} "export CFLAGS='${cflags}'\n\n"
        ${PRINTF_BIN} "# CXXFLAGS:\n"
        ${PRINTF_BIN} "export CXXFLAGS='${cxxflags}'\n\n"

        # MANPATH
        manpath="${DEFAULT_MANPATH}"
        process () {
            for app in ${1}*; do
                exp="${app}/man"
                if [ -e "${exp}" ]; then
                    manpath="${exp}:${manpath}"
                fi
                exp="${app}/share/man"
                if [ -e "${exp}" ]; then
                    manpath="${exp}:${manpath}"
                fi
            done
        }
        process ${SOFTWARE_ROOT_DIR}
        if [ "${USERNAME}" != "root" ]; then
            process ${SOFTWARE_DIR}
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
        REQ="${2}"
        APP="$(${PRINTF_BIN} "${3}" | ${CUT_BIN} -c1 | ${TR_BIN} '[a-z]' '[A-Z]')$(${PRINTF_BIN} "${3}" | ${SED_BIN} 's/^[a-zA-Z]//')"
        if [ ! -e "${SOFTWARE_DIR}${APP}" ]; then
            error "Bundle not found: ${APP}"
            exit 1
        fi
        note "Performing upgrade of requirement: ${REQ} in application bundle: ${APP}"
        REM="${SOFTWARE_DIR}${APP}/${REQ}${INSTALLED_MARK}"
        if [ ! -e "${REM}" ]; then
            error "No requirement: ${REM} found of bundle: ${APP}"
            exit 1
        fi

        # getting list of file/ folders matching definition name
        files=""
        debug "Performing find in ${SOFTWARE_DIR}${APP}"
        for old in $(${FIND_BIN} "${SOFTWARE_DIR}${APP}" -name "*${REQ}*" -regex '.*\.[o\$\|so\|a\$\|la\$\|h\$\|hpp\$].*' -type f); do
            files="${files}${old} "
            ${RM_BIN} -f "${old}"
        done
        debug "Old files removed before doing upgrade: ${files}"
        debug "Removing install marker: ${REM}"
        ${RM_BIN} -f "${REM}"

        debug "Relaunching installation script once again…"
        ${SCRIPT_NAME} install ${3}
        exit
        ;;


    install|get)

        if [ "$2" = "" ]; then
            error "For \"$1\" application installation mode, second argument with at least one application name or list is required!"
            exit 1
        fi

        if [ ! -f "${CACHE_DIR}definitions/defaults.def" ]; then
            note "No definitions found in ${CACHE_DIR}definitions/defaults.def. Updating…"
            update_definitions
        fi

        # first of all, try using a list if exists:
        if [ -f "${LISTS_DIR}$2" ]; then
            export APPLICATIONS="$(${CAT_BIN} ${LISTS_DIR}$2 | ${TR_BIN} '\n' ' ')"
            note "Installing software: ${APPLICATIONS}"
        else
            export APPLICATIONS="$(echo ${SOFIN_ARGS})"
            note "Installing software: ${SOFIN_ARGS}"
        fi
        ;;


    deps|dependencies|local)
        LOCAL_DIR="$(${PWD_BIN})/"
        if [ "${USERNAME}" = "root" ]; then
            warn "Installation of project dependencies as root is immoral."
            # exit 1
            # unset USERNAME
        fi
        if [ ! -f "${CACHE_DIR}definitions/defaults.def" ]; then
            note "No definitions found in ${CACHE_DIR}definitions/defaults.def. Updating…"
            update_definitions
        fi
        cd "${LOCAL_DIR}"
        note "Looking for $(${PWD_BIN})/${DEPENDENCIES_FILE} file…"
        if [ ! -e "$(${PWD_BIN})/${DEPENDENCIES_FILE}" ]; then
            error "Dependencies file not found!"
            exit 1
        fi
        export APPLICATIONS="$(${CAT_BIN} ${LOCAL_DIR}${DEPENDENCIES_FILE} | ${TR_BIN} '\n' ' ')"
        note "Installing dependencies: ${APPLICATIONS}\n"
        ;;


    delete|remove|uninstall|rm)
        if [ "$2" = "" ]; then
            error "For \"$1\" task, second argument with application name is required!"
            exit 1
        fi

        # first look for a list with that name:
        if [ -e "${LISTS_DIR}${2}" ]; then
            export APPLICATIONS="$(${CAT_BIN} ${LISTS_DIR}$2 | ${TR_BIN} '\n' ' ')"
            note "Remove of list of software requested: ${APPLICATIONS}"
        else
            export APPLICATIONS="$(echo ${SOFIN_ARGS})"
            note "Removing applications: ${SOFIN_ARGS}"
        fi

        for app in $APPLICATIONS; do
            APP_NAME="$(${PRINTF_BIN} "${app}" | ${CUT_BIN} -c1 | ${TR_BIN} '[a-z]' '[A-Z]')$(${PRINTF_BIN} "${app}" | ${SED_BIN} 's/^[a-zA-Z]//')"
            if [ -d "${SOFTWARE_DIR}${APP_NAME}" ]; then
                note "Removing ${APP_NAME}"
                if [ "${APP_NAME}" = "/" ]; then
                    error "Czy Ty orzeszki?"
                    exit 1
                fi
                debug "Removing software from: ${SOFTWARE_DIR}${APP_NAME}"
                ${RM_BIN} -rfv "${SOFTWARE_DIR}${APP_NAME}" >> "${LOG}"
            else
                error "Application: ${APP_NAME} not installed."
            fi
            update_shell_vars ${USERNAME}
        done
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


    update|updatedefs|up)
        update_definitions
        note "Definitions were updated to latest version."
        exit
        ;;


    available)
        cd "${DEFINITIONS_DIR}"
        note "Available definitions:"
        ${LS_BIN} -m *def | ${SED_BIN} 's/\.def//g'
        note "Definitions count:"
        ${LS_BIN} -a *def | ${WC_BIN} -l
        cd "${LISTS_DIR}"
        note "Available lists:"
        ${LS_BIN} -m * | ${SED_BIN} 's/\.def//g'
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

        for dir in "/bin/" "/sbin/" "/libexec/"; do
            debug "Testing ${dir} looking into: ${SOFTWARE_DIR}${APP}${dir}"
            if [ -e "${SOFTWARE_DIR}${APP}${dir}${EXPORT}" ]; then
                note "Exporting binary: ${SOFTWARE_DIR}${APP}${dir}${EXPORT}"
                curr_dir="$(${PWD_BIN})"
                cd "${SOFTWARE_DIR}${APP}${dir}"
                ${LN_BIN} -vfs "..${dir}/${EXPORT}" "../exports/${EXPORT}" >> "$LOG"
                cd "${curr_dir}"
            fi
        done
        exit
        ;;


    outdated)
        update_definitions
        note "Definitions were updated to latest version."
        echo
        debug "Checking software from ${SOFTWARE_DIR}"
        if [ -d ${SOFTWARE_DIR} ]; then
            for prefix in ${SOFTWARE_DIR}*; do
                debug "Looking into: ${prefix}"
                application="$(${BASENAME_BIN} "${prefix}" | ${TR_BIN} '[A-Z]' '[a-z]')" # lowercase for case sensitive fs

                if [ ! -f "${prefix}/${application}${INSTALLED_MARK}" ]; then
                    error "Application: ${application} is not properly installed."
                    continue
                fi
                ver="$(${CAT_BIN} "${prefix}/${application}${INSTALLED_MARK}")"

                if [ ! -f "${DEFINITIONS_DIR}${application}.def" ]; then
                    error "No such definition found: ${application}"
                    continue
                fi
                . "${DEFINITIONS_DIR}${application}.def"

                check_version () { # $1 => installed version, $2 => available version
                    if [ ! "${1}" = "" ]; then
                        if [ ! "${2}" = "" ]; then
                            if [ ! "${1}" = "${2}" ]; then
                                warn "${application}: version ${2} available in definition, but installed: ${1}"
                                export outdated="true"
                            fi
                        fi
                    fi
                }

                check_version "${ver}" "${APP_VERSION}"
            done
        fi

        if [ "${outdated}" = "true" ]; then
            exit 1
        else
            note "No outdated installed software found."
            exit
        fi
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
    if [ ! -f "${DEFINITIONS_DIR}${application}.def" ]; then
        error "No such definition found: ${application}"
        continue
    fi
    . "${DEFINITIONS_DIR}${application}.def" # prevent installation of requirements of disabled application:
    check_disabled "${DISABLE_ON}" # after which just check if it's not disabled
    if [ ! "${ALLOW}" = "1" ]; then
        note "Requirement: ${APP_NAME} disabled on architecture: ${SYSTEM_NAME}.\n"
    else
        for definition in ${DEFINITIONS_DIR}${application}.def; do
            debug "Reading definition: ${definition}"
            . "${DEFAULTS}"
            . "${definition}"
            check_disabled "${DISABLE_ON}" # after which just check if it's not disabled

            # fancy old style Capitalize
            APP_NAME="$(${PRINTF_BIN} "${APP_NAME}" | ${CUT_BIN} -c1 | ${TR_BIN} '[a-z]' '[A-Z]')$(${PRINTF_BIN} "${APP_NAME}" | ${SED_BIN} 's/^[a-zA-Z]//')"
            if [ "${REQUIRE_ROOT_ACCESS}" = "true" ]; then
                if [ "${USERNAME}" != "root" ]; then
                    warn "Definition requires root priviledges to install: ${APP_NAME}. Wont install."
                    break
                fi
            fi

            # note "Preparing application: ${APP_NAME}${APP_POSTFIX} (${APP_FULL_NAME} v${APP_VERSION})"
            if [ "${USERNAME}" = "root" ]; then
                debug "Normal build"
                export PREFIX="${SOFTWARE_DIR}${APP_NAME}"
            else
                debug "User build: ${USERNAME}"
                export PREFIX="${HOME}/${HOME_APPS_DIR}${APP_NAME}"
                if [ ! -d "${HOME}/${HOME_APPS_DIR}" ]; then
                    ${MKDIR_BIN} -p "${HOME}/${HOME_APPS_DIR}"
                fi
            fi

            # append app postfix
            if [ ! -z "$APP_POSTFIX" ]; then
                export PREFIX="${PREFIX}${APP_POSTFIX}"
            fi

            # binary build of whole software bundle
            ABSNAME="${APP_NAME}${APP_POSTFIX}-${APP_VERSION}"
            ${MKDIR_BIN} -p "${HOME}/${HOME_APPS_DIR}" > /dev/null 2>&1
            ${MKDIR_BIN} -p "${BINBUILDS_CACHE_DIR}${ABSNAME}" > /dev/null 2>&1

            cd "${BINBUILDS_CACHE_DIR}${ABSNAME}/"
            BIN_POSTFIX="common"
            if [ "${USERNAME}" = "root" ]; then
                export BIN_POSTFIX="root"
            fi
            MIDDLE="${SYSTEM_NAME}-${SYSTEM_ARCH}-${BIN_POSTFIX}"
            if [ ! -e "./${APP_NAME}${APP_POSTFIX}-${APP_VERSION}.tar.gz" ]; then
                note "Seeking binary build: ${MIDDLE}/${APP_NAME}${APP_POSTFIX}-${APP_VERSION}"
                ${FETCH_BIN} "${MAIN_BINARY_REPOSITORY}${MIDDLE}/${APP_NAME}${APP_POSTFIX}-${APP_VERSION}.tar.gz"  >> ${LOG} 2>&1
            fi
            cd "${HOME}/${HOME_APPS_DIR}"
            ${TAR_BIN} zxf "${BINBUILDS_CACHE_DIR}${ABSNAME}/${APP_NAME}${APP_POSTFIX}-${APP_VERSION}.tar.gz" >> ${LOG} 2>&1
            if [ "$?" = "0" ]; then # if archive is valid
                note "Binary bundle installed: ${APP_NAME}${APP_POSTFIX} with version: ${APP_VERSION}"
                break
            else
                note "No binary bundle available for ${APP_NAME}${APP_POSTFIX}"
                ${RM_BIN} -fr "${BINBUILDS_CACHE_DIR}${ABSNAME}"
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

                # binary build of software dependency
                BIN_POSTFIX="common"
                if [ "${USERNAME}" = "root" ]; then
                    export BIN_POSTFIX="root"
                fi
                MIDDLE="${SYSTEM_NAME}-${SYSTEM_ARCH}-${BIN_POSTFIX}"
                REQ_APPNAME="$(${PRINTF_BIN} "${APP_NAME}" | ${CUT_BIN} -c1 | ${TR_BIN} '[a-z]' '[A-Z]')$(${PRINTF_BIN} "${APP_NAME}" | ${SED_BIN} 's/^[a-zA-Z]//')"
                BINBUILD_ADDRESS="${MAIN_BINARY_REPOSITORY}${MIDDLE}/${REQ_APPNAME}${APP_POSTFIX}-${APP_VERSION}.tar.gz"
                BINBUILD_FILE="$(${BASENAME_BIN} ${BINBUILD_ADDRESS})"
                TMP_REQ_DIR="${BINBUILDS_CACHE_DIR}${REQ_APPNAME}${APP_POSTFIX}-${APP_VERSION}"
                EXITCODE="0"
                ${MKDIR_BIN} -p ${BINBUILDS_CACHE_DIR} > /dev/null 2>&1
                ${MKDIR_BIN} -p ${TMP_REQ_DIR} > /dev/null 2>&1
                note "   → Seeking binary build of requirement: ${REQ_APPNAME}${APP_POSTFIX} with version: ${APP_VERSION}"
                debug "Binary build should be available here: ${MAIN_BINARY_REPOSITORY}${MIDDLE}/${REQ_APPNAME}${APP_POSTFIX}-${APP_VERSION}.tar.gz"

                cd "${TMP_REQ_DIR}"
                if [ ! -f "./${BINBUILD_FILE}" ]; then
                    debug "Fetching binary build: ${BINBUILD_FILE}"
                    ${FETCH_BIN} "${BINBUILD_ADDRESS}" >> ${LOG} 2>&1
                fi
                ${TAR_BIN} zxf ${REQ_APPNAME}${APP_POSTFIX}-${APP_VERSION}.tar.gz >> ${LOG} 2>&1
                export EXITCODE="$?"

                ${RM_BIN} -rf "${TMP_REQ_DIR}/${REQ_APPNAME}${APP_POSTFIX}/exports"
                cd "${CACHE_DIR}" # back to existing cache dir
                if [ "${EXITCODE}" = "0" ]; then # if archive is valid
                    note "   → Binary requirement: ${REQ_APPNAME}${APP_POSTFIX} installed with version: ${APP_VERSION}"
                    if [ ! -d ${PREFIX} ]; then
                        ${MKDIR_BIN} -p ${PREFIX}
                    fi
                    cd "${TMP_REQ_DIR}/${REQ_APPNAME}${APP_POSTFIX}"
                    for i in ${TMP_REQ_DIR}/${REQ_APPNAME}${APP_POSTFIX}/*; do # copy each folder to destination
                        debug "COPY: ${i} to ${PREFIX}"
                        ${CP_BIN} -fR "${i}/" "${PREFIX}" >> ${LOG} 2> ${LOG}
                    done
                    cd "${CACHE_DIR}"
                    debug "Cleaning unpacked binary cache folder: ${TMP_REQ_DIR}/${REQ_APPNAME}${APP_POSTFIX}"
                    ${RM_BIN} -rf "${TMP_REQ_DIR}/${REQ_APPNAME}${APP_POSTFIX}"
                    debug "Marking as installed '$1' in: ${PREFIX}"
                    ${TOUCH_BIN} "${PREFIX}/$1${INSTALLED_MARK}"
                    continue
                else
                    note "   → No binary build available for requirement: ${REQ_APPNAME}"
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
                # export LD_LIBRARY_PATH="${PREFIX}/lib:${PREFIX}/libexec:/usr/lib:/lib"
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
                        # debug "Runtime SHA1: ${RUNTIME_SHA}"
                        export BUILD_DIR_ROOT="${CACHE_DIR}cache/${APP_NAME}${APP_POSTFIX}-${APP_VERSION}/"
                        ${MKDIR_BIN} -p "${BUILD_DIR_ROOT}"
                        CUR_DIR="$(${PWD_BIN})"
                        cd "${BUILD_DIR_ROOT}"
                        for bd in ${BUILD_DIR_ROOT}/*; do
                            if [ -d "${bd}" ]; then
                                debug "Unpacked source code found in build dir. Removing: ${bd}"
                                if [ "${bd}" != "/" ]; then # it's better to be safe than sorry
                                    ${RM_BIN} -rf "${bd}"
                                fi
                            fi
                        done
                        if [ ! -e ${BUILD_DIR_ROOT}${APP_NAME}*${APP_HTTP_PATH##*.} ]; then
                            note "   → Fetching requirement source from: ${APP_HTTP_PATH}"
                            run "${FETCH_BIN} ${APP_HTTP_PATH}"
                        else
                            debug "Already fetched. Using tarball from cache"
                        fi

                        FIND_RESULT="${FIND_BIN} ${BUILD_DIR_ROOT} -maxdepth 1 -type f"
                        debug "Build dir: ${BUILD_DIR_ROOT}, find result: ${FIND_RESULT}"
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
                                $($FIND_BIN "${BUILD_DIR_ROOT}" -maxdepth 1 -type f -name "${file}" | ${XARGS_BIN} ${RM_BIN} -f)
                                # remove lock
                                if [ -e "${LOCK_FILE}" ]; then
                                    debug "Removing lock file: ${LOCK_FILE}"
                                    ${RM_BIN} -f "${LOCK_FILE}"
                                fi
                                # and restart script with same arguments:
                                eval "${SCRIPT_NAME} ${SCRIPT_ARGS}"
                                exit
                            fi
                        fi

                        debug "→ Unpacking source code of: ${APP_NAME}"
                        debug "Build dir root: ${BUILD_DIR_ROOT}"

                        # export BUILD_DIRECTORY="${BUILD_DIR}/${RUNTIME_SHA}"
                        # ${MKDIR_BIN} -p "${BUILD_DIRECTORY}"

                        APP_LOC="${BUILD_DIR_ROOT}${APP_NAME}"
                        run "${TAR_BIN} xf ${APP_LOC}*"

                        export BUILD_DIR="$(${FIND_BIN} ${BUILD_DIR_ROOT}/* -maxdepth 0 -type d -name "*${APP_VERSION}*")"
                        debug "Build Dir Core before: '${BUILD_DIR}'"
                        if [ "${BUILD_DIR}" = "" ]; then
                            export BUILD_DIR=$(${FIND_BIN} ${BUILD_DIR_ROOT}/* -maxdepth 0 -type d) # try any dir instead
                        fi
                        debug "Build Dir Core after: '${BUILD_DIR}'"
                        for dir in ${BUILD_DIR}; do
                            debug "Changing dir to: ${dir}/${APP_SOURCE_DIR_POSTFIX}"
                            cd "${dir}/${APP_SOURCE_DIR_POSTFIX}"
                            if [ ! -z "${APP_AFTER_UNPACK_CALLBACK}" ]; then
                                debug "Running after unpack callback"
                                run "${APP_AFTER_UNPACK_CALLBACK}"
                            fi

                            LIST_DIR="${DEFINITIONS_DIR}patches/$1" # $1 is definition file name
                            if [ -d "${LIST_DIR}" ]; then
                                note "   → Applying patches for: ${APP_NAME}${APP_POSTFIX}"
                                patches_files="$(${FIND_BIN} ${LIST_DIR}/* -maxdepth 0 -type f)"
                                for patch in ${patches_files}; do
                                    debug "Patching source code with patch: ${patch}"
                                    ${PATCH_BIN} -N -f -i "${patch}" >> "${LOG}" 2>> "${LOG}" # don't use run.. it may fail - we don't care
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

                                posix)
                                    run "./configure -prefix ${PREFIX} -cc $(${BASENAME_BIN} ${CC}) ${APP_CONFIGURE_ARGS}"
                                    ;;

                                cmake)
                                    run "${APP_CONFIGURE_SCRIPT} . -LH -DCMAKE_INSTALL_PREFIX=${PREFIX} -DCMAKE_BUILD_TYPE=Release ${APP_CONFIGURE_ARGS}"
                                    ;;

                                *)
                                    run "${APP_CONFIGURE_SCRIPT} ${APP_CONFIGURE_ARGS} --prefix=${PREFIX}"
                                    ;;

                            esac

                            if [ ! -z "${APP_AFTER_CONFIGURE_CALLBACK}" ]; then
                                debug "Running after configure callback"
                                run "${APP_AFTER_CONFIGURE_CALLBACK}"
                            fi

                            if [ "${APP_MAKE_METHOD}" != "true" ]; then
                                note "   → Building requirement: $1"
                                run "${APP_MAKE_METHOD}"
                                if [ ! -z "${APP_AFTER_MAKE_CALLBACK}" ]; then
                                    debug "Running after make callback"
                                    run "${APP_AFTER_MAKE_CALLBACK}"
                                fi
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
                        if [ -z "${DEVEL}" ]; then # if devel mode not set
                            debug "Removing build dir: ${BUILD_DIR}"
                            ${RM_BIN} -rf "${BUILD_DIR}"
                        else
                            debug "Leaving build dir cause in devel mode: ${BUILD_DIR_ROOT}"
                        fi
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
                    note "  ${req} (${req_amount} of ${req_all} remaining)"
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
                note "${SUCCESS_CHAR} ${application} [${ver}]\n"
            }

            if [ -e "${PREFIX}/${application}${INSTALLED_MARK}" ]; then
                if [ "${CHANGED}" = "true" ]; then
                    note "  ${application} (1 of ${req_all})"
                    note "   → App dependencies changed. Rebuilding ${application}"
                    execute_process "${application}"
                    unset CHANGED
                    mark
                    # strip_lib_bin
                    show_done
                else
                    note "  ${application} (1 of ${req_all})"
                    check_current_by_definition "${application}"
                    show_done
                    debug "${SUCCESS_CHAR} ${application} current: ${ver}, definition: [${APP_VERSION}] Ok."
                fi
            else
                note "  ${application} (1 of ${req_all})"
                execute_process "${application}"
                mark
                # strip_lib_bin
                note "${SUCCESS_CHAR} ${application} [${APP_VERSION}]\n"
            fi

            . "${DEFINITIONS_DIR}${application}.def"
            debug "Exporting binaries:${EXPORT_LIST}"
            if [ -d "${PREFIX}/exports-disabled" ]; then # just bring back disabled exports
                ${MV_BIN} "${PREFIX}/exports-disabled" "${PREFIX}/exports"
            else
                ${MKDIR_BIN} -p "${PREFIX}/exports"
                EXPORT_LIST=""
                for exp in ${APP_EXPORTS}; do
                    for dir in "/bin/" "/sbin/" "/libexec/"; do
                        debug "Testing ${dir} looking into: ${PREFIX}${dir}${exp}"
                        if [ -f "${PREFIX}${dir}${exp}" ]; then # a file
                            if [ -x "${PREFIX}${dir}${exp}" ]; then # and it's executable'
                                curr_dir="$(${PWD_BIN})"
                                cd "${PREFIX}${dir}"
                                ${LN_BIN} -vfs "..${dir}${exp}" "../exports/${exp}" >> "$LOG"
                                cd "${curr_dir}"
                                exp_elem="$(${BASENAME_BIN} ${PREFIX}${dir}${exp})"
                                EXPORT_LIST="${EXPORT_LIST} ${exp_elem}"
                            fi
                        fi
                    done
                done
            fi
            debug "Doing app conflict resolve"
            if [ ! -z "${APP_CONFLICTS_WITH}" ]; then
                note "Resolving conflicts."
                for app in ${APP_CONFLICTS_WITH}; do
                    if [ "${USERNAME}" != "root" ]; then
                        export apphome="${HOME}/${HOME_APPS_DIR}"
                    else
                        export apphome="${SOFTWARE_DIR}${apps}"
                    fi
                    an_app="${apphome}${app}"
                    if [ -d "${an_app}" ]; then
                        debug "Found app dir: ${an_app}"
                        if [ -e "${an_app}/exports" ]; then
                            ${MV_BIN} "${an_app}/exports" "${an_app}/exports-disabled"
                        fi
                    fi
                done
            fi

        done
    fi
done


update_shell_vars

if [ ! -z "${SHELL_PID}" ]; then
    note "All done. Reloading configuration of $(${BASENAME_BIN} ${SHELL}) with pid: ${SHELL_PID}…"
    ${KILL_BIN} -SIGUSR2 ${SHELL_PID}
else
    write_info_about_shell_configuration
fi


exit
