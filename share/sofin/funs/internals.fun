#!/usr/bin/env sh

usage_howto () {
    permnote "Built in tasks:"
    permnote
    permnote "  $(distn "i | install | get | pick | use       ") installs software from list or from definition and switches exports for it ($(distn "example: "${SOFIN_BIN_SHORT}" install Rust" "${ColorExample}"))"
    permnote "  $(distn "dependencies | deps | local          ") installs software from list defined in '$(distn "${DEFAULT_PROJECT_DEPS_LIST_FILE}")' file in current directory"
    permnote "  $(distn "rm | uninstall | destroy | delete    ") removes an application or list ($(distn "example: "${SOFIN_BIN_SHORT}" uninstall Rust" "${ColorExample}"))"
    permnote "  $(distn "list | installed                     ") gives short list of installed software"
    permnote "  $(distn "full | fulllist | fullinstalled      ") gives detailed list with installed software including requirements"
    permnote "  $(distn "available | avail                    ") lists available software definitions"
    permnote "  $(distn "bundlelist | bundles                 ") lists available binary bundles"
    permnote "  $(distn "export | exp | exportapp             ") adds given command to application exports ($(distn "example: "${SOFIN_BIN_SHORT}" export rails Rust" "${ColorExample}"))"
    permnote
    permnote "  $(distn "dump                                 ") dumps current default compiler and environment settings"
    permnote "  $(distn "dump definition-name                 ") dumps definition-specific compiler and environment settings"
    permnote
    permnote "  $(distn "log                                  ") shows tail of all logs (for debug messages and verbose info)"
    permnote "  $(distn "log @                                ") shows tail of all Sofin logs"
    permnote "  $(distn "log -                                ") shows tail of Sofin internal log only"
    permnote "  $(distn "log +                                ") shows and watches all recently modified files"
    permnote "  $(distn "log any-part-of-def-name             ") shows and watches log(s) which name matches pattern"
    permnote
    permnote "  $(distn "up | update                          ") only update definitions from remote repository and exit"
    permnote "  $(distn "upgrade defname srcurl               ") upgrade given definition using url as source archive"
    permnote "  $(distn "ver | version                        ") shows "${SOFIN_BIN_SHORT}" script version"
    permnote "  $(distn "util Bundle1 B2 BundleN              ") build given definitions as Sofin utilities."
    permnote "  $(distn "clean                                ") cleans binbuilds cache, unpacked source content and logs"
    permnote "  $(distn "distclean                            ") cleans binbuilds cache, unpacked source content, logs and definitions"
    permnote "  $(distn "purge                                ") cleans binbuilds cache, unpacked source content, logs, definitions, source cache and possible states"
    permnote "  $(distn "out | outdated                       ") lists outdated software"
    permnote "  $(distn "build                                ") does binary build from source for software specified as params"
    permnote "  $(distn "deploy | push | send                 ") creates binary build of software bundle(s) and pushes it to remote server ($(distn "example: "${SOFIN_BIN_SHORT}" push Rust Vifm Curl" "${ColorExample}"))"
    permnote "  $(distn "wipe                                 ") wipes binary builds (matching given name) from binary respositories ($(distn "example: "${SOFIN_BIN_SHORT}" wipe Rust Vifm" "${ColorExample}"))"

    permnote
    permnote "  $(distn "env                                  ") reads current Sofin environment."
    permnote "  $(distn "env Bundle1 BundleN                  ") builds env for given bundles only (no persistence)."
    permnote "  $(distn "env +Bundle1 +BundleN +Bund8 Any1    ") add given Bundle(s) to current env profile."
    permnote "  $(distn "env +Bundle1 BundleN                 ") add given Bundle(s) to current env profile."
    permnote "  $(distn "env -Bundle1 -Sup2 -BundleN          ") remove given Bundle(s) from current env profile."
    permnote "  $(distn "env -Bundle1 Sup2 -BundleN           ") remove given Bundle(s) from current env profile."
    permnote "  $(distn "env reset                            ") resets Sofin env to defaults."
    permnote "  $(distn "env save MyProjectX                  ") saves Sofin env profile with given name."
    permnote "  $(distn "env load MyProjectX                  ") loads Sofin env profile with given name (no persistence)."
    permnote "  $(distn "env status                           ") shows Sofin status - list of Bundle(s) enabled for currently loaded profile."
    permnote "  $(distn "env reload | rehash                  ") recreates and reloads Sofin shell environment"

    permnote
    permnote "  $(distn "dev                                  ") puts definition content on the fly. Second argument is (lowercase) definition name (no extension). ($(distn "example: "${SOFIN_BIN_SHORT}" dev rubinius" "${ColorExample}"))"
    permnote "  $(distn "reset                                ") resets local definitions repository"
    permnote "  $(distn "diff                                 ") displays changes in current definitions cache. Accepts any part of definition name"
    permnote "  $(distn "srccheck                             ") checks sources availability for all existing definitions in local definitions repository"
    permnote "  $(distn "oldsrc                               ") lists unused sources in main repository"
    permnote
    permnote "  $(distn "origins all | @                      ") checks origin of all definitions, for the new versions"
    permnote "  $(distn "origins name othername               ") checks origin of specified software definitions, for the new versions"
}


