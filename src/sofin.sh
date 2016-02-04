#!/bin/sh
# @author: Daniel (dmilith) Dettlaff (dmilith at me dot com)

# load configuration from sofin.conf
readonly CONF_FILE="/etc/sofin.conf.sh"
if [ -e "${CONF_FILE}" ]; then
    . "${CONF_FILE}"
    validate_env
else
    echo "FATAL: No configuration file found: ${CONF_FILE}. Sofin isn't installed properly."
    exit 1
fi

if [ "${SOFIN_TRACE}" = "YES" ]; then
    set -x
fi

SOFIN_ARGS=$*
SOFIN_ARGS_FULL="${SOFIN_ARGS}"
SOFIN_ONLYNAME="$(${BASENAME_BIN} "${SOFIN_BIN}" 2>/dev/null)"
readonly SOFIN_ARGS="$(echo ${SOFIN_ARGS} | ${CUT_BIN} -d' ' -f2- 2>/dev/null)"
readonly ALL_INSTALL_PHRASES="i|install|get|pick|choose|use|switch"
readonly BUILD_AND_DEPLOY_PHRASES="b|build|d|deploy"

# Some lazy shortcuts..
FILES_COUNT_GUARD="${WC_BIN} -l 2>/dev/null | ${SED_BIN} 's/ //g' 2>/dev/null"
OLDEST_BUILD_DIR_GUARD="${SORT_BIN} -k1 -n 2>/dev/null | ${TAIL_BIN} -n1 2>/dev/null | ${CUT_BIN} -f2 -d' ' 2>/dev/null | ${SORT_BIN} -k1 -n 2>/dev/null | ${TAIL_BIN} -n1 2>/dev/null | ${CUT_BIN} -f2 -d' ' 2>/dev/null"


check_definition_dir () {
    if [ ! -d "${SOFTWARE_DIR}" ]; then
        debug "No ${SOFTWARE_DIR} found. Creating one."
        "${MKDIR_BIN}" -p "${SOFTWARE_DIR}"
    fi
    if [ ! -d "${CACHE_DIR}" ]; then
        debug "No cache folder found. Creating one at: ${CACHE_DIR}"
        "${MKDIR_BIN}" -p "${CACHE_DIR}"
    fi
}


check_requirements () {
    if [ "${APPLICATIONS}" = "" ]; then
        exit
    fi
    if [ "${SYSTEM_NAME}" != "Darwin" ]; then
        if [ -d "/usr/local" ]; then
            files="$(${FIND_BIN} /usr/local -maxdepth 3 -type f 2>/dev/null | ${WC_BIN} -l 2>/dev/null | ${SED_BIN} -e 's/^ *//g;s/ *$//g' 2>/dev/null)"
            if [ "${files}" != "0" ]; then
                warn "/usr/local has been found, and contains ${files}+ file(s)"
            fi
        fi
    fi
    if [ ! -z "${DEBUGBUILD}" ]; then
        warn "Debug build is enabled."
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


retry () {
    retries="***"
    while [ ! -z "${retries}" ]; do
        if [ ! -z "$1" ]; then
            debug "$(${DATE_BIN} +%H%M%S-%s 2>/dev/null) retry('$@')[${retries}];"
            if [ ! -f "${LOG}" -o ! -d "${LOGS_DIR}" ]; then
                ${MKDIR_BIN} -p "${LOGS_DIR}"
            fi
            gitroot="$(${BASENAME_BIN} $(${BASENAME_BIN} ${GIT_BIN}))"
            eval PATH="/bin:/usr/bin:${gitroot}/bin:${gitroot}/libexec/git-core" "$@" >> "${LOG}" 2>&1 && \
            return 0
        else
            error "An empty command to retry?"
        fi
        retries="$(echo "${retries}" | ${SED_BIN} 's/\*//' 2>/dev/null)"
        debug "Retries left: ${retries}"
    done
    error "All retries exhausted for launch command: '$@'"
}


update_definitions () {
    if [ "${USE_UPDATE}" = "false" ]; then
        debug "Definitions update skipped on demand"
        return
    fi
    note "${SOFIN_HEADER}"
    if [ ! -x "${GIT_BIN}" ]; then
        note "Installing initial definition list from tarball to cache dir: ${cyan}${CACHE_DIR}"
        ${RM_BIN} -rf "${CACHE_DIR}definitions"
        ${MKDIR_BIN} -p "${LOGS_DIR}" "${CACHE_DIR}definitions"
        cd "${CACHE_DIR}definitions"
        INITIAL_DEFINITIONS="${MAIN_SOURCE_REPOSITORY}initial-definitions${DEFAULT_ARCHIVE_EXT}"
        debug "Fetching latest tarball with initial definitions from: ${INITIAL_DEFINITIONS}"
        retry "${FETCH_BIN} ${INITIAL_DEFINITIONS}" && \
        ${TAR_BIN} xf *${DEFAULT_ARCHIVE_EXT} && \
        ${RM_BIN} -vrf "$(${BASENAME_BIN} ${INITIAL_DEFINITIONS} 2>/dev/null)"
        return
    fi
    if [ -d "${CACHE_DIR}definitions/.git" -a -f "${DEFAULTS}" ]; then
        cd "${CACHE_DIR}definitions"
        current_branch="$(${GIT_BIN} rev-parse --abbrev-ref HEAD 2>/dev/null)"
        if [ "${current_branch}" != "${BRANCH}" ]; then # use current_branch value if branch isn't matching default branch
            debug "Checking out branch: ${current_branch}"
            ${GIT_BIN} checkout -b "${current_branch}" >> ${LOG} 2>&1 || \
                ${GIT_BIN} checkout "${current_branch}" >> ${LOG} 2>&1

            (retry "${GIT_BIN} pull origin ${current_branch}" && \
             note "Updated branch: ${cyan}${current_branch} ${green}of repository: ${cyan}${REPOSITORY}") || \
                error "Error occured: Update from branch: ${BRANCH} of repository: ${REPOSITORY} wasn't possible."

        else # else use default branch
            debug "Using default branch: ${BRANCH}"
            ${GIT_BIN} checkout -b "${BRANCH}" >> ${LOG} 2>&1 || \
                ${GIT_BIN} checkout "${BRANCH}" >> ${LOG} 2>&1

            (retry "${GIT_BIN} pull origin ${BRANCH}" && \
             note "Updated branch: ${cyan}${BRANCH} ${green}of repository: ${cyan}${REPOSITORY}") || \
                error "Error occured: Update from branch: ${BRANCH} of repository: ${REPOSITORY} wasn't possible."
        fi
    else
        # create cache; clone definitions repository:
        ${MKDIR_BIN} -p "${CACHE_DIR}"
        cd "${CACHE_DIR}"
        ${MKDIR_BIN} -p "${LOGS_DIR}"
        debug "Cloning repository: ${REPOSITORY} from branch: ${BRANCH}; LOGS_DIR: ${LOGS_DIR}, CACHE_DIR: ${CACHE_DIR}"
        ${RM_BIN} -rf definitions >> ${LOG} 2>&1 # if something is already here, wipe it out from cache
        retry "${GIT_BIN} clone ${REPOSITORY} definitions" || \
            error "Error occured: Cloning repository: ${REPOSITORY} isn't possible. Please make sure that given repository and branch are valid."
        cd "${CACHE_DIR}definitions"
        ${GIT_BIN} checkout -b "${BRANCH}" >> ${LOG} 2>&1
        retry "${GIT_BIN} pull origin ${BRANCH}" && \
        note "Updated branch: ${cyan}${BRANCH} ${green}of repository: ${cyan}${REPOSITORY}" || \
            error "Error occured: Update from branch: ${BRANCH} of repository: ${REPOSITORY} isn't possible. Please make sure that given repository and branch are valid."
    fi
}


create_cache_directories () {
    # check for regular cache dirs for existence:
    if [ ! -d "${CACHE_DIR}" -o \
         ! -d "${BINBUILDS_CACHE_DIR}" -o \
         ! -d "${LOGS_DIR}" ]; then
         ${MKDIR_BIN} -p "${CACHE_DIR}" "${BINBUILDS_CACHE_DIR}" "${LOGS_DIR}"
    fi
    if [ ! -d "${DEFINITIONS_DIR}" -o \
         ! -f "${DEFAULTS}" ]; then
        note "No valid definitions cache found. Creating a new cache in: ${cyan}${CACHE_DIR}"
        clean_purge
        update_definitions
    fi
}


write_info_about_shell_configuration () {
    warn "SHELL_PID is not set. Sofin auto-reload function is temporarely disabled."
}


usage_howto () {
    note "Built in tasks:"
    note "  ${cyan}install | get | pick | choose | use  ${gray}-${green} installs software from list or from definition and switches exports for it (example: ${SOFIN_ONLYNAME} install Rubinius)"
    note "  ${cyan}dependencies | deps | local          ${gray}-${green} installs software from list defined in '${DEPENDENCIES_FILE}' file in current directory"
    note "  ${cyan}uninstall | remove | delete          ${gray}-${green} removes an application or list (example: ${SOFIN_ONLYNAME} uninstall Rubinius)"
    note "  ${cyan}list | installed                     ${gray}-${green} gives short list of installed software"
    note "  ${cyan}fulllist | fullinstalled             ${gray}-${green} gives detailed list with installed software including requirements"
    note "  ${cyan}available                            ${gray}-${green} lists available software"
    note "  ${cyan}export | exp | exportapp             ${gray}-${green} adds given command to application exports (example: ${SOFIN_ONLYNAME} export rails Rubinius)"
    note "  ${cyan}getshellvars | shellvars | vars      ${gray}-${green} returns shell variables for installed software"
    note "  ${cyan}log                                  ${gray}-${green} shows and watches log file (for debug messages and verbose info)"
    note "  ${cyan}reload | rehash                      ${gray}-${green} recreates shell vars and reloads current shell"
    note "  ${cyan}update                               ${gray}-${green} only update definitions from remote repository and exit"
    note "  ${cyan}ver | version                        ${gray}-${green} shows ${SOFIN_ONLYNAME} script version"
    note "  ${cyan}clean                                ${gray}-${green} cleans binbuilds cache, unpacked source content and logs"
    note "  ${cyan}distclean                            ${gray}-${green} cleans binbuilds cache, unpacked source content, logs and definitions"
    note "  ${cyan}purge                                ${gray}-${green} cleans binbuilds cache, unpacked source content, logs, definitions, source cache and possible states"
    note "  ${cyan}outdated                             ${gray}-${green} lists outdated software"
    note "  ${cyan}build                                ${gray}-${green} does binary build from source for software specified as params"
    note "  ${cyan}continue Bundlename                  ${gray}-${green} continues build from \"make stage\" of bundle name, given as param (previous build dir reused)"
    note "  ${cyan}deploy                               ${gray}-${green} build + push"
    note "  ${cyan}push | binpush | send                ${gray}-${green} creates binary build from prebuilt software bundles name given as params (example: ${SOFIN_ONLYNAME} push Rubinius Vifm Curl)"
    note "  ${cyan}wipe                                 ${gray}-${green} wipes binary builds (matching given name) from binary respositories (example: ${SOFIN_ONLYNAME} wipe Rubinius Vifm)"
    note "  ${cyan}port                                 ${gray}-${green} gathers port of ServeD running service by service name"
    note "  ${cyan}enable                               ${gray}-${green} enables Sofin developer environment (full environment stored in ~/.profile). It's the default"
    note "  ${cyan}disable                              ${gray}-${green} disables Sofin developer environment (only PATH, PKG_CONFIG_PATH and MANPATH written to ~/.profile)"
    note "  ${cyan}status                               ${gray}-${green} shows Sofin status"
    note "  ${cyan}dev                                  ${gray}-${green} puts definition content on the fly. Second argument is (lowercase) definition name (no extension). (example: sofin dev rubinius)"
    note "  ${cyan}rebuild                              ${gray}-${green} rebuilds and pushes each software bundle that depends on definition given as a param. (example: ${SOFIN_ONLYNAME} rebuild openssl - will rebuild all bundles that have 'openssl' dependency)"
    note "  ${cyan}reset                               ${gray}-${green} resets local definitions repository"

    exit
}


update_shell_vars () {
    # TODO: consider filtering debug messages to enable debug statements in early sofin code: | ${GREP_BIN} -v 'DEBUG:?'
    if [ "${USERNAME}" = "root" ]; then
        debug "Updating ${SOFIN_PROFILE} settings."
        ${PRINTF_BIN} "$(${SOFIN_BIN} getshellvars 2>/dev/null)" > "${SOFIN_PROFILE}" 2>/dev/null
    else
        debug "Updating ${HOME}/.profile settings."
        ${PRINTF_BIN} "$(${SOFIN_BIN} getshellvars ${USERNAME} 2>/dev/null)" > "${HOME}/.profile" 2>/dev/null
    fi
}


check_disabled () {
    # check requirement for disabled state:
    export ALLOW="1"
    if [ ! "$1" = "" ]; then
        for disabled in ${1}; do
            debug "Running system: ${SYSTEM_NAME}; disable_on element: ${disabled}"
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


clean_binbuilds () {
    if [ -d "${BINBUILDS_CACHE_DIR}" ]; then
        note "Removing binary builds from: ${cyan}${BINBUILDS_CACHE_DIR}"
        ${RM_BIN} -rf "${BINBUILDS_CACHE_DIR}" || warn "Privileges problem in '${BINBUILDS_CACHE_DIR}'? All files should belong to '${USER}' there."
    fi
}


clean_failbuilds () {
    if [ -d "${CACHE_DIR}cache" ]; then
        number="0"
        files=$(${FIND_BIN} "${CACHE_DIR}cache" -maxdepth 2 -mindepth 1 -type d 2>/dev/null)
        num="$(echo "${files}" | eval ${FILES_COUNT_GUARD})"
        if [ ! -z "${num}" ]; then
            number="${number} + ${num} - 1"
        fi
        for i in ${files}; do
            debug "Removing directory: ${i}"
            ${RM_BIN} -rf "${i}" 2>/dev/null || warn "Privileges problem in failbuilds dir: '${i}'? All files should belong to '${USER}' there."
        done
        result="$(echo "${number}" | ${BC_BIN} 2>/dev/null)"
        note "${cyan}${result} ${green}directories cleaned."
    fi
}


clean_logs () {
    if [ -d "${LOGS_DIR}" ]; then
        note "Removing build logs from: ${cyan}${LOGS_DIR}"
        ${RM_BIN} -rf "${LOGS_DIR}" 2>/dev/null || warn "Privileges problem in logs dir: '${LOGS_DIR}'? All files should belong to '${USER}' there."
    fi
}


clean_purge () {
    if [ -d "${CACHE_DIR}" ]; then
        note "Purging all caches from: ${cyan}${CACHE_DIR}"
        ${RM_BIN} -rf "${CACHE_DIR}" 2>/dev/null || warn "Privileges problem in cache dir: '${CACHE_DIR}'? All files should belong to '${USER}' there."
    fi
}


perform_clean () {
    case "$1" in
        purge) # purge
            clean_purge
            ;;

        dist) # distclean
            note "Dist cleaning.."
            clean_logs
            clean_binbuilds
            clean_failbuilds
            ;;

        *) # clean
            clean_failbuilds
            ;;
    esac
    create_cache_directories
    exit
}


