#!/bin/sh
# @author: Daniel (dmilith) Dettlaff (dmilith@verknowsys.com)

# config settings
readonly VERSION="0.70.6"

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
    fi
    if [ "${SYSTEM_NAME}" != "Darwin" ]; then
        if [ -d "/usr/local" ]; then
            files="$(${FIND_BIN} /usr/local -type f | ${WC_BIN} -l | ${SED_BIN} -e 's/^ *//g;s/ *$//g' )"
            if [ "${files}" != "0" ]; then
                warn "/usr/local has been found, and contains ${files} file(s)"
            fi
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


update_definitions () {
    note "${HEADER}"
    if [ ! -x "${GIT_BIN}" ]; then
        note "Installing initial definition list from tarball."
        cd "${CACHE_DIR}"
        INITIAL_DEFINITIONS="${MAIN_SOURCE_REPOSITORY}initial-definitions.tar.gz"
        ${RM_BIN} -rf definitions
        ${FETCH_BIN} "${INITIAL_DEFINITIONS}" >> ${LOG} 2>&1
        ${TAR_BIN} xf "$(${BASENAME_BIN} ${INITIAL_DEFINITIONS})"
        ${RM_BIN} -rf "$(${BASENAME_BIN} ${INITIAL_DEFINITIONS})"
        return
    fi
    if [ -d "${CACHE_DIR}definitions/.git" ]; then
        cd "${CACHE_DIR}definitions"
        current_branch="$(${GIT_BIN} rev-parse --abbrev-ref HEAD)"
        if [ "${current_branch}" != "${BRANCH}" ]; then # use current_branch value if branch isn't matching default branch
            # ${GIT_BIN} stash save -a >> ${LOG} 2>&1
            ${GIT_BIN} checkout -b "${current_branch}" >> ${LOG} 2>&1 || ${GIT_BIN} checkout "${current_branch}" >> ${LOG} 2>&1
            ${GIT_BIN} pull origin "${current_branch}" >> ${LOG} && note "Updated branch ${current_branch} of repository ${REPOSITORY}" || error "Error occured: Update from branch: ${BRANCH} of repository ${REPOSITORY} wasn't possible."

        else # else use default branch
            ${GIT_BIN} checkout -b "${BRANCH}" >> ${LOG} 2>&1 || ${GIT_BIN} checkout "${BRANCH}" >> ${LOG} 2>&1
            (${GIT_BIN} pull origin "${BRANCH}" >> ${LOG} && note "Updated branch ${BRANCH} of repository ${REPOSITORY}") || error "Error occured: Update from branch: ${BRANCH} of repository ${REPOSITORY} wasn't possible."

        fi

    else
        # clone definitions repository:
        cd "${CACHE_DIR}"
        note "Cloning repository ${REPOSITORY} from branch: ${BRANCH}"
        ${RM_BIN} -rf definitions >> ${LOG} 2>&1 # if something is already here, wipe it out from cache
        ${GIT_BIN} clone "${REPOSITORY}" definitions >> ${LOG} 2>&1 || error "Error occured: Cloning repository ${REPOSITORY} isn't possible. Make sure it's valid."
        cd "${CACHE_DIR}definitions"
        ${GIT_BIN} checkout -b "${BRANCH}" >> ${LOG} 2>&1
        (${GIT_BIN} pull origin "${BRANCH}" && note "Updated branch ${BRANCH} of repository ${REPOSITORY}") || error "Error occured: Update from branch: ${BRANCH} of repository ${REPOSITORY} isn't possible. Make sure that given repository and branch are valid." # XXX: temporary >> ${LOG} 2>&1
    fi
}


write_info_about_shell_configuration () {
    note
    warn "SHELL_PID is not set. Sofin auto-reload function is temporarely disabled."
}


usage_howto () {
    note "Built in tasks:"
    note
    note "install | get                        - installs software from list or from definition (example: $(${BASENAME_BIN} ${SCRIPT_NAME}) install ruby)"
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
    note "clean                                - cleans binbuilds cache, unpacked source content and logs"
    note "distclean                            - cleans binbuilds cache, unpacked source content, logs and definitions"
    note "purge                                - cleans binbuilds cache, unpacked source content, logs, definitions, source cache and possible states"
    note "outdated                             - lists outdated software"
    note "push | binpush                       - creates binary build from prebuilt software bundles name given as params (example: $(${BASENAME_BIN} ${SCRIPT_NAME}) push Ruby Vifm Curl)"
    note "port                                 - gather port of TheSS running service by service name"
    note "setup                                - switch definitions repository/ branch from env value 'REPOSITORY' and 'BRANCH' (example: BRANCH=master REPOSITORY=/my/local/definitions/repo/ sofin setup)"
    note "enable                               - enable Sofin developer environment (full environment stored in ~/.profile). It's the default"
    note "disable                              - disable Sofin developer environment (only PATH, PKG_CONFIG_PATH and MANPATH written to ~/.profile)"
    note "dev                                  - puts definition content on the fly. Second argument is definition name (no extension)"
    exit
}


