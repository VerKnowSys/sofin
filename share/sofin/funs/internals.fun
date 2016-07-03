usage_howto () {
    note "Built in tasks:"
    note "  $(distinct n "install | get | pick | choose | use  ") installs software from list or from definition and switches exports for it (example: ${SOFIN_BIN_SHORT} install Rubinius)"
    note "  $(distinct n "dependencies | deps | local          ") installs software from list defined in '$(distinct n ${DEPENDENCIES_FILE})' file in current directory"
    note "  $(distinct n "uninstall | remove | delete          ") removes an application or list (example: ${SOFIN_BIN_SHORT} uninstall Rubinius)"
    note "  $(distinct n "list | installed                     ") gives short list of installed software"
    note "  $(distinct n "full | fulllist | fullinstalled      ") gives detailed list with installed software including requirements"
    note "  $(distinct n "available | avail                    ") lists available software"
    note "  $(distinct n "export | exp | exportapp             ") adds given command to application exports (example: ${SOFIN_BIN_SHORT} export rails Rubinius)"
    note "  $(distinct n "getshellvars | shellvars | vars      ") returns shell variables for installed software"
    note "  $(distinct n "log                                  ") shows tail of all logs (for debug messages and verbose info)"
    note "  $(distinct n "log -                                ") shows tail of Sofin internal log only"
    note "  $(distinct n "log +                                ") shows and watches all recently modified files"
    note "  $(distinct n "log any-part-of-def-name             ") shows and watches log(s) which name matches pattern"
    note "  $(distinct n "reload | rehash                      ") recreates shell vars and reloads current shell"
    note "  $(distinct n "up | update                          ") only update definitions from remote repository and exit"
    note "  $(distinct n "ver | version                        ") shows ${SOFIN_BIN_SHORT} script version"
    note "  $(distinct n "clean                                ") cleans binbuilds cache, unpacked source content and logs"
    note "  $(distinct n "distclean                            ") cleans binbuilds cache, unpacked source content, logs and definitions"
    note "  $(distinct n "purge                                ") cleans binbuilds cache, unpacked source content, logs, definitions, source cache and possible states"
    note "  $(distinct n "out | outdated                       ") lists outdated software"
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
    if [ "${USER}" != "root" ]; then
        process ${SOFTWARE_DIR}
    fi

    # LD_LIBRARY_PATH, LDFLAGS, PKG_CONFIG_PATH:
    # ldresult="/lib:/usr/lib"
    pkg_config_path="."
    ldflags="${LDFLAGS} ${DEFAULT_LDFLAGS}"
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
    if [ "${USER}" != "root" ]; then
        process ${SOFTWARE_DIR}
    fi

    # CFLAGS, CXXFLAGS:
    cflags="${COMMON_COMPILER_FLAGS}"
    process () {
        for app in ${1}*; do
            exp="${app}/include"
            if [ -e "${exp}" ]; then
                cflags="-I${exp} ${cflags}"
            fi
        done
    }
    process ${SOFTWARE_DIR}
    if [ "${USER}" != "root" ]; then
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
    if [ "${USER}" != "root" ]; then
        process ${SOFTWARE_DIR}
    fi

    ${PRINTF_BIN} "# PATH:\nexport PATH=\"$(echo "${result}" | eval ${CUT_TRAILING_SPACES_GUARD})\"\n\n"

    compiler_setup "silent"

    ${PRINTF_BIN} "# CC:\nexport CC='${CC}'\n\n"
    ${PRINTF_BIN} "# CXX:\nexport CXX='${CXX}'\n\n"
    ${PRINTF_BIN} "# CPP:\nexport CPP='${CPP}'\n\n"

    if [ -f "${SOFIN_ENV_DISABLED_INDICATOR_FILE}" ]; then # sofin disabled. Default system environment
        ${PRINTF_BIN} "# CFLAGS:\nexport CFLAGS=''\n\n"
        ${PRINTF_BIN} "# CXXFLAGS:\nexport CXXFLAGS=''\n\n"
        ${PRINTF_BIN} "# LDFLAGS:\nexport LDFLAGS=''\n\n"

    else # sofin environment override enabled, Default behavior:
        ${PRINTF_BIN} "# CFLAGS:\nexport CFLAGS='$(echo "${cflags}" | eval ${CUT_TRAILING_SPACES_GUARD})'\n\n"
        ${PRINTF_BIN} "# CXXFLAGS:\nexport CXXFLAGS='$(echo "${cxxflags}" | eval ${CUT_TRAILING_SPACES_GUARD})'\n\n"

        ${PRINTF_BIN} "# LDFLAGS:\nexport LDFLAGS='$(echo "${ldflags}" | eval ${CUT_TRAILING_SPACES_GUARD})'\n\n"
    fi

    # common
    ${PRINTF_BIN} "# PKG_CONFIG_PATH:\nexport PKG_CONFIG_PATH='$(echo "${pkg_config_path}" | eval ${CUT_TRAILING_SPACES_GUARD})'\n\n"
    ${PRINTF_BIN} "# MANPATH:\nexport MANPATH='$(echo "${manpath}" | eval ${CUT_TRAILING_SPACES_GUARD})'\n\n"

    unset result cflags cxxflags ldflags pkg_config_path manpath
}


