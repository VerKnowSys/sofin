#!/usr/bin/env sh

usage_howto () {
    permnote "Built in tasks:"
    permnote
    permnote "  ${ColorDistinct}i | install | get | pick | use       ${ColorNote} installs software from list or from definition and switches exports for it ($(distn "example: "${SOFIN_BIN_SHORT}" install Rust" "${ColorExample}"))"
    permnote "  ${ColorDistinct}dependencies | deps | local          ${ColorNote} installs software from list defined in '${ColorDistinct}${DEFAULT_PROJECT_DEPS_LIST_FILE}${ColorNote}' file in current directory"
    permnote "  ${ColorDistinct}rm | uninstall | destroy | delete    ${ColorNote} removes an application or list ($(distn "example: "${SOFIN_BIN_SHORT}" uninstall Rust" "${ColorExample}"))"
    permnote "  ${ColorDistinct}list | installed                     ${ColorNote} gives short list of installed software"
    permnote "  ${ColorDistinct}full | fulllist | fullinstalled      ${ColorNote} gives detailed list with installed software including requirements"
    permnote "  ${ColorDistinct}available | avail                    ${ColorNote} lists available software definitions"
    permnote "  ${ColorDistinct}bundlelist | bundles                 ${ColorNote} lists available binary bundles"
    permnote "  ${ColorDistinct}export | exp | exportapp             ${ColorNote} adds given command to application exports ($(distn "example: "${SOFIN_BIN_SHORT}" export rails Rust" "${ColorExample}"))"
    permnote
    permnote "  ${ColorDistinct}dump                                 ${ColorNote} dumps current default compiler and environment settings"
    permnote "  ${ColorDistinct}dump definition-name                 ${ColorNote} dumps definition-specific compiler and environment settings"
    permnote
    permnote "  ${ColorDistinct}log                                  ${ColorNote} shows tail of all logs (for debug messages and verbose info)"
    permnote "  ${ColorDistinct}log @                                ${ColorNote} shows tail of all Sofin logs"
    permnote "  ${ColorDistinct}log -                                ${ColorNote} shows tail of Sofin internal log only"
    permnote "  ${ColorDistinct}log +                                ${ColorNote} shows and watches all recently modified files"
    permnote "  ${ColorDistinct}log any-part-of-def-name             ${ColorNote} shows and watches log(s) which name matches pattern"
    permnote
    permnote "  ${ColorDistinct}up | update                          ${ColorNote} only update definitions from remote repository and exit"
    permnote "  ${ColorDistinct}upgrade defname srcurl               ${ColorNote} upgrade given definition using url as source archive"
    permnote "  ${ColorDistinct}ver | version                        ${ColorNote} shows "${SOFIN_BIN_SHORT}" script version"
    permnote "  ${ColorDistinct}util Bundle1 B2 BundleN              ${ColorNote} build given definitions as Sofin utilities."
    permnote "  ${ColorDistinct}clean                                ${ColorNote} cleans binbuilds cache, unpacked source content and logs"
    permnote "  ${ColorDistinct}distclean                            ${ColorNote} cleans binbuilds cache, unpacked source content, logs and definitions"
    permnote "  ${ColorDistinct}purge                                ${ColorNote} cleans binbuilds cache, unpacked source content, logs, definitions, source cache and possible states"
    permnote "  ${ColorDistinct}out | outdated                       ${ColorNote} lists outdated software"
    permnote "  ${ColorDistinct}build                                ${ColorNote} does binary build from source for software specified as params"
    permnote "  ${ColorDistinct}deploy | push | send                 ${ColorNote} creates binary build of software bundle(s) and pushes it to remote server ($(distn "example: "${SOFIN_BIN_SHORT}" push Rust Vifm Curl" "${ColorExample}"))"
    permnote "  ${ColorDistinct}wipe                                 ${ColorNote} wipes binary builds (matching given name) from binary respositories ($(distn "example: "${SOFIN_BIN_SHORT}" wipe Rust Vifm" "${ColorExample}"))"

    permnote
    permnote "  ${ColorDistinct}env                                  ${ColorNote} reads current Sofin environment."
    permnote "  ${ColorDistinct}env Bundle1 BundleN                  ${ColorNote} builds env for given bundles only (no persistence)."
    permnote "  ${ColorDistinct}env +Bundle1 +BundleN +Bund8 Any1    ${ColorNote} add given Bundle(s) to current env profile."
    permnote "  ${ColorDistinct}env +Bundle1 BundleN                 ${ColorNote} add given Bundle(s) to current env profile."
    permnote "  ${ColorDistinct}env -Bundle1 -Sup2 -BundleN          ${ColorNote} remove given Bundle(s) from current env profile."
    permnote "  ${ColorDistinct}env -Bundle1 Sup2 -BundleN           ${ColorNote} remove given Bundle(s) from current env profile."
    permnote "  ${ColorDistinct}env reset                            ${ColorNote} resets Sofin env to defaults."
    permnote "  ${ColorDistinct}env save MyProjectX                  ${ColorNote} saves Sofin env profile with given name."
    permnote "  ${ColorDistinct}env load MyProjectX                  ${ColorNote} loads Sofin env profile with given name (no persistence)."
    permnote "  ${ColorDistinct}env status                           ${ColorNote} shows Sofin status - list of Bundle(s) enabled for currently loaded profile."
    permnote "  ${ColorDistinct}env reload | rehash                  ${ColorNote} recreates and reloads Sofin shell environment"

    permnote
    permnote "  ${ColorDistinct}dev                                  ${ColorNote} puts definition content on the fly. Second argument is (lowercase) definition name (no extension). ($(distn "example: "${SOFIN_BIN_SHORT}" dev rubinius" "${ColorExample}"))"
    permnote "  ${ColorDistinct}reset                                ${ColorNote} resets local definitions repository"
    permnote "  ${ColorDistinct}diff                                 ${ColorNote} displays changes in current definitions cache. Accepts any part of definition name"
    permnote "  ${ColorDistinct}srccheck                             ${ColorNote} checks sources availability for all existing definitions in local definitions repository"
    permnote "  ${ColorDistinct}oldsrc                               ${ColorNote} lists unused sources in main repository"
    permnote "  ${ColorDistinct}service-dir|serv-dir|sdir bundle     ${ColorNote} prints the service path of a given software bundle"
    permnote "  ${ColorDistinct}software-dir|soft-dir|dir bundle     ${ColorNote} prints the software path of a given bundle"
    permnote "  ${ColorDistinct}utils-path|upath                     ${ColorNote} prints the Sofin utilities path (on the build hosts)"
    permnote
    permnote "  ${ColorDistinct}origins all | @                      ${ColorNote} checks origin of all definitions, for the new versions"
    permnote "  ${ColorDistinct}origins name othername               ${ColorNote} checks origin of specified software definitions, for the new versions"
}