if [ ! "$1" = "" ]; then
    case $1 in

    dev)
        create_cache_directories
        note "Paste your definition below. Hit ctrl-d after a newline to commit"
        ${CAT_BIN} > ${DEFINITIONS_DIR}/${2}.def
        exit
        ;;


    p|port)
        # support for ServeD /Services:
        app="$2"
        if [ "$app" = "" ]; then
            error "Must specify service name!"
        fi

        # user_app_dir="${SERVICES_DIR}${app}"
        # user_port_file="${user_app_dir}/.ports/0"
        # if [ "${USERNAME}" = "root" ]; then
        #     user_app_dir="${SERVICES_DIR}${app}"
        #     user_port_file="${user_app_dir}/.ports/0"
        # fi
        # if [ -f "${user_port_file}" ]; then
        #     printf "$(${CAT_BIN} ${user_port_file})\n"
        # else

        error "Not implemented (for now)"
        ;;


    ver|version)
        note "${SOFIN_HEADER}"
        exit
        ;;


    log)
        create_cache_directories
        shift
        pattern="$*"
        if [ "${pattern}" = "-" -o "${pattern}" = "sofin" ]; then
            ${TAIL_BIN} -n ${LOG_LINES_AMOUNT} -F ${LOG}
        elif [ "${pattern}" = "" ]; then
            ${TAIL_BIN} -n ${LOG_LINES_AMOUNT} -F ${LOG}*
        else
            note "Seeking log files.."
            log_helper () {
                files=$(${FIND_BIN} ${CACHE_DIR}logs -type f -iname "sofin*${pattern}*" 2>/dev/null)
                num="$(echo "${files}" | eval ${FILES_COUNT_GUARD})"
                if [ -z "${num}" ]; then
                    num="0"
                fi
                if [ -z "${files}" ]; then
                    ${SLEEP_BIN} 2
                    log_helper
                else
                    case ${num} in
                        0)
                            ${SLEEP_BIN} 2
                            log_helper
                            ;;

                        1)
                            note "Found ${cyan}${num}${green} log file, that matches pattern: ${cyan}${pattern}${green}. Attaching tail.."
                            ${TAIL_BIN} -n ${LOG_LINES_AMOUNT} -F ${files}
                            ;;

                        *)
                            note "Found ${cyan}${num}${green} log files, that match pattern: ${cyan}${pattern}${green}. Attaching tails.."
                            ${TAIL_BIN} -n ${LOG_LINES_AMOUNT} -F ${files}
                            ;;
                    esac
                fi
            }
            log_helper
        fi
        exit
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


    stat|status)
        if [ -f ${SOFIN_DISABLED_INDICATOR_FILE} ]; then
            note "Sofin shell environment is: ${red}disabled${reset}"
        else
            note "Sofin shell environment is: ${cyan}enabled${reset}"
        fi
        exit
        ;;


    l|installed|list)
        debug "Listing installed software alphabetically:"
        if [ -d ${SOFTWARE_DIR} ]; then
            ${FIND_BIN} ${SOFTWARE_DIR} -maxdepth 1 -mindepth 1 -type d  -not -name ".*" -print 2>/dev/null | ${XARGS_BIN} ${BASENAME_BIN} 2>/dev/null | ${SORT_BIN} 2>/dev/null
        fi
        exit
        ;;


    f|fullinstalled|fulllist|full)
        note "Installed applications (with dependencies):"
        if [ -d ${SOFTWARE_DIR} ]; then
            for app in ${SOFTWARE_DIR}*; do
                note
                app_name="$(${BASENAME_BIN} ${app} 2>/dev/null)"
                lowercase="$(${PRINTF_BIN} "${app_name}" | ${TR_BIN} '[A-Z]' '[a-z]' 2>/dev/null)"
                installed_file="${SOFTWARE_DIR}/${app_name}/${lowercase}${INSTALLED_MARK}"
                if [ -e "${installed_file}" ]; then
                    note "${SUCCESS_CHAR} ${app_name}"
                else
                    note "${red}${ERROR_CHAR} ${app_name} ${reset}[${red}!${reset}]"
                fi
                for req in $(${FIND_BIN} ${app} -maxdepth 1 -name *${INSTALLED_MARK} 2>/dev/null | ${SORT_BIN} 2>/dev/null); do
                    pp="$(${PRINTF_BIN} "$(${BASENAME_BIN} ${req} 2>/dev/null)" | ${SED_BIN} "s/${INSTALLED_MARK}//" 2>/dev/null)"
                    note "   ${NOTE_CHAR2} ${green}${pp} ${reset}[${cyan}$(${CAT_BIN} ${req} 2>/dev/null)${reset}]"
                done
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
        A_CC="$(echo "${CC}" | ${SED_BIN} 's/ //' 2>/dev/null)"
        A_CXX="$(echo "${CXX}" | ${SED_BIN} 's/ //' 2>/dev/null)"
        ${PRINTF_BIN} "# CC:\nexport CC='${A_CC}'\n\n"
        ${PRINTF_BIN} "# CXX:\nexport CXX='${A_CXX}'\n\n"
        ${PRINTF_BIN} "# CPP:\nexport CPP='${CPP}'\n\n"

        if [ -f "${SOFIN_DISABLED_INDICATOR_FILE}" ]; then # sofin disabled. Default system environment
            ${PRINTF_BIN} "# PATH:\nexport PATH=${result}\n\n"
            ${PRINTF_BIN} "# CFLAGS:\nexport CFLAGS=''\n\n"
            ${PRINTF_BIN} "# CXXFLAGS:\nexport CXXFLAGS=''\n\n"
            if [ "${SYSTEM_NAME}" = "Darwin" ]; then
                ${PRINTF_BIN} "# LDFLAGS:\nexport LDFLAGS=''\n\n"
                ${PRINTF_BIN} "# PKG_CONFIG_PATH:\nexport PKG_CONFIG_PATH='${pkg_config_path}'\n\n" # commented out: :/opt/X11/lib/pkgconfig
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
                ${PRINTF_BIN} "# PKG_CONFIG_PATH:\nexport PKG_CONFIG_PATH='${pkg_config_path}'\n\n" # commented out: :/opt/X11/lib/pkgconfig
            else
                ${PRINTF_BIN} "# LDFLAGS:\nexport LDFLAGS='${ldflags} -Wl,--enable-new-dtags'\n\n"
                ${PRINTF_BIN} "# PKG_CONFIG_PATH:\nexport PKG_CONFIG_PATH='${pkg_config_path}'\n\n"
            fi
            ${PRINTF_BIN} "# MANPATH:\nexport MANPATH='${manpath}'\n\n"
        fi
        exit
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
        note "Found most recent build dir: ${cyan}${a_build_dir}${green} for bundle: ${cyan}${a_bundle_name}${green}"
        note "Resuming interrupted build.."
        export APPLICATIONS="${a_bundle_name}"
        export PREVIOUS_BUILD_DIR="${MOST_RECENT_DIR}"
        export SOFIN_CONTINUE_BUILD="YES"
        ;;


    i|install|get|pick|choose|use|switch)
        create_cache_directories
        if [ "$2" = "" ]; then
            error "For \"$1\" application installation mode, second argument with at least one application name or list is required!"
        fi

        # try a list - it will have priority if file exists:
        if [ -f "${LISTS_DIR}${2}" ]; then
            export APPLICATIONS="$(${CAT_BIN} ${LISTS_DIR}${2} 2>/dev/null | ${TR_BIN} '\n' ' ' 2>/dev/null)"
            note "Processing software: ${cyan}${APPLICATIONS} ${green}for architecture: ${cyan}${SYSTEM_ARCH}"
        else
            export APPLICATIONS="${SOFIN_ARGS}"
            note "Processing software: ${cyan}${SOFIN_ARGS} ${green}for architecture: ${cyan}${SYSTEM_ARCH}"
        fi
        ;;


    deps|dependencies|local)
        create_cache_directories
        if [ "${USERNAME}" = "root" ]; then
            warn "Installation of project dependencies as root is immoral"
        fi
        note "Looking for a dependencies list file: ${cyan}${DEPENDENCIES_FILE}${green} in current directory"
        if [ ! -e "./${DEPENDENCIES_FILE}" ]; then
            error "Dependencies file not found!"
        fi
        export APPLICATIONS="$(${CAT_BIN} ./${DEPENDENCIES_FILE} 2>/dev/null | ${TR_BIN} '\n' ' ' 2>/dev/null)"
        note "Installing dependencies: ${cyan}${APPLICATIONS}"
        ;;


    p|push|binpush|send)
        create_cache_directories
        note "Preparing to push binary bundle: ${cyan}${SOFIN_ARGS}${green} from ${cyan}${SOFTWARE_DIR}${green} to binary repository."
        cd "${SOFTWARE_DIR}"
        for element in ${SOFIN_ARGS}; do
            if [ -d "${element}" ]; then
                if [ ! -L "${element}" ]; then
                    lowercase_element="$(${PRINTF_BIN} "${element}" | ${TR_BIN} '[A-Z]' '[a-z]' 2>/dev/null)"
                    version_element="$(${CAT_BIN} ${element}/${lowercase_element}${INSTALLED_MARK} 2>/dev/null)"
                    name="${element}-${version_element}${DEFAULT_ARCHIVE_EXT}"
                    dig_query="$(${DIG_BIN} +short ${MAIN_SOFTWARE_ADDRESS} A 2>/dev/null)"
                    if [ ${OS_VERSION} -gt 93 ]; then
                        # In FreeBSD 10 there's drill utility instead of dig
                        dig_query=$(${DIG_BIN} A ${MAIN_SOFTWARE_ADDRESS} 2>/dev/null | ${GREP_BIN} "^${MAIN_SOFTWARE_ADDRESS}" 2>/dev/null | ${AWK_BIN} '{print $5;}' 2>/dev/null)
                    fi
                    if [ -z "${dig_query}" ]; then
                        error "No mirrors found in address: ${MAIN_SOFTWARE_ADDRESS}"
                    fi
                    debug "MIRROR: ${dig_query}"
                    for mirror in ${dig_query}; do
                        SYS="${SYSTEM_NAME}-${FULL_SYSTEM_VERSION}-${SYSTEM_ARCH}"
                        system_path="${MAIN_SOFTWARE_PREFIX}/software/binary/${SYS}"
                        address="${MAIN_USER}@${mirror}:${system_path}"
                        def_error () {
                            error "Error sending ${1} to ${address}/${1}"
                        }
                        aname="$(echo "${APP_NAME}${APP_POSTFIX}" | ${TR_BIN} '[A-Z]' '[a-z]' 2>/dev/null)"
                        ${SSH_BIN} -p ${MAIN_PORT} ${MAIN_USER}@${mirror} "mkdir -p ${MAIN_SOFTWARE_PREFIX}/software/binary/${SYS}" >> "${LOG}-${aname}" 2>&1

                        if [ "${SYSTEM_NAME}" = "FreeBSD" ]; then # NOTE: feature designed for FBSD.
                            note "Preparing service dataset for: ${cyan}${element}"
                            svcs_no_slashes="$(echo "${SERVICES_DIR}" | ${SED_BIN} 's/\///g' 2>/dev/null)"
                            inner_dir="$(${ZFS_BIN} list -H 2>/dev/null | ${GREP_BIN} "${element}$" 2>/dev/null | ${AWK_BIN} '{print $1;}' 2>/dev/null | ${SED_BIN} "s/.*${svcs_no_slashes}\///; s/\/.*//" 2>/dev/null)/"
                            certain_dataset="${SERVICES_DIR}${inner_dir}${element}"
                            full_dataset_name="${DEFAULT_ZPOOL}${certain_dataset}"
                            snap_file="${element}-${version_element}.${SERVICE_SNAPSHOT_POSTFIX}"
                            final_snap_file="${snap_file}${DEFAULT_ARCHIVE_EXT}"
                            snap_size="0"
                            ${ZFS_BIN} list -H 2>/dev/null | ${GREP_BIN} "${element}$" >/dev/null 2>&1
                            if [ "$?" = "0" ]; then # if dataset exists, unmount it, send to file, and remount back
                                ${ZFS_BIN} umount ${full_dataset_name} || error "ZFS umount ${full_dataset_name}. Dataset busy on build host? Not good :)"
                                ${ZFS_BIN} send ${full_dataset_name} | ${XZ_BIN} > ${final_snap_file} && \
                                snap_size="$(${STAT_BIN} -f%z "${final_snap_file}" 2>/dev/null)" && \
                                ${ZFS_BIN} mount ${full_dataset_name} && \
                                note "Stream sent successfully to: ${cyan}${final_snap_file}"
                            fi
                            if [ "${snap_size}" = "0" ]; then
                                ${RM_BIN} -f "${final_snap_file}"
                                note "Initial dataset for service: ${cyan}${element}-${version_element}${green} is unavailable"
                            fi
                        fi

                        note "Preparing ${cyan}${element}${green} archives.."
                        if [ ! -e "./${name}" ]; then
                            ${TAR_BIN} -cJf "${name}" "./${element}"
                        else
                            if [ ! -e "./${name}.sha1" ]; then
                                note "No sha1 file found. Existing archive may be incomplete or damaged. Rebuilding.."
                                ${RM_BIN} -f "${name}"
                                ${TAR_BIN} -cJf "${name}" "./${element}"
                            else
                                note "Archive already exists. Skipping archive preparation for: ${cyan}${name}"
                            fi
                        fi

                        archive_sha1="NO-SHA"
                        case "${SYSTEM_NAME}" in
                            Darwin|Linux)
                                archive_sha1="$(${SHA_BIN} "${name}" 2>/dev/null | ${AWK_BIN} '{print $1;}' 2>/dev/null)"
                                ;;

                            FreeBSD)
                                archive_sha1="$(${SHA_BIN} -q "${name}" 2>/dev/null)"
                                ;;
                        esac

                        ${PRINTF_BIN} "${archive_sha1}" > "${name}.sha1"
                        debug "Setting common access to archive files before we send them: ${name}, ${name}.sha1"
                        ${CHMOD_BIN} a+r "${name}" "${name}.sha1"

                        note "Pushing archive #${cyan}${archive_sha1}${green} to remote: ${cyan}${MAIN_BINARY_REPOSITORY}${SYS}/${name}"
                        retry "${SCP_BIN} -P ${MAIN_PORT} ${name} ${address}/${name}.partial" || def_error ${name}
                        if [ "$?" = "0" ]; then
                            ${SSH_BIN} -p ${MAIN_PORT} ${MAIN_USER}@${mirror} "cd ${MAIN_SOFTWARE_PREFIX}/software/binary/${SYS} && mv ${name}.partial ${name}"
                            retry "${SCP_BIN} -P ${MAIN_PORT} ${name}.sha1 ${address}/${name}.sha1" || def_error ${name}.sha1
                        else
                            error "Failed to push binary build of: '${name}' to remote: ${MAIN_BINARY_REPOSITORY}${SYS}/${name}"
                        fi

                        if [ "${SYSTEM_NAME}" = "FreeBSD" ]; then # NOTE: feature designed for FBSD.
                            if [ -f "${final_snap_file}" ]; then
                                system_path="${MAIN_SOFTWARE_PREFIX}/software/binary/${MAIN_COMMON_NAME}"
                                address="${MAIN_USER}@${mirror}:${system_path}"

                                ${SSH_BIN} -p ${MAIN_PORT} ${MAIN_USER}@${mirror} "cd ${MAIN_SOFTWARE_PREFIX}/software/binary; mkdir -p ${MAIN_COMMON_NAME} ; chmod 755 ${MAIN_COMMON_NAME}"

                                debug "Setting common access to archive files before we send it: ${final_snap_file}"
                                ${CHMOD_BIN} a+r "${final_snap_file}"
                                debug "Sending initial service stream to ${MAIN_COMMON_NAME} repository: ${MAIN_BINARY_REPOSITORY}${MAIN_COMMON_NAME}/${final_snap_file}"

                                retry "${SCP_BIN} -P ${MAIN_PORT} ${final_snap_file} ${address}/${final_snap_file}.partial" || def_error ${final_snap_file}
                                if [ "$?" = "0" ]; then
                                    ${SSH_BIN} -p ${MAIN_PORT} ${MAIN_USER}@${mirror} "cd ${MAIN_SOFTWARE_PREFIX}/software/binary/${MAIN_COMMON_NAME} && mv ${final_snap_file}.partial ${final_snap_file}"
                                else
                                    error "Failed to send service snapshot archive to remote!"
                                fi
                            else
                                note "No service stream available for: ${cyan}${element}"
                            fi
                        fi
                    done
                    ${RM_BIN} -f "${name}" "${name}.sha1" "${final_snap_file}"
                fi
            else
                warn "Not found software named: ${element}!"
            fi
        done
        exit
        ;;

    b|build)
        create_cache_directories
        shift
        dependencies="$*"
        note "Software bundles to be built: ${cyan}${dependencies}"
        def_error () {
            error "Failure in definition: ${cyan}${software}${red}. Report or fix the definition please!"
        }
        for dep in ${dependencies}; do
            sofin_ps_list="$(${PS_BIN} axv 2>/dev/null | ${GREP_BIN} -v grep 2>/dev/null | ${EGREP_BIN} "sh ${SOFIN_BIN} (${ALL_INSTALL_PHRASES}|${BUILD_AND_DEPLOY_PHRASES}) ${dep}" 2>/dev/null)"
            sofins_all="$(echo "${sofin_ps_list}" | ${WC_BIN} -l 2>/dev/null | ${SED_BIN} 's/ //g' 2>/dev/null)"
            test ${sofins_all} -gt 2 && error "Bundle: ${cyan}${dep}${green} is in a middle of build process in background! Aborting."
        done
        # update_definitions
        USE_UPDATE=false USE_BINBUILD=false ${SOFIN_BIN} install ${dependencies} || def_error
        exit
        ;;


    d|deploy)
        create_cache_directories
        shift
        dependencies="$*"
        note "Software bundles to be built and deployed to remote: ${cyan}${dependencies}"
        def_error () {
            error "Failure in definition: ${cyan}${software}${red}. Report or fix the definition please!"
        }
        for dep in ${dependencies}; do
            sofin_ps_list="$(${PS_BIN} axv 2>/dev/null | ${GREP_BIN} -v grep 2>/dev/null | ${EGREP_BIN} "sh ${SOFIN_BIN} (${ALL_INSTALL_PHRASES}|${BUILD_AND_DEPLOY_PHRASES}) ${dep}" 2>/dev/null)"
            sofins_all="$(echo "${sofin_ps_list}" | ${WC_BIN} -l 2>/dev/null | ${SED_BIN} 's/ //g' 2>/dev/null)"
            test ${sofins_all} -gt 2 && error "Bundle: ${dep} is in a middle of build process in background! Aborting."
        done
        # update_definitions
        for software in ${dependencies}; do
            USE_BINBUILD=false ${SOFIN_BIN} install ${software} || def_error && \
            ${SOFIN_BIN} push ${software} || def_error && \
            note "Software bundle deployed successfully: ${cyan}${software}"
            note "______________________________________________________________"
        done
        exit 0
        ;;


    reset)
        create_cache_directories
        cd ${DEFINITIONS_DIR}
        ${GIT_BIN} reset --hard
        update_definitions
        exit 0
        ;;

    rebuild)
        create_cache_directories
        if [ "$2" = "" ]; then
            error "Missing second argument with library/software name."
        fi
        dependency="$2"

        # go to definitions dir, and gather software list that include given dependency:
        all_defs="$(${FIND_BIN} ${DEFINITIONS_DIR} -maxdepth 1 -type f -name '*.def' 2>/dev/null)"
        to_rebuild=""
        for deps in ${all_defs}; do
            . ${DEFAULTS}
            . ${deps}
            echo "${APP_REQUIREMENTS}" | ${GREP_BIN} "${dependency}" >/dev/null 2>&1
            if [ "$?" = "0" ]; then
                dep="$(${BASENAME_BIN} "${deps}" 2>/dev/null)"
                rawname="$(${PRINTF_BIN} "${dep}" | ${SED_BIN} 's/\.def//g' 2>/dev/null)"
                app_name="$(${PRINTF_BIN} "${rawname}" | ${CUT_BIN} -c1 2>/dev/null | ${TR_BIN} '[a-z]' '[A-Z]' 2>/dev/null)$(${PRINTF_BIN} "${rawname}" | ${SED_BIN} 's/^[a-zA-Z]//' 2>/dev/null)"
                to_rebuild="${app_name} ${to_rebuild}"
            fi
        done

        def_error () {
            error "Failure in definition: ${software}. Report or fix the definition please!"
        }

        note "Will rebuild, wipe and push these bundles: ${cyan}${to_rebuild}"
        for software in ${to_rebuild}; do
            if [ "${software}" = "Git" -o "${software}" = "Zsh" -o "${software}" = "Rsync" -o "${software}" = "Rsync-static" ]; then
                continue
            fi
            ${SOFIN_BIN} remove ${software}
            USE_BINBUILD=false ${SOFIN_BIN} install ${software} || def_error
            FORCE=true ${SOFIN_BIN} wipe ${software} || def_error
            ${SOFIN_BIN} push ${software} || def_error
        done
        exit
        ;;


    wipe)
        ANS="YES"
        if [ "${FORCE}" != "true" ]; then
            note "Are you sure you want to wipe binary bundles: ${cyan}${SOFIN_ARGS} ${green}from binary repository: ${cyan}${MAIN_BINARY_REPOSITORY}${green}? (YES to confirm)"
            read ANS
        fi
        if [ "${ANS}" = "YES" ]; then
            cd "${SOFTWARE_DIR}"
            for element in ${SOFIN_ARGS}; do
                lowercase_element="$(${PRINTF_BIN} "${element}" | ${TR_BIN} '[A-Z]' '[a-z]' 2>/dev/null)"
                name="${element}-"
                dig_query="$(${DIG_BIN} +short ${MAIN_SOFTWARE_ADDRESS} A 2>/dev/null)"
                if [ ${OS_VERSION} -gt 93 ]; then
                    # In FreeBSD 10 there's drill utility instead of dig
                    dig_query=$(${DIG_BIN} A ${MAIN_SOFTWARE_ADDRESS} 2>/dev/null | ${GREP_BIN} "^${MAIN_SOFTWARE_ADDRESS}" 2>/dev/null | ${AWK_BIN} '{print $5;}' 2>/dev/null)
                fi
                debug "MIRROR: ${dig_query}"
                for mirror in ${dig_query}; do
                    SYS="${SYSTEM_NAME}-${FULL_SYSTEM_VERSION}-${SYSTEM_ARCH}"
                    system_path="${MAIN_SOFTWARE_PREFIX}/software/binary/${SYS}"
                    note "Wiping out remote: ${cyan}${mirror} ${green}binary archives: ${cyan}${name}*"
                    ${SSH_BIN} -p ${MAIN_PORT} ${MAIN_USER}@${mirror} "${RM_BIN} -f ${system_path}/${name}* ${system_path}/${name}.sha1" >> "${LOG}" 2>&1
                done
            done
        else
            note "Aborted."
        fi
        exit
        ;;


    delete|remove|uninstall|rm)
        if [ "$2" = "" ]; then
            error "For \"$1\" task, second argument with application name is required!"
        fi

        # first look for a list with that name:
        if [ -e "${LISTS_DIR}${2}" ]; then
            export APPLICATIONS="$(${CAT_BIN} ${LISTS_DIR}${2} 2>/dev/null | ${TR_BIN} '\n' ' ' 2>/dev/null)"
            debug "Removing list of applications: ${APPLICATIONS}"
        else
            export APPLICATIONS="${SOFIN_ARGS}"
            debug "Removing applications: ${APPLICATIONS}"
        fi

        for app in $APPLICATIONS; do
            given_app_name="$(${PRINTF_BIN} "${app}" | ${CUT_BIN} -c1 2>/dev/null | ${TR_BIN} '[a-z]' '[A-Z]' 2>/dev/null)$(${PRINTF_BIN} "${app}" | ${SED_BIN} 's/^[a-zA-Z]//' 2>/dev/null)"
            if [ -d "${SOFTWARE_DIR}${given_app_name}" ]; then
                if [ "${given_app_name}" = "/" ]; then
                    error "Czy Ty orzeszki?"
                fi
                note "Removing software bundle: ${cyan}${given_app_name}"
                aname="$(echo "${APP_NAME}${APP_POSTFIX}" | ${TR_BIN} '[A-Z]' '[a-z]' 2>/dev/null)"
                ${RM_BIN} -rfv "${SOFTWARE_DIR}${given_app_name}" >> "${LOG}-${aname}"

                debug "Looking for other installed versions that might be exported automatically.."
                name="$(echo "${given_app_name}" | ${SED_BIN} 's/[0-9]*//g' 2>/dev/null)"
                alternative="$(${FIND_BIN} ${SOFTWARE_DIR} -maxdepth 1 -name "${name}*" -not -name "${given_app_name}" 2>/dev/null | ${SED_BIN} 's/^.*\///g' 2>/dev/null | ${HEAD_BIN} -n1 2>/dev/null)"
                alt_lower="$(echo "${alternative}" | ${TR_BIN} '[A-Z]' '[a-z]' 2>/dev/null)"
                debug "Alternative: ${alternative}, Given: ${given_app_name}, Alt_lower: ${alt_lower}, full: ${SOFTWARE_DIR}${alternative}/${alt_lower}${INSTALLED_MARK}"
                if [ ! -z "${alternative}" -a -f "${SOFTWARE_DIR}${alternative}/${alt_lower}${INSTALLED_MARK}" ]; then
                    note "Automatically picking first alternative already installed: ${cyan}${alternative}"
                    export APPLICATIONS="${alternative}"
                    continue
                elif [ -z "${alternative}" ]; then
                    debug "No alternative: ${alternative} != ${given_app_name}"
                    export APPLICATIONS=""
                    continue
                fi
            else
                warn "Application: ${cyan}${given_app_name} ${yellow}not installed."
                export APPLICATIONS=""
                continue
            fi
        done
        ;;


    reload|rehash)
        if [ ! -z "${SHELL_PID}" ]; then
            update_shell_vars
            pids=$(${PS_BIN} ax 2>/dev/null | ${GREP_BIN} -v grep 2>/dev/null | ${GREP_BIN} zsh 2>/dev/null | ${AWK_BIN} '{print $1;}' 2>/dev/null)
            note "Reloading configuration of all ${cyan}$(${BASENAME_BIN} "${SHELL}" 2>/dev/null) ${green}with pids: $(echo ${pids} | ${TR_BIN} '\n' ' ' 2>/dev/null)"
            for pid in ${pids}; do
                ${KILL_BIN} -SIGUSR2 ${pid}
            done
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


    avail|available)
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
        APP="$(${PRINTF_BIN} "${3}" | ${CUT_BIN} -c1 2>/dev/null | ${TR_BIN} '[a-z]' '[A-Z]' 2>/dev/null)$(${PRINTF_BIN} "${3}" | ${SED_BIN} 's/^[a-zA-Z]//' 2>/dev/null)"

        for dir in "/bin/" "/sbin/" "/libexec/"; do
            debug "Testing ${dir} looking into: ${SOFTWARE_DIR}${APP}${dir}"
            if [ -e "${SOFTWARE_DIR}${APP}${dir}${EXPORT}" ]; then
                note "Exporting binary: ${cyan}${SOFTWARE_DIR}${APP}${dir}${EXPORT}"
                cd "${SOFTWARE_DIR}${APP}${dir}"
                ${MKDIR_BIN} -p "${SOFTWARE_DIR}${APP}/exports" # make sure exports dir already exists
                aname="$(echo "${APP}" | ${TR_BIN} '[A-Z]' '[a-z]' 2>/dev/null)"
                ${LN_BIN} -vfs "..${dir}/${EXPORT}" "../exports/${EXPORT}" >> "${LOG}-${aname}"
                exit
            else
                debug "Not found: ${SOFTWARE_DIR}${APP}${dir}${EXPORT}"
            fi
        done
        exit 1
        ;;


    old|outdated)
        create_cache_directories
        # update_definitions
        note "Definitions were updated to latest version."
        debug "Checking software from ${SOFTWARE_DIR}"
        if [ -d ${SOFTWARE_DIR} ]; then
            for prefix in ${SOFTWARE_DIR}*; do
                debug "Looking into: ${prefix}"
                application="$(${BASENAME_BIN} "${prefix}" 2>/dev/null | ${TR_BIN} '[A-Z]' '[a-z]' 2>/dev/null)" # lowercase for case sensitive fs

                if [ ! -f "${prefix}/${application}${INSTALLED_MARK}" ]; then
                    warn "Application: ${application} is not properly installed."
                    continue
                fi
                ver="$(${CAT_BIN} "${prefix}/${application}${INSTALLED_MARK}" 2>/dev/null)"

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
    specified="${application}" # store original value of user input
    application="$(${PRINTF_BIN} "${application}" | ${TR_BIN} '[A-Z]' '[a-z]' 2>/dev/null)" # lowercase for case sensitive fs
    . "${DEFAULTS}"
    if [ ! -f "${DEFINITIONS_DIR}${application}.def" ]; then
        contents=""
        maybe_version="$(${FIND_BIN} ${DEFINITIONS_DIR} -maxdepth 1 -name ${application}\*.def 2>/dev/null)"
        for maybe in ${maybe_version}; do
            elem="$(${BASENAME_BIN} ${maybe} 2>/dev/null)"
            head="$(echo "${elem}" | ${SED_BIN} 's/\(.\)\(.*\)/\1/' 2>/dev/null | ${TR_BIN} '[a-z]' '[A-Z]' 2>/dev/null)"
            tail="$(echo "${elem}" | ${SED_BIN} 's/\(.\)\(.*\)/\2/' 2>/dev/null)"
            contents="${contents}$(echo "${head}${tail}" | ${SED_BIN} 's/\..*//' 2>/dev/null) "
        done
        if [ "${contents}" != "" ]; then
            warn "No such definition found: ${application}. Alternatives found: ${contents}"
        else
            warn "No such definition found: ${application}. No alternatives found."
        fi
        exit
    fi
    . "${DEFINITIONS_DIR}${application}.def" # prevent installation of requirements of disabled application:
    check_disabled "${DISABLE_ON}" # after which just check if it's not disabled
    if [ ! "${ALLOW}" = "1" ]; then
        warn "Software: ${application} disabled on architecture: ${SYSTEM_NAME}-${FULL_SYSTEM_VERSION}-${SYSTEM_ARCH}"
        ${RM_BIN} -rf "${PREFIX}"
    else
        for definition in ${DEFINITIONS_DIR}${application}.def; do
            export DONT_BUILD_BUT_DO_EXPORTS=""
            debug "Reading definition: ${definition}"
            . "${DEFAULTS}"
            . "${definition}"
            check_disabled "${DISABLE_ON}" # after which just check if it's not disabled

            # export APP_POSTFIX="$(echo "${APP_VERSION}" | ${SED_BIN} 's/\.[0-9]*$//;s/\.//')"

            APP_LOWER="${APP_NAME}"
            head="$(echo "${APP_NAME}" | ${SED_BIN} 's/\(.\)\(.*\)/\1/' 2>/dev/null | ${TR_BIN} '[a-z]' '[A-Z]' 2>/dev/null)"
            tail="$(echo "${APP_NAME}" | ${SED_BIN} 's/\(.\)\(.*\)/\2/' 2>/dev/null)"
            # Capitalize:
            APP_NAME="${head}${tail}"
            # some additional convention check:
            if [ "${APP_NAME}" != "${specified}" -a "${APP_NAME}${APP_POSTFIX}" != "${specified}" ]; then
                warn "You specified lowercase name of bundle, which is in contradiction to Sofin's convention (bundle - capitalized: f.e. \"Rubinius\", dependencies and definitions - lowercase: f.e. \"yaml\")."
            fi
            # if definition requires root privileges, throw an "exception":
            if [ "${REQUIRE_ROOT_ACCESS}" = "true" ]; then
                if [ "${USERNAME}" != "root" ]; then
                    warn "Definition requires root priviledges to install: ${APP_NAME}. Wont install."
                    break
                fi
            fi

            # note "Preparing application: ${APP_NAME}${APP_POSTFIX} (${APP_FULL_NAME} v${APP_VERSION})"
            export PREFIX="${SOFTWARE_DIR}${APP_NAME}${APP_POSTFIX}"
            export SERVICE_DIR="${SERVICES_DIR}${APP_NAME}${APP_POSTFIX}"
            if [ "${APP_STANDALONE}" = "true" ]; then
                # TODO: create zfs dataset!
                ${MKDIR_BIN} -p "${SERVICE_DIR}"
                ${CHMOD_BIN} 0710 "${SERVICE_DIR}"
            fi

            run () {
                if [ ! -z "$1" ]; then
                    aname="$(echo "${APP_NAME}${APP_POSTFIX}" | ${TR_BIN} '[A-Z]' '[a-z]' 2>/dev/null)"
                    if [ ! -d "${LOGS_DIR}" ]; then
                        ${MKDIR_BIN} -p "${LOGS_DIR}"
                    fi
                    debug "$(${DATE_BIN} +%H%M%S-%s 2>/dev/null) run('$@'); aname(${aname});"
                    if [ -z "${aname}" ]; then
                        eval PATH="${PATH}" "$@" >> "${LOG}" 2>&1
                        check_command_result $? "$@"
                    else
                        eval PATH="${PATH}" "$@" >> "${LOG}-${aname}" 2>&1
                        check_command_result $? "$@"
                    fi
                else
                    error "An empty command to run for: ${APP_NAME}?"
                fi
            }

            try () {
                if [ ! -z "$1" ]; then
                    aname="$(echo "${APP_NAME}${APP_POSTFIX}" | ${TR_BIN} '[A-Z]' '[a-z]' 2>/dev/null)"
                    if [ ! -d "${LOGS_DIR}" ]; then
                        ${MKDIR_BIN} -p "${LOGS_DIR}"
                    fi
                    debug "$(${DATE_BIN} +%H%M%S-%s 2>/dev/null) try('$@'); aname(${aname});"
                    if [ -z "${aname}" ]; then
                        eval PATH="${PATH}" "$@" >> "${LOG}" 2>&1
                    else
                        eval PATH="${PATH}" "$@" >> "${LOG}-${aname}" 2>&1
                    fi
                else
                    error "An empty command to run for: ${APP_NAME}?"
                fi
            }

            # binary build of whole software bundle
            ABSNAME="${APP_NAME}${APP_POSTFIX}-${APP_VERSION}"
            ${MKDIR_BIN} -p "${BINBUILDS_CACHE_DIR}${ABSNAME}" > /dev/null 2>&1

            MIDDLE="${SYSTEM_NAME}-${FULL_SYSTEM_VERSION}-${SYSTEM_ARCH}"
            ARCHIVE_NAME="${APP_NAME}${APP_POSTFIX}-${APP_VERSION}${DEFAULT_ARCHIVE_EXT}"
            INSTALLED_INDICATOR="${PREFIX}/${APP_LOWER}${APP_POSTFIX}${INSTALLED_MARK}"

            if [ "${SOFIN_CONTINUE_BUILD}" != "YES" ]; then # normal build by default
                if [ ! -e "${INSTALLED_INDICATOR}" ]; then
                    if [ "${USE_BINBUILD}" = "false" ]; then
                        debug "   ${NOTE_CHAR2} Binary build check was skipped"
                    else
                        aname="$(echo "${APP_NAME}${APP_POSTFIX}" | ${TR_BIN} '[A-Z]' '[a-z]' 2>/dev/null)"
                        if [ ! -e "${BINBUILDS_CACHE_DIR}${ABSNAME}/${ARCHIVE_NAME}" ]; then
                            cd ${BINBUILDS_CACHE_DIR}${ABSNAME}
                            note "Trying binary build for: ${cyan}${MIDDLE}/${APP_NAME}${APP_POSTFIX}-${APP_VERSION}"
                            retry "${FETCH_BIN} ${MAIN_BINARY_REPOSITORY}${MIDDLE}/${ARCHIVE_NAME}.sha1"
                            retry "${FETCH_BIN} ${MAIN_BINARY_REPOSITORY}${MIDDLE}/${ARCHIVE_NAME}"

                            # checking archive sha1 checksum
                            if [ -e "./${ARCHIVE_NAME}" ]; then
                                debug "Found binary build archive: ${BINBUILDS_CACHE_DIR}${ABSNAME}/${ARCHIVE_NAME}"
                                case "${SYSTEM_NAME}" in
                                    Darwin|Linux)
                                        export current_archive_sha1="$(${SHA_BIN} "${ARCHIVE_NAME}" 2>/dev/null | ${AWK_BIN} '{print $1;}' 2>/dev/null)"
                                        ;;

                                    FreeBSD)
                                        export current_archive_sha1="$(${SHA_BIN} -q "${ARCHIVE_NAME}" 2>/dev/null)"
                                        ;;
                                esac
                                debug "current_archive_sha1: ${current_archive_sha1}"
                            fi
                            current_sha_file="${BINBUILDS_CACHE_DIR}${ABSNAME}/${ARCHIVE_NAME}.sha1"
                            if [ -e "${current_sha_file}" ]; then
                                export sha1_value="$(${CAT_BIN} ${current_sha_file} 2>/dev/null)"
                            fi

                            debug "Checking SHA1 match: ${current_archive_sha1} vs ${sha1_value}"
                            if [ "${current_archive_sha1}" != "${sha1_value}" ]; then
                                debug "Checksums doesn't match, removing binary builds and proceeding into build phase"
                                ${RM_BIN} -fv ${ARCHIVE_NAME}
                                ${RM_BIN} -fv ${ARCHIVE_NAME}.sha1
                            fi
                        fi
                        cd "${SOFTWARE_ROOT_DIR}"

                        debug "ARCHIVE_NAME: ${ARCHIVE_NAME}. Expecting binbuild to be available in: ${BINBUILDS_CACHE_DIR}${ABSNAME}/${ARCHIVE_NAME}"
                        if [ -e "${BINBUILDS_CACHE_DIR}${ABSNAME}/${ARCHIVE_NAME}" ]; then # if exists, then checksum is ok
                            ${TAR_BIN} xJf "${BINBUILDS_CACHE_DIR}${ABSNAME}/${ARCHIVE_NAME}" >> ${LOG}-${aname} 2>&1
                            if [ "$?" = "0" ]; then # if archive is valid
                                note "  ${NOTE_CHAR2} Binary bundle installed: ${cyan}${APP_NAME}${APP_POSTFIX} ${green}with version: ${APP_VERSION}"
                                export DONT_BUILD_BUT_DO_EXPORTS="true"
                            else
                                debug "  ${NOTE_CHAR2} No binary bundle available for: ${cyan}${APP_NAME}${APP_POSTFIX}"
                                ${RM_BIN} -fr "${BINBUILDS_CACHE_DIR}${ABSNAME}"
                            fi
                        else
                            debug "  ${NOTE_CHAR2} Binary build checksum doesn't match for: ${ABSNAME}"
                        fi
                    fi
                else
                    note "Software already installed: ${cyan}${APP_NAME}${APP_POSTFIX} ${green}with version: ${cyan}$(${CAT_BIN} ${INSTALLED_INDICATOR} 2>/dev/null)"
                    export DONT_BUILD_BUT_DO_EXPORTS="true"
                fi

            else # continue build!
                note "Continuing build in: ${cyan}${PREVIOUS_BUILD_DIR}"
                cd "${PREVIOUS_BUILD_DIR}"
            fi

            execute_process () {
                if [ -z "$1" ]; then
                    error "No param given for execute_process()!"
                fi
                req_definition_file="${DEFINITIONS_DIR}${1}.def"
                debug "Checking requirement: $1 file: $req_definition_file"
                if [ ! -e "${req_definition_file}" ]; then
                    error "Cannot fetch definition: ${cyan}${req_definition_file}${red}! Aborting!"
                fi

                . "${DEFAULTS}" # load definition and check for current version
                . "${req_definition_file}"
                # check_current "${APP_VERSION}" "${APP_CURRENT_VERSION}"
                check_disabled "${DISABLE_ON}" # check requirement for disabled state:

                if [ ! -z "${FORCE_GNU_COMPILER}" ]; then # force GNU compiler usage on definition side:
                    warn "   ${NOTE_CHAR2} GNU compiler set for: ${cyan}${APP_NAME}"
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
                export LDFLAGS="-L${PREFIX}/lib ${APP_LINKER_ARGS} ${DEFAULT_LDFLAGS}"

                if [ -z "${APP_LINKER_NO_DTAGS}" ]; then
                    if [ "${SYSTEM_NAME}" != "Darwin" ]; then # feature isn't required on Darwin
                        export LDFLAGS="${LDFLAGS} -Wl,-rpath=${PREFIX}/lib,--enable-new-dtags"
                    fi
                fi

                if [ "${ALLOW}" = "1" ]; then
                    if [ -z "${APP_HTTP_PATH}" ]; then
                        note "   ${NOTE_CHAR2} No source given for definition (${cyan}APP_HTTP_PATH=\"\"${green}), it's only valid for meta bundles (${cyan}APP_CONFIGURE_SCRIPT=\"meta\" ${green}special)"
                    else
                        CUR_DIR="$(${PWD_BIN} 2>/dev/null)"

                        if [ "${SOFIN_CONTINUE_BUILD}" != "YES"  ]; then
                            debug "Runtime SHA1: ${RUNTIME_SHA}"
                            export BUILD_DIR_ROOT="${CACHE_DIR}cache/${APP_NAME}${APP_POSTFIX}-${APP_VERSION}-${RUNTIME_SHA}/"
                            ${MKDIR_BIN} -p "${BUILD_DIR_ROOT}"
                            cd "${BUILD_DIR_ROOT}"
                            for bd in ${BUILD_DIR_ROOT}/*; do
                                if [ -d "${bd}" ]; then
                                    debug "Unpacked source code found in build dir. Removing: '${bd}'"
                                    if [ "${bd}" != "/" ]; then # it's better to be safe than sorry
                                        ${RM_BIN} -rf "${bd}"
                                    fi
                                fi
                            done
                            if [ -z "${APP_GIT_MODE}" ]; then # Standard http tarball method:
                                if [ ! -e ${BUILD_DIR_ROOT}/../$(${BASENAME_BIN} ${APP_HTTP_PATH} 2>/dev/null) ]; then
                                    note "   ${NOTE_CHAR2} Fetching requirement source from: ${cyan}${APP_HTTP_PATH}"
                                    retry "${FETCH_BIN} ${APP_HTTP_PATH}"
                                    ${MV_BIN} $(${BASENAME_BIN} ${APP_HTTP_PATH} 2>/dev/null) ${BUILD_DIR_ROOT}/..
                                fi

                                file="${BUILD_DIR_ROOT}/../$(${BASENAME_BIN} ${APP_HTTP_PATH} 2>/dev/null)"
                                debug "Build dir: ${BUILD_DIR_ROOT}, file: ${file}"
                                if [ "${APP_SHA}" = "" ]; then
                                    error "${NOTE_CHAR2} Missing SHA sum for source: ${file}."
                                else
                                    case "${SYSTEM_NAME}" in
                                        Darwin|Linux)
                                            export cur="$(${SHA_BIN} ${file} 2>/dev/null | ${AWK_BIN} '{print $1;}' 2>/dev/null)"
                                            ;;

                                        FreeBSD)
                                            export cur="$(${SHA_BIN} -q ${file} 2>/dev/null)"
                                            ;;
                                    esac
                                    if [ "${cur}" = "${APP_SHA}" ]; then
                                        debug "${NOTE_CHAR2} Bundle checksum is fine."
                                    else
                                        warn "${NOTE_CHAR2} ${cur} vs ${APP_SHA}"
                                        warn "${NOTE_CHAR2} Bundle checksum mismatch detected!"
                                        warn "${NOTE_CHAR2} Removing corrupted file from cache: '${file}' and retrying."
                                        # remove corrupted file
                                        ${RM_BIN} -f "${file}"
                                        # and restart script with same arguments:
                                        debug "Evaluating: ${SOFIN_BIN} ${SOFIN_ARGS_FULL}"
                                        eval "${SOFIN_BIN} ${SOFIN_ARGS_FULL}"
                                        exit
                                    fi
                                fi

                                note "   ${NOTE_CHAR2} Unpacking source code of: ${cyan}${APP_NAME}"
                                debug "Build dir root: ${BUILD_DIR_ROOT}"
                                run "${TAR_BIN} xf ${file}"

                            else
                                # git method
                                note "   ${NOTE_CHAR2} Fetching requirement source from git repository: ${cyan}${APP_HTTP_PATH}"
                                retry "${GIT_BIN} clone ${APP_HTTP_PATH} ${APP_NAME}${APP_VERSION}"
                            fi

                            export BUILD_DIR="$(${FIND_BIN} ${BUILD_DIR_ROOT}/* -maxdepth 0 -type d -name "*${APP_VERSION}*" 2>/dev/null)"
                            if [ -z "${BUILD_DIR}" ]; then
                                export BUILD_DIR=$(${FIND_BIN} ${BUILD_DIR_ROOT}/* -maxdepth 0 -type d 2>/dev/null) # try any dir instead
                            fi
                            if [ ! -z "${APP_SOURCE_DIR_POSTFIX}" ]; then
                                export BUILD_DIR="${BUILD_DIR}/${APP_SOURCE_DIR_POSTFIX}"
                            fi
                            cd "${BUILD_DIR}"
                            debug "Switched to build dir: '${BUILD_DIR}'"

                            if [ "${APP_GIT_CHECKOUT}" != "" ]; then
                                note "   ${NOTE_CHAR2} Checking out: ${cyan}${APP_GIT_CHECKOUT}"
                                run "${GIT_BIN} checkout ${APP_GIT_CHECKOUT}"
                            fi

                            if [ ! -z "${APP_AFTER_UNPACK_CALLBACK}" ]; then
                                debug "Running after unpack callback"
                                run "${APP_AFTER_UNPACK_CALLBACK}"
                            fi

                            aname="$(echo "${APP_NAME}${APP_POSTFIX}" | ${TR_BIN} '[A-Z]' '[a-z]' 2>/dev/null)"
                            LIST_DIR="${DEFINITIONS_DIR}patches/$1" # $1 is definition file name
                            if [ -d "${LIST_DIR}" ]; then
                                patches_files="$(${FIND_BIN} ${LIST_DIR}/* -maxdepth 0 -type f 2>/dev/null)"
                                note "   ${NOTE_CHAR2} Applying common patches for: ${cyan}${APP_NAME}${APP_POSTFIX}"
                                for patch in ${patches_files}; do
                                    for level in 0 1 2 3 4 5; do
                                        debug "Trying to patch source with patch: ${patch}, level: ${level}"
                                        ${PATCH_BIN} -p${level} -N -f -i "${patch}" >> "${LOG}-${aname}" 2>> "${LOG}-${aname}" # don't use run.. it may fail - we don't care
                                        if [ "$?" = "0" ]; then # skip applying single patch if it already passed
                                            debug "Patch: '${patch}' applied successfully!"
                                            break;
                                        fi
                                    done
                                done
                                pspatch_dir="${LIST_DIR}/${SYSTEM_NAME}"
                                debug "Checking psp dir: ${pspatch_dir}"
                                if [ -d "${pspatch_dir}" ]; then
                                    note "   ${NOTE_CHAR2} Applying platform specific patches for: ${cyan}${APP_NAME}${APP_POSTFIX}/${SYSTEM_NAME}"
                                    patches_files="$(${FIND_BIN} ${pspatch_dir}/* -maxdepth 0 -type f 2>/dev/null)"
                                    for platform_specific_patch in ${patches_files}; do
                                        for level in 0 1 2 3 4 5; do
                                            debug "Patching source code with pspatch: ${platform_specific_patch} (p${level})"
                                            ${PATCH_BIN} -p${level} -N -f -i "${platform_specific_patch}" >> "${LOG}-${aname}" 2>> "${LOG}-${aname}"
                                            if [ "$?" = "0" ]; then # skip applying single patch if it already passed
                                                debug "Patch: '${platform_specific_patch}' applied successfully!"
                                                break;
                                            fi
                                        done
                                    done
                                fi
                            fi

                            if [ ! -z "${APP_AFTER_PATCH_CALLBACK}" ]; then
                                debug "Running after patch callback"
                                run "${APP_AFTER_PATCH_CALLBACK}"
                            fi

                            debug "-------------- PRE CONFIGURE SETTINGS DUMP --------------"
                            debug "Current DIR: $(${PWD_BIN} 2>/dev/null)"
                            debug "PREFIX: ${PREFIX}"
                            debug "SERVICE_DIR: ${SERVICE_DIR}"
                            debug "PATH: ${PATH}"
                            debug "CC: ${CC}"
                            debug "CXX: ${CXX}"
                            debug "CPP: ${CPP}"
                            debug "CXXFLAGS: ${CXXFLAGS}"
                            debug "CFLAGS: ${CFLAGS}"
                            debug "LDFLAGS: ${LDFLAGS}"
                            debug "LD_LIBRARY_PATH: ${LD_LIBRARY_PATH}"

                            note "   ${NOTE_CHAR2} Configuring: ${cyan}$1${green}, version: ${cyan}${APP_VERSION}"
                            case "${APP_CONFIGURE_SCRIPT}" in

                                ignore)
                                    note "   ${NOTE_CHAR2} Ignored configuration of definition: ${cyan}$1"
                                    ;;

                                no-conf)
                                    note "   ${NOTE_CHAR2} No configuration for definition: ${cyan}$1"
                                    export APP_MAKE_METHOD="${APP_MAKE_METHOD} PREFIX=${PREFIX}"
                                    export APP_INSTALL_METHOD="${APP_INSTALL_METHOD} PREFIX=${PREFIX}"
                                    ;;

                                binary)
                                    note "   ${NOTE_CHAR2} Prebuilt definition of: ${cyan}$1"
                                    export APP_MAKE_METHOD="true"
                                    export APP_INSTALL_METHOD="true"
                                    ;;

                                posix)
                                    run "./configure -prefix ${PREFIX} -cc $(${BASENAME_BIN} ${CC} 2>/dev/null) ${APP_CONFIGURE_ARGS}"
                                    ;;

                                cmake)
                                    run "${APP_CONFIGURE_SCRIPT} . -LH -DCMAKE_INSTALL_PREFIX=${PREFIX} -DCMAKE_BUILD_TYPE=Release -DSYSCONFDIR=${SERVICE_DIR}/etc -DWITH_DEBUG=0 ${APP_CONFIGURE_ARGS}"
                                    ;;

                                void|meta|empty)
                                    APP_MAKE_METHOD="true"
                                    APP_INSTALL_METHOD="true"
                                    ;;

                                *)
                                    if [ "${SYSTEM_NAME}" = "Linux" ]; then
                                        # NOTE: No /Services feature implemented for Linux.
                                        run "${APP_CONFIGURE_SCRIPT} ${APP_CONFIGURE_ARGS} --prefix=${PREFIX}"
                                    else
                                        # do a simple check for "configure" in APP_CONFIGURE_SCRIPT definition
                                        # this way we can tell if we want to put configure options as params
                                        echo "${APP_CONFIGURE_SCRIPT}" | ${GREP_BIN} "configure" >/dev/null 2>&1
                                        if [ "$?" = "0" ]; then
                                            # NOTE: By default try to configure software with these options:
                                            #   --sysconfdir=${SERVICE_DIR}/etc
                                            #   --localstatedir=${SERVICE_DIR}/var
                                            #   --runstatedir=${SERVICE_DIR}/run
                                            try "${APP_CONFIGURE_SCRIPT} ${APP_CONFIGURE_ARGS} --prefix=${PREFIX} --sysconfdir=${SERVICE_DIR}/etc --localstatedir=${SERVICE_DIR}/var --runstatedir=${SERVICE_DIR}/run" || \
                                            try "${APP_CONFIGURE_SCRIPT} ${APP_CONFIGURE_ARGS} --prefix=${PREFIX} --sysconfdir=${SERVICE_DIR}/etc --localstatedir=${SERVICE_DIR}/var" || \
                                            try "${APP_CONFIGURE_SCRIPT} ${APP_CONFIGURE_ARGS} --prefix=${PREFIX} --sysconfdir=${SERVICE_DIR}/etc" || \
                                            run "${APP_CONFIGURE_SCRIPT} ${APP_CONFIGURE_ARGS} --prefix=${PREFIX}" # only as a  fallback

                                        else # fallback again:
                                            run "${APP_CONFIGURE_SCRIPT} ${APP_CONFIGURE_ARGS} --prefix=${PREFIX}"
                                        fi
                                    fi
                                    ;;

                            esac
                            if [ ! -z "${APP_AFTER_CONFIGURE_CALLBACK}" ]; then
                                debug "Running after configure callback"
                                run "${APP_AFTER_CONFIGURE_CALLBACK}"
                            fi

                        else # in "continue-build" mode, we reuse current cache dir..
                            export BUILD_DIR_ROOT="${PREVIOUS_BUILD_DIR}"
                            export BUILD_DIR="${PREVIOUS_BUILD_DIR}"
                            cd "${BUILD_DIR}"
                        fi

                        # and common part between normal and continue modes:
                        note "   ${NOTE_CHAR2} Building requirement: ${cyan}$1"
                        run "${APP_MAKE_METHOD}"
                        if [ ! -z "${APP_AFTER_MAKE_CALLBACK}" ]; then
                            debug "Running after make callback"
                            run "${APP_AFTER_MAKE_CALLBACK}"
                        fi

                        note "   ${NOTE_CHAR2} Installing requirement: ${cyan}$1"
                        run "${APP_INSTALL_METHOD}"
                        if [ ! "${APP_AFTER_INSTALL_CALLBACK}" = "" ]; then
                            debug "After install callback: ${APP_AFTER_INSTALL_CALLBACK}"
                            run "${APP_AFTER_INSTALL_CALLBACK}"
                        fi

                        debug "Marking as installed '$1' in: ${PREFIX}"
                        ${TOUCH_BIN} "${PREFIX}/$1${INSTALLED_MARK}"
                        debug "Writing version: ${APP_VERSION} of app: '${APP_NAME}' installed in: ${PREFIX}"
                        ${PRINTF_BIN} "${APP_VERSION}" > "${PREFIX}/$1${INSTALLED_MARK}"

                        if [ -z "${DEVEL}" ]; then # if devel mode not set
                            debug "Cleaning build dir: '${BUILD_DIR_ROOT}' of bundle: '${APP_NAME}${APP_POSTFIX}', after successful build."
                            ${RM_BIN} -rf "${BUILD_DIR_ROOT}"
                        else
                            debug "Leaving build dir intact when working in devel mode. Last build dir: '${BUILD_DIR_ROOT}'"
                        fi
                        cd "${CUR_DIR}" 2>/dev/null
                    fi
                else
                    warn "   ${NOTE_CHAR2} Requirement: ${cyan}${APP_NAME} ${yellow}disabled on: ${cyan}${SYSTEM_NAME}"
                    if [ ! -d "${PREFIX}" ]; then # case when disabled requirement is first on list of dependencies
                        ${MKDIR_BIN} -p "${PREFIX}"
                    fi
                    ${TOUCH_BIN} "${PREFIX}/${req}${INSTALLED_MARK}"
                    ${PRINTF_BIN} "os-default" > "${PREFIX}/${req}${INSTALLED_MARK}"
                fi
            }

            if [ -z "${DONT_BUILD_BUT_DO_EXPORTS}" ]; then
                if [ -z "${APP_REQUIREMENTS}" ]; then
                    note "Installing: ${cyan}${application} ${green}v${cyan}${APP_VERSION}"
                else
                    note "Installing: ${cyan}${application} ${green}v${cyan}${APP_VERSION}${green}, with requirements: ${cyan}${APP_REQUIREMENTS}"
                fi
                export req_amount="$(${PRINTF_BIN} "${APP_REQUIREMENTS}" | ${WC_BIN} -w 2>/dev/null | ${AWK_BIN} '{print $1;}' 2>/dev/null)"
                export req_amount="$(${PRINTF_BIN} "${req_amount} + 1\n" | ${BC_BIN} 2>/dev/null)"
                export req_all="${req_amount}"
                for req in ${APP_REQUIREMENTS}; do
                    if [ ! "${APP_USER_INFO}" = "" ]; then
                        warn "${APP_USER_INFO}"
                    fi
                    if [ -z "${req}" ]; then
                        note "  No requirements"
                        break
                    else
                        note "  ${req} (${cyan}${req_amount}${green} of ${cyan}${req_all}${green} remaining)"
                        if [ ! -e "${PREFIX}/${req}${INSTALLED_MARK}" ]; then
                            export CHANGED="true"
                            execute_process "${req}"
                        fi
                    fi
                    export req_amount="$(${PRINTF_BIN} "${req_amount} - 1\n" | ${BC_BIN} 2>/dev/null)"
                done
            fi

            mark () {
                debug "Marking definition: ${application} installed"
                ${TOUCH_BIN} "${PREFIX}/${application}${INSTALLED_MARK}"
                debug "Writing version: ${APP_VERSION} of app: '${application}' installed in: ${PREFIX}"
                ${PRINTF_BIN} "${APP_VERSION}" > "${PREFIX}/${application}${INSTALLED_MARK}"
            }

            show_done () {
                ver="$(${CAT_BIN} "${PREFIX}/${application}${INSTALLED_MARK}" 2>/dev/null)"
                note "${SUCCESS_CHAR} ${application} [${cyan}${ver}${green}]\n"
            }

            if [ -z "${DONT_BUILD_BUT_DO_EXPORTS}" ]; then
                if [ -e "${PREFIX}/${application}${INSTALLED_MARK}" ]; then
                    if [ "${CHANGED}" = "true" ]; then
                        note "  ${application} (${cyan}1${green} of ${cyan}${req_all}${green})"
                        note "   ${NOTE_CHAR2} App dependencies changed. Rebuilding: ${cyan}${application}"
                        execute_process "${application}"
                        unset CHANGED
                        mark
                        show_done
                    else
                        note "  ${application} (${cyan}1${green} of ${cyan}${req_all}${green})"
                        show_done
                        debug "${SUCCESS_CHAR} ${application} current: ${ver}, definition: [${APP_VERSION}] Ok."
                    fi
                else
                    note "  ${application} (${cyan}1${green} of ${cyan}${req_all}${green})"
                    execute_process "${application}"
                    mark
                    note "${SUCCESS_CHAR} ${application} [${cyan}${APP_VERSION}${green}]\n"
                fi
            fi

            debug "Doing app conflict resolve"
            if [ ! -z "${APP_CONFLICTS_WITH}" ]; then
                disabled_exps=""
                debug "  ${NOTE_CHAR2} Resolving possible conflicts with: ${APP_CONFLICTS_WITH}"
                for app in ${APP_CONFLICTS_WITH}; do
                    maybe_software="$(${FIND_BIN} ${SOFTWARE_DIR} -maxdepth 1 -type d -iname "${app}*" 2>/dev/null)"
                    for an_app in ${maybe_software}; do
                        if [ -e "${an_app}/exports" ]; then
                            debug "Disabling exports for ${an_app}"
                            ${MV_BIN} "${an_app}/exports" "${an_app}/exports-disabled"
                            disabled_exps="${disabled_exp} ${an_app}"
                        fi
                    done
                done
                note "  ${NOTE_CHAR2} Disabled conflicting bundles:${cyan}${disabled_exps}"
            fi

            . "${DEFINITIONS_DIR}${application}.def"
            if [ -d "${PREFIX}/exports-disabled" ]; then # just bring back disabled exports
                debug "Moving ${PREFIX}/exports-disabled to ${PREFIX}/exports"
                ${MV_BIN} "${PREFIX}/exports-disabled" "${PREFIX}/exports"
            fi
            if [ -z "${APP_EXPORTS}" ]; then
                note "  ${NOTE_CHAR2} Defined no binaries to export of prefix: ${cyan}${PREFIX}"
            else
                aname="$(echo "${APP_NAME}${APP_POSTFIX}" | ${TR_BIN} '[A-Z]' '[a-z]' 2>/dev/null)"
                note "  ${NOTE_CHAR2} Exporting binaries: ${cyan}${APP_EXPORTS}${green}, of prefix: ${cyan}${PREFIX}"
                ${MKDIR_BIN} -p "${PREFIX}/exports"
                EXPORT_LIST=""
                for exp in ${APP_EXPORTS}; do
                    for dir in "/bin/" "/sbin/" "/libexec/"; do
                        file_to_exp="${PREFIX}${dir}${exp}"
                        if [ -f "${file_to_exp}" ]; then # a file
                            if [ -x "${file_to_exp}" ]; then # and it's executable'
                                curr_dir="$(${PWD_BIN} 2>/dev/null)"
                                cd "${PREFIX}${dir}"
                                ${LN_BIN} -vfs "..${dir}${exp}" "../exports/${exp}" >> "${LOG}-${aname}"
                                cd "${curr_dir}"
                                exp_elem="$(${BASENAME_BIN} ${file_to_exp} 2>/dev/null)"
                                EXPORT_LIST="${EXPORT_LIST} ${exp_elem}"
                            fi
                        fi
                    done
                done
            fi
        done

        if [ ! -z "${APP_AFTER_EXPORT_CALLBACK}" ]; then
            debug "Executing APP_AFTER_EXPORT_CALLBACK"
            run "${APP_AFTER_EXPORT_CALLBACK}"
        fi

        if [ "${APP_CLEAN_USELESS}" = "true" ]; then
            for pattern in ${APP_USELESS} ${APP_DEFAULT_USELESS}; do
                if [ ! -z "${PREFIX}" ]; then
                    debug "Pattern: ${pattern}"
                    ${RM_BIN} -rf ${PREFIX}/${pattern}
                fi
            done
            for dir in bin sbin libexec; do
                if [ -d "${PREFIX}/${dir}" ]; then
                    ALL_BINS=$(${FIND_BIN} ${PREFIX}/${dir} -maxdepth 1 -type f -or -type l 2>/dev/null)
                    debug "ALL_BINS: $(echo "${ALL_BINS}" | ${TR_BIN} '\n' ' ' 2>/dev/null)"
                    for file in ${ALL_BINS}; do
                        base="$(${BASENAME_BIN} ${file} 2>/dev/null)"
                        if [ -e "${PREFIX}/exports/${base}" ]; then
                            debug "Found export: ${base}"
                        else
                            # traverse through APP_USEFUL for file patterns required by software but not exported
                            commit_removal=""
                            for is_useful in ${APP_USEFUL}; do
                                echo "${file}" | ${GREP_BIN} "${is_useful}" >/dev/null 2>&1
                                if [ "$?" = "0" ]; then
                                    commit_removal="no"
                                fi
                            done
                            if [ -z "${commit_removal}" ]; then
                                debug "Removing useless file: ${file}"
                                ${RM_BIN} -f "${file}"
                            else
                                debug "Useful file left intact: ${file}"
                            fi
                        fi
                    done
                fi
            done
        fi

        dirs_to_strip=""
        case "${APP_STRIP}" in
            all)
                dirs_to_strip="${PREFIX}/bin ${PREFIX}/sbin ${PREFIX}/lib ${PREFIX}/libexec"
                ;;
            exports)
                dirs_to_strip="${PREFIX}/bin ${PREFIX}/sbin ${PREFIX}/libexec"
                ;;
            libs)
                dirs_to_strip="${PREFIX}/lib"
                ;;
            no)
                ;;
        esac
        if [ "${APP_STRIP}" != "no" ]; then
            if [ -z "${DEBUGBUILD}" ]; then
                counter="0"
                for strip in ${dirs_to_strip}; do
                    if [ -d "${strip}" ]; then
                        files="$(${FIND_BIN} ${strip} -maxdepth 1 -type f 2>/dev/null)"
                        for file in ${files}; do
                            ${STRIP_BIN} ${file} > /dev/null 2>&1
                            if [ "$?" = "0" ]; then
                                counter="${counter} + 1"
                            else
                                counter="${counter} - 1"
                            fi
                        done
                    fi
                done
                result="$(echo "${counter}" | ${BC_BIN} 2>/dev/null)"
                if [ "${result}" -lt "0" ]; then
                    result="0"
                fi
                note "  ${NOTE_CHAR2} Clean complete. ${cyan}${result} ${green}files stripped"
            else
                warn "  ${NOTE_CHAR2} Debug build is enabled. Strip skipped."
            fi
        fi

        case ${SYSTEM_NAME} in
            Darwin) # disabled for now, since OSX finds more problems than they're
                ;;

            Linux) # Not supported
                ;;

            *)
                # start from checking ${SERVICES_DIR}/Bundlename directory
                if [ ! -d "${SERVICE_DIR}" ]; then
                    ${MKDIR_BIN} -p "${SERVICE_DIR}" && \
                    note "  ${NOTE_CHAR2} Prepared service directory in: ${cyan}${SERVICE_DIR}"
                fi

                # count Sofin jobs. For more than one job available,
                sofin_ps_list="$(${PS_BIN} axv 2>/dev/null | ${GREP_BIN} -v grep 2>/dev/null | ${EGREP_BIN} "sh ${SOFIN_BIN} (${ALL_INSTALL_PHRASES}) [A-Z].*" 2>/dev/null)"
                debug "Sofin ps list: $(echo "${sofin_ps_list}" | ${TR_BIN} '\n' ' ' 2>/dev/null)"
                sofins_all="$(echo "${sofin_ps_list}" | ${WC_BIN} -l 2>/dev/null | ${SED_BIN} 's/ //g' 2>/dev/null)"
                sofins_running="$(echo "${sofins_all} - 1" | ${BC_BIN} 2>/dev/null)"
                test -z "${sofins_running}" && sofins_running="0"
                export jobs_in_parallel="NO"
                if [ ${sofins_running} -gt 1 ]; then
                    note "Exactly ${sofins_running} additional running Sofin found in background. Limiting jobs to current bundle only"
                    export jobs_in_parallel="YES"
                else
                    note "  ${NOTE_CHAR2} Traversing through several datasets at once, since single Sofin instance is running"
                fi

                # Create a dataset for any existing dirs in Services dir that are not ZFS datasets.
                all_dirs="$(${FIND_BIN} ${SERVICES_DIR} -mindepth 1 -maxdepth 1 -type d -not -name '.*' -print 2>/dev/null | ${XARGS_BIN} ${BASENAME_BIN} 2>/dev/null)"
                debug "Checking for non-dataset directories in ${SERVICES_DIR}: EOF:\n$(echo "${all_dirs}" | ${TR_BIN} '\n' ' ' 2>/dev/null)\nEOF\n"
                full_bundle_name="$(${BASENAME_BIN} "${PREFIX}" 2>/dev/null)"
                for maybe_dataset in ${all_dirs}; do
                    debug "Normal name: ${full_bundle_name}"
                    aname="$(echo "${full_bundle_name}" | ${TR_BIN} '[A-Z]' '[a-z]' 2>/dev/null)"
                    app_name_lowercase="$(echo "${maybe_dataset}" | ${TR_BIN} '[A-Z]' '[a-z]' 2>/dev/null)"
                    if [ "${app_name_lowercase}" = "${aname}" -o ${jobs_in_parallel} = "NO" ]; then
                        # find name of mount from default ZFS Services:
                        inner_dir=""
                        if [ "${USERNAME}" = "root" ]; then
                            inner_dir="root/"
                        else
                            # NOTE: In ServeD-OS there's only 1 inner dir name that's also the cell name
                            no_ending_slash="$(echo "${SERVICES_DIR}" | ${SED_BIN} 's/\/$//' 2>/dev/null)"
                            inner_dir="$(${ZFS_BIN} list -H 2>/dev/null | ${EGREP_BIN} "${no_ending_slash}$" 2>/dev/null | ${AWK_BIN} '{print $1;}' 2>/dev/null | ${SED_BIN} 's/.*\///' 2>/dev/null)/"
                            if [ -z "${inner_dir}" ]; then
                                warn "Falling back with inner dir name to current user name: ${USERNAME}/"
                                inner_dir="${USERNAME}/"
                            fi
                        fi
                        certain_dataset="${SERVICES_DIR}${inner_dir}${maybe_dataset}"
                        certain_fileset="${SERVICES_DIR}${maybe_dataset}"
                        full_dataset_name="${DEFAULT_ZPOOL}${certain_dataset}"
                        snap_file="${maybe_dataset}-${APP_VERSION}.${SERVICE_SNAPSHOT_POSTFIX}"
                        final_snap_file="${snap_file}${DEFAULT_ARCHIVE_EXT}"

                        create_or_receive () {
                            dataset_name="$1"
                            remote_path="${MAIN_BINARY_REPOSITORY}${MAIN_COMMON_NAME}/${final_snap_file}"
                            debug "Seeking remote snapshot existence: ${remote_path}"
                            try "${FETCH_BIN} ${remote_path}" || \
                            try "${FETCH_BIN} ${remote_path}" || \
                            try "${FETCH_BIN} ${remote_path}"
                            if [ "$?" = "0" ]; then
                                debug "Stream archive available. Creating service dataset: ${dataset_name} from file stream: ${final_snap_file}"
                                note "  ${NOTE_CHAR2} Dataset: ${cyan}${dataset_name} ${green}$(${XZCAT_BIN} "${final_snap_file}" | ${ZFS_BIN} receive -v "${dataset_name}" 2>/dev/null | ${TAIL_BIN} -n1)"
                                ${ZFS_BIN} rename ${dataset_name}@--head-- @origin && \
                                debug "Cleaning snapshot file: ${final_snap_file}, after successful receive"
                                ${RM_BIN} -f "${final_snap_file}"
                            else
                                debug "Initial service dataset unavailable"
                                ${ZFS_BIN} create "${dataset_name}" 2>/dev/null && \
                                note "  ${NOTE_CHAR2} Created an empty service dataset for: ${cyan}${dataset_name}"
                            fi
                        }

                        # check dataset existence and create/receive it if necessary
                        ds_mounted="$(${ZFS_BIN} get -H -o value mounted ${full_dataset_name} 2>/dev/null)"
                        debug "Dataset: ${full_dataset_name} is mounted?: ${ds_mounted}"
                        if [ "${ds_mounted}" != "yes" ]; then
                            debug "Moving ${certain_fileset} to ${certain_fileset}-tmp" && \
                            ${MV_BIN} "${certain_fileset}" "${certain_fileset}-tmp" && \
                            debug "Creating dataset: ${full_dataset_name}" && \
                            create_or_receive "${full_dataset_name}" && \
                            debug "Copying ${certain_fileset}-tmp/ back to ${certain_fileset}" && \
                            ${CP_BIN} -RP "${certain_fileset}-tmp/" "${certain_fileset}" && \
                            debug "Cleaning ${certain_fileset}-tmp" && \
                            ${RM_BIN} -rf "${certain_fileset}-tmp" && \
                            debug "Dataset created: ${full_dataset_name}"
                        fi

                    else # no name match
                        debug "No match for: ${app_name_lowercase}"
                    fi
                done
                ;;
        esac

        if [ "${APP_APPLE_BUNDLE}" = "true" ]; then
            APP_LOWERNAME="${APP_NAME}"
            APP_NAME="$(${PRINTF_BIN} "${APP_NAME}" | ${CUT_BIN} -c1 2>/dev/null | ${TR_BIN} '[a-z]' '[A-Z]' 2>/dev/null)$(${PRINTF_BIN} "${APP_NAME}" | ${SED_BIN} 's/^[a-zA-Z]//' 2>/dev/null)"
            APP_BUNDLE_NAME="${PREFIX}.app"
            aname="$(echo "${APP_NAME}${APP_POSTFIX}" | ${TR_BIN} '[A-Z]' '[a-z]' 2>/dev/null)"
            note "  ${NOTE_CHAR2} Creating Apple bundle: ${cyan}${APP_NAME} ${green}in: ${cyan}${APP_BUNDLE_NAME}"
            ${MKDIR_BIN} -p "${APP_BUNDLE_NAME}/libs"
            ${MKDIR_BIN} -p "${APP_BUNDLE_NAME}/Contents"
            ${MKDIR_BIN} -p "${APP_BUNDLE_NAME}/Contents/Resources/${APP_LOWERNAME}"
            ${MKDIR_BIN} -p "${APP_BUNDLE_NAME}/exports"
            ${MKDIR_BIN} -p "${APP_BUNDLE_NAME}/share"

            ${CP_BIN} -R ${PREFIX}/${APP_NAME}.app/Contents/* "${APP_BUNDLE_NAME}/Contents/"
            ${CP_BIN} -R ${PREFIX}/bin/${APP_LOWERNAME} "${APP_BUNDLE_NAME}/exports/"

            for lib in $(${FIND_BIN} "${PREFIX}" -name '*.dylib' -type f 2>/dev/null); do
                ${CP_BIN} -vf ${lib} ${APP_BUNDLE_NAME}/libs/ >> ${LOG}-${aname} 2>&1
            done

            # if symlink exists, remove it.
            ${RM_BIN} -f ${APP_BUNDLE_NAME}/lib
            ${LN_BIN} -s "${APP_BUNDLE_NAME}/libs ${APP_BUNDLE_NAME}/lib"

            # move data, and support files from origin:
            ${CP_BIN} -R "${PREFIX}/share/${APP_LOWERNAME}" "${APP_BUNDLE_NAME}/share/"
            ${CP_BIN} -R "${PREFIX}/lib/${APP_LOWERNAME}" "${APP_BUNDLE_NAME}/libs/"

            cd "${APP_BUNDLE_NAME}/Contents"
            test -L MacOS || ${LN_BIN} -s ../exports MacOS >> ${LOG}-${aname} 2>&1

            note "  ${NOTE_CHAR2} Creating relative libraries search path"
            cd ${APP_BUNDLE_NAME}

            note "  ${NOTE_CHAR2} Processing exported binary: ${cyan}${i}"
            ${SOFIN_LIBBUNDLE_BIN} -x "${APP_BUNDLE_NAME}/Contents/MacOS/${APP_LOWERNAME}" >> ${LOG}-${aname} 2>&1

        fi

    fi
done


update_shell_vars

if [ ! -z "${SHELL_PID}" ]; then
    pids=$(${PS_BIN} ax 2>/dev/null | ${GREP_BIN} -v grep 2>/dev/null | ${GREP_BIN} zsh 2>/dev/null | ${AWK_BIN} '{print $1;}' 2>/dev/null)
    note "Reloading configuration of all ${cyan}$(${BASENAME_BIN} "${SHELL}" 2>/dev/null) ${green}with pids: ${cyan}$(echo ${pids} | ${TR_BIN} '\n' ' ' 2>/dev/null)"
    for pid in ${pids}; do
        ${KILL_BIN} -SIGUSR2 ${pid}
    done
else
    write_info_about_shell_configuration
fi


exit