default_compiler_features () {
    if [ "clang" = "${CC_NAME}" ] \
    && [ "clang++" = "${CXX_NAME}" ]; then
        permnote "\t $(distn "${SUCCESS_CHAR}" "${ColorGreen}") $(distn "LLVM compilers" "${ColorDistinct}")"
    fi
    if [ -z "${DEF_NO_LLVM_LINKER}" ] && [ "YES" = "${CAP_SYS_LLVM_LD}" ]; then
        permnote "\t $(distn "${SUCCESS_CHAR}" "${ColorGreen}") $(distn "LLVM-LLD-linker" "${ColorDistinct}")"
    elif [ -z "${DEF_NO_GOLDEN_LINKER}" ] && [ -n "${DEF_NO_LLVM_LINKER}" ] && [ "YES" = "${CAP_SYS_GOLD_LD}" ]; then
        permnote "\t $(distn "${SUCCESS_CHAR}" "${ColorGreen}") $(distn "GNU-GOLD-linker" "${ColorDistinct}")"
    else
        ${LD_BIN} -v 2>&1 \
            | ${GREP_BIN} -F "Apple" >/dev/null 2>&1
        if [ "0" = "${?}" ]; then
            permnote "\t $(distn "${SUCCESS_CHAR}" "${ColorGreen}") $(distn "LD64 Dynamic-linker (Apple)" "${ColorDistinct}")"
        fi

        ${LD_BIN} -v 2>&1 \
            | ${GREP_BIN} -E "^LLD [[:digit:]]*.[[:digit:]]*.[[:digit:]]*.*${SYSTEM_NAME} " >/dev/null 2>&1
        if [ "0" = "${?}" ]; then
            permnote "\t $(distn "${SUCCESS_CHAR}" "${ColorGreen}") $(distn "LLVM LLD-linker" "${ColorDistinct}")"
        fi

        ${LD_BIN} -v 2>&1 \
            | ${GREP_BIN} -E "GNU ld [[:digit:]]*.[[:digit:]]*.[[:digit:]]*.*${SYSTEM_NAME}" >/dev/null 2>&1
        if [ "0" = "${?}" ]; then
            permnote "\t $(distn "${SUCCESS_CHAR}" "${ColorGreen}") $(distn "GNU linker" "${ColorDistinct}")"
        fi
    fi

    # -fPIC + -fPIE checks:
    if [ -z "${DEF_NO_PIC}" ] \
    && [ -z "${DEF_NO_PIE}" ] \
    && [ -z "${DEF_NO_LLVM_LINKER}" ] \
    && [ "YES" = "${CAP_SYS_LLVM_LD}" ]; then
        permnote "\t $(distn "${SUCCESS_CHAR}" "${ColorGreen}") $(distn "position-independent-code (PIC)" "${ColorDistinct}")"
        permnote "\t $(distn "${SUCCESS_CHAR}" "${ColorGreen}") $(distn "position-independent-executable (PIE)" "${ColorDistinct}")"
        permnote "\t $(distn "${SUCCESS_CHAR}" "${ColorGreen}") $(distn "linker-RELRO" "${ColorDistinct}")"
        permnote "\t $(distn "${SUCCESS_CHAR}" "${ColorGreen}") $(distn "linker-BINDNOW" "${ColorDistinct}")"
    fi

    if [ -z "${DEF_NO_LINKER_DTAGS}" ]; then
        permnote "\t $(distn "${SUCCESS_CHAR}" "${ColorGreen}") $(distn "linker-new-DTAGS" "${ColorDistinct}")"
    fi
    if [ -n "${DEF_USE_LTO}" ] \
    && [ "arm64" != "${SYSTEM_ARCH}" ] \
    && [ "aarch64" != "${SYSTEM_ARCH}" ]; then
        permnote "\t $(distn "${SUCCESS_CHAR}" "${ColorGreen}") $(distn "link-time-optimizations (LLVM-LTO)" "${ColorDistinct}")"
    fi
    if [ -n "${DEF_USE_CFI}" ]; then
        permnote "\t $(distn "${SUCCESS_CHAR}" "${ColorGreen}") $(distn "control-flow-integrity (LLVM-CFI)" "${ColorDistinct}")"
    fi

    # -fstack-protector-all check:
    printf "%b\n" "${CFLAGS} ${CXXFLAGS}" | ${EGREP_BIN} 'fstack-protector-all' >/dev/null 2>&1 \
        && permnote "\t $(distn "${SUCCESS_CHAR}" "${ColorGreen}") $(distn "stack-protector-all" "${ColorDistinct}")"

    # -fstack-protector-strong check:
    printf "%b\n" "${CFLAGS} ${CXXFLAGS}" | ${EGREP_BIN} 'fstack-protector-strong' >/dev/null 2>&1 \
        && permnote "\t $(distn "${SUCCESS_CHAR}" "${ColorGreen}") $(distn "stack-protector-strong" "${ColorDistinct}")"

    # -fno-strict-overflow check:
    printf "%b\n" "${CFLAGS} ${CXXFLAGS}" | ${EGREP_BIN} 'fno-strict-overflow' >/dev/null 2>&1 \
        && permnote "\t $(distn "${SUCCESS_CHAR}" "${ColorGreen}") $(distn "no-strict-overflow" "${ColorDistinct}")"

    # -ftrapv check:
    # NOTE: Signed integer overflow raises the signal SIGILL instead of SIGABRT/SIGSEGV:
    printf "%b\n" "${CFLAGS} ${CXXFLAGS}" | ${EGREP_BIN} 'ftrapv' >/dev/null 2>&1 \
        && permnote "\t $(distn "${SUCCESS_CHAR}" "${ColorGreen}") $(distn "trap-signed-integer-overflow (TRAPV)" "${ColorDistinct}")"


    if [ -n "${DEF_USE_SAFE_STACK}" ] \
    && [ "arm64" != "${SYSTEM_ARCH}" ] \
    && [ "aarch64" != "${SYSTEM_ARCH}" ]; then
        permnote "\t $(distn "${SUCCESS_CHAR}" "${ColorGreen}") $(distn "safe-stack" "${ColorDistinct}")"
    fi
    if [ -z "${DEF_NO_RETPOLINE}" ]; then
        permnote "\t $(distn "${SUCCESS_CHAR}" "${ColorGreen}") $(distn "retpoline" "${ColorDistinct}")"
    fi
    if [ -n "${DEBUGBUILD}" ]; then
        permnote "\t $(distn "${SUCCESS_CHAR}" "${ColorGreen}") $(distn "debug-build" "${ColorDistinct}")"
    fi
    if [ -z "${DEF_NO_SSP_BUFFER_OVERRIDE}" ]; then
        permnote "\t $(distn "${SUCCESS_CHAR}" "${ColorGreen}") $(distn "ssp-buffer-override" "${ColorDistinct}")"
    fi
    if [ -z "${DEF_NO_FORTIFY_SOURCE}" ]; then
        permnote "\t $(distn "${SUCCESS_CHAR}" "${ColorGreen}") $(distn "fortify-source" "${ColorDistinct}")"
    fi

    # C++ standard used:
    if [ -n "${DEF_USE_CXX11}" ]; then
        permnote "\t $(distn "${SUCCESS_CHAR}" "${ColorGreen}") $(distn "std-c++11" "${ColorDistinct}")"
    elif [ -n "${DEF_USE_CXX14}" ]; then
        permnote "\t $(distn "${SUCCESS_CHAR}" "${ColorGreen}") $(distn "std-c++14" "${ColorDistinct}")"
    elif [ -n "${DEF_USE_CXX17}" ]; then
        permnote "\t $(distn "${SUCCESS_CHAR}" "${ColorGreen}") $(distn "std-c++17" "${ColorDistinct}")"
    fi
    if [ -z "${DEF_USE_CXX11}" ] \
    && [ -z "${DEF_USE_CXX14}" ] \
    && [ -z "${DEF_USE_CXX17}" ]; then
        # 14 is current standard since Sofin v1.8
        permnote "\t $(distn "${SUCCESS_CHAR}" "${ColorGreen}") $(distn "std-c++14" "${ColorDistinct}")"
    fi

}