default_compiler_features () {
    if [ "clang" = "${CC_NAME}" ] \
    && [ "clang++" = "${CXX_NAME}" ]; then
        permnote "\t ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorNote} ${ColorDistinct:-${ColorDistinct}}LLVM compilers${ColorNote}"
    fi
    if [ -z "${DEF_NO_LLVM_LINKER}" ] && [ "YES" = "${CAP_SYS_LLVM_LD}" ]; then
        permnote "\t ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorNote} ${ColorDistinct:-${ColorDistinct}}LLVM-LLD-linker${ColorNote}"
    elif [ -z "${DEF_NO_GOLDEN_LINKER}" ] && [ -n "${DEF_NO_LLVM_LINKER}" ] && [ "YES" = "${CAP_SYS_GOLD_LD}" ]; then
        permnote "\t ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorNote} ${ColorDistinct:-${ColorDistinct}}GNU-GOLD-linker${ColorNote}"
    else
        ${LD_BIN} -v 2>&1 \
            | ${GREP_BIN} -F "Apple" >/dev/null 2>&1
        if [ "0" = "${?}" ]; then
            permnote "\t ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorNote} ${ColorDistinct:-${ColorDistinct}}LD64 Dynamic-linker (Apple)${ColorNote}"
        fi

        ${LD_BIN} -v 2>&1 \
            | ${GREP_BIN} -E "^LLD [[:digit:]]*.[[:digit:]]*.[[:digit:]]*.*${SYSTEM_NAME} " >/dev/null 2>&1
        if [ "0" = "${?}" ]; then
            permnote "\t ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorNote} ${ColorDistinct:-${ColorDistinct}}LLVM LLD-linker${ColorNote}"
        fi

        ${LD_BIN} -v 2>&1 \
            | ${GREP_BIN} -E "GNU ld [[:digit:]]*.[[:digit:]]*.[[:digit:]]*.*${SYSTEM_NAME}" >/dev/null 2>&1
        if [ "0" = "${?}" ]; then
            permnote "\t ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorNote} ${ColorDistinct:-${ColorDistinct}}GNU linker${ColorNote}"
        fi
    fi

    # -fPIC + -fPIE checks:
    if [ -z "${DEF_NO_PIC}" ] \
    && [ -z "${DEF_NO_PIE}" ] \
    && [ -z "${DEF_NO_LLVM_LINKER}" ] \
    && [ "YES" = "${CAP_SYS_LLVM_LD}" ]; then
        permnote "\t ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorNote} ${ColorDistinct:-${ColorDistinct}}position-independent-code (PIC)${ColorNote}"
        permnote "\t ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorNote} ${ColorDistinct:-${ColorDistinct}}position-independent-executable (PIE)${ColorNote}"
        permnote "\t ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorNote} ${ColorDistinct:-${ColorDistinct}}linker-RELRO${ColorNote}"
        permnote "\t ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorNote} ${ColorDistinct:-${ColorDistinct}}linker-BINDNOW${ColorNote}"
    fi

    if [ -z "${DEF_NO_LINKER_DTAGS}" ]; then
        permnote "\t ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorNote} ${ColorDistinct:-${ColorDistinct}}linker-new-DTAGS${ColorNote}"
    fi
    if [ -n "${DEF_USE_LTO}" ] \
    && [ "arm64" != "${SYSTEM_ARCH}" ] \
    && [ "aarch64" != "${SYSTEM_ARCH}" ]; then
        permnote "\t ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorNote} ${ColorDistinct:-${ColorDistinct}}link-time-optimizations (LLVM-LTO)${ColorNote}"
    fi
    if [ -n "${DEF_USE_CFI}" ]; then
        permnote "\t ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorNote} ${ColorDistinct:-${ColorDistinct}}control-flow-integrity (LLVM-CFI)${ColorNote}"
    fi

    # -fstack-protector-all check:
    printf "%b\n" "${CFLAGS} ${CXXFLAGS}" | ${EGREP_BIN} 'fstack-protector-all' >/dev/null 2>&1 \
        && permnote "\t ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorNote} ${ColorDistinct:-${ColorDistinct}}stack-protector-all${ColorNote}"

    # -fstack-protector-strong check:
    printf "%b\n" "${CFLAGS} ${CXXFLAGS}" | ${EGREP_BIN} 'fstack-protector-strong' >/dev/null 2>&1 \
        && permnote "\t ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorNote} ${ColorDistinct:-${ColorDistinct}}stack-protector-strong${ColorNote}"

    # -fno-strict-overflow check:
    printf "%b\n" "${CFLAGS} ${CXXFLAGS}" | ${EGREP_BIN} 'fno-strict-overflow' >/dev/null 2>&1 \
        && permnote "\t ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorNote} ${ColorDistinct:-${ColorDistinct}}no-strict-overflow${ColorNote}"

    # -ftrapv check:
    # NOTE: Signed integer overflow raises the signal SIGILL instead of SIGABRT/SIGSEGV:
    printf "%b\n" "${CFLAGS} ${CXXFLAGS}" | ${EGREP_BIN} 'ftrapv' >/dev/null 2>&1 \
        && permnote "\t ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorNote} ${ColorDistinct:-${ColorDistinct}}trap-signed-integer-overflow (TRAPV)${ColorNote}"


    if [ -n "${DEF_USE_SAFE_STACK}" ] \
    && [ "arm64" != "${SYSTEM_ARCH}" ] \
    && [ "aarch64" != "${SYSTEM_ARCH}" ]; then
        permnote "\t ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorNote} ${ColorDistinct:-${ColorDistinct}}safe-stack${ColorNote}"
    fi
    if [ -z "${DEF_NO_RETPOLINE}" ]; then
        permnote "\t ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorNote} ${ColorDistinct:-${ColorDistinct}}retpoline${ColorNote}"
    fi
    if [ -n "${DEBUGBUILD}" ]; then
        permnote "\t ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorNote} ${ColorDistinct:-${ColorDistinct}}debug-build${ColorNote}"
    fi
    if [ -z "${DEF_NO_SSP_BUFFER_OVERRIDE}" ]; then
        permnote "\t ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorNote} ${ColorDistinct:-${ColorDistinct}}ssp-buffer-override${ColorNote}"
    fi
    if [ -z "${DEF_NO_FORTIFY_SOURCE}" ]; then
        permnote "\t ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorNote} ${ColorDistinct:-${ColorDistinct}}fortify-source${ColorNote}"
    fi

    # C++ standard used:
    if [ -n "${DEF_USE_CXX11}" ]; then
        permnote "\t ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorNote} ${ColorDistinct:-${ColorDistinct}}std-c++11${ColorNote}"
    elif [ -n "${DEF_USE_CXX14}" ]; then
        permnote "\t ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorNote} ${ColorDistinct:-${ColorDistinct}}std-c++14${ColorNote}"
    elif [ -n "${DEF_USE_CXX17}" ]; then
        permnote "\t ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorNote} ${ColorDistinct:-${ColorDistinct}}std-c++17${ColorNote}"
    fi
    if [ -z "${DEF_USE_CXX11}" ] \
    && [ -z "${DEF_USE_CXX14}" ] \
    && [ -z "${DEF_USE_CXX17}" ]; then
        # 14 is current standard since Sofin v1.8
        permnote "\t ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorNote} ${ColorDistinct:-${ColorDistinct}}std-c++14${ColorNote}"
    fi

}


