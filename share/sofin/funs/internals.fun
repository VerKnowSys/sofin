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
    note "  $(distinct n "log                                  ") shows tail of all logs (for debug messages and verbose info)"
    note "  $(distinct n "log -                                ") shows tail of Sofin internal log only"
    note "  $(distinct n "log +                                ") shows and watches all recently modified files"
    note "  $(distinct n "log any-part-of-def-name             ") shows and watches log(s) which name matches pattern"
    note "  $(distinct n "reload | rehash                      ") recreates shell vars and reloads current shell"
    note "  $(distinct n "update                               ") only update definitions from remote repository and exit"
    note "  $(distinct n "ver | version                        ") shows ${SOFIN_BIN_SHORT} script version"
    note "  $(distinct n "clean                                ") cleans binbuilds cache, unpacked source content and logs"
    note "  $(distinct n "distclean                            ") cleans binbuilds cache, unpacked source content, logs and definitions"
    note "  $(distinct n "purge                                ") cleans binbuilds cache, unpacked source content, logs, definitions, source cache and possible states"
    note "  $(distinct n "outdated                             ") lists outdated software"
    note "  $(distinct n "build                                ") does binary build from source for software specified as params"
    # note "  $(distinct n "continue Bundlename                  ") continues build from \"make stage\" of bundle name, given as param (previous build dir reused)"
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
}


write_info_about_shell_configuration () {
    warn "$(distinct n SHELL_PID) has no value (normally contains pid of current shell)"
    warn "Shell auto reload function is disabled for this session"
}


sofin_header () {
    ${PRINTF_BIN} "$(distinct n 'Sof')tware $(distinct n 'In')staller v$(distinct n ${SOFIN_VERSION}) -- (c) 2o11-2o16 -- Daniel ($(distinct n dmilith)) Dettlaff\n\
"
}


processes_all () {
    ${PS_BIN} ${PS_DEFAULT_OPTS} 2>/dev/null | ${EGREP_BIN} -v "(grep|egrep)" 2>/dev/null
}


processes_all_sofin () {
    processes_all | ${EGREP_BIN} "${SOFIN_BIN}" 2>/dev/null
}


# processes_installing () {
#     filter="$1"
#     if [ -z "${filter}" ]; then # general case
#         general_matcher="[A-Z0-9]+[a-z0-9]*"
#         matcher=""
#         for phrase in i install get pick choose use switch p push binpush send b build d deploy; do
#             if [ -z "${matcher}" ]; then
#                 matcher="(${SOFIN_BIN} ${phrase} ${general_matcher}"
#             else
#                 matcher="${matcher}|${SOFIN_BIN} ${phrase} ${general_matcher}"
#             fi
#         done
#         matcher="${matcher})"
#     else
#         general_matcher="${filter}"
#         matcher=""
#         for phrase in i install get pick choose use switch p push binpush send b build d deploy; do
#             if [ -z "${matcher}" ]; then
#                 matcher="(${SOFIN_BIN} ${phrase} ${general_matcher}"
#             else
#                 matcher="${matcher}|${SOFIN_BIN} ${phrase} ${general_matcher}"
#             fi
#         done
#         matcher="${matcher})"
#     fi
#     debug "processes_installing-matcher: /${matcher}/"
#     processes_all_sofin | ${EGREP_BIN} "${matcher}" 2>/dev/null
# }


get_shell_vars () {
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

    setup_sofin_compiler

    ${PRINTF_BIN} "# CC:\nexport CC='${CC}'\n\n"
    ${PRINTF_BIN} "# CXX:\nexport CXX='${CXX}'\n\n"
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
}


list_bundles_full () {
    note "Installed software bundles (with dependencies):"
    if [ -d ${SOFTWARE_DIR} ]; then
        for app in ${SOFTWARE_DIR}*; do
            note
            app_name="$(${BASENAME_BIN} ${app} 2>/dev/null)"
            lowercase="$(lowercase ${app_name})"
            installed_file="${SOFTWARE_DIR}/${app_name}/${lowercase}${INSTALLED_MARK}"
            if [ -e "${installed_file}" ]; then
                note "${SUCCESS_CHAR} ${app_name}"
            else
                note "${red}${FAIL_CHAR} ${app_name} ${reset}[${red}!${reset}]"
            fi
            for req in $(${FIND_BIN} ${app} -maxdepth 1 -name *${INSTALLED_MARK} 2>/dev/null | ${SORT_BIN} 2>/dev/null); do
                pp="$(${PRINTF_BIN} "$(${BASENAME_BIN} ${req} 2>/dev/null)" | ${SED_BIN} "s/${INSTALLED_MARK}//" 2>/dev/null)"
                note "   ${NOTE_CHAR} ${pp} $(distinct "${gray}" "[")$(distinct n $(${CAT_BIN} ${req} 2>/dev/null))$(distinct "${gray}" "]")"
            done
        done
    fi
}


