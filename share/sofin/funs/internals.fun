usage_howto () {
    note "Built in tasks:"
    note "  $(distn "install | get | pick | choose | use  ") installs software from list or from definition and switches exports for it ($(distn "example: ${SOFIN_BIN_SHORT} install Rubinius" ${ColorExample}))"
    note "  $(distn "dependencies | deps | local          ") installs software from list defined in '$(distn "${DEFAULT_PROJECT_DEPS_LIST_FILE}")' file in current directory"
    note "  $(distn "uninstall | remove | delete          ") removes an application or list ($(distn "example: ${SOFIN_BIN_SHORT} uninstall Rubinius" ${ColorExample}))"
    note "  $(distn "list | installed                     ") gives short list of installed software"
    note "  $(distn "full | fulllist | fullinstalled      ") gives detailed list with installed software including requirements"
    note "  $(distn "available | avail                    ") lists available software"
    note "  $(distn "export | exp | exportapp             ") adds given command to application exports ($(distn "example: ${SOFIN_BIN_SHORT} export rails Rubinius" ${ColorExample}))"
    note "  $(distn "getshellvars | shellvars | vars      ") returns shell variables for installed software"
    note "  $(distn "log                                  ") shows tail of all logs (for debug messages and verbose info)"
    note "  $(distn "log -                                ") shows tail of Sofin internal log only"
    note "  $(distn "log +                                ") shows and watches all recently modified files"
    note "  $(distn "log any-part-of-def-name             ") shows and watches log(s) which name matches pattern"
    note "  $(distn "reload | rehash                      ") recreates shell vars and reloads current shell"
    note "  $(distn "up | update                          ") only update definitions from remote repository and exit"
    note "  $(distn "ver | version                        ") shows ${SOFIN_BIN_SHORT} script version"
    note "  $(distn "clean                                ") cleans binbuilds cache, unpacked source content and logs"
    note "  $(distn "distclean                            ") cleans binbuilds cache, unpacked source content, logs and definitions"
    note "  $(distn "purge                                ") cleans binbuilds cache, unpacked source content, logs, definitions, source cache and possible states"
    note "  $(distn "out | outdated                       ") lists outdated software"
    note "  $(distn "build                                ") does binary build from source for software specified as params"
    note "  $(distn "deploy                               ") build + push"
    note "  $(distn "push | binpush | send                ") creates binary build from prebuilt software bundles name given as params ($(distn "example: ${SOFIN_BIN_SHORT} push Rubinius Vifm Curl" ${ColorExample}))"
    note "  $(distn "wipe                                 ") wipes binary builds (matching given name) from binary respositories ($(distn "example: ${SOFIN_BIN_SHORT} wipe Rubinius Vifm" ${ColorExample}))"
    note "  $(distn "enable                               ") enables Sofin developer environment (full environment stored in ~/.profile). It's the default"
    note "  $(distn "disable                              ") disables Sofin developer environment (only PATH, PKG_CONFIG_PATH and MANPATH written to ~/.profile)"
    note "  $(distn "status                               ") shows Sofin status"
    note "  $(distn "dev                                  ") puts definition content on the fly. Second argument is (lowercase) definition name (no extension). ($(distn "example: ${SOFIN_BIN_SHORT} dev rubinius" ${ColorExample}))"
    note "  $(distn "rebuild                              ") rebuilds and pushes each software bundle that depends on definition given as a param. ($(distn "example: ${SOFIN_BIN_SHORT} rebuild openssl - will rebuild all bundles that have 'openssl' dependency" ${ColorExample}))"
    note "  $(distn "reset                               ") resets local definitions repository"
    note "  $(distn "diff                                ") displays changes in current definitions cache. Accepts any part of definition name"
    # TODO: fix-hack
    # note "  $(distn "hack                                ") hack through build dirs matching pattern given as param"
}


write_info_about_shell_configuration () {
    if [ "YES" = "${TTY}" ]; then
        warn "$(distw SHELL_PID) has no value (normally contains pid of current shell)\nShell auto reload function is disabled for this session"
    else
        debug "$(distd SHELL_PID) has no value (normally contains pid of current shell)\nShell auto reload function is disabled for this session"
    fi
}