sofin_header () {
    printf "\n     %b\n%b\n\n  %b\n  %b\n  %b\n\n  %b\n  %b\n\n" \
        "$(distn 'Sof' "${ColorWhite}")$(distn 'tware' "${ColorGray}") $(distn 'In' "${ColorWhite}")$(distn 'staller v' "${ColorGray}")$(distn "${SOFIN_VERSION}" "${ColorWhite}")" \
        "$(distn "____________________________________" "${ColorGreen}")" \
        "design, implementation: $(distn "@dmilith")" \
        "developed since: $(distn "2011")" \
        "released under: $(distn "MIT/BSD")" \
        "running os: $(distn "${OS_TRIPPLE}")" \
        "running shell: $(distn "${SHELL}")"

    printf "  %b\n" "system capabilities:"
    IFS=\n set 2>/dev/null | ${EGREP_BIN} -I 'CAP_SYS_' 2>/dev/null | while IFS= read -r _envv; do
        if [ -n "${_envv}" ]; then
            printf "\t %b %b\n" \
                "$(distn "${SUCCESS_CHAR}" "${ColorGreen}")" \
                "$(distn "$(lowercase "${_envv%=YES}")")"
        fi
    done

    printf "\n  %b\n" "terminal capabilities:"
    IFS=\n set 2>/dev/null | ${EGREP_BIN} -I 'CAP_TERM_' 2>/dev/null | while IFS= read -r _envv; do
        if [ -n "${_envv}" ]; then
            printf "\t %b %b\n" \
                "$(distn "${SUCCESS_CHAR}" "${ColorGreen}")" \
                "$(distn "$(lowercase "${_envv%=YES}")")"
        fi
    done

    printf "\n  %b\n" "default build features:"
    load_defaults
    compiler_setup
    default_compiler_features

    printf "%b\n" "${ColorReset}"
}


