#!/bin/sh
# @author: Daniel (dmilith) Dettlaff (dmilith at me dot com)

# load configuration from sofin.conf
readonly CONF_FILE="/etc/s.conf"
if [ -e "${CONF_FILE}" ]; then
    . "${CONF_FILE}"
    validate_env
else
    echo "FATAL: No configuration file found: ${CONF_FILE}. Sofin isn't installed properly."
    exit 1
fi

if [ ! -z "${SOFIN_TRACE}" ]; then
    set -x
fi

SOFIN_ARGS=$*
SOFIN_ARGS_FULL="${SOFIN_ARGS}"
readonly SOFIN_ARGS="$(echo ${SOFIN_ARGS} | ${CUT_BIN} -d' ' -f2- 2>/dev/null)"
readonly ALL_INSTALL_PHRASES="i|install|get|pick|choose|use|switch|p|push|binpush|send"
readonly BUILD_DEPLOY_PHRASES="b|build|d|deploy"

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

            # Gold linker support:
            if [ -x "/usr/bin/ld.gold" -a -f "/usr/lib/LLVMgold.so" ]; then
                export LD="/usr/bin/ld --plugin /usr/lib/LLVMgold.so"
                export NM="/usr/bin/nm --plugin /usr/lib/LLVMgold.so"
            fi
            ;;
    esac
}


retry () {
    retries="***"
    while [ ! -z "${retries}" ]; do
        if [ ! -z "$1" ]; then
            debug "$(${DATE_BIN} +%H%M%S-%s 2>/dev/null) Retry('$@')[${retries}];"
            if [ ! -f "${LOG}" -o ! -d "${LOGS_DIR}" ]; then
                ${MKDIR_BIN} -p "${LOGS_DIR}"
            fi
            gitroot="$(${BASENAME_BIN} $(${BASENAME_BIN} ${GIT_BIN} 2>/dev/null) 2>/dev/null)"
            eval PATH="/bin:/usr/bin:${gitroot}/bin:${gitroot}/libexec/git-core" "$@" >> "${LOG}" 2>> "${LOG}" && \
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
    if [ ! -z "${USE_UPDATE}" ]; then
        debug "Definitions update skipped on demand"
        return
    fi
    note "$(sofin_header)"
    if [ ! -x "${GIT_BIN}" ]; then
        note "Installing initial definition list from tarball to cache dir: $(distinct n ${CACHE_DIR})"
        ${RM_BIN} -rf "${CACHE_DIR}definitions"
        ${MKDIR_BIN} -p "${LOGS_DIR}" "${CACHE_DIR}definitions"
        cd "${CACHE_DIR}definitions"
        INITIAL_DEFINITIONS="${MAIN_SOURCE_REPOSITORY}initial-definitions${DEFAULT_ARCHIVE_EXT}"
        debug "Fetching latest tarball with initial definitions from: ${INITIAL_DEFINITIONS}"
        retry "${FETCH_BIN} ${INITIAL_DEFINITIONS}" && \
        ${TAR_BIN} -xJf *${DEFAULT_ARCHIVE_EXT} >> ${LOG} 2>> ${LOG} && \
            ${RM_BIN} -vrf "$(${BASENAME_BIN} ${INITIAL_DEFINITIONS} 2>/dev/null)"
        return
    fi
    if [ -d "${CACHE_DIR}definitions/.git" -a -f "${DEFAULTS}" ]; then
        cd "${CACHE_DIR}definitions"
        current_branch="$(${GIT_BIN} rev-parse --abbrev-ref HEAD 2>/dev/null)"
        if [ "${current_branch}" != "${BRANCH}" ]; then # use current_branch value if branch isn't matching default branch
            debug "Checking out branch: ${current_branch}"
            ${GIT_BIN} checkout -b "${current_branch}" >> ${LOG} 2>> ${LOG} || \
                ${GIT_BIN} checkout "${current_branch}" >> ${LOG} 2>> ${LOG}
            ${GIT_BIN} pull origin ${current_branch} >> ${LOG} 2>> ${LOG} && \
            note "Updated branch: $(distinct n ${current_branch}) of repository: $(distinct n ${REPOSITORY})" && \
            return

            note "${red}Error occured: Update from branch: ${BRANCH} of repository: ${REPOSITORY} wasn't possible. Log below:${reset}"
            ${TAIL_BIN} -n${LOG_LINES_AMOUNT_ON_ERR} ${LOG} 2>/dev/null
            error "$(fill)"

        else # else use default branch
            debug "Using default branch: ${BRANCH}"
            ${GIT_BIN} checkout -b "${BRANCH}" >> ${LOG} 2>> ${LOG} || \
                ${GIT_BIN} checkout "${BRANCH}" >> ${LOG} 2>> ${LOG}

            ${GIT_BIN} pull origin ${BRANCH} >> ${LOG} 2>> ${LOG} && \
            note "Updated branch: $(distinct n ${BRANCH}) of repository: $(distinct n ${REPOSITORY})" && \
            return

            note "${red}Error occured: Update from branch: $(distinct e ${BRANCH}) of repository: $(distinct e ${REPOSITORY}) wasn't possible. Log's below:${reset}"
            ${TAIL_BIN} -n${LOG_LINES_AMOUNT_ON_ERR} ${LOG} 2>/dev/null
            error "$(fill)"
        fi
    else
        # create cache; clone definitions repository:
        ${MKDIR_BIN} -p "${CACHE_DIR}"
        cd "${CACHE_DIR}"
        ${MKDIR_BIN} -p "${LOGS_DIR}"
        debug "Cloning repository: $(distinct d ${REPOSITORY}) from branch: $(distinct d ${BRANCH}); LOGS_DIR: $(distinct d ${LOGS_DIR}), CACHE_DIR: $(distinct d ${CACHE_DIR})"
        ${RM_BIN} -rf definitions >> ${LOG} 2>> ${LOG} # if something is already here, wipe it out from cache
        ${GIT_BIN} clone ${REPOSITORY} definitions >> ${LOG} 2>> ${LOG} || \
            error "Error occured: Update from branch: $(distinct e ${BRANCH}) of repository: $(distinct e ${REPOSITORY}) isn't possible. Please make sure that given repository and branch are valid."
        cd "${CACHE_DIR}definitions"
        ${GIT_BIN} checkout -b "${BRANCH}" >> ${LOG} 2>> ${LOG} || \
            ${GIT_BIN} checkout "${BRANCH}" >> ${LOG} 2>> ${LOG}

        ${GIT_BIN} pull origin "${BRANCH}" >> ${LOG} 2>> ${LOG} && \
        note "Updated branch: $(distinct n ${BRANCH} )of repository: $(distinct n ${REPOSITORY})" && \
        return

        note "${red}Error occured: Update from branch: ${BRANCH} of repository: ${REPOSITORY} wasn't possible. Log below:${reset}"
        ${TAIL_BIN} -n${LOG_LINES_AMOUNT_ON_ERR} ${LOG} 2>/dev/null
        error "$(fill)"
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
        note "No valid definitions cache found. Purging leftovers from: $(distinct n ${CACHE_DIR})"
        clean_purge
        update_definitions
    fi
}


reload_zsh_shells () {
    if [ ! -z "${SHELL_PID}" ]; then
        pattern="zsh"
        if [ "${SYSTEM_NAME}" = "Darwin" ]; then
            pattern="\d ${ZSH_BIN}" # NOTE: this fixes issue with SIGUSR2 signal sent to iTerm
        fi
        pids=$(sofin_processes | ${EGREP_BIN} "${pattern}" 2>/dev/null | ${AWK_BIN} '{print $1;}' 2>/dev/null)
        wishlist=""
        for pid in ${pids}; do
            wishlist="${wishlist}${pid} "
        done
        ${KILL_BIN} -SIGUSR2 ${wishlist} && \
        note "All running $(distinct n $(${BASENAME_BIN} "${SHELL}" 2>/dev/null)) sessions: $(distinct n ${wishlist}) were reloaded successfully"
        unset wishlist pids
    else
        write_info_about_shell_configuration
    fi
}


write_info_about_shell_configuration () {
    warn "$(distinct n SHELL_PID) has no value (normally contains pid of current shell)"
    warn "Shell auto reload function is disabled for this session"
}