list_bundles_full () {
    note "Installed software bundles (with dependencies):"
    if [ -d "${SOFTWARE_DIR}" ]; then
        for _lbfapp in ${SOFTWARE_DIR}*; do
            echo
            _lbfapp_name="$(${BASENAME_BIN} "${_lbfapp}" 2>/dev/null)"
            _lbflowercase="$(lowercase "${_lbfapp_name}")"
            _lbinstald_file="${SOFTWARE_DIR}/${_lbfapp_name}/${_lbflowercase}${INSTALLED_MARK}"
            if [ -e "${_lbinstald_file}" ]; then
                note "${SUCCESS_CHAR} ${_lbfapp_name}"
            else
                note "${red}${FAIL_CHAR} ${_lbfapp_name} ${reset}[${red}!${reset}]"
            fi
            for _lbfreq in $(${FIND_BIN} ${_lbfapp} -maxdepth 1 -name *${INSTALLED_MARK} 2>/dev/null | ${SORT_BIN} 2>/dev/null); do
                _lbpp="$(${PRINTF_BIN} "$(${BASENAME_BIN} "${_lbfreq}" 2>/dev/null)" | ${SED_BIN} "s/${INSTALLED_MARK}//" 2>/dev/null)"
                note "   ${NOTE_CHAR} ${_lbpp} $(distinct "${gray}" "[")$(distinct n $(${CAT_BIN} "${_lbfreq}" 2>/dev/null))$(distinct "${gray}" "]")"
            done
        done
        unset _lbfreq _lbfapp _lbflowercase _lbfapp_name _lbinstald_file _lbpp
    fi
}


show_diff () {
    create_dirs
    _sddefname="${1}"
    # if specified a file name, make sure it's named properly:
    ${EGREP_BIN} "${DEFAULT_DEF_EXT}$" "${_sddefname}" >/dev/null 2>&1 || \
        _sddefname="${_sddefname}${DEFAULT_DEF_EXT}"
    _beauty_defn="$(distinct n "${_sddefname}")"

    cd ${DEFINITIONS_DIR}
    if [ -f "./${_sddefname}" ]; then
        debug "Checking status for untracked files.."
        ${GIT_BIN} status --short "${_sddefname}" 2>/dev/null | ${EGREP_BIN} '\?\?' >/dev/null 2>&1
        if [ "$?" = "0" ]; then # found "??" which means file is untracked..
            note "No diff available for definition: ${_beauty_defn} (currently untracked)"
        else
            note "Showing detailed modifications of defintion: ${_beauty_defn}"
        fi
        ${GIT_BIN} status -vv --long "${_sddefname}" 2>/dev/null
    else
        note "Showing all modifications from current defintions cache"
        ${GIT_BIN} status --short 2>/dev/null
    fi
    unset _sddefname _beauty_defn
}


develop () {
    create_dirs
    _defname_input="${1}"
    _defname_no_ext="$(echo "${_defname_input}" | ${SED_BIN} -e "s#\.${DEFAULT_DEF_EXT}##" 2>/dev/null)"
    _devname="$(lowercase "$(${BASENAME_BIN} ${_defname_no_ext} 2>/dev/null)")"
    if [ -z "${_devname}" ]; then
        error "No definition file name specified as first param!"
    fi
    note "Paste your definition below. Hit ctrl-d (after a newline) to commit. ctrl-c breaks."
    ${CAT_BIN} > "${DEFINITIONS_DIR}/${_devname}${DEFAULT_DEF_EXT}" 2>/dev/null
    unset _devname _defname_no_ext _defname_input
}


enable_sofin_env () {
    ${RM_BIN} -f ${SOFIN_ENV_DISABLED_INDICATOR_FILE}
    update_shell_vars
    if [ -z "${SHELL_PID}" ]; then
        note "Enabled Sofin environment, yet no SHELL_PID defined. Autoreload skipped."
    else
        note "Enabled Sofin environment. Reloading shell"
        ${KILL_BIN} -SIGUSR2 ${SHELL_PID} >/dev/null 2>&1
    fi
}