processes_all_sofin () {
    _processes=""
    for _ff in $(${FIND_BIN} "${LOCKS_DIR}" -name '*.lock' 2>/dev/null); do
        _pid="$(${CAT_BIN} "${_ff}" 2>/dev/null)"
        ${KILL_BIN} -0 "${_pid}" >/dev/null 2>&1
        if [ "0" = "${?}" ] \
        && [ "${SOFIN_PID}" != "${_pid}" ]; then
            if [ -z "${_processes}" ]; then
                _processes="${_pid}"
            else
                _processes="${_processes} ${_pid}"
            fi
        fi
    done
    if [ -n "${_processes}" ]; then
        debug "Sofin-tasks-locked by processes: $(distd "${_processes}")"
        printf "%b\n" "${_processes}"
    fi
    return 0
}


print_local_env_vars () {
    _s_env_file="${PWD}/.${SOFIN_NAME}.env"
    if [ -f "${_s_env_file}" ]; then
        printf "\n# Local environment loaded from: %b\n" "${_s_env_file}"
        ${CAT_BIN} "${_s_env_file}" 2>/dev/null
    fi
    unset _s_env_file
}


print_shell_vars () {
    _pkg_config_path="."
    _ldflags="${DEFAULT_LINKER_FLAGS}"
    _cflags="${DEFAULT_COMPILER_FLAGS}"
    _cxxflags="${CXX14_CXXFLAGS} ${_cflags}"
    _path="${DEFAULT_PATH}"
    _manpath="${DEFAULT_MANPATH}"
    for _exp in $(${FIND_BIN} "${SOFTWARE_DIR}" -mindepth 2 -maxdepth 3 -name 'man' -type d 2>/dev/null); do
        _manpath="${_exp}:${_manpath}"
    done

    if [ -f "${SOFIN_ENV_ENABLED_INDICATOR_FILE}" ]; then
        # /Software
        for _enabled in $(${CAT_BIN} "${SOFIN_ENV_ENABLED_INDICATOR_FILE}" 2>/dev/null); do
            if [ -d "${SOFTWARE_DIR}/${_enabled}/exports" ]; then
                _path="${SOFTWARE_DIR}/${_enabled}/exports:${_path}"
            fi
            if [ -d "${SOFTWARE_DIR}/${_enabled}/include" ]; then
                _cflags="-I${SOFTWARE_DIR}/${_enabled}/include ${_cflags}"
            fi
            if [ -d "${SOFTWARE_DIR}/${_enabled}/include" ]; then
                _cxxflags="-I${SOFTWARE_DIR}/${_enabled}/include ${_cxxflags}"
            fi
            if [ -d "${SOFTWARE_DIR}/${_enabled}/lib" ]; then
                _ldflags="-L${SOFTWARE_DIR}/${_enabled}/lib ${_ldflags}"
            fi
            if [ -d "${SOFTWARE_DIR}/${_enabled}/lib/pkgconfig" ]; then
                _pkg_config_path="${SOFTWARE_DIR}/${_enabled}/lib/pkgconfig:${_pkg_config_path}"
            fi
        done

        # /Services
        for _enabled in $(${CAT_BIN} "${SOFIN_ENV_ENABLED_INDICATOR_FILE}" 2>/dev/null); do
            if [ -d "${SERVICES_DIR}/${_enabled}/exports" ]; then
                _path="${SERVICES_DIR}/${_enabled}/exports:${_path}"
            fi
            if [ -d "${SERVICES_DIR}/${_enabled}/include" ]; then
                _cflags="-I${SERVICES_DIR}/${_enabled}/include ${_cflags}"
            fi
            if [ -d "${SERVICES_DIR}/${_enabled}/include" ]; then
                _cxxflags="-I${SERVICES_DIR}/${_enabled}/include ${_cxxflags}"
            fi
            if [ -d "${SERVICES_DIR}/${_enabled}/lib" ]; then
                _ldflags="-L${SERVICES_DIR}/${_enabled}/lib ${_ldflags}"
            fi
            if [ -d "${SERVICES_DIR}/${_enabled}/lib/pkgconfig" ]; then
                _pkg_config_path="${SERVICES_DIR}/${_enabled}/lib/pkgconfig:${_pkg_config_path}"
            fi
        done

    else
        # /Software
        for _exp in $(${FIND_BIN} "${SOFTWARE_DIR}" -mindepth 2 -maxdepth 2 -name 'exports' -type d 2>/dev/null); do
            _path="${_exp}:${_path}"
        done
        for _exp in $(${FIND_BIN} "${SOFTWARE_DIR}" -mindepth 2 -maxdepth 2 -name 'lib' -or -name 'libexec' -type d 2>/dev/null); do
            _ldflags="-L${_exp} ${_ldflags}"
        done
        for _exp in $(${FIND_BIN} "${SOFTWARE_DIR}" -mindepth 2 -maxdepth 3 -name 'pkgconfig' -type d 2>/dev/null); do
            _pkg_config_path="${_exp}:${_pkg_config_path}"
        done
        for _exp in $(${FIND_BIN} "${SOFTWARE_DIR}" -mindepth 2 -maxdepth 2 -name 'include' -type d 2>/dev/null); do
            _cflags="-I${_exp} ${_cflags}"
        done

        # /Services
        for _exp in $(${FIND_BIN} "${SERVICES_DIR}" -mindepth 2 -maxdepth 2 -name 'exports' -type d 2>/dev/null); do
            if [ "${_exp}" != "${SERVICES_DIR}/${SOFIN_BUNDLE_NAME}/exports" ]; then # skip Sofin utility exports
                _path="${_exp}:${_path}"
            fi
        done
        for _exp in $(${FIND_BIN} "${SERVICES_DIR}" -mindepth 2 -maxdepth 2 -name 'lib' -or -name 'libexec' -type d 2>/dev/null); do
            _ldflags="-L${_exp} ${_ldflags}"
        done
        for _exp in $(${FIND_BIN} "${SERVICES_DIR}" -mindepth 2 -maxdepth 3 -name 'pkgconfig' -type d 2>/dev/null); do
            _pkg_config_path="${_exp}:${_pkg_config_path}"
        done
        for _exp in $(${FIND_BIN} "${SERVICES_DIR}" -mindepth 2 -maxdepth 2 -name 'include' -type d 2>/dev/null); do
            _cflags="-I${_exp} ${_cflags}"
        done
    fi

    # Store values to environment file:
    printf "# %bMANPATH:%b\n" "${ColorParams}" "${ColorReset}"
    printf "%b\n" "export MANPATH=\"${_manpath}\""

    if [ -f "${SOFIN_ENV_ENABLED_INDICATOR_FILE}" ]; then # sofin disabled. Default system environment
        _cflags="$(printf "%b\n" "${_cflags}" | ${SED_BIN} 's/ *$//g; s/  //g' 2>/dev/null)"
        _cxxflags="$(printf "%b\n" "${_cxxflags}" | ${SED_BIN} 's/ *$//g; s/  //g' 2>/dev/null)"
        _ldflags="$(printf "%b\n" "${_ldflags}" | ${SED_BIN} 's/ *$//g; s/  //g' 2>/dev/null)"
        _pkg_config_path="$(printf "%b\n" "${_pkg_config_path}" | ${SED_BIN} 's/ *$//g; s/  //g' 2>/dev/null)"
        printf "# %bCFLAGS:%b\n" "${ColorParams}" "${ColorReset}"
        printf "%b\n" "export CFLAGS=\"${_cflags}\""
        printf "# %bCXXFLAGS:%b\n" "${ColorParams}" "${ColorReset}"
        printf "%b\n" "export CXXFLAGS=\"${_cxxflags}\""
        printf "# %bLDFLAGS:%b\n" "${ColorParams}" "${ColorReset}"
        printf "%b\n" "export LDFLAGS=\"${_ldflags}\""
        printf "# %bPKG_CONFIG_PATH:%b\n" "${ColorParams}" "${ColorReset}"
        printf "%b\n" "export PKG_CONFIG_PATH=\"${_pkg_config_path}\""
    else # sofin environment override enabled, Default behavior:
        printf "# %bCFLAGS:%b\n" "${ColorParams}" "${ColorReset}"
        printf "%b\n" "export CFLAGS=\"\""
        printf "# %bCXXFLAGS:%b\n" "${ColorParams}" "${ColorReset}"
        printf "%b\n" "export CXXFLAGS=\"\""
        printf "# %bLDFLAGS:%b\n" "${ColorParams}" "${ColorReset}"
        printf "%b\n" "export LDFLAGS=\"\""
        printf "# %bPKG_CONFIG_PATH:%b\n" "${ColorParams}" "${ColorReset}"
        printf "%b\n" "export PKG_CONFIG_PATH=\"\""
    fi

    # common
    printf "# %bPATH:%b\n" "${ColorParams}" "${ColorReset}"
    printf "%b\n" "export PATH=\"${_path}\""
    printf "# %bCC:%b\n" "${ColorParams}" "${ColorReset}"
    printf "%b\n" "export CC=\"${CC_NAME}\""
    printf "# %bCXX:%b\n" "${ColorParams}" "${ColorReset}"
    printf "%b\n" "export CXX=\"${CXX_NAME}\""
    printf "# %bCPP:%b\n" "${ColorParams}" "${ColorReset}"
    printf "%b\n" "export CPP=\"${CPP}\""

    unset _cflags _cxxflags _ldflags _pkg_config_path _manpath _app _exp
}