sofin_header () {
    printf "\n     %b\n%b\n\n  %b\n  %b\n  %b\n\n  %b\n  %b\n\n" \
        "$(distn 'Sof' "${ColorWhite}")$(distn 'tware' "${ColorGray}") $(distn 'In' "${ColorWhite}")$(distn 'staller v' "${ColorGray}")${ColorWhite:-${ColorDistinct}}${SOFIN_VERSION}${ColorNote}" \
        "${ColorGreen:-${ColorDistinct}}____________________________________${ColorNote}" \
        "design, implementation: ${ColorDistinct}@dmilith${ColorNote}" \
        "developed since: ${ColorDistinct}2011${ColorNote}" \
        "released under: ${ColorDistinct}MIT/BSD${ColorNote}" \
        "running os: ${ColorDistinct}${OS_TRIPPLE}${ColorNote}" \
        "running shell: ${ColorDistinct}${SHELL}${ColorNote}"

    printf "  %b\n" "system capabilities:"
    IFS=\n set 2>/dev/null | ${EGREP_BIN} -I 'CAP_SYS_' 2>/dev/null | while IFS= read -r _envv; do
        if [ -n "${_envv}" ]; then
            printf "\t %b %b\n" \
                "${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorNote}" \
                "${ColorDistinct}$(lowercase "${_envv%=YES}")${ColorNote}"
        fi
    done

    printf "\n  %b\n" "terminal capabilities:"
    IFS=\n set 2>/dev/null | ${EGREP_BIN} -I 'CAP_TERM_' 2>/dev/null | while IFS= read -r _envv; do
        if [ -n "${_envv}" ]; then
            printf "\t %b %b\n" \
                "${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorNote}" \
                "${ColorDistinct}$(lowercase "${_envv%=YES}")${ColorNote}"
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
        debug "Sofin-tasks-locked by processes: ${ColorDistinct}${_processes}${ColorDebug}"
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
                permnote "${SUCCESS_CHAR} ${ColorDistinct}${_lbfapp_name}${ColorNote}"
            else
                warn "${ColorRed:-${ColorDistinct}}${FAIL_CHAR}${ColorWarning} ${_lbfapp_name} ${ColorRed:-${ColorDistinct}}[!]${ColorWarning}"
            fi
            for _lbfreq in $(${FIND_BIN} "${_lbfapp}" -mindepth 1 -maxdepth 1 -iname "*${DEFAULT_INST_MARK_EXT}" 2>/dev/null | ${SORT_BIN} 2>/dev/null); do
                _lbpp="$(printf "%b\n" "${_lbfreq##*/}" | ${SED_BIN} "s/${DEFAULT_INST_MARK_EXT}//" 2>/dev/null)"
                note "   ${NOTE_CHAR} ${ColorDistinct}${_lbpp}${ColorNote} ${ColorGray:-${ColorDistinct}}[${ColorNote}${ColorDistinct}$(${CAT_BIN} "${_lbfreq}" 2>/dev/null)${ColorNote}${ColorGray:-${ColorDistinct}}]${ColorNote}"
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
    case "${_sddefname}" in
        *"${DEFAULT_DEF_EXT}")
            ;;

        *)
            _sddefname="${_sddefname}${DEFAULT_DEF_EXT}"
            ;;
    esac
    _beauty_defn="${ColorDistinct}${_sddefname}${ColorNote}"

    (
        cd "${DEFINITIONS_DIR}"
        if [ -f "./${_sddefname}" ]; then
            debug "Checking status for untracked files of: ${ColorDistinct}${_sddefname}${ColorDebug}"
            ${GIT_BIN} status --short "${_sddefname}" 2>/dev/null | ${EGREP_BIN} '\?\?' >/dev/null 2>&1
            if [ "${?}" = "0" ]; then # found "??" which means file is untracked..
                permnote "No diff available for definition: ${_beauty_defn} (currently untracked)"
            else
                permnote "Showing detailed modifications of defintion: ${_beauty_defn}"
            fi
            ${GIT_BIN} status -vv --long "${_sddefname}" 2>/dev/null
        else
            permnote "Listing all modified definitions in local cache: (${ColorDistinct}${CACHE_DIR}${ColorNote})"
            ${GIT_BIN} status --short 2>/dev/null
        fi
    )
    unset _sddefname _beauty_defn
}