sofin_header () {
    ${PRINTF_BIN} '%s\n\n' "$(distn 'Sof')tware $(distn 'In')staller v$(distn "${SOFIN_VERSION}") -- (c) 2o11-2o16 -- Daniel ($(distn dmilith)) Dettlaff"
}


processes_all () {
    ${PS_BIN} ${DEFAULT_PS_OPTS} 2>/dev/null | ${EGREP_BIN} -v "(grep|egrep)" 2>/dev/null
}


processes_all_sofin () {
    processes_all | ${EGREP_BIN} "${SOFIN_BIN}" 2>/dev/null
}


# processes_installing () {
#     filter="${1}"
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
    _path="${DEFAULT_PATH}"
    gsv_int_path () {
        for _app in ${1}*; do
            _exp="${_app}/exports"
            if [ -e "${_exp}" ]; then
                _path="${_exp}:${_path}"
            fi
        done
    }
    gsv_int_path "${SOFTWARE_DIR}"

    # LDFLAGS, PKG_CONFIG_PATH:
    # _ldresult="/lib:/usr/lib"
    _pkg_config_path="."
    _ldflags="${LDFLAGS} ${DEFAULT_LDFLAGS}"
    gsv_int_ldflags () {
        for _app in ${1}*; do # LIB_DIR
            if [ -e "${_app}/lib" ]; then
                # _ldresult="${_app}/lib:${_ldresult}"
                _ldflags="-L${_app}/lib ${_ldflags}" # NOTE: not required anymore? -R${_app}/lib
            fi
            if [ -e "${_app}/libexec" ]; then
                # _ldresult="${_app}/libexec:${_ldresult}"
                _ldflags="-L${_app}/libexec ${_ldflags}" # NOTE: not required anymore? -R${_app}/libexec
            fi
            if [ -e "${_app}/lib/pkgconfig" ]; then
                _pkg_config_path="${_app}/lib/pkgconfig:${_pkg_config_path}"
            fi
        done
    }
    gsv_int_ldflags "${SOFTWARE_DIR}"

    # CFLAGS, CXXFLAGS:
    _cflags="${COMMON_COMPILER_FLAGS}"
    gsv_int_cflags () {
        for _app in ${1}*; do
            _exp="${_app}/include"
            if [ -e "${_exp}" ]; then
                _cflags="-I${_exp} ${_cflags}"
            fi
        done
    }
    gsv_int_cflags "${SOFTWARE_DIR}"
    _cxxflags="-std=c++11 ${_cflags}"

    # MANPATH
    _manpath="${DEFAULT_MANPATH}"
    gsv_int_manpath () {
        for _app in ${1}*; do
            _exp="${_app}/man"
            if [ -e "${_exp}" ]; then
                _manpath="${_exp}:${_manpath}"
            fi
            _exp="${_app}/share/man"
            if [ -e "${_exp}" ]; then
                _manpath="${_exp}:${_manpath}"
            fi
        done
    }
    gsv_int_manpath "${SOFTWARE_DIR}"

    ${PRINTF_BIN} "# ${ColorParams}PATH${ColorReset}:\n"
    ${PRINTF_BIN} '%s\n' "export PATH=\"$(${PRINTF_BIN} '%s\n' "${_path}" 2>/dev/null | eval "${CUT_TRAILING_SPACES_GUARD}")\""
    ${PRINTF_BIN} "# ${ColorParams}CC${ColorReset}:\n"
    ${PRINTF_BIN} '%s\n' "export CC=\"${CC}\""
    ${PRINTF_BIN} "# ${ColorParams}CXX${ColorReset}:\n"
    ${PRINTF_BIN} '%s\n' "export CXX=\"${CXX}\""
    ${PRINTF_BIN} "# ${ColorParams}CPP${ColorReset}:\n"
    ${PRINTF_BIN} '%s\n' "export CPP=\"${CPP}\""

    if [ -f "${SOFIN_ENV_DISABLED_INDICATOR_FILE}" ]; then # sofin disabled. Default system environment
        ${PRINTF_BIN} "# ${ColorParams}CFLAGS${ColorReset}:\n"
        ${PRINTF_BIN} '%s\n' "export CFLAGS=\"\""
        ${PRINTF_BIN} "# ${ColorParams}CXXFLAGS${ColorReset}:\n"
        ${PRINTF_BIN} '%s\n' "export CXXFLAGS=\"\""
        ${PRINTF_BIN} "# ${ColorParams}LDFLAGS${ColorReset}:\n"
        ${PRINTF_BIN} '%s\n' "export LDFLAGS=\"\""
    else # sofin environment override enabled, Default behavior:
        ${PRINTF_BIN} "# ${ColorParams}CFLAGS${ColorReset}:\n"
        ${PRINTF_BIN} '%s\n' "export CFLAGS=\"$(${PRINTF_BIN} '%s\n' "${_cflags}" 2>/dev/null | eval "${CUT_TRAILING_SPACES_GUARD}")\""
        ${PRINTF_BIN} "# ${ColorParams}CXXFLAGS${ColorReset}:\n"
        ${PRINTF_BIN} '%s\n' "export CXXFLAGS=\"$(${PRINTF_BIN} '%s\n' "${_cxxflags}" 2>/dev/null | eval "${CUT_TRAILING_SPACES_GUARD}")\"${ColorReset}"
        ${PRINTF_BIN} "# ${ColorParams}LDFLAGS${ColorReset}:\n"
        ${PRINTF_BIN} '%s\n' "export LDFLAGS=\"$(${PRINTF_BIN} '%s\n' "${_ldflags}" 2>/dev/null | eval "${CUT_TRAILING_SPACES_GUARD}")\""
    fi

    # common
    ${PRINTF_BIN} "# ${ColorParams}PKG_CONFIG_PATH${ColorReset}:\n"
    ${PRINTF_BIN} '%s\n' "export PKG_CONFIG_PATH=\"$(${PRINTF_BIN} '%s\n' "${_pkg_config_path}" 2>/dev/null | eval "${CUT_TRAILING_SPACES_GUARD}")\""
    ${PRINTF_BIN} "# ${ColorParams}MANPATH${ColorReset}:\n"
    ${PRINTF_BIN} '%s\n' "export MANPATH=\"$(${PRINTF_BIN} '%s\n' "${_manpath}" 2>/dev/null | eval "${CUT_TRAILING_SPACES_GUARD}")\""

    unset _cflags _cxxflags _ldflags _pkg_config_path _manpath _app _exp
}