list_bundles_full () {
    note "Bundle checks in progress${CHAR_DOTS}"
    for _lbfapp in ${SOFTWARE_DIR}/*; do
        if [ -d "${_lbfapp}" ]; then
            _lbfapp_name="${_lbfapp##*/}"
            _lbflowercase="$(lowercase "${_lbfapp_name}")"
            _lbinstald_file="${SOFTWARE_DIR}/${_lbfapp_name}/${_lbflowercase}${DEFAULT_INST_MARK_EXT}"
            if [ -e "${_lbinstald_file}" ]; then
                permnote "${SUCCESS_CHAR} $(distn "${_lbfapp_name}")"
            else
                warn "$(distw "${FAIL_CHAR}" "${ColorRed}") ${_lbfapp_name} $(distw "[!]" "${ColorRed}")"
            fi
            for _lbfreq in $(${FIND_BIN} "${_lbfapp}" -mindepth 1 -maxdepth 1 -iname "*${DEFAULT_INST_MARK_EXT}" 2>/dev/null | ${SORT_BIN} 2>/dev/null); do
                _lbpp="$(printf "%b\n" "${_lbfreq##*/}" | ${SED_BIN} "s/${DEFAULT_INST_MARK_EXT}//" 2>/dev/null)"
                note "   ${NOTE_CHAR} $(distn "${_lbpp}") $(distn "[" "${ColorGray}")$(distn "$(${CAT_BIN} "${_lbfreq}" 2>/dev/null)")$(distn "]" "${ColorGray}")"
            done
        fi
    done
    unset _lbfreq _lbfapp _lbflowercase _lbfapp_name _lbinstald_file _lbpp
    permnote "Bundle checks completed."
}