develop () {
    _defname_input="${*}"
    create_sofin_dirs
    _defname_no_ext="${_defname_input%"${DEFAULT_DEF_EXT}"}"
    _devname="$(lowercase "${_defname_no_ext##*/}")"
    if [ -z "${_defname_input}" ]; then
        error "No definition file name specified as first param!"
    fi
    permnote "Paste your definition below. Hit ${ColorDistinct}[Enter]${ColorNote}, ${ColorDistinct}Ctrl-D${ColorNote} to update definitions file: ${ColorDistinct}${DEFINITIONS_DIR}/${_devname}${DEFAULT_DEF_EXT}${ColorNote}"
    ${CAT_BIN} > "${DEFINITIONS_DIR}/${_devname}${DEFAULT_DEF_EXT}" 2>/dev/null
    unset _defname_input _devname _defname_no_ext
}


env_status () {
    if [ -f "${SOFIN_ENV_ENABLED_INDICATOR_FILE}" ]; then
        permnote "Sofin environment of ${ColorDistinct}specific${ColorNote} bundles: ${ColorDistinct}$(${CAT_BIN} "${SOFIN_ENV_ENABLED_INDICATOR_FILE}" | ${TR_BIN} '\n' ' ' 2>/dev/null)${ColorNote}"
    else
        permnote "Sofin environment is ${ColorDistinct}dynamic${ColorNote}. All installed software-bundles are included"
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
        && debug "Stored version: ${ColorDistinct}${_verfile}${ColorDebug} of software: ${ColorDistinct}${_softfile}${ColorDebug} installed in: ${ColorDistinct}${PREFIX}${ColorDebug}"
    unset _softname _verfile _softfile
}


mark_dependency_test_passed () {
    _softname="${1}"
    if [ -z "${_softname}" ]; then
        error "To mark dependency '${ColorDistinct}PASSED${ColorError}' - you must provide it's name first!"
    fi
    _softfile="$(lowercase "${_softname}")"
    run "${TOUCH_BIN} '${PREFIX}/${_softfile}${DEFAULT_TEST_PASSED_EXT}'" \
        && debug "Test suite ${ColorDistinct}PASSED${ColorDebug} for dependency: ${ColorDistinct}${_softfile}${ColorDebug}"
    unset _softname _verfile _softfile
}


show_done () {
    _sd_low_name="$(lowercase "${1}")"
    _sdver="$(${CAT_BIN} "${PREFIX}/${_sd_low_name}${DEFAULT_INST_MARK_EXT}" 2>/dev/null)"
    if [ -z "${_sdver}" ]; then
        _sdver="0"
    fi
    note "${SUCCESS_CHAR} ${_sd_low_name} [${ColorDistinct}${_sdver}${ColorNote}]"
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
            warn "No such definition: ${ColorDistinct}${_an_app}${ColorWarning}. No alternatives found."
        else
            warn "No such definition: ${ColorDistinct}${_an_app}${ColorWarning}. Alternatives found: ${ColorDistinct}${_contents}${ColorWarning}"
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