update_shell_vars () {
    if [ "${USERNAME}" = "root" ]; then
        debug "Updating ${SOFIN_PROFILE} settings."
        ${PRINTF_BIN} "$(${SCRIPT_NAME} getshellvars)" > "${SOFIN_PROFILE}"
    else
        debug "Updating ${HOME}/.profile settings."
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


perform_clean () {
    note "Cleaning failed build directories in: ${CACHE_DIR}cache"
    if [ -d "${CACHE_DIR}cache" ]; then
        for i in $(${FIND_BIN} "${CACHE_DIR}cache" -maxdepth 1 -mindepth 1 -type d); do
            note "Removing build directory: ${i}"
            ${RM_BIN} -rf "${i}"
        done
    fi
    note "Removing binary builds from ${BINBUILDS_CACHE_DIR}"
    ${RM_BIN} -rf "${BINBUILDS_CACHE_DIR}"
    note "Removing log: ${LOG}"
    ${RM_BIN} -rf "${LOG}"
}


if [ ! "$1" = "" ]; then
    case $1 in

    dev)
        test -d ${DEFINITIONS_DIR} || update_definitions
        note "Paste your definition below. Hit ctrl-d after a newline to commit"
        ${CAT_BIN} > ${DEFINITIONS_DIR}/${2}.def
        exit
        ;;

    s|setup)
        if [ -d "${REPOSITORY}" ]; then
            note "Changing repository to local directory: ${REPOSITORY}"
        else
            note "Changing repository to: ${REPOSITORY}"
        fi
        ${PRINTF_BIN} "${REPOSITORY}\n" > "${REPOSITORY_CACHE_FILE}" # print repository name to cache file
        ${RM_BIN} -rf "${CACHE_DIR}/definitions" # wipe out current definitions from cache
        update_definitions # get repository specified by user
        exit
        ;;

    p|port)
        # support for TheSS /SoftwareData:
        app="$2"
        if [ "$app" = "" ]; then
            error "Must specify service name!"
        fi

        user_app_dir="${HOME}/SoftwareData/${app}"
        user_port_file="${user_app_dir}/.ports/0"
        if [ "${USERNAME}" = "root" ]; then
            user_app_dir="/SystemUsers/SoftwareData/${app}"
            user_port_file="${user_app_dir}/.ports/0"
        fi
        if [ -f "${user_port_file}" ]; then
            printf "$(${CAT_BIN} ${user_port_file})\n"
        else
            error "No service port found with name: '${app}'"
        fi

        exit
        ;;


    ver|version)
        note "${HEADER}"
        exit
        ;;


    log)
        ${TAIL_BIN} -n "${LOG_LINES_AMOUNT}" -F "${LOG}"
        ;;


    clean)
        perform_clean
        exit
        ;;


    distclean)
        note "Performing dist-clean."
        ${RM_BIN} -rf "${CACHE_DIR}definitions"
        perform_clean
        exit
        ;;


    purge)
        note "Performing purge-clean."
        perform_clean
        ${RM_BIN} -rf "${CACHE_DIR}"
        exit
        ;;


    enable)
        ${RM_BIN} -f ${SOFIN_DISABLED_INDICATOR_FILE}
        update_shell_vars
        note "Enabled Sofin environment. Reloading shell"
        ${KILL_BIN} -SIGUSR2 ${SHELL_PID}
        exit
        ;;


    disable)
        ${TOUCH_BIN} ${SOFIN_DISABLED_INDICATOR_FILE}
        update_shell_vars
        note "Disabled Sofin environment. Reloading shell"
        ${KILL_BIN} -SIGUSR2 ${SHELL_PID}
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
                lowercase="$(${PRINTF_BIN} "${app_name}" | ${TR_BIN} '[A-Z]' '[a-z]')"
                installed_file="${SOFTWARE_DIR}/${app_name}/${lowercase}${INSTALLED_MARK}"
                if [ -e "${installed_file}" ]; then
                    note "${SUCCESS_CHAR} ${app_name} [$(${CAT_BIN} ${installed_file})]\n"
                else
                    note "${SUCCESS_CHAR} ${app_name} [unknown]\n"
                fi
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

        # LD_LIBRARY_PATH, LDFLAGS, PKG_CONFIG_PATH:
        # ldresult="/lib:/usr/lib"
        # pkg_config_path="."
        export ldflags="${LDFLAGS} ${DEFAULT_LDFLAGS}"
        process () {
            for app in ${1}*; do # LIB_DIR
                if [ -e "${app}/lib" ]; then
                    ldresult="${app}/lib:${ldresult}"
                    ldflags="-L${app}/lib ${ldflags}" # NOTE: not required anymore? -R${app}/lib
                fi
                if [ -e "${app}/libexec" ]; then
                    ldresult="${app}/libexec:${ldresult}"
                    ldflags="-L${app}/libexec ${ldflags}" # NOTE: not required anymore? -R${app}/libexec
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

        set_c_compiler CLANG
        ${PRINTF_BIN} "# CC:\nexport CC='${CC}'\n\n"
        ${PRINTF_BIN} "# CXX:\nexport CXX='${CXX}'\n\n"
        ${PRINTF_BIN} "# CPP:\nexport CPP='${CPP}'\n\n"

        if [ -f "${SOFIN_DISABLED_INDICATOR_FILE}" ]; then # sofin disabled. Default system environment
            ${PRINTF_BIN} "# PATH:\nexport PATH=${result}\n\n"
            ${PRINTF_BIN} "# CFLAGS:\nexport CFLAGS=''\n\n"
            ${PRINTF_BIN} "# CXXFLAGS:\nexport CXXFLAGS=''\n\n"
            if [ "${SYSTEM_NAME}" = "Darwin" ]; then
                ${PRINTF_BIN} "# LDFLAGS:\nexport LDFLAGS=''\n\n"
                ${PRINTF_BIN} "# PKG_CONFIG_PATH:\nexport PKG_CONFIG_PATH='${pkg_config_path}:/opt/X11/lib/pkgconfig'\n\n" # pkg config should be ok
            else
                ${PRINTF_BIN} "# LDFLAGS:\nexport LDFLAGS=''\n\n"
                ${PRINTF_BIN} "# PKG_CONFIG_PATH:\nexport PKG_CONFIG_PATH='${pkg_config_path}'\n\n"
            fi
            ${PRINTF_BIN} "# MANPATH:\nexport MANPATH='${manpath}'\n\n"

        else # sofin enabled, Default behavior:

            ${PRINTF_BIN} "# PATH:\nexport PATH=${result}\n\n"
            ${PRINTF_BIN} "# CFLAGS:\nexport CFLAGS='${cflags}'\n\n"
            ${PRINTF_BIN} "# CXXFLAGS:\nexport CXXFLAGS='${cxxflags}'\n\n"
            if [ "${SYSTEM_NAME}" = "Darwin" ]; then
                ${PRINTF_BIN} "# LDFLAGS:\nexport LDFLAGS='${ldflags}'\n\n"
                ${PRINTF_BIN} "# PKG_CONFIG_PATH:\nexport PKG_CONFIG_PATH='${pkg_config_path}:/opt/X11/lib/pkgconfig'\n\n"
            else
                ${PRINTF_BIN} "# LDFLAGS:\nexport LDFLAGS='${ldflags} -Wl,--enable-new-dtags'\n\n"
                ${PRINTF_BIN} "# PKG_CONFIG_PATH:\nexport PKG_CONFIG_PATH='${pkg_config_path}'\n\n"
            fi
            ${PRINTF_BIN} "# MANPATH:\nexport MANPATH='${manpath}'\n\n"

        fi

        exit
        ;;


    install|get)
        if [ "$2" = "" ]; then
            error "For \"$1\" application installation mode, second argument with at least one application name or list is required!"
        fi
        update_definitions
        # first of all, try using a list if exists:
        if [ -f "${LISTS_DIR}$2" ]; then
            export APPLICATIONS="$(${CAT_BIN} ${LISTS_DIR}$2 | ${TR_BIN} '\n' ' ')"
            note "Processing software: ${APPLICATIONS}"
        else
            export APPLICATIONS="$(echo ${SOFIN_ARGS})"
            note "Processing software: ${SOFIN_ARGS}"
        fi
        ;;


    deps|dependencies|local)
        LOCAL_DIR="$(${PWD_BIN})/"
        if [ "${USERNAME}" = "root" ]; then
            warn "Installation of project dependencies as root is immoral."
        fi
        update_definitions
        cd "${LOCAL_DIR}"
        note "Looking for $(${PWD_BIN})/${DEPENDENCIES_FILE} file."
        if [ ! -e "$(${PWD_BIN})/${DEPENDENCIES_FILE}" ]; then
            error "Dependencies file not found!"
        fi
        export APPLICATIONS="$(${CAT_BIN} ${LOCAL_DIR}${DEPENDENCIES_FILE} | ${TR_BIN} '\n' ' ')"
        note "Installing dependencies: ${APPLICATIONS}\n"
        ;;


    push|binpush)
        note "Preparing to push binary bundle: ${SOFIN_ARGS} from ${SOFTWARE_DIR} to binary repository."
        cd "${SOFTWARE_DIR}"
        for element in ${SOFIN_ARGS}; do
            if [ -d "${element}" ]; then
                if [ ! -L "${element}" ]; then
                    lowercase_element="$(${PRINTF_BIN} "${element}" | ${TR_BIN} '[A-Z]' '[a-z]')"
                    version_element="$(${CAT_BIN} ${element}/${lowercase_element}.installed)"
                    name="${element}-${version_element}${DEFAULT_ARCHIVE_EXT}"
                    note "Preparing archive of: ${name}"
                    if [ ! -e "./${name}" ]; then
                        ${TAR_BIN} zcf "${name}" "./${element}"
                    else
                        note "Archive already exists. Skipping: ${name}"
                    fi

                    case "${SYSTEM_NAME}" in
                        Darwin|Linux)
                            export archive_sha1="$(${SHA_BIN} "${name}" | ${AWK_BIN} '{ print $1 }')"
                            ;;

                        FreeBSD)
                            export archive_sha1="$(${SHA_BIN} -q "${name}")"
                            ;;
                    esac

                    ${PRINTF_BIN} "${archive_sha1}" > "${name}.sha1"
                    note "Archive sha: ${archive_sha1}"
                    dig_query="$(${DIG_BIN} +short ${MAIN_SOFTWARE_ADDRESS} A)"
                    if [ ${OS_VERSION} -gt 93 ]; then
                        # In FreeBSD 10 there's drill utility instead of dig
                        dig_query=$(${DIG_BIN} A ${MAIN_SOFTWARE_ADDRESS} | ${GREP_BIN} "^${MAIN_SOFTWARE_ADDRESS}" | ${AWK_BIN} '{print $5}')
                    fi
                    debug "MIRROR: ${dig_query}"
                    for mirror in ${dig_query}; do
                        SYS="${SYSTEM_NAME}-${FULL_SYSTEM_VERSION}-${SYSTEM_ARCH}"
                        address="${MAIN_USER}@${mirror}:${MAIN_SOFTWARE_PREFIX}/software/binary/${SYS}/"
                        note "Creating destination dirs for ${SYS} if necessary"
                        ${SSH_BIN} -p ${MAIN_PORT} ${MAIN_USER}@${mirror} "mkdir -p ${MAIN_SOFTWARE_PREFIX}/software/binary/${SYS}"
                        note "Sending archive to remote: ${address}"
                        ${SCP_BIN} -P ${MAIN_PORT} "${name}" "${address}${name}" >> "${LOG}" 2>&1
                        ${SCP_BIN} -P ${MAIN_PORT} "${name}.sha1" "${address}${name}.sha1" >> "${LOG}" 2>&1
                    done
                    ${RM_BIN} -f "${name}"
                    ${RM_BIN} -f "${name}.sha1"
                    note "Done."
                fi
            else
                warn "Not found software named: ${element}!"
            fi
        done
        exit
        ;;


    delete|remove|uninstall|rm)
        if [ "$2" = "" ]; then
            error "For \"$1\" task, second argument with application name is required!"
        fi

        # first look for a list with that name:
        if [ -e "${LISTS_DIR}${2}" ]; then
            export APPLICATIONS="$(${CAT_BIN} ${LISTS_DIR}$2 | ${TR_BIN} '\n' ' ')"
            debug "Removing list of applications: ${APPLICATIONS}"
        else
            export APPLICATIONS="$(echo ${SOFIN_ARGS})"
            debug "Removing applications: ${SOFIN_ARGS}"
        fi

        for app in $APPLICATIONS; do
            APP_NAME="$(${PRINTF_BIN} "${app}" | ${CUT_BIN} -c1 | ${TR_BIN} '[a-z]' '[A-Z]')$(${PRINTF_BIN} "${app}" | ${SED_BIN} 's/^[a-zA-Z]//')"
            if [ -d "${SOFTWARE_DIR}${APP_NAME}" ]; then
                note "Removing ${APP_NAME}"
                if [ "${APP_NAME}" = "/" ]; then
                    error "Czy Ty orzeszki?"
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
            note "Reloading configuration of $(${BASENAME_BIN} ${SHELL}) with pid: ${SHELL_PID}."
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
        fi
        if [ "$3" = "" ]; then
            error "Missing third argument with source app is required!"
        fi
        EXPORT="$2"
        APP="$(${PRINTF_BIN} "${3}" | ${CUT_BIN} -c1 | ${TR_BIN} '[a-z]' '[A-Z]')$(${PRINTF_BIN} "${3}" | ${SED_BIN} 's/^[a-zA-Z]//')"

        for dir in "/bin/" "/sbin/" "/libexec/"; do
            debug "Testing ${dir} looking into: ${SOFTWARE_DIR}${APP}${dir}"
            if [ -e "${SOFTWARE_DIR}${APP}${dir}${EXPORT}" ]; then
                note "Exporting binary: ${SOFTWARE_DIR}${APP}${dir}${EXPORT}"
                curr_dir="$(${PWD_BIN})"
                cd "${SOFTWARE_DIR}${APP}${dir}"
                ${MKDIR_BIN} -p "${SOFTWARE_DIR}${APP}/exports" # make sure exports dir already exists
                ${LN_BIN} -vfs "..${dir}/${EXPORT}" "../exports/${EXPORT}" >> "$LOG"
                cd "${curr_dir}"
                exit
            else
                debug "Not found: ${SOFTWARE_DIR}${APP}${dir}${EXPORT}"
            fi
        done
        exit 1
        ;;


    outdated)
        update_definitions
        note "Definitions were updated to latest version."
        debug "Checking software from ${SOFTWARE_DIR}"
        if [ -d ${SOFTWARE_DIR} ]; then
            for prefix in ${SOFTWARE_DIR}*; do
                debug "Looking into: ${prefix}"
                application="$(${BASENAME_BIN} "${prefix}" | ${TR_BIN} '[A-Z]' '[a-z]')" # lowercase for case sensitive fs

                if [ ! -f "${prefix}/${application}${INSTALLED_MARK}" ]; then
                    warn "Application: ${application} is not properly installed."
                    continue
                fi
                ver="$(${CAT_BIN} "${prefix}/${application}${INSTALLED_MARK}")"

                if [ ! -f "${DEFINITIONS_DIR}${application}.def" ]; then
                    warn "No such definition found: ${application}"
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
        warn "No such definition found: ${application}"
        continue
    fi
    . "${DEFINITIONS_DIR}${application}.def" # prevent installation of requirements of disabled application:
    check_disabled "${DISABLE_ON}" # after which just check if it's not disabled
    if [ ! "${ALLOW}" = "1" ]; then
        note "Software: ${application} disabled on architecture: ${SYSTEM_NAME}-${FULL_SYSTEM_VERSION}-${SYSTEM_ARCH}"
    else
        for definition in ${DEFINITIONS_DIR}${application}.def; do
            export DONT_BUILD_BUT_DO_EXPORTS=""
            debug "Reading definition: ${definition}"
            . "${DEFAULTS}"
            . "${definition}"
            check_disabled "${DISABLE_ON}" # after which just check if it's not disabled

            # fancy old style Capitalize
            APP_LOWER="${APP_NAME}"
            APP_NAME="$(${PRINTF_BIN} "${APP_NAME}" | ${CUT_BIN} -c1 | ${TR_BIN} '[a-z]' '[A-Z]')$(${PRINTF_BIN} "${APP_NAME}" | ${SED_BIN} 's/^[a-zA-Z]//')"
            if [ "${REQUIRE_ROOT_ACCESS}" = "true" ]; then
                if [ "${USERNAME}" != "root" ]; then
                    warn "Definition requires root priviledges to install: ${APP_NAME}. Wont install."
                    break
                fi
            fi

            # note "Preparing application: ${APP_NAME}${APP_POSTFIX} (${APP_FULL_NAME} v${APP_VERSION})"
            export PREFIX="${SOFTWARE_DIR}${APP_NAME}"

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
                fi
            }

            # binary build of whole software bundle
            ABSNAME="${APP_NAME}${APP_POSTFIX}-${APP_VERSION}"
            ${MKDIR_BIN} -p "${BINBUILDS_CACHE_DIR}${ABSNAME}" > /dev/null 2>&1

            cd "${BINBUILDS_CACHE_DIR}${ABSNAME}/"
            MIDDLE="${SYSTEM_NAME}-${FULL_SYSTEM_VERSION}-${SYSTEM_ARCH}"
            ARCHIVE_NAME="${APP_NAME}${APP_POSTFIX}-${APP_VERSION}${DEFAULT_ARCHIVE_EXT}"
            INSTALLED_INDICATOR="${PREFIX}/${APP_LOWER}${APP_POSTFIX}.installed"
            if [ ! -e "${INSTALLED_INDICATOR}" ]; then
                if [ "${USE_BINBUILD}" = "false" ]; then
                    note "   ${NOTE_CHAR2} Binary build check was skipped"
                else
                    if [ "${USERNAME}" != "${BUILD_USER_NAME}" ]; then # don't use bin builds for build-user
                        if [ ! -e "./${ARCHIVE_NAME}" ]; then
                            note "Trying binary build for: ${MIDDLE}/${APP_NAME}${APP_POSTFIX}-${APP_VERSION}"
                            ${FETCH_BIN} "${MAIN_BINARY_REPOSITORY}${MIDDLE}/${ARCHIVE_NAME}"  >> ${LOG} 2>&1
                            ${FETCH_BIN} "${MAIN_BINARY_REPOSITORY}${MIDDLE}/${ARCHIVE_NAME}.sha1"  >> ${LOG} 2>&1

                            # checking archive sha1 checksum
                            if [ -e "${ARCHIVE_NAME}" ]; then
                                case "${SYSTEM_NAME}" in
                                    Darwin|Linux)
                                        export current_archive_sha1="$(${SHA_BIN} "${ARCHIVE_NAME}" | ${AWK_BIN} '{ print $1 }')"
                                        ;;

                                    FreeBSD)
                                        export current_archive_sha1="$(${SHA_BIN} -q "${ARCHIVE_NAME}")"
                                        ;;
                                esac
                            fi
                            current_sha_file="${ARCHIVE_NAME}.sha1"
                            if [ -e "${current_sha_file}" ]; then
                                export sha1_value="$(cat ${current_sha_file})"
                            fi

                            debug "${current_archive_sha1} vs ${sha1_value}"
                            if [ "${current_archive_sha1}" != "${sha1_value}" ]; then
                                ${RM_BIN} -f ${ARCHIVE_NAME}
                                ${RM_BIN} -f ${ARCHIVE_NAME}.sha1
                            fi
                        fi
                        cd "${SOFTWARE_ROOT_DIR}"

                        if [ -e "${BINBUILDS_CACHE_DIR}${ABSNAME}/${ARCHIVE_NAME}" ]; then # if exists, then checksum is ok
                            ${TAR_BIN} zxf "${BINBUILDS_CACHE_DIR}${ABSNAME}/${ARCHIVE_NAME}" >> ${LOG} 2>&1
                            if [ "$?" = "0" ]; then # if archive is valid
                                note "  ${NOTE_CHAR2} Binary bundle installed: ${APP_NAME}${APP_POSTFIX} with version: ${APP_VERSION}"
                                export DONT_BUILD_BUT_DO_EXPORTS="true"
                            else
                                debug "  ${NOTE_CHAR2} No binary bundle available for ${APP_NAME}${APP_POSTFIX}"
                                ${RM_BIN} -fr "${BINBUILDS_CACHE_DIR}${ABSNAME}"
                            fi
                        else
                            debug "  ${NOTE_CHAR2} Binary build checksum doesn't match for: ${ABSNAME}"
                        fi
                    else # build-user
                        note "Binary builds disabled for ${BUILD_USER_NAME}!"
                    fi
                fi
            else
                note "Software already installed: ${APP_NAME}${APP_POSTFIX} with version: $(cat ${INSTALLED_INDICATOR})"
                export DONT_BUILD_BUT_DO_EXPORTS="true"
            fi

            execute_process () {
                if [ -z "$1" ]; then
                    error "No param given for execute_process()!"
                fi
                req_definition_file="${DEFINITIONS_DIR}${1}.def"
                debug "Checking requirement: $1 file: $req_definition_file"
                if [ ! -e "${req_definition_file}" ]; then
                    error "Cannot fetch definition ${req_definition_file}! Aborting!"
                fi

                . "${DEFAULTS}" # load definition and check for current version
                . "${req_definition_file}"
                # check_current "${APP_VERSION}" "${APP_CURRENT_VERSION}"
                check_disabled "${DISABLE_ON}" # check requirement for disabled state:

                if [ ! -z "${FORCE_GNU_COMPILER}" ]; then # force GNU compiler usage on definition side:
                    warn "   ${NOTE_CHAR2} GNU compiler set for: ${APP_NAME}"
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
                    else
                        debug "Runtime SHA1: ${RUNTIME_SHA}"
                        export BUILD_DIR_ROOT="${CACHE_DIR}cache/${APP_NAME}${APP_POSTFIX}-${APP_VERSION}-${RUNTIME_SHA}/"
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

                        if [ "${APP_GIT_MODE}" = "" ]; then
                            # Standard http tarball method:
                            if [ ! -e ${BUILD_DIR_ROOT}/../$(${BASENAME_BIN} ${APP_HTTP_PATH}) ]; then
                                note "   ${NOTE_CHAR2} Fetching requirement source from: ${APP_HTTP_PATH}"
                                run "${FETCH_BIN} ${APP_HTTP_PATH}"
                                ${MV_BIN} $(${BASENAME_BIN} ${APP_HTTP_PATH}) ${BUILD_DIR_ROOT}/..
                            fi

                            file="${BUILD_DIR_ROOT}/../$(${BASENAME_BIN} ${APP_HTTP_PATH})"
                            debug "Build dir: ${BUILD_DIR_ROOT}, file: ${file}"
                            if [ "${APP_SHA}" = "" ]; then
                                error "${NOTE_CHAR2} Missing SHA sum for source: ${file}."
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
                                    debug "${NOTE_CHAR2} SHA sum match in file: ${file}"
                                else
                                    warn "${NOTE_CHAR2} ${cur} vs ${APP_SHA}"
                                    warn "${NOTE_CHAR2} SHA sum mismatch. Removing corrupted file from cache: ${file}, and retrying."
                                    # remove corrupted file
                                    ${RM_BIN} -v "${file}" >> "${LOG}"
                                    # and restart script with same arguments:
                                    eval "${SCRIPT_NAME} ${SCRIPT_ARGS}"
                                    exit
                                fi
                            fi

                            note "   ${NOTE_CHAR2} Unpacking source code of: ${APP_NAME}"
                            debug "Build dir root: ${BUILD_DIR_ROOT}"
                            run "${TAR_BIN} xf ${file}"

                        else
                            # git method
                            note "   ${NOTE_CHAR2} Fetching requirement source from git repository: ${APP_HTTP_PATH}"
                            run "${GIT_BIN} clone ${APP_HTTP_PATH} ${APP_NAME}${APP_VERSION}"
                        fi

                        export BUILD_DIR="$(${FIND_BIN} ${BUILD_DIR_ROOT}/* -maxdepth 0 -type d -name "*${APP_VERSION}*")"
                        debug "Build Dir Core before: '${BUILD_DIR}'"
                        if [ "${BUILD_DIR}" = "" ]; then
                            export BUILD_DIR=$(${FIND_BIN} ${BUILD_DIR_ROOT}/* -maxdepth 0 -type d) # try any dir instead
                        fi
                        debug "Build Dir Core after: '${BUILD_DIR}'"
                        for dir in ${BUILD_DIR}; do
                            debug "Changing dir to: ${dir}/${APP_SOURCE_DIR_POSTFIX}"
                            cd "${dir}/${APP_SOURCE_DIR_POSTFIX}"

                            if [ "${APP_GIT_CHECKOUT}" != "" ]; then
                                note "   ${NOTE_CHAR2} Checking out: ${APP_GIT_CHECKOUT}"
                                run "${GIT_BIN} checkout ${APP_GIT_CHECKOUT}"
                            fi

                            if [ ! -z "${APP_AFTER_UNPACK_CALLBACK}" ]; then
                                debug "Running after unpack callback"
                                run "${APP_AFTER_UNPACK_CALLBACK}"
                            fi

                            LIST_DIR="${DEFINITIONS_DIR}patches/$1" # $1 is definition file name
                            if [ -d "${LIST_DIR}" ]; then
                                note "   ${NOTE_CHAR2} Applying patches for: ${APP_NAME}${APP_POSTFIX}"
                                patches_files="$(${FIND_BIN} ${LIST_DIR}/* -maxdepth 0 -type f)"
                                for patch in ${patches_files}; do
                                    for level in 0 1 2 3 4 5; do
                                        debug "Trying to patch source with patch: ${patch} (p${level})"
                                        ${PATCH_BIN} -p${level} -N -f -i "${patch}" >> "${LOG}" 2>> "${LOG}" # don't use run.. it may fail - we don't care
                                        debug "Patching (p${level}) exit code: $?"
                                    done
                                done
                                pspatch_dir="${LIST_DIR}/${SYSTEM_NAME}"
                                debug "Checking psp dir: ${pspatch_dir}"
                                if [ -d "${pspatch_dir}" ]; then
                                    note "   ${NOTE_CHAR2} Applying platform specific patches for: ${APP_NAME}${APP_POSTFIX}/${SYSTEM_NAME}"
                                    patches_files="$(${FIND_BIN} ${pspatch_dir}/* -maxdepth 0 -type f)"
                                    for platform_specific_patch in ${patches_files}; do
                                        for level in 0 1 2 3 4 5; do
                                            debug "Patching source code with pspatch: ${platform_specific_patch} (p${level})"
                                            ${PATCH_BIN} -p${level} -N -f -i "${platform_specific_patch}" >> "${LOG}" 2>> "${LOG}"
                                            debug "Patching (p${level}) exit code: $?"
                                        done
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

                            note "   ${NOTE_CHAR2} Configuring: $1, version: ${APP_VERSION}"
                            case "${APP_CONFIGURE_SCRIPT}" in

                                ignore)
                                    note "   ${NOTE_CHAR2} Ignored configuration of definition: $1"
                                    ;;

                                no-conf)
                                    note "   ${NOTE_CHAR2} No configuration for definition: $1"
                                    export APP_MAKE_METHOD="${APP_MAKE_METHOD} PREFIX=${PREFIX}"
                                    export APP_INSTALL_METHOD="${APP_INSTALL_METHOD} PREFIX=${PREFIX}"
                                    ;;

                                binary)
                                    note "   ${NOTE_CHAR2} Prebuilt definition of: $1"
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
                                note "   ${NOTE_CHAR2} Building requirement: $1"
                                run "${APP_MAKE_METHOD}"
                                if [ ! -z "${APP_AFTER_MAKE_CALLBACK}" ]; then
                                    debug "Running after make callback"
                                    run "${APP_AFTER_MAKE_CALLBACK}"
                                fi
                            fi

                            note "   ${NOTE_CHAR2} Installing requirement: $1"
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
                            debug "Removing build dirs: ${BUILD_DIR} and ${BUILD_DIR_ROOT}"
                            ${RM_BIN} -rf "${BUILD_DIR}" "${BUILD_DIR_ROOT}"
                        else
                            debug "Leaving build dir cause in devel mode: ${BUILD_DIR_ROOT}"
                        fi
                        cd "${CUR_DIR}"
                    fi
                else
                    warn "   ${NOTE_CHAR2} Requirement: ${APP_NAME} disabled on architecture: ${SYSTEM_NAME}-${FULL_SYSTEM_VERSION}-${SYSTEM_ARCH}"
                    if [ ! -d "${PREFIX}" ]; then # case when disabled requirement is first on list of dependencies
                        ${MKDIR_BIN} -p "${PREFIX}"
                    fi
                    ${TOUCH_BIN} "${PREFIX}/${req}${INSTALLED_MARK}"
                    ${PRINTF_BIN} "system-version" > "${PREFIX}/${req}${INSTALLED_MARK}"
                fi
            }

            if [ "${DONT_BUILD_BUT_DO_EXPORTS}" = "" ]; then
                if [ "${APP_REQUIREMENTS}" = "" ]; then
                    note "Installing ${application} v${APP_VERSION}"
                else
                    note "Installing ${application} v${APP_VERSION}, with requirements: ${APP_REQUIREMENTS}"
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
                    # check_current_by_definition "${req}"
                    export req_amount="$(${PRINTF_BIN} "${req_amount} - 1\n" | ${BC_BIN})"
                done
            fi

            mark () {
                debug "Marking definition: ${application} installed"
                ${TOUCH_BIN} "${PREFIX}/${application}${INSTALLED_MARK}"
                debug "Writing version: ${APP_VERSION} of app: '${application}' installed in: ${PREFIX}"
                ${PRINTF_BIN} "${APP_VERSION}" > "${PREFIX}/${application}${INSTALLED_MARK}"
            }

            show_done () {
                ver="$(${CAT_BIN} "${PREFIX}/${application}${INSTALLED_MARK}")"
                note "${SUCCESS_CHAR} ${application} [${ver}]\n"
            }

            if [ "${DONT_BUILD_BUT_DO_EXPORTS}" = "" ]; then
                if [ -e "${PREFIX}/${application}${INSTALLED_MARK}" ]; then
                    if [ "${CHANGED}" = "true" ]; then
                        note "  ${application} (1 of ${req_all})"
                        note "   ${NOTE_CHAR2} App dependencies changed. Rebuilding ${application}"
                        execute_process "${application}"
                        unset CHANGED
                        mark
                        # strip_lib_bin
                        show_done
                    else
                        note "  ${application} (1 of ${req_all})"
                        # check_current_by_definition "${application}"
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
            fi

            . "${DEFINITIONS_DIR}${application}.def"
            note "Exporting binaries: ${APP_EXPORTS} of prefix: ${PREFIX}"
            if [ -d "${PREFIX}/exports-disabled" ]; then # just bring back disabled exports
                debug "Moving ${PREFIX}/exports-disabled to ${PREFIX}/exports"
                ${MV_BIN} "${PREFIX}/exports-disabled" "${PREFIX}/exports"
            else
                ${MKDIR_BIN} -p "${PREFIX}/exports"
                EXPORT_LIST=""
                for exp in ${APP_EXPORTS}; do
                    for dir in "/bin/" "/sbin/" "/libexec/"; do
                        if [ -f "${PREFIX}${dir}${exp}" ]; then # a file
                            if [ -x "${PREFIX}${dir}${exp}" ]; then # and it's executable'
                                debug "Exporting ${PREFIX}${dir}${exp}"
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
                note "Resolving conflicts: ${APP_CONFLICTS_WITH}"
                for app in ${APP_CONFLICTS_WITH}; do
                    export apphome="${SOFTWARE_DIR}"
                    an_app="${apphome}${app}"
                    if [ -d "${an_app}" ]; then
                        debug "Found conflicting app: ${an_app}"
                        if [ -e "${an_app}/exports" ]; then
                            note "Disabling exports for ${an_app}"
                            ${MV_BIN} "${an_app}/exports" "${an_app}/exports-disabled"
                        fi
                    fi
                done
            fi

        done

        if [ ! -z "${APP_AFTER_EXPORT_CALLBACK}" ]; then
            debug "Executing APP_AFTER_EXPORT_CALLBACK"
            run "${APP_AFTER_EXPORT_CALLBACK}"
        fi

        if [ "${APP_APPLE_BUNDLE}" = "true" ]; then
            APP_LOWERNAME="${APP_NAME}"
            APP_NAME="$(${PRINTF_BIN} "${APP_NAME}" | ${CUT_BIN} -c1 | ${TR_BIN} '[a-z]' '[A-Z]')$(${PRINTF_BIN} "${APP_NAME}" | ${SED_BIN} 's/^[a-zA-Z]//')"
            APP_BUNDLE_NAME="${PREFIX}.app"
            note "Creating Apple bundle: ${APP_NAME} in ${APP_BUNDLE_NAME}"
            ${MKDIR_BIN} -p "${APP_BUNDLE_NAME}/libs"
            ${MKDIR_BIN} -p "${APP_BUNDLE_NAME}/Contents"
            ${MKDIR_BIN} -p "${APP_BUNDLE_NAME}/Contents/Resources/${APP_LOWERNAME}"
            ${MKDIR_BIN} -p "${APP_BUNDLE_NAME}/exports"
            ${MKDIR_BIN} -p "${APP_BUNDLE_NAME}/share"

            ${CP_BIN} -R ${PREFIX}/${APP_NAME}.app/Contents/* "${APP_BUNDLE_NAME}/Contents/"
            ${CP_BIN} -R ${PREFIX}/bin/${APP_LOWERNAME} "${APP_BUNDLE_NAME}/exports/"

            for lib in $(${FIND_BIN} "${PREFIX}" -name '*.dylib' -type f); do
                ${CP_BIN} -vf ${lib} ${APP_BUNDLE_NAME}/libs/ >> ${LOG} 2>&1
            done

            # if symlink exists, remove it.
            ${RM_BIN} -f ${APP_BUNDLE_NAME}/lib
            ${LN_BIN} -s "${APP_BUNDLE_NAME}/libs ${APP_BUNDLE_NAME}/lib"

            # move data, and support files from origin:
            ${CP_BIN} -R "${PREFIX}/share/${APP_LOWERNAME}" "${APP_BUNDLE_NAME}/share/"
            ${CP_BIN} -R "${PREFIX}/lib/${APP_LOWERNAME}" "${APP_BUNDLE_NAME}/libs/"

            cd "${APP_BUNDLE_NAME}/Contents"
            test -L MacOS || ${LN_BIN} -s ../exports MacOS >> ${LOG} 2>&1

            note "Creating relative libraries search path"
            cd ${APP_BUNDLE_NAME}

            note "Processing exported binary: ${i}"
            ${SOFIN_LIBBUNDLE_BIN} -x "${APP_BUNDLE_NAME}/Contents/MacOS/${APP_LOWERNAME}" >> ${LOG} 2>&1

        fi

    fi
done


update_shell_vars

if [ ! -z "${SHELL_PID}" ]; then
    note "All done. Reloading configuration of $(${BASENAME_BIN} "${SHELL}") with pid: ${SHELL_PID}."
    ${KILL_BIN} -SIGUSR2 ${SHELL_PID}
else
    write_info_about_shell_configuration
fi


exit