usage_howto () {
    note "Built in tasks:"
    note "  $(distinct n "install | get | pick | choose | use  ") installs software from list or from definition and switches exports for it (example: ${SOFIN_BIN_SHORT} install Rubinius)"
    note "  $(distinct n "dependencies | deps | local          ") installs software from list defined in '$(distinct n ${DEPENDENCIES_FILE})' file in current directory"
    note "  $(distinct n "uninstall | remove | delete          ") removes an application or list (example: ${SOFIN_BIN_SHORT} uninstall Rubinius)"
    note "  $(distinct n "list | installed                     ") gives short list of installed software"
    note "  $(distinct n "fulllist | fullinstalled             ") gives detailed list with installed software including requirements"
    note "  $(distinct n "available                            ") lists available software"
    note "  $(distinct n "export | exp | exportapp             ") adds given command to application exports (example: ${SOFIN_BIN_SHORT} export rails Rubinius)"
    note "  $(distinct n "getshellvars | shellvars | vars      ") returns shell variables for installed software"
    note "  $(distinct n "log                                  ") shows and watches log file (for debug messages and verbose info)"
    note "  $(distinct n "reload | rehash                      ") recreates shell vars and reloads current shell"
    note "  $(distinct n "update                               ") only update definitions from remote repository and exit"
    note "  $(distinct n "ver | version                        ") shows ${SOFIN_BIN_SHORT} script version"
    note "  $(distinct n "clean                                ") cleans binbuilds cache, unpacked source content and logs"
    note "  $(distinct n "distclean                            ") cleans binbuilds cache, unpacked source content, logs and definitions"
    note "  $(distinct n "purge                                ") cleans binbuilds cache, unpacked source content, logs, definitions, source cache and possible states"
    note "  $(distinct n "outdated                             ") lists outdated software"
    note "  $(distinct n "build                                ") does binary build from source for software specified as params"
    note "  $(distinct n "continue Bundlename                  ") continues build from \"make stage\" of bundle name, given as param (previous build dir reused)"
    note "  $(distinct n "deploy                               ") build + push"
    note "  $(distinct n "push | binpush | send                ") creates binary build from prebuilt software bundles name given as params (example: ${SOFIN_BIN_SHORT} push Rubinius Vifm Curl)"
    note "  $(distinct n "wipe                                 ") wipes binary builds (matching given name) from binary respositories (example: ${SOFIN_BIN_SHORT} wipe Rubinius Vifm)"
    note "  $(distinct n "enable                               ") enables Sofin developer environment (full environment stored in ~/.profile). It's the default"
    note "  $(distinct n "disable                              ") disables Sofin developer environment (only PATH, PKG_CONFIG_PATH and MANPATH written to ~/.profile)"
    note "  $(distinct n "status                               ") shows Sofin status"
    note "  $(distinct n "dev                                  ") puts definition content on the fly. Second argument is (lowercase) definition name (no extension). (example: sofin dev rubinius)"
    note "  $(distinct n "rebuild                              ") rebuilds and pushes each software bundle that depends on definition given as a param. (example: ${SOFIN_BIN_SHORT} rebuild openssl - will rebuild all bundles that have 'openssl' dependency)"
    note "  $(distinct n "reset                               ") resets local definitions repository"
    note "  $(distinct n "diff                                ") displays changes in current definitions cache. Accepts any part of definition name"
    note "  $(distinct n "hack                                ") hack through build dirs matching pattern given as param"

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
        note "Removing binary builds from: $(distinct n ${BINBUILDS_CACHE_DIR})"
        ${FIND_BIN} "${BINBUILDS_CACHE_DIR}" -delete 2>/dev/null
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
            ${FIND_BIN} "${i}" -delete 2>/dev/null
        done
        result="$(echo "${number}" | ${BC_BIN} 2>/dev/null)"
        note "$(distinct n ${result} )directories cleaned."
    fi
}


clean_logs () {
    if [ -d "${LOGS_DIR}" ]; then
        note "Removing build logs from: $(distinct n ${LOGS_DIR})"
        ${FIND_BIN} "${LOGS_DIR}" -delete 2>/dev/null
    fi
}