show_diff () {
    create_sofin_dirs
    _sddefname="${1}"
    # if specified a file name, make sure it's named properly:
    ${EGREP_BIN} "${DEFAULT_DEF_EXT}$" "${_sddefname}" >/dev/null 2>&1 \
        || _sddefname="${_sddefname}${DEFAULT_DEF_EXT}"
    _beauty_defn="$(distn "${_sddefname}")"

    (
        cd "${DEFINITIONS_DIR}"
        if [ -f "./${_sddefname}" ]; then
            debug "Checking status for untracked files of: $(distd "${_sddefname}")"
            ${GIT_BIN} status --short "${_sddefname}" 2>/dev/null | ${EGREP_BIN} '\?\?' >/dev/null 2>&1
            if [ "${?}" = "0" ]; then # found "??" which means file is untracked..
                permnote "No diff available for definition: ${_beauty_defn} (currently untracked)"
            else
                permnote "Showing detailed modifications of defintion: ${_beauty_defn}"
            fi
            ${GIT_BIN} status -vv --long "${_sddefname}" 2>/dev/null
        else
            permnote "Listing all modified definitions in local cache: ($(distn "${CACHE_DIR}"))"
            ${GIT_BIN} status --short 2>/dev/null
        fi
    )
    unset _sddefname _beauty_defn
}