show_diff () {
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
}


develop () {
    create_cache_directories
    if [ -z "${2}" ]; then
        error "No definition file name specified."
    fi
    note "Paste your definition below. Hit ctrl-d after a newline to commit"
    ${CAT_BIN} > ${DEFINITIONS_DIR}/${2}.def 2>/dev/null
}


enable_sofin_env () {
    ${RM_BIN} -f ${SOFIN_DISABLED_INDICATOR_FILE}
    update_shell_vars
    if [ -z "${SHELL_PID}" ]; then
        note "Enabled Sofin environment, yet no SHELL_PID defined. Autoreload skipped."
    else
        note "Enabled Sofin environment. Reloading shell"
        ${KILL_BIN} -SIGUSR2 ${SHELL_PID} >/dev/null 2>&1
    fi
}


disable_sofin_env () {
    ${TOUCH_BIN} ${SOFIN_DISABLED_INDICATOR_FILE}
    update_shell_vars
    if [ -z "${SHELL_PID}" ]; then
        note "Disabled Sofin environment, yet no SHELL_PID defined. Autoreload skipped."
    else
        note "Disabled Sofin environment. Reloading shell"
        ${KILL_BIN} -SIGUSR2 ${SHELL_PID} 2>/dev/null 2>&1
    fi
}


sofin_status () {
    if [ -f ${SOFIN_DISABLED_INDICATOR_FILE} ]; then
        note "Sofin shell environment is: ${red}disabled${reset}"
    else
        note "Sofin shell environment is: $(distinct n enabled${reset})"
    fi
}


list_bundles_alphabetic () {
    if [ -d "${SOFTWARE_DIR}" ]; then
        debug "Listing installed software bundles in alphabetical order."
        ${FIND_BIN} ${SOFTWARE_DIR} -maxdepth 1 -mindepth 1 -type d  -not -name ".*" -print 2>/dev/null | \
        ${SED_BIN} -e 's#/.*/##' 2>/dev/null | ${SORT_BIN} 2>/dev/null
    fi
}


mark () {
    debug "Marking definition: $(distinct d ${application}) as installed"
    ${TOUCH_BIN} "${PREFIX}/${application}${INSTALLED_MARK}"
    debug "Writing version: $(distinct d ${APP_VERSION}) of software: $(distinct d ${application}) installed in: $(distinct d ${PREFIX})"
    ${PRINTF_BIN} "${APP_VERSION}" > "${PREFIX}/${application}${INSTALLED_MARK}"
}


show_done () {
    ver="$(${CAT_BIN} "${PREFIX}/${application}${INSTALLED_MARK}" 2>/dev/null)"
    note "${SUCCESS_CHAR} ${application} [$(distinct n ${ver})]\n"
}


create_or_receive () {
    dataset_name="$1"
    remote_path="${MAIN_BINARY_REPOSITORY}${MAIN_COMMON_NAME}/${final_snap_file}"
    debug "Seeking remote snapshot existence: $(distinct d ${remote_path})"
    try "${FETCH_BIN} ${remote_path}" || \
    try "${FETCH_BIN} ${remote_path}" || \
    try "${FETCH_BIN} ${remote_path}"
    if [ "$?" = "0" ]; then
        debug "Stream archive available. Creating service dataset: $(distinct d ${dataset_name}) from file stream: $(distinct d ${final_snap_file})"
        note "Dataset: $(distinct n ${dataset_name}) - $(${XZCAT_BIN} "${final_snap_file}" | ${ZFS_BIN} receive -v "${dataset_name}" 2>/dev/null | ${TAIL_BIN} -n1)"
        ${ZFS_BIN} rename ${dataset_name}@--head-- @origin >> ${LOG} 2>> ${LOG} && \
        debug "Cleaning snapshot file: $(distinct d ${final_snap_file}), after successful receive"
        ${RM_BIN} -f "${final_snap_file}"
    else
        debug "Initial service dataset unavailable"
        ${ZFS_BIN} create "${dataset_name}" >> ${LOG} 2>> ${LOG} && \
        note "Created an empty service dataset for: $(distinct n ${dataset_name})"
    fi
}