clean_purge () {
    if [ -d "${CACHE_DIR}" ]; then
        note "Purging all caches from: $(distinct n ${CACHE_DIR})"
        ${FIND_BIN} "${CACHE_DIR}" -delete 2>/dev/null
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


fail_on_background_sofin_job () {
    deps=$*
    for dep in ${deps}; do
        debug "Checking for background jobs of: $(distinct d ${dep})"
        sofin_ps_list="$(sofin_processes | ${EGREP_BIN} "sh ${SOFIN_BIN} (${BUILD_DEPLOY_PHRASES}) ${dep}" 2>/dev/null)"
        debug "pslist: ${sofin_ps_list}"
        sofins_all="$(echo "${sofin_ps_list}" 2>/dev/null | ${WC_BIN} -l 2>/dev/null | ${SED_BIN} 's/ //g' 2>/dev/null)"
        debug "sofins_all: ${sofin_ps_list}"
        test ${sofins_all} -gt 2 && \
            error "Found currently processing jobs, for software bundle: $(distinct e ${dep}). Task aborted"
    done
    unset dep sofin_ps_list sofins_all
}


if [ ! "$1" = "" ]; then
    case $1 in

    dev)
        create_cache_directories
        if [ -z "${2}" ]; then
            error "No definition file name specified."
        fi
        note "Paste your definition below. Hit ctrl-d after a newline to commit"
        ${CAT_BIN} > ${DEFINITIONS_DIR}/${2}.def 2>/dev/null
        exit
        ;;


    hack|h)
        create_cache_directories
        if [ -z "${2}" ]; then
            error "No pattern specified"
        fi
        pattern="${2}"
        beauty_pat="$(distinct n *${pattern}*)"
        all_dirs=$(${FIND_BIN} ${CACHE_DIR}cache -type d -mindepth 2 -maxdepth 2 -iname "*${pattern}*" 2>/dev/null)
        amount="$(echo "${all_dirs}" | ${WC_BIN} -l 2>/dev/null | ${TR_BIN} -d '\t|\r|\ ' 2>/dev/null)"
        ${TEST_BIN} -z "${amount}" && amount="0"
        if [ -z "${all_dirs}" ]; then
            error "No matching build dirs found for pattern: ${beauty_pat}"
        else
            note "Sofin will now walk through: $(distinct n ${amount}) build dirs in: $(distinct n ${CACHE_DIR}cache), that matches pattern: $(distinct n ${beauty_pat})"
        fi
        for dir in ${all_dirs}; do
            note
            warn "$(fill)"
            warn "Quit viever/ Exit that shell, to continue with next build dir"
            warn "Sofin will now traverse through build logs, looking for errors.."

            currdir="$(${PWD_BIN} 2>/dev/null)"
            cd "${dir}"

            found_any=""
            log_viewer="${LESS_BIN} ${LESS_DEFAULT_OPTIONS} +/error:"
            for logfile in config.log build.log CMakeFiles/CMakeError.log CMakeFiles/CMakeOutput.log; do
                if [ -f "${logfile}" ]; then
                    found_any="yes"
                    eval "cd ${dir} && ${ZSH_BIN} --login -c '${log_viewer} ${logfile} || exit'"
                fi
            done
            if [ -z "${found_any}" ]; then
                note "Entering build dir.."
                eval "cd ${dir} && ${ZSH_BIN} --login"
            fi
            cd "${currdir}"
            warn "---------------------------------------------------------"
        done
        note "Hack process finished for pattern: ${beauty_pat}"
        exit
        ;;


    diffs|diff)
        create_cache_directories
        defname="${2}"
        # if specified a file name, make sure it's named properly:
        ${EGREP_BIN} '\.def$' "${defname}" >/dev/null 2>&1 || \
            defname="${defname}.def"
        beauty_defn="$(distinct n ${defname})"

        cd ${DEFINITIONS_DIR}
        if [ -f "./${defname}" ]; then
            debug "Checking status for untracked files.."
            ${GIT_BIN} status --short "${defname}" 2>/dev/null | ${EGREP_BIN} '\?\?' >/dev/null 2>&1
            if [ "$?" = "0" ]; then # found "??" which means file is untracked..
                note "No diff available for definition: ${beauty_defn} (currently untracked)"
            else
                note "Showing detailed modifications of defintion: ${beauty_defn}"
            fi
            ${GIT_BIN} status -vv --long "${defname}" 2>/dev/null
        else
            note "Showing all modifications from current defintions cache"
            ${GIT_BIN} status --short 2>/dev/null
        fi
        exit
        ;;


    ver|version)
        note "$(sofin_header)"
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
                            note "Found $(distinct n ${num}) log file, that matches pattern: $(distinct n ${pattern}). Attaching tail.."
                            ${TAIL_BIN} -n ${LOG_LINES_AMOUNT} -F ${files}
                            ;;

                        *)
                            note "Found $(distinct n ${num}) log files, that match pattern: $(distinct n ${pattern}). Attaching to all available files.."
                            ${TAIL_BIN} -F ${files}
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
            note "Sofin shell environment is: $(distinct n enabled${reset})"
        fi
        exit
        ;;


    l|installed|list)
        debug "Listing installed software alphabetically:"
        if [ -d ${SOFTWARE_DIR} ]; then
            ${FIND_BIN} ${SOFTWARE_DIR} -maxdepth 1 -mindepth 1 -type d  -not -name ".*" -print 2>/dev/null | \
            ${SED_BIN} -e 's#/.*/##' 2>/dev/null | ${SORT_BIN} 2>/dev/null
        fi
        exit
        ;;


    f|fullinstalled|fulllist|full)
        note "Installed applications (with dependencies):"
        if [ -d ${SOFTWARE_DIR} ]; then
            for app in ${SOFTWARE_DIR}*; do
                note
                app_name="$(${BASENAME_BIN} ${app} 2>/dev/null)"
                lowercase="$(lowercase ${app_name})"
                installed_file="${SOFTWARE_DIR}/${app_name}/${lowercase}${INSTALLED_MARK}"
                if [ -e "${installed_file}" ]; then
                    note "${SUCCESS_CHAR} ${app_name}"
                else
                    note "${red}${ERROR_CHAR} ${app_name} ${reset}[${red}!${reset}]"
                fi
                for req in $(${FIND_BIN} ${app} -maxdepth 1 -name *${INSTALLED_MARK} 2>/dev/null | ${SORT_BIN} 2>/dev/null); do
                    pp="$(${PRINTF_BIN} "$(${BASENAME_BIN} ${req} 2>/dev/null)" | ${SED_BIN} "s/${INSTALLED_MARK}//" 2>/dev/null)"
                    note "   ${NOTE_CHAR} ${pp} $(distinct lightgray "[")$(distinct n $(${CAT_BIN} ${req} 2>/dev/null))$(distinct lightgray "]")"
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
        process ${SOFTWARE_DIR}
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
        process ${SOFTWARE_DIR}
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
        process ${SOFTWARE_DIR}
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
        process ${SOFTWARE_DIR}
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
        create_cache_directories
        fail_on_background_sofin_job ${SOFIN_ARGS}
        note "Pushing binary bundle: $(distinct n ${SOFIN_ARGS}) to remote: $(distinct n ${MAIN_BINARY_REPOSITORY})"
        cd "${SOFTWARE_DIR}"
        for element in ${SOFIN_ARGS}; do
            lowercase_element="$(lowercase ${element})"
            install_indicator_file="${element}/${lowercase_element}${INSTALLED_MARK}"
            version_element="$(${CAT_BIN} "${install_indicator_file}" 2>/dev/null)"
            if [ -d "${element}" -a \
                 -f "${install_indicator_file}" -a \
                 ! -z "${version_element}" ]; then
                if [ ! -L "${element}" ]; then
                    if [ -z "${version_element}" ]; then
                        error "No version information available for bundle: $(distinct e "${element}")"
                    fi
                    name="${element}-${version_element}${DEFAULT_ARCHIVE_EXT}"
                    dig_query="$(${DIG_BIN} A ${MAIN_SOFTWARE_ADDRESS} 2>/dev/null | ${GREP_BIN} "^${MAIN_SOFTWARE_ADDRESS}" 2>/dev/null | ${AWK_BIN} '{print $5;}' 2>/dev/null)"
                    if [ -z "${dig_query}" ]; then
                        error "No mirrors found in address: $(distinct e ${MAIN_SOFTWARE_ADDRESS})"
                    fi
                    debug "Using defined mirror(s): $(distinct d "${dig_query}")"
                    for mirror in ${dig_query}; do
                        OS_TRIPPLE="$(os_tripple)"
                        system_path="${MAIN_SOFTWARE_PREFIX}/software/binary/${OS_TRIPPLE}"
                        address="${MAIN_USER}@${mirror}:${system_path}"
                        aname="$(lowercase ${APP_NAME}${APP_POSTFIX})"
                        ${SSH_BIN} -p "${MAIN_PORT}" "${MAIN_USER}@${mirror}" \
                            "${MKDIR_BIN} -p ${MAIN_SOFTWARE_PREFIX}/software/binary/${OS_TRIPPLE}" >> "${LOG}-${aname}" 2>> "${LOG}-${aname}"

                        if [ "${SYSTEM_NAME}" = "FreeBSD" ]; then # NOTE: feature designed for FBSD.
                            svcs_no_slashes="$(echo "${SERVICES_DIR}" | ${SED_BIN} 's/\///g' 2>/dev/null)"
                            inner_dir="$(${ZFS_BIN} list -H 2>/dev/null | ${GREP_BIN} "${element}$" 2>/dev/null | ${AWK_BIN} '{print $1;}' 2>/dev/null | ${SED_BIN} "s/.*${svcs_no_slashes}\///; s/\/.*//" 2>/dev/null)/"
                            certain_dataset="${SERVICES_DIR}${inner_dir}${element}"
                            full_dataset_name="${DEFAULT_ZPOOL}${certain_dataset}"
                            snap_file="${element}-${version_element}.${SERVICE_SNAPSHOT_POSTFIX}"
                            final_snap_file="${snap_file}${DEFAULT_ARCHIVE_EXT}"
                            snap_size="0"
                            note "Preparing service dataset: $(distinct n ${full_dataset_name}), for bundle: $(distinct n ${element})"
                            ${ZFS_BIN} list -H 2>/dev/null | ${GREP_BIN} "${element}\$" >/dev/null 2>&1
                            if [ "$?" = "0" ]; then # if dataset exists, unmount it, send to file, and remount back
                                ${ZFS_BIN} umount ${full_dataset_name} || error "ZFS umount failed for: $(distinct e "${full_dataset_name}"). Dataset shouldn't be locked nor used on build hosts."
                                ${ZFS_BIN} send "${full_dataset_name}" 2>> "${LOG}-aname" \
                                    | ${XZ_BIN} > "${final_snap_file}" && \
                                    snap_size="$(${STAT_BIN} -f%z "${final_snap_file}" 2>/dev/null)" && \
                                    ${ZFS_BIN} mount ${full_dataset_name} 2>> "${LOG}-aname" && \
                                    note "Stream file: $(distinct n ${final_snap_file}), of size: $(distinct n ${snap_size}) successfully sent to remote."
                            fi
                            if [ "${snap_size}" = "0" ]; then
                                ${RM_BIN} -f "${final_snap_file}"
                                note "Service dataset has no contents for bundle: $(distinct n ${element}-${version_element}), hence upload will be skipped"
                            fi
                        fi

                        build_software_bundle () {
                            if [ ! -e "./${name}" ]; then
                                ${TAR_BIN} -cJ --use-compress-program="${XZ_BIN} --threads=${CPUS}" -f "${name}" "./${element}" 2>> ${LOG} && \
                                    note "Bundle archive of: $(distinct n ${element}) (using: $(distinct n ${CPUS}) threads) has been built." && \
                                    break
                                ${TAR_BIN} -cJf "${name}" "./${element}" 2>> ${LOG} && \
                                    note "Bundle archive of: $(distinct n ${element}) has been built." && \
                                    break
                                error "Failed to create archives for: $(distinct e ${element})"
                            else
                                if [ ! -e "./${name}.sha1" ]; then
                                    debug "Found sha-less archive. It may be incomplete or damaged. Rebuilding (using: $(distinct d ${CPUS}) threads)"
                                    ${RM_BIN} -f "${name}"
                                    ${TAR_BIN} -cJ --use-compress-program="${XZ_BIN} --threads=${CPUS}" -f "${name}" "./${element}" 2>> ${LOG} || \
                                    ${TAR_BIN} -cJf "${name}" "./${element}" 2>> ${LOG} || \
                                        error "Failed to create archives for: $(distinct e ${element})"
                                    note "Archived bundle: $(distinct n "${element}") is ready to deploy"
                                else
                                    note "Archived bundle: $(distinct n "${element}") already exists, and will be reused to deploy"
                                fi
                            fi
                        }

                        store_checksum_bundle () {
                            if [ -z "${name}" ]; then
                                error "Empty archive name in function: $(distinct e "store_checksum_bundle()")!"
                            fi
                            archive_sha1="$(file_checksum "${name}")"
                            if [ -z "${archive_sha1}" ]; then
                                error "Empty checksum for archive: $(distinct e "${name}")"
                            fi
                            ${PRINTF_BIN} "${archive_sha1}" > "${name}.sha1" && \
                            debug "Stored checksum: $(distinct d ${archive_sha1}) for bundle file: $(distinct d "${name}")"
                            unset archive_sha1
                        }

                        build_software_bundle
                        store_checksum_bundle

                        ${CHMOD_BIN} a+r "${name}" "${name}.sha1" && \
                            debug "Set read access for archives: $(distinct d ${name}), $(distinct d ${name}.sha1) before we send them to public remote"

                        if [ "${SYSTEM_NAME}" = "Linux" ]; then
                            debug "Performing Linux specific additional copy of binary bundle"
                            ${MKDIR_BIN} -p /tmp/sofin-bundles/
                            ${CP_BIN} ${name} /tmp/sofin-bundles/
                            ${CP_BIN} ${name}.sha1 /tmp/sofin-bundles/
                        fi

                        shortsha="$(${CAT_BIN} "${name}.sha1" 2>/dev/null | ${CUT_BIN} -c -16 2>/dev/null)…"
                        note "Pushing archive #$(distinct n ${shortsha}) to remote repository.."
                        retry "${SCP_BIN} -P ${MAIN_PORT} ${name} ${address}/${name}.partial" || def_error "${name}" "Error sending: $(distinct e "${1}") bundle to: $(distinct e "${address}/${1}")"
                        if [ "$?" = "0" ]; then
                            ${SSH_BIN} -p ${MAIN_PORT} ${MAIN_USER}@${mirror} "cd ${MAIN_SOFTWARE_PREFIX}/software/binary/${OS_TRIPPLE} && ${MV_BIN} ${name}.partial ${name}"
                            retry "${SCP_BIN} -P ${MAIN_PORT} ${name}.sha1 ${address}/${name}.sha1" || def_error ${name}.sha1 "Error sending: $(distinct e ${name}.sha1) file to: $(distinct e "${address}/${1}")"
                        else
                            error "Failed to push binary build of: $(distinct e ${name}) to remote: $(distinct n ${MAIN_BINARY_REPOSITORY}${OS_TRIPPLE}/${name})"
                        fi

                        if [ "${SYSTEM_NAME}" = "FreeBSD" ]; then # NOTE: feature designed for FBSD.
                            if [ -f "${final_snap_file}" ]; then
                                system_path="${MAIN_SOFTWARE_PREFIX}/software/binary/${MAIN_COMMON_NAME}"
                                address="${MAIN_USER}@${mirror}:${system_path}"

                                ${SSH_BIN} -p ${MAIN_PORT} "${MAIN_USER}@${mirror}" \
                                    "cd ${MAIN_SOFTWARE_PREFIX}/software/binary; ${MKDIR_BIN} -p ${MAIN_COMMON_NAME} ; ${CHMOD_BIN} 755 ${MAIN_COMMON_NAME}"

                                debug "Setting common access to archive files before we send it: $(distinct d ${final_snap_file})"
                                ${CHMOD_BIN} a+r "${final_snap_file}"
                                debug "Sending initial service stream to $(distinct d ${MAIN_COMMON_NAME}) repository: $(distinct d ${MAIN_BINARY_REPOSITORY}${MAIN_COMMON_NAME}/${final_snap_file})"

                                retry "${SCP_BIN} -P ${MAIN_PORT} ${final_snap_file} ${address}/${final_snap_file}.partial"
                                if [ "$?" = "0" ]; then
                                    ${SSH_BIN} -p ${MAIN_PORT} "${MAIN_USER}@${mirror}" \
                                        "cd ${MAIN_SOFTWARE_PREFIX}/software/binary/${MAIN_COMMON_NAME} && ${MV_BIN} ${final_snap_file}.partial ${final_snap_file}"
                                else
                                    error "Failed to send service snapshot archive file: $(distinct e "${final_snap_file}") to remote host: $(distinct e "${MAIN_USER}@${mirror}")!"
                                fi
                            else
                                note "No service stream available for: $(distinct n ${element})"
                            fi
                        fi
                    done
                    ${RM_BIN} -f "${name}" "${name}.sha1" "${final_snap_file}"
                fi
            else
                warn "Not found software: ${element}!"
            fi
        done
        exit
        ;;

    b|build)
        create_cache_directories
        shift
        dependencies=$*
        note "Software bundles to be built: $(distinct n ${dependencies})"
        def_error () {
            error "Failure in build process. Report or fix the definition please!"
        }
        fail_on_background_sofin_job ${dependencies}

        export USE_UPDATE=NO
        export USE_BINBUILD=NO
        export APPLICATIONS="${dependencies}"
        ;;


    d|deploy)
        create_cache_directories
        shift
        dependencies=$*
        note "Software bundles to be built and deployed to remote: $(distinct n ${dependencies})"
        for software in ${dependencies}; do
            fail_on_background_sofin_job ${software}
            USE_BINBUILD=NO ${SOFIN_BIN} install ${software} || def_error "${software}" && \
            ${SOFIN_BIN} push ${software} || def_error "${software}" && \
            note "Software bundle deployed successfully: $(distinct n ${software})"
            note "$(fill)"
        done
        exit 0
        ;;


    reset)
        create_cache_directories
        cd ${DEFINITIONS_DIR}
        result="$(${GIT_BIN} reset --hard HEAD 2>> ${LOG})" && \
            note "State of definitions repository was reset to: $(distinct n "${result}")"
        for line in $(${GIT_BIN} status --short 2>/dev/null); do
            untracked_file="$(echo "${line}" | ${SED_BIN} -e 's/^?? //' 2>/dev/null)"
            ${FIND_BIN} "./${untracked_file}" -delete >> ${LOG} 2>> ${LOG} && \
                debug "Removed untracked file: $(distinct d "${untracked_file}")"
        done
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
                app_name="$(capitalize ${rawname})"
                to_rebuild="${app_name} ${to_rebuild}"
            fi
        done

        note "Will rebuild, wipe and push these bundles: $(distinct n ${to_rebuild})"
        for software in ${to_rebuild}; do
            if [ "${software}" = "Git" -o "${software}" = "Zsh" -o "${software}" = "Rsync" -o "${software}" = "Rsync-static" ]; then
                continue
            fi
            ${SOFIN_BIN} remove ${software}
            USE_BINBUILD=NO ${SOFIN_BIN} install ${software} || def_error "${software}"
            USE_FORCE=YES ${SOFIN_BIN} wipe ${software} || def_error "${software}"
            ${SOFIN_BIN} push ${software} || def_error "${software}"
        done
        exit
        ;;


    wipe)
        ANS="YES"
        if [ -z "${USE_FORCE}" ]; then
            warn "Are you sure you want to wipe binary bundles: $(distinct w ${SOFIN_ARGS}) from binary repository: $(distinct w ${MAIN_BINARY_REPOSITORY})? (Type $(distinct w YES) to confirm)"
            read ANS
        fi
        if [ "${ANS}" = "YES" ]; then
            cd "${SOFTWARE_DIR}"
            for element in ${SOFIN_ARGS}; do
                lowercase_element="$(lowercase ${element})"
                name="${element}-"
                dig_query="$(${DIG_BIN} A ${MAIN_SOFTWARE_ADDRESS} 2>/dev/null | ${GREP_BIN} "^${MAIN_SOFTWARE_ADDRESS}" 2>/dev/null | ${AWK_BIN} '{print $5;}' 2>/dev/null)"
                if [ ${OS_VERSION} -lt 10 ]; then
                    dig_query=$(${DIG_BIN} A ${MAIN_SOFTWARE_ADDRESS} 2>/dev/null | ${GREP_BIN} "^${MAIN_SOFTWARE_ADDRESS}" 2>/dev/null | ${AWK_BIN} '{print $5;}' 2>/dev/null)
                fi
                if [ -z "${dig_query}" ]; then
                    error "No mirrors found in address: $(distinct e ${MAIN_SOFTWARE_ADDRESS})"
                fi
                debug "Using defined mirror(s): $(distinct d "${dig_query}")"
                for mirror in ${dig_query}; do
                    OS_TRIPPLE="$(os_tripple)"
                    system_path="${MAIN_SOFTWARE_PREFIX}/software/binary/${OS_TRIPPLE}"
                    note "Wiping out remote: $(distinct n ${mirror}) binary archives: $(distinct n "${name}")"
                    ${SSH_BIN} -p ${MAIN_PORT} "${MAIN_USER}@${mirror}" \
                        "${FIND_BIN} ${system_path} -iname '${name}' -delete" >> "${LOG}" 2>> "${LOG}"
                done
            done
        else
            error "Aborted remote wipe of: $(distinct e "${SOFIN_ARGS}")"
        fi
        exit
        ;;


    delete|remove|uninstall|rm)
        if [ "$2" = "" ]; then
            error "Second argument with application name is required!"
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
            given_app_name="$(capitalize ${app})"
            if [ -d "${SOFTWARE_DIR}${given_app_name}" ]; then
                if [ "${given_app_name}" = "/" ]; then
                    error "Czy Ty orzeszki?"
                fi
                note "Removing software bundle: $(distinct n ${given_app_name})"
                aname="$(lowercase ${APP_NAME}${APP_POSTFIX})"
                ${RM_BIN} -rfv "${SOFTWARE_DIR}${given_app_name}" >> "${LOG}-${aname}"

                debug "Looking for other installed versions that might be exported automatically.."
                name="$(echo "${given_app_name}" | ${SED_BIN} 's/[0-9]*//g' 2>/dev/null)"
                alternative="$(${FIND_BIN} ${SOFTWARE_DIR} -maxdepth 1 -type d -name "${name}*" -not -name "${given_app_name}" 2>/dev/null | ${SED_BIN} 's/^.*\///g' 2>/dev/null | ${HEAD_BIN} -n1 2>/dev/null)"
                alt_lower="$(lowercase ${alternative})"
                debug "Alternative: ${alternative}, Given: ${given_app_name}, Alt_lower: ${alt_lower}, full: ${SOFTWARE_DIR}${alternative}/${alt_lower}${INSTALLED_MARK}"
                if [ ! -z "${alternative}" -a -f "${SOFTWARE_DIR}${alternative}/${alt_lower}${INSTALLED_MARK}" ]; then
                    note "Automatically picking first alternative already installed: $(distinct n ${alternative})"
                    export APPLICATIONS="${alternative}"
                    continue
                elif [ -z "${alternative}" ]; then
                    debug "No alternative: ${alternative} != ${given_app_name}"
                    export APPLICATIONS=""
                    continue
                fi
            else
                warn "Bundle: $(distinct w ${given_app_name}) not installed."
                export APPLICATIONS=""
                continue
            fi
        done
        ;;


    reload|rehash)
        update_shell_vars
        reload_zsh_shells
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
        APP="$(capitalize ${3})"
        for dir in "/bin/" "/sbin/" "/libexec/"; do
            debug "Looking into: $(distinct d ${SOFTWARE_DIR}${APP}${dir})"
            if [ -e "${SOFTWARE_DIR}${APP}${dir}${EXPORT}" ]; then
                note "Exporting binary: $(distinct n ${SOFTWARE_DIR}${APP}${dir}${EXPORT})"
                cd "${SOFTWARE_DIR}${APP}${dir}"
                ${MKDIR_BIN} -p "${SOFTWARE_DIR}${APP}/exports" # make sure exports dir already exists
                aname="$(lowercase ${APP})"
                ${LN_BIN} -vfs "..${dir}/${EXPORT}" "../exports/${EXPORT}" >> "${LOG}-${aname}"
                exit
            else
                debug "Export not found: $(distinct d ${SOFTWARE_DIR}${APP}${dir}${EXPORT})"
            fi
        done
        error "Nothing to export"
        ;;


    old|out|outdated|rusk)
        create_cache_directories
        if [ -d ${SOFTWARE_DIR} ]; then
            for prefix in $(${FIND_BIN} ${SOFTWARE_DIR} -mindepth 1 -maxdepth 1 -type d 2>/dev/null); do
                application="$(${BASENAME_BIN} "${prefix}" 2>/dev/null | ${TR_BIN} '[A-Z]' '[a-z]' 2>/dev/null)" # lowercase for case sensitive fs

                if [ ! -f "${prefix}/${application}${INSTALLED_MARK}" ]; then
                    warn "Bundle: $(distinct w ${application}) is not yet installed or damaged."
                    continue
                fi
                ver="$(${CAT_BIN} "${prefix}/${application}${INSTALLED_MARK}" 2>/dev/null)"
                if [ ! -f "${DEFINITIONS_DIR}${application}.def" ]; then
                    warn "No such bundle found: $(distinct w ${application})"
                    continue
                fi
                . "${DEFINITIONS_DIR}${application}.def"

                check_version () { # $1 => installed version, $2 => available version
                    if [ ! "${1}" = "" ]; then
                        if [ ! "${2}" = "" ]; then
                            if [ ! "${1}" = "${2}" ]; then
                                warn "Bundle: $(distinct w ${application}), version: $(distinct w ${2}) is definied, but installed version is: $(distinct w ${1})"
                                export outdated=YES
                            fi
                        fi
                    fi
                }

                check_version "${ver}" "${APP_VERSION}"
            done
        fi

        if [ "${outdated}" = "YES" ]; then
            exit 1
        else
            note "All installed bundles looks recent"
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
    application="$(lowercase ${application})"
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
            warn "No such definition found: $(distinct w ${application}). Alternatives found: $(distinct w ${contents})"
        else
            warn "No such definition found: $(distinct w ${application}). No alternatives found."
        fi
        exit
    fi
    . "${DEFINITIONS_DIR}${application}.def" # prevent installation of requirements of disabled application:
    check_disabled "${DISABLE_ON}" # after which just check if it's not disabled
    if [ ! "${ALLOW}" = "1" ]; then
        warn "Bundle: $(distinct w ${application}) disabled on architecture: $(distinct w $(os_tripple))"
        ${FIND_BIN} ${PREFIX} -delete >> ${LOG} 2>> ${LOG}
    else
        for definition in ${DEFINITIONS_DIR}${application}.def; do
            unset DONT_BUILD_BUT_DO_EXPORTS
            debug "Reading definition: $(distinct d ${definition})"
            . "${DEFAULTS}"
            . "${definition}"
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

            run () {
                if [ ! -z "$1" ]; then
                    aname="$(lowercase ${APP_NAME}${APP_POSTFIX})"
                    if [ ! -d "${LOGS_DIR}" ]; then
                        ${MKDIR_BIN} -p "${LOGS_DIR}"
                    fi
                    debug "tStamp: $(${DATE_BIN} +%s 2>/dev/null)\
                        Launching action: '$(distinct d $@)', for: $(distinct d ${aname})"
                    if [ -z "${aname}" ]; then
                        eval PATH="${PATH}" "$@" >> "${LOG}" 2>&1
                        check_command_result $? "$@"
                    else
                        eval PATH="${PATH}" "$@" >> "${LOG}-${aname}" 2>&1
                        check_command_result $? "$@"
                    fi
                else
                    error "An empty command to run?"
                fi
            }

            try () {
                if [ ! -z "$1" ]; then
                    aname="$(lowercase ${APP_NAME}${APP_POSTFIX})"
                    if [ ! -d "${LOGS_DIR}" ]; then
                        ${MKDIR_BIN} -p "${LOGS_DIR}"
                    fi
                    debug "$(${DATE_BIN} +%H%M%S-%s 2>/dev/null) try('$@'); aname(${aname});"
                    if [ -z "${aname}" ]; then
                        eval PATH="${PATH}" "$@" >> "${LOG}" 2>> "${LOG}"
                    else
                        eval PATH="${PATH}" "$@" >> "${LOG}-${aname}" 2>> "${LOG}-${aname}"
                    fi
                else
                    error "An empty command to run for: ${APP_NAME}?"
                fi
            }

            # binary build of whole software bundle
            ABSNAME="${APP_NAME}${APP_POSTFIX}-${APP_VERSION}"
            ${MKDIR_BIN} -p "${BINBUILDS_CACHE_DIR}${ABSNAME}"

            MIDDLE="$(os_tripple)"
            ARCHIVE_NAME="${APP_NAME}${APP_POSTFIX}-${APP_VERSION}${DEFAULT_ARCHIVE_EXT}"
            INSTALLED_INDICATOR="${PREFIX}/${APP_LOWER}${INSTALLED_MARK}"

            if [ "${SOFIN_CONTINUE_BUILD}" != "YES" ]; then # normal build by default
                if [ ! -e "${INSTALLED_INDICATOR}" ]; then
                    if [ ! -z "${USE_BINBUILD}" ]; then
                        debug "Binary build check was skipped"
                    else
                        aname="$(lowercase ${APP_NAME}${APP_POSTFIX})"
                        confirm () {
                            debug "Fetched archive: $(distinct d ${BINBUILDS_CACHE_DIR}${ABSNAME}/${ARCHIVE_NAME})"
                        }
                        if [ ! -e "${BINBUILDS_CACHE_DIR}${ABSNAME}/${ARCHIVE_NAME}" ]; then
                            cd ${BINBUILDS_CACHE_DIR}${ABSNAME}
                            try "${FETCH_BIN} ${MAIN_BINARY_REPOSITORY}${MIDDLE}/${ARCHIVE_NAME}.sha1" || \
                                try "${FETCH_BIN} ${MAIN_BINARY_REPOSITORY}${MIDDLE}/${ARCHIVE_NAME}.sha1"
                            if [ "$?" = "0" ]; then
                                $(try "${FETCH_BIN} ${MAIN_BINARY_REPOSITORY}${MIDDLE}/${ARCHIVE_NAME}" && confirm) || \
                                $(try "${FETCH_BIN} ${MAIN_BINARY_REPOSITORY}${MIDDLE}/${ARCHIVE_NAME}" && confirm) || \
                                $(try "${FETCH_BIN} ${MAIN_BINARY_REPOSITORY}${MIDDLE}/${ARCHIVE_NAME}" && confirm) || \
                                error "Failure fetching available binary build for: $(distinct e "${ARCHIVE_NAME}"). Please check your DNS / Network setup!"
                            else
                                note "No binary build available for: $(distinct n ${MIDDLE}/${APP_NAME}${APP_POSTFIX}-${APP_VERSION})"
                            fi

                            # checking archive sha1 checksum
                            if [ -e "./${ARCHIVE_NAME}" ]; then
                                note "Found binary build archive: $(distinct n "${ARCHIVE_NAME}")"
                                current_archive_sha1="$(file_checksum "${ARCHIVE_NAME}")"
                                debug "current_archive_sha1: ${current_archive_sha1}"
                            else
                                error "No bundle archive found?"
                            fi
                            current_sha_file="${BINBUILDS_CACHE_DIR}${ABSNAME}/${ARCHIVE_NAME}.sha1"
                            if [ -e "${current_sha_file}" ]; then
                                export sha1_value="$(${CAT_BIN} ${current_sha_file} 2>/dev/null)"
                            fi

                            debug "Checking SHA1 match: $(distinct d ${current_archive_sha1}) vs $(distinct d ${sha1_value})"
                            if [ "${current_archive_sha1}" != "${sha1_value}" ]; then
                                debug "Bundle archive checksum doesn't match, removing binary builds and proceeding into build phase"
                                ${RM_BIN} -fv ${ARCHIVE_NAME}
                                ${RM_BIN} -fv ${ARCHIVE_NAME}.sha1
                            fi
                        fi
                        cd "${SOFTWARE_DIR}"

                        debug "ARCHIVE_NAME: ${ARCHIVE_NAME}. Expecting binbuild to be available in: ${BINBUILDS_CACHE_DIR}${ABSNAME}/${ARCHIVE_NAME}"
                        if [ -e "${BINBUILDS_CACHE_DIR}${ABSNAME}/${ARCHIVE_NAME}" ]; then # if exists, then checksum is ok
                            ${TAR_BIN} -xJf "${BINBUILDS_CACHE_DIR}${ABSNAME}/${ARCHIVE_NAME}" >> "${LOG}-${aname}" 2>> "${LOG}-${aname}"
                            if [ "$?" = "0" ]; then # if archive is valid
                                note "Software bundle installed: $(distinct n ${APP_NAME}${APP_POSTFIX}), with version: $(distinct n ${APP_VERSION})"
                                export DONT_BUILD_BUT_DO_EXPORTS=YES
                            else
                                debug "  ${NOTE_CHAR} No binary bundle available for: $(distinct n ${APP_NAME}${APP_POSTFIX})"
                                ${RM_BIN} -fr "${BINBUILDS_CACHE_DIR}${ABSNAME}"
                            fi
                        else
                            debug "Binary build checksum doesn't match for: $(distinct n ${ABSNAME})"
                        fi
                    fi
                else
                    already_installed_version="$(${CAT_BIN} ${INSTALLED_INDICATOR} 2>/dev/null)"
                    if [ "${APP_VERSION}" = "${already_installed_version}" ]; then
                        note "$(distinct n ${APP_NAME}${APP_POSTFIX}) bundle is installed with version: $(distinct n ${already_installed_version})"
                    else
                        warn "$(distinct w ${APP_NAME}${APP_POSTFIX}) bundle is installed with version: $(distinct w ${already_installed_version}), but newer version is defined: $(distinct w "${APP_VERSION}")"
                    fi
                    export DONT_BUILD_BUT_DO_EXPORTS=YES
                fi

            else # continue build!
                note "Continuing build in: $(distinct n ${PREVIOUS_BUILD_DIR})"
                cd "${PREVIOUS_BUILD_DIR}"
            fi

            execute_process () {
                if [ -z "$1" ]; then
                    error "No param given for execute_process()!"
                fi
                req_definition_file="${DEFINITIONS_DIR}${1}.def"
                debug "Checking requirement: $1 file: $req_definition_file"
                if [ ! -e "${req_definition_file}" ]; then
                    error "Cannot fetch definition: $(distinct e ${req_definition_file})! Aborting!"
                fi

                debug "Setting up default system compiler"
                set_c_compiler CLANG # look for bundled compiler:

                . "${DEFAULTS}" # load definition and check for current version
                . "${req_definition_file}"
                check_disabled "${DISABLE_ON}" # check requirement for disabled state:

                if [ ! -z "${FORCE_GNU_COMPILER}" ]; then # force GNU compiler usage on definition side:
                    warn "   ${WARN_CHAR} GNU compiler set for: $(distinct n ${APP_NAME})"
                    set_c_compiler GNU
                fi

                # Golden linker causes troubles with some build systems like Qt, so we give option to disable it:
                if [ ! -z "${APP_NO_GOLDEN_LINKER}" ]; then
                    debug "Trying to disable golden linker.."
                    CROSS_PLATFORM_COMPILER_FLAGS="-fPIC -fno-strict-overflow -fstack-protector-all"
                    DEFAULT_LDFLAGS="-fPIC -fPIE"
                    unset NM
                    unset LD
                    unset CFLAGS
                    unset CXXFLAGS
                    unset LDFLAGS
                fi

                if [ ! -z "${APP_NO_FAST_MATH}" ]; then
                    debug "Trying to disable fast math option"
                    CROSS_PLATFORM_COMPILER_FLAGS="$(echo "${CROSS_PLATFORM_COMPILER_FLAGS}" | ${SED_BIN} -e 's/-ffast-math//' 2>/dev/null)"
                    DEFAULT_COMPILER_FLAGS="$(echo "${DEFAULT_COMPILER_FLAGS}" | ${SED_BIN} -e 's/-ffast-math//' 2>/dev/null)"
                    CFLAGS="$(echo "${CFLAGS}" | ${SED_BIN} -e 's/-ffast-math//' 2>/dev/null)"
                    CXXFLAGS="$(echo "${CXXFLAGS}" | ${SED_BIN} -e 's/-ffast-math//' 2>/dev/null)"
                fi

                if [ -z "${APP_NO_CCACHE}" ]; then # ccache is supported by default but it's optional
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
                        export CFLAGS="${CFLAGS} -Wl,-rpath=${PREFIX}/lib,--enable-new-dtags"
                        export CXXFLAGS="${CXXFLAGS} -Wl,-rpath=${PREFIX}/lib,--enable-new-dtags"
                        export LDFLAGS="${LDFLAGS} -Wl,-rpath=${PREFIX}/lib,--enable-new-dtags"
                    fi
                fi

                if [ "${ALLOW}" = "1" ]; then
                    if [ -z "${APP_HTTP_PATH}" ]; then
                        definition_file_no_ext="\
                            $(echo "$(${BASENAME_BIN} ${req_definition_file} 2>/dev/null)" | \
                            ${SED_BIN} -e 's/\..*$//g' 2>/dev/null)"
                        note "   ${NOTE_CHAR2} $(distinct n "APP_HTTP_PATH=\"\"") is undefined for: $(distinct n "${definition_file_no_ext}")."
                        note "NOTE: It's only valid for meta bundles. You may consider setting: $(distinct n "APP_CONFIGURE_SCRIPT=\"meta\"") in bundle definition file. Type: $(distinct n "s dev ${definition_file_no_ext}"))"
                    else
                        CUR_DIR="$(${PWD_BIN} 2>/dev/null)"
                        if [ -z "${SOFIN_CONTINUE_BUILD}" ]; then
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
                                    note "   ${NOTE_CHAR} Fetching requirement source from: $(distinct n ${APP_HTTP_PATH})"
                                    retry "${FETCH_BIN} ${APP_HTTP_PATH}"
                                    ${MV_BIN} $(${BASENAME_BIN} ${APP_HTTP_PATH} 2>/dev/null) ${BUILD_DIR_ROOT}/..
                                fi

                                file="${BUILD_DIR_ROOT}/../$(${BASENAME_BIN} ${APP_HTTP_PATH} 2>/dev/null)"
                                debug "Build dir: ${BUILD_DIR_ROOT}, file: ${file}"
                                if [ "${APP_SHA}" = "" ]; then
                                    error "${NOTE_CHAR} Missing SHA sum for source: ${file}."
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
                                        debug "${NOTE_CHAR} Bundle checksum is fine."
                                    else
                                        warn "${WARN_CHAR} ${cur} vs ${APP_SHA}"
                                        warn "${WARN_CHAR} Bundle checksum mismatch detected!"
                                        warn "${WARN_CHAR} Removing corrupted file from cache: '${file}' and retrying."
                                        # remove corrupted file
                                        ${RM_BIN} -f "${file}"
                                        # and restart script with same arguments:
                                        debug "Evaluating: ${SOFIN_BIN} ${SOFIN_ARGS_FULL}"
                                        eval "${SOFIN_BIN} ${SOFIN_ARGS_FULL}"
                                        exit
                                    fi
                                fi

                                note "   ${NOTE_CHAR} Unpacking source code of: $(distinct n ${APP_NAME})"
                                debug "Build dir root: ${BUILD_DIR_ROOT}"
                                try "${TAR_BIN} -xf ${file}" || \
                                try "${TAR_BIN} -xfj ${file}" || \
                                run "${TAR_BIN} -xfJ ${file}"
                            else
                                # git method:
                                # .cache/git-cache => git bare repos
                                ${MKDIR_BIN} -p ${GIT_CACHE_DIR}
                                app_cache_dir="${GIT_CACHE_DIR}${APP_NAME}${APP_VERSION}.git"
                                note "   ${NOTE_CHAR} Fetching git repository: $(distinct n ${APP_HTTP_PATH}${reset})"
                                try "${GIT_BIN} clone --depth 1 --bare ${APP_HTTP_PATH} ${app_cache_dir}" || \
                                try "${GIT_BIN} clone --depth 1 --bare ${APP_HTTP_PATH} ${app_cache_dir}" || \
                                try "${GIT_BIN} clone --depth 1 --bare ${APP_HTTP_PATH} ${app_cache_dir}"
                                if [ "$?" = "0" ]; then
                                    debug "Fetched bare repository: ${APP_NAME}${APP_VERSION}"
                                else
                                    if [ ! -d "${app_cache_dir}/branches" -a ! -f "${app_cache_dir}/config" ]; then
                                        note "\n${red}Definitions were not updated. Below displaying $(distinct n ${LOG_LINES_AMOUNT_ON_ERR}) lines of internal log:${reset}"
                                        ${TAIL_BIN} -n${LOG_LINES_AMOUNT_ON_ERR} ${LOG} 2>/dev/null
                                        note "$(fill)"
                                    else
                                        current="$(${PWD_BIN} 2>/dev/null)"
                                        debug "Trying to update existing bare repository cache in: ${app_cache_dir}"
                                        cd "${app_cache_dir}"
                                        try "${GIT_BIN} fetch origin ${APP_GIT_CHECKOUT}" || \
                                        try "${GIT_BIN} fetch origin" || \
                                        warn "   ${WARN_CHAR} Failed to fetch an update from bare repository: $(distinct n ${app_cache_dir})"
                                        # for empty APP_VERSION it will fill it with first 16 chars of repository HEAD SHA1:
                                        if [ -z "${APP_VERSION}" ]; then
                                            APP_VERSION="$(${GIT_BIN} rev-parse HEAD 2>/dev/null | ${CUT_BIN} -c -16 2>/dev/null)"
                                        fi
                                        cd "${current}"
                                    fi
                                fi
                                # bare repository is already cloned, so we just clone from it now..
                                run "${GIT_BIN} clone ${app_cache_dir} ${APP_NAME}${APP_VERSION}" && \
                                debug "Cloned git respository from git bare cache repository"
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
                                note "   ${NOTE_CHAR} Checking out: $(distinct n ${APP_GIT_CHECKOUT})"
                                run "${GIT_BIN} checkout -b ${APP_GIT_CHECKOUT}"
                            fi

                            if [ ! -z "${APP_AFTER_UNPACK_CALLBACK}" ]; then
                                debug "Running after unpack callback"
                                run "${APP_AFTER_UNPACK_CALLBACK}"
                            fi

                            aname="$(lowercase ${APP_NAME}${APP_POSTFIX})"
                            LIST_DIR="${DEFINITIONS_DIR}patches/$1" # $1 is definition file name
                            if [ -d "${LIST_DIR}" ]; then
                                patches_files="$(${FIND_BIN} ${LIST_DIR}/* -maxdepth 0 -type f 2>/dev/null)"
                                ${TEST_BIN} ! -z "${patches_files}" && \
                                note "   ${NOTE_CHAR} Applying common patches for: $(distinct n ${APP_NAME}${APP_POSTFIX})"
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
                                    note "   ${NOTE_CHAR} Applying platform specific patches for: $(distinct n ${APP_NAME}${APP_POSTFIX}/${SYSTEM_NAME})"
                                    patches_files="$(${FIND_BIN} ${pspatch_dir}/* -maxdepth 0 -type f 2>/dev/null)"
                                    ${TEST_BIN} ! -z "${patches_files}" && \
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

                            note "   ${NOTE_CHAR} Configuring: $(distinct n $1), version: $(distinct n ${APP_VERSION})"
                            case "${APP_CONFIGURE_SCRIPT}" in

                                ignore)
                                    note "   ${NOTE_CHAR} Configuration skipped for definition: $(distinct n $1)"
                                    ;;

                                no-conf)
                                    note "   ${NOTE_CHAR} No configuration for definition: $(distinct n $1)"
                                    export APP_MAKE_METHOD="${APP_MAKE_METHOD} PREFIX=${PREFIX}"
                                    export APP_INSTALL_METHOD="${APP_INSTALL_METHOD} PREFIX=${PREFIX}"
                                    ;;

                                binary)
                                    note "   ${NOTE_CHAR} Prebuilt definition of: $(distinct n $1)"
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
                        note "   ${NOTE_CHAR} Building requirement: $(distinct n $1)"
                        run "${APP_MAKE_METHOD}"
                        if [ ! -z "${APP_AFTER_MAKE_CALLBACK}" ]; then
                            debug "Running after make callback"
                            run "${APP_AFTER_MAKE_CALLBACK}"
                        fi

                        debug "Cleaning man dir from previous dependencies, we want to install man pages that belong to LAST requirement which is app bundle itself"
                        for place in man share/man share/info share/doc share/docs; do
                            ${FIND_BIN} "${PREFIX}/${place}" -delete 2>/dev/null
                        done

                        note "   ${NOTE_CHAR} Installing requirement: $(distinct n $1)"
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
                    warn "   ${WARN_CHAR} Requirement: $(distinct w ${APP_NAME})disabled on: $(distinct n ${SYSTEM_NAME})"
                    if [ ! -d "${PREFIX}" ]; then # case when disabled requirement is first on list of dependencies
                        ${MKDIR_BIN} -p "${PREFIX}"
                    fi
                    ${TOUCH_BIN} "${PREFIX}/${req}${INSTALLED_MARK}"
                    ${PRINTF_BIN} "os-default" > "${PREFIX}/${req}${INSTALLED_MARK}"
                fi
            }

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

            mark () {
                debug "Marking definition: ${application} installed"
                ${TOUCH_BIN} "${PREFIX}/${application}${INSTALLED_MARK}"
                debug "Writing version: ${APP_VERSION} of app: '${application}' installed in: ${PREFIX}"
                ${PRINTF_BIN} "${APP_VERSION}" > "${PREFIX}/${application}${INSTALLED_MARK}"
            }

            show_done () {
                ver="$(${CAT_BIN} "${PREFIX}/${application}${INSTALLED_MARK}" 2>/dev/null)"
                note "${SUCCESS_CHAR} ${application} [$(distinct n ${ver})]\n"
            }

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
                        debug "${SUCCESS_CHAR} ${application} current: ${ver}, definition: [${APP_VERSION}] Ok."
                    fi
                else
                    note "  ${application} ($(distinct n 1) of $(distinct n ${req_all}))"
                    execute_process "${application}"
                    mark
                    note "${SUCCESS_CHAR} ${application} [$(distinct n ${APP_VERSION})]\n"
                fi
            fi

            debug "Doing app conflict resolve"
            if [ ! -z "${APP_CONFLICTS_WITH}" ]; then
                debug "  ${NOTE_CHAR} Resolving possible conflicts with: ${APP_CONFLICTS_WITH}"
                for app in ${APP_CONFLICTS_WITH}; do
                    maybe_software="$(${FIND_BIN} ${SOFTWARE_DIR} -maxdepth 1 -type d -iname "${app}*" 2>/dev/null)"
                    for an_app in ${maybe_software}; do
                        app_name="$(${BASENAME_BIN} ${an_app} 2>/dev/null)"
                        if [ -e "${an_app}/exports" \
                             -a "${app_name}" != "${APP_NAME}" \
                             -a "${app_name}" != "${APP_NAME}${APP_POSTFIX}" \
                        ]; then
                            ${MV_BIN} "${an_app}/exports" "${an_app}/exports-disabled" && \
                                note "Resolved conflict with: $(distinct n ${app_name})"
                        fi
                    done
                done
            fi

            . "${DEFINITIONS_DIR}${application}.def"
            if [ -d "${PREFIX}/exports-disabled" ]; then # just bring back disabled exports
                debug "Moving ${PREFIX}/exports-disabled to ${PREFIX}/exports"
                ${MV_BIN} "${PREFIX}/exports-disabled" "${PREFIX}/exports"
            fi
            if [ -z "${APP_EXPORTS}" ]; then
                note "  ${NOTE_CHAR} Defined no binaries to export of prefix: $(distinct n ${PREFIX})"
            else
                aname="$(lowercase ${APP_NAME}${APP_POSTFIX})"
                amount="$(echo "${APP_EXPORTS}" | ${WC_BIN} -w 2>/dev/null | ${TR_BIN} -d '\t|\r|\ ' 2>/dev/null)"
                note "Exporting $(distinct n ${amount}) binaries of prefix: $(distinct n ${PREFIX})"
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
            debug "Executing APP_AFTER_EXPORT_CALLBACK: $(distinct d "${APP_AFTER_EXPORT_CALLBACK}")"
            run "${APP_AFTER_EXPORT_CALLBACK}"
        fi

        if [ "${APP_CLEAN_USELESS}" = "YES" ]; then
            for pattern in ${APP_USELESS} ${APP_DEFAULT_USELESS}; do
                if [ ! -z "${PREFIX}" ]; then
                    debug "Pattern: $(distinct d ${pattern})"
                    ${RM_BIN} -rf ${PREFIX}/${pattern}
                fi
            done
            for dir in bin sbin libexec; do
                if [ -d "${PREFIX}/${dir}" ]; then
                    ALL_BINS=$(${FIND_BIN} ${PREFIX}/${dir} -maxdepth 1 -type f -or -type l 2>/dev/null)
                    for file in ${ALL_BINS}; do
                        base="$(${BASENAME_BIN} ${file} 2>/dev/null)"
                        if [ -e "${PREFIX}/exports/${base}" ]; then
                            debug "Found export: $(distinct d ${base})"
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
                                debug "Removing useless file: $(distinct d ${file})"
                                ${RM_BIN} -f "${file}"
                            else
                                debug "Useful file left intact: $(distinct d ${file})"
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
                note "Clean completed, $(distinct n ${result}) files were stripped"
            else
                warn "Debug build is enabled. Strip skipped"
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
                    ${MKDIR_BIN} -p "${SERVICE_DIR}/etc" "${SERVICE_DIR}/var" && \
                        note "Prepared service directory: $(distinct n ${SERVICE_DIR})"
                fi

                # count Sofin jobs. For more than one job available,
                sofin_ps_list="$(sofin_processes | ${EGREP_BIN} "sh ${SOFIN_BIN} (${ALL_INSTALL_PHRASES}) [A-Z].*" 2>/dev/null)"
                debug "Sofin ps list: $(echo "${sofin_ps_list}" | ${TR_BIN} '\n' ' ' 2>/dev/null)"
                sofins_all="$(echo "${sofin_ps_list}" | ${WC_BIN} -l 2>/dev/null | ${SED_BIN} 's/ //g' 2>/dev/null)"
                sofins_running="$(echo "${sofins_all} - 1" | ${BC_BIN} 2>/dev/null)"
                test -z "${sofins_running}" && sofins_running="0"
                export jobs_in_parallel="NO"
                if [ ${sofins_running} -gt 1 ]; then
                    note "Found: $(distinct n ${sofins_running}) running Sofin instances. Parallel jobs not allowed"
                    export jobs_in_parallel="YES"
                else
                    note "Parallel jobs allowed. Traversing several datasets at once.."
                fi

                # Create a dataset for any existing dirs in Services dir that are not ZFS datasets.
                all_dirs="$(${FIND_BIN} ${SERVICES_DIR} -mindepth 1 -maxdepth 1 -type d -not -name '.*' -print 2>/dev/null | ${XARGS_BIN} ${BASENAME_BIN} 2>/dev/null)"
                debug "Checking for non-dataset directories in ${SERVICES_DIR}: EOF:\n$(echo "${all_dirs}" | ${TR_BIN} '\n' ' ' 2>/dev/null)\nEOF\n"
                full_bundle_name="$(${BASENAME_BIN} "${PREFIX}" 2>/dev/null)"
                for maybe_dataset in ${all_dirs}; do
                    aname="$(lowercase ${full_bundle_name})"
                    app_name_lowercase="$(lowercase ${maybe_dataset})"
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
                                note "Dataset: $(distinct n ${dataset_name} )$(${XZCAT_BIN} "${final_snap_file}" | ${ZFS_BIN} receive -v "${dataset_name}" 2>/dev/null | ${TAIL_BIN} -n1)"
                                ${ZFS_BIN} rename ${dataset_name}@--head-- @origin && \
                                debug "Cleaning snapshot file: ${final_snap_file}, after successful receive"
                                ${RM_BIN} -f "${final_snap_file}"
                            else
                                debug "Initial service dataset unavailable"
                                ${ZFS_BIN} create "${dataset_name}" 2>/dev/null && \
                                note "Created an empty service dataset for: $(distinct n ${dataset_name})"
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

        if [ ! -z "${APP_APPLE_BUNDLE}" ]; then
            APP_LOWERNAME="${APP_NAME}"
            APP_NAME="$(${PRINTF_BIN} "${APP_NAME}" | ${CUT_BIN} -c1 2>/dev/null | ${TR_BIN} '[a-z]' '[A-Z]' 2>/dev/null)$(${PRINTF_BIN} "${APP_NAME}" | ${SED_BIN} 's/^[a-zA-Z]//' 2>/dev/null)"
            APP_BUNDLE_NAME="${PREFIX}.app"
            aname="$(lowercase ${APP_NAME}${APP_POSTFIX})"
            note "Creating Apple bundle: $(distinct n ${APP_NAME} )in: $(distinct n ${APP_BUNDLE_NAME})"
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

            note "Creating relative libraries search path"
            cd ${APP_BUNDLE_NAME}

            note "Processing exported binary: $(distinct n ${i})"
            ${SOFIN_LIBBUNDLE_BIN} -x "${APP_BUNDLE_NAME}/Contents/MacOS/${APP_LOWERNAME}" >> ${LOG}-${aname} 2>&1

        fi

    fi
done


update_shell_vars
reload_zsh_shells

exit