list_bundles_full () {
    note "Installed software bundles (with dependencies):"
    if [ -d "${SOFTWARE_DIR}" ]; then
        for _lbfapp in ${SOFTWARE_DIR}*; do
            _lbfapp_name="${_lbfapp##*/}"
            _lbflowercase="$(lowercase "${_lbfapp_name}")"
            _lbinstald_file="${SOFTWARE_DIR}/${_lbfapp_name}/${_lbflowercase}${DEFAULT_INST_MARK_EXT}"
            if [ -e "${_lbinstald_file}" ]; then
                note "${SUCCESS_CHAR} ${_lbfapp_name}"
            else
                note "$(distn "${FAIL_CHAR}" ${ColorRed}) ${_lbfapp_name} $(distn "[!]" ${ColorRed})"
            fi
            for _lbfreq in $(${FIND_BIN} ${_lbfapp} -mindepth 1 -maxdepth 1 -iname "*${DEFAULT_INST_MARK_EXT}" 2>/dev/null | ${SORT_BIN} 2>/dev/null); do
                _lbpp="$(${PRINTF_BIN} '%s' "${_lbfreq##*/}" | ${SED_BIN} "s/${DEFAULT_INST_MARK_EXT}//" 2>/dev/null)"
                note "   ${NOTE_CHAR} ${_lbpp} $(distn "[" ${ColorGray})$(distn $(${CAT_BIN} "${_lbfreq}" 2>/dev/null))$(distn "]" ${ColorGray})"
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
    _beauty_defn="$(distn "${_sddefname}")"

    cd ${DEFINITIONS_DIR}
    if [ -f "./${_sddefname}" ]; then
        debug "Checking status for untracked files.."
        ${GIT_BIN} status --short "${_sddefname}" 2>/dev/null | ${EGREP_BIN} '\?\?' >/dev/null 2>&1
        if [ "${?}" = "0" ]; then # found "??" which means file is untracked..
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
    _defname_input="${@}"
    ${TEST_BIN} -d "${DEFINITIONS_DIR}" 2>/dev/null || create_dirs # only definiions dir is requires, so skip dir traverse
    _defname_no_ext="$(${PRINTF_BIN} '%s\n' "${_defname_input}" | ${SED_BIN} -e "s#\.${DEFAULT_DEF_EXT}##" 2>/dev/null)"
    _devname="$(lowercase "${_defname_no_ext##*/}")"
    if [ -z "${_defname_input}" ]; then
        error "No definition file name specified as first param!"
    fi
    note "Paste your definition below. Hit $(distn "[Enter]"), $(distn "Ctrl-D") to update definitions file: $(distn "${DEFINITIONS_DIR}${_devname}${DEFAULT_DEF_EXT}")"
    ${CAT_BIN} > "${DEFINITIONS_DIR}${_devname}${DEFAULT_DEF_EXT}" 2>/dev/null
    unset _defname_input  _devname _defname_no_ext
}


sofin_status () {
    if [ -f ${SOFIN_ENV_DISABLED_INDICATOR_FILE} ]; then
        note "Sofin shell environment is: $(distn "disabled" ${ColorRed})"
    else
        note "Sofin shell environment is: $(distn "enabled" ${ColorParams})"
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
    _verfile="${2}"
    if [ -z "${_softname}" ]; then
        error "Failed with an empty _softname!"
    fi
    if [ -z "${_verfile}" ]; then
        error "Failed with an empty _verfile!"
    fi
    _softfile="$(lowercase "${_softname}")"
    run "${PRINTF_BIN} \"${_verfile}\" > ${PREFIX}/${_softfile}${DEFAULT_INST_MARK_EXT}" && \
        debug "Stored version: $(distd "${_verfile}") of software: $(distd "${_softfile}") installed in: $(distd "${PREFIX}")"
    unset _softname _verfile _softfile
}


mark_dependency_test_passed () {
    _softname="${1}"
    if [ -z "${_softname}" ]; then
        error "To mark dependency '$(diste "PASSED")' - you must provide it's name first!"
    fi
    _softfile="$(lowercase "${_softname}")"
    run "${TOUCH_BIN} ${PREFIX}/${_softfile}${DEFAULT_TEST_PASSED_EXT}" && \
        debug "Test suite $(distd "PASSED") for dependency: $(distd "${_softfile}")"
    unset _softname _verfile _softfile
}


show_done () {
    _sd_low_name="$(lowercase "${1}")"
    _sdver="$(${CAT_BIN} "${PREFIX}/${_sd_low_name}${DEFAULT_INST_MARK_EXT}" 2>/dev/null)"
    if [ -z "${_sdver}" ]; then
        _sdver="0"
    fi
    note "${SUCCESS_CHAR} ${_sd_low_name} [$(distn "${_sdver}")]"
    unset _sdver _sd_low_name
}


show_alt_definitions_and_exit () {
    _an_app="${1}"
    if [ ! -f "${DEFINITIONS_DIR}${_an_app}${DEFAULT_DEF_EXT}" ]; then
        unset _contents
        _maybe_version="$(${FIND_BIN} ${DEFINITIONS_DIR} -maxdepth 1 -name "${_an_app}*${DEFAULT_DEF_EXT}" 2>/dev/null)"
        for _maybe in ${_maybe_version}; do
            _contents="${_contents}$(${PRINTF_BIN} '%s\n' "$(capitalize "${_maybe##*/}")" | ${SED_BIN} 's/\..*//' 2>/dev/null) "
        done
        if [ -z "${_contents}" ]; then
            warn "No such definition found: $(distw "${_an_app}"). No alternatives found."
        else
            warn "No such definition found: $(distw "${_an_app}"). Alternatives found: $(distw "${_contents}")"
        fi
        unset _an_app _contents _maybe_version _maybe_version _maybe
        exit
    fi
    unset _an_app
}