disable_sofin_env () {
    ${TOUCH_BIN} ${SOFIN_ENV_DISABLED_INDICATOR_FILE}
    update_shell_vars
    if [ -z "${SHELL_PID}" ]; then
        note "Disabled Sofin environment, yet no SHELL_PID defined. Autoreload skipped."
    else
        note "Disabled Sofin environment. Reloading shell"
        ${KILL_BIN} -SIGUSR2 ${SHELL_PID} 2>/dev/null 2>&1
    fi
}


sofin_status () {
    if [ -f ${SOFIN_ENV_DISABLED_INDICATOR_FILE} ]; then
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


mark_installed () {
    _softname="${1}"
    _ver_to_write="${2}"
    if [ -z "${_softname}" ]; then
        error "mark(): Failed with an empty _softname!"
    fi
    if [ -z "${_ver_to_write}" ]; then
        error "mark(): Failed with an empty _ver_to_write!"
    fi
    _softfile="$(lowercase "${_softname}")"
    debug "Marking definition: $(distinct d ${_softfile}) as installed"
    ${TOUCH_BIN} "${PREFIX}/${_softfile}${INSTALLED_MARK}"
    debug "Writing version: $(distinct d ${_ver_to_write}) of software: $(distinct d ${_softfile}) installed in: $(distinct d ${PREFIX})"
    ${PRINTF_BIN} "${_ver_to_write}" > "${PREFIX}/${_softfile}${INSTALLED_MARK}"
    unset _softname _ver_to_write _softfile
}


show_done () {
    _sd_low_name="$(lowercase "${1}")"
    _sdver="$(${CAT_BIN} "${PREFIX}/${_sd_low_name}${INSTALLED_MARK}" 2>/dev/null)"
    if [ -z "${_sdver}" ]; then
        _sdver="0"
    fi
    note "${SUCCESS_CHAR} ${_sd_low_name} [$(distinct n ${_sdver})]"
    unset _sdver _sd_low_name
}


create_or_receive () {
    _dataset_name="$(capitalize "$1")"
    _final_snap_file="${2}"
    if [ -z "${_dataset_name}" -o \
         -z "${_final_snap_file}" ]; then
        error "create_or_receive(): Expected two aruments: $(distinct e dataset_name) and $(distinct e final_snapshot_file)."
    fi
    _commons_path="${MAIN_COMMON_REPOSITORY}/${_final_snap_file}"
    try "${FETCH_BIN} ${FETCH_OPTS} ${_commons_path}" || \
        try "${FETCH_BIN} ${FETCH_OPTS} ${_commons_path}" || \
        try "${FETCH_BIN} ${FETCH_OPTS} ${_commons_path}"
    if [ "$?" = "0" ]; then
        try "${XZCAT_BIN} ${_final_snap_file} 2>/dev/null | \
             ${ZFS_BIN} receive -e origin -v ${_dataset_name}" && \
            ${RM_BIN} -fv "${_final_snap_file}" >> ${LOG} 2>> ${LOG}
        note "Common stream available for: $(distinct n "${_dataset_name}"). Creating service dataset: $(distinct n ${_dataset_name}), from file stream: $(distinct n ${_final_snap_file})."
    else
        debug "Initial service dataset unavailable"
        try "${ZFS_BIN} create ${_dataset_name}" && \
            note "Created an empty service dataset for: $(distinct n ${_dataset_name})"
    fi
    unset _dataset_name _final_snap_file _commons_path
}


show_alt_definitions_and_exit () {
    _an_app="$1"
    if [ ! -f "${DEFINITIONS_DIR}${_an_app}${DEFAULT_DEF_EXT}" ]; then
        _contents=""
        _maybe_version="$(${FIND_BIN} ${DEFINITIONS_DIR} -maxdepth 1 -name "${_an_app}*${DEFAULT_DEF_EXT}" 2>/dev/null)"
        for _maybe in ${_maybe_version}; do
            _elem="$(${BASENAME_BIN} "${_maybe}" 2>/dev/null)"
            _cap_elem="$(capitalize "${_elem}")"
            _contents="${_contents}$(echo "${_cap_elem}" | ${SED_BIN} 's/\..*//' 2>/dev/null) "
        done
        if [ -z "${_contents}" ]; then
            warn "No such definition found: $(distinct w "${_an_app}"). No alternatives found."
        else
            warn "No such definition found: $(distinct w "${_an_app}"). Alternatives found: $(distinct w "${_contents}")"
        fi
        unset _an_app _elem _cap_elem _contents _maybe_version _maybe_version _maybe
        exit
    fi
    unset _an_app
}