develop () {
    _defname_input="${*}"
    create_sofin_dirs
    _defname_no_ext="$(printf "%b\n" "${_defname_input}" | ${SED_BIN} -e "s#\.${DEFAULT_DEF_EXT}##" 2>/dev/null)"
    _devname="$(lowercase "${_defname_no_ext##*/}")"
    if [ -z "${_defname_input}" ]; then
        error "No definition file name specified as first param!"
    fi
    permnote "Paste your definition below. Hit $(distn "[Enter]"), $(distn "Ctrl-D") to update definitions file: $(distn "${DEFINITIONS_DIR}/${_devname}${DEFAULT_DEF_EXT}")"
    ${CAT_BIN} > "${DEFINITIONS_DIR}/${_devname}${DEFAULT_DEF_EXT}" 2>/dev/null
    unset _defname_input _devname _defname_no_ext
}


env_status () {
    if [ -f "${SOFIN_ENV_ENABLED_INDICATOR_FILE}" ]; then
        permnote "Sofin environment of $(distn "specific") bundles: $(distn "$(${CAT_BIN} "${SOFIN_ENV_ENABLED_INDICATOR_FILE}" | ${TR_BIN} '\n' ' ' 2>/dev/null)")"
    else
        permnote "Sofin environment is $(distn "dynamic"). All installed software-bundles are included"
    fi
}


print_env_status () {
    if [ -f "${SOFIN_ENV_ENABLED_INDICATOR_FILE}" ]; then
        printf "#\n# Generated environment from specific bundles: %b\n#\n" "$(${CAT_BIN} "${SOFIN_ENV_ENABLED_INDICATOR_FILE}" | ${TR_BIN} '\n' ' ' 2>/dev/null)"
    else
        printf "#\n# Generated dynamic environment. (env is built from all installed software-bundles) \n#\n"
    fi
}


list_bundles_alphabetic () {
    if [ -d "${SOFTWARE_DIR}/" ]; then
        for _elem in $(${FIND_BIN} "${SOFTWARE_DIR}/" -maxdepth 1 -mindepth 1 -type d  -not -name ".*" -print 2>/dev/null | ${SED_BIN} -e 's#/.*/##' 2>/dev/null | ${SORT_BIN} 2>/dev/null); do
            if [ -d "${SOFTWARE_DIR}/${_elem}/exports" ]; then
                printf "%b\n" "${_elem}"
            fi
        done
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
    printf "%b\n" "${_verfile}" > "${PREFIX}/${_softfile}${DEFAULT_INST_MARK_EXT}" \
        && debug "Stored version: $(distd "${_verfile}") of software: $(distd "${_softfile}") installed in: $(distd "${PREFIX}")"
    unset _softname _verfile _softfile
}


mark_dependency_test_passed () {
    _softname="${1}"
    if [ -z "${_softname}" ]; then
        error "To mark dependency '$(diste "PASSED")' - you must provide it's name first!"
    fi
    _softfile="$(lowercase "${_softname}")"
    run "${TOUCH_BIN} '${PREFIX}/${_softfile}${DEFAULT_TEST_PASSED_EXT}'" \
        && debug "Test suite $(distd "PASSED") for dependency: $(distd "${_softfile}")"
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
    if [ ! -f "${DEFINITIONS_DIR}/${_an_app}${DEFAULT_DEF_EXT}" ]; then
        unset _contents
        for _maybe in $(${FIND_BIN} "${DEFINITIONS_DIR}" -maxdepth 1 -name "${_an_app}*${DEFAULT_DEF_EXT}" 2>/dev/null); do
            _contents="${_contents}$(printf "%b\n" "$(capitalize_abs "${_maybe##*/}")" | ${SED_BIN} 's/\..*//' 2>/dev/null) "
        done
        if [ -z "${_contents}" ]; then
            warn "No such definition: $(distw "${_an_app}"). No alternatives found."
        else
            warn "No such definition: $(distw "${_an_app}"). Alternatives found: $(distw "${_contents}")"
        fi
        unset _an_app _contents _maybe
        finalize_and_quit_gracefully_with_exitcode
    fi
    unset _an_app
}


list_unused_sources () {
    if [ -x "${CURL_BIN}" ]; then
        _fetch_cmd="${CURL_BIN}"
        _fetch_opts="-s"
    else
        _fetch_cmd="${FETCH_BIN}"
        _fetch_opts="-qo-"
    fi

    _sourcelist="$("${_fetch_cmd}" "${_fetch_opts}" "${MAIN_SOURCE_REPOSITORY}" | "${GREP_BIN}" "href" | "${GREP_BIN}" -v "\/\"" \
    | "${AWK_BIN}" -F"\"" '{print $2,$3}' | "${AWK_BIN}" '{print $1,$5}' | "${SORT_BIN}" -n -r -k 2 | "${SED_BIN}" -E 's/%2B/\+/g')"

    _alldefs="$(${FIND_BIN} "${DEFINITIONS_DIR}" -mindepth 1 -maxdepth 1 -type f -name "*${DEFAULT_DEF_EXT}" 2>/dev/null)"

    for _def in $(to_iter "${_alldefs}"); do
        . "${_def}"
        _defsrc="${DEF_SOURCE_PATH##*/}"
        if [ -n "${_defsrc}" ]; then
            _sourcelist="$(echo "${_sourcelist}" | "${GREP_BIN}" -v "${_defsrc}")"
        fi
    done

    load_defaults
    echo "${_sourcelist}" | "${AWK_BIN}" '{print $1}'

    unset _sourcelist _def _alldefs _defsrc _fetch_cmd _fetch_opts
}
