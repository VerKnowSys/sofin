#!/usr/bin/env sh

env_reset () {
    # unset conflicting environment variables
    # dynamic linker:
    unset LD_PRELOAD LD_LIBRARY_PATH DYLD_LIBRARY_PATH

    # utils
    unset CC CXX CPP LD AR RANLIB NM AS LIBTOOL

    # flags
    unset CFLAGS CXXFLAGS CPPFLAGS LDFLAGS

    # env, shell:
    unset LC_ALL LC_CTYPE LANGUAGE MAIL CDPATH

    LANG="${DEFAULT_LOCALE}"
    export LANG
}


env_pedantic () {
    set -e
}


env_forgivable () {
    set +e
}


enable_sofin_env () {
    _envs="${*}"
    if [ -z "${_envs}" ]; then
        _envs="Doas Git Mc Vim Sofin Zsh"
    fi
    debug "Enabling Sofin env for: ${ColorDistinct}${_envs}${ColorDebug}"
    for _env in $(to_iter "${_envs}"); do
        ${GREP_BIN} -Fx "${_env}" "${SOFIN_ENV_ENABLED_INDICATOR_FILE}" >/dev/null 2>&1 \
            || printf "%b\n" "${_env}" >> "${SOFIN_ENV_ENABLED_INDICATOR_FILE}"
    done
    note "Enabled Sofin environment for bundles: ${ColorDistinct}${_envs}${ColorNote}"
}


disable_sofin_env () {
    _envs="${*}"
    if [ -z "${_envs}" ]; then
        error "No bundles to disable were provided!"
    fi
    if [ "@" = "${_envs}" ]; then
        ${RM_BIN} -f "${SOFIN_ENV_ENABLED_INDICATOR_FILE}" \
            && debug "Environment file: ${ColorDistinct}${SOFIN_ENV_ENABLED_INDICATOR_FILE}${ColorDebug} removed."
    else
        for _env in $(to_iter "${_envs}"); do
            if [ -f "${SOFIN_ENV_ENABLED_INDICATOR_FILE}" ]; then
                # NOTE: remove exact line matches only (Git shouldn't remove Gitea):
                ${GREP_BIN} -vFx "${_env}" "${SOFIN_ENV_ENABLED_INDICATOR_FILE}" > "${SOFIN_ENV_ENABLED_INDICATOR_FILE}.tmp" 2>/dev/null
                ${MV_BIN} -f "${SOFIN_ENV_ENABLED_INDICATOR_FILE}.tmp" "${SOFIN_ENV_ENABLED_INDICATOR_FILE}"
            fi
        done
        permnote "Disabled bundles: ${ColorDistinct}${_envs}${ColorNote} from the Sofin environment"
    fi
}


set_c_and_cxx_flags () {
    _flagz="${*}"
    CFLAGS="-pipe ${_flagz} ${DEFAULT_COMPILER_FLAGS} -I${PREFIX}/include ${DEF_COMPILER_FLAGS}"
    CXXFLAGS="-pipe ${_flagz} ${DEFAULT_COMPILER_FLAGS} -I${PREFIX}/include ${DEF_COMPILER_FLAGS}"
    LDFLAGS="${DEFAULT_LINKER_FLAGS} -L${PREFIX}/lib ${DEF_LINKER_FLAGS}"
    # debug "set_c_and_cxx_flags(): flags: '${_flagz}'. CFLAGS: '${CFLAGS}'"
    # CFLAGS="$(printf "%b\n" "${_flagz} ${DEFAULT_COMPILER_FLAGS} -I${PREFIX}/include ${DEF_COMPILER_FLAGS}" | eval "${CUT_TRAILING_SPACES_GUARD}")"
    # CXXFLAGS="$(printf "%b\n" "${_flagz} ${DEFAULT_COMPILER_FLAGS} -I${PREFIX}/include ${DEF_COMPILER_FLAGS}" | eval "${CUT_TRAILING_SPACES_GUARD}")"
    # LDFLAGS="$(printf "%b\n" "${DEFAULT_LINKER_FLAGS} -L${PREFIX}/lib ${DEF_LINKER_FLAGS}" | eval "${CUT_TRAILING_SPACES_GUARD}")"
    unset _flagz
    export CFLAGS CXXFLAGS LDFLAGS
}


dump_compiler_setup () {
    if [ -n "${DEBUGBUILD}" ]; then
        debug " ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorDebug} ${ColorGreen:-${ColorDistinct}}debug-build${ColorDebug}"
        debug " ${ColorYellow:-${ColorDistinct}}${FAIL_CHAR}${ColorDebug} ${ColorGray:-${ColorDistinct}}production-build${ColorDebug}"
    else
        debug " ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorDebug} ${ColorGreen:-${ColorDistinct}}production-build${ColorDebug}"
        debug " ${ColorYellow:-${ColorDistinct}}${FAIL_CHAR}${ColorDebug} ${ColorGray:-${ColorDistinct}}debug-build${ColorDebug}"
    fi

    if [ -z "${DEF_NO_HARDEN_FLAGS}" ]; then
        debug " ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorDebug} ${ColorGreen:-${ColorDistinct}}extra-hardened-compiler-flags${ColorDebug}"
    else
        debug " ${ColorYellow:-${ColorDistinct}}${FAIL_CHAR}${ColorDebug} ${ColorGray:-${ColorDistinct}}extra-hardened-compiler-flags${ColorDebug}"
    fi

    if [ -z "${DEF_NO_CCACHE}" ]; then # ccache is supported by default but it's optional
        debug " ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorDebug} ${ColorGreen:-${ColorDistinct}}ccached-build${ColorDebug}"
    else
        debug " ${ColorYellow:-${ColorDistinct}}${FAIL_CHAR}${ColorDebug} ${ColorGray:-${ColorDistinct}}ccached-build${ColorDebug}"
    fi

    if [ -z "${DEF_NO_RETPOLINE}" ]; then
        debug " ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorDebug} ${ColorGreen:-${ColorDistinct}}cpu-branch-predict-mitigation (retpoline)${ColorDebug}"
    else
        debug " ${ColorYellow:-${ColorDistinct}}${FAIL_CHAR}${ColorDebug} ${ColorGray:-${ColorDistinct}}cpu-branch-predict-mitigation (retpoline)${ColorDebug}"
    fi

    if [ -z "${DEF_NO_SSP_BUFFER_OVERRIDE}" ]; then
        debug " ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorDebug} ${ColorGreen:-${ColorDistinct}}ssp-buffer-override${ColorDebug}"
    else
        debug " ${ColorYellow:-${ColorDistinct}}${FAIL_CHAR}${ColorDebug} ${ColorGray:-${ColorDistinct}}ssp-buffer-override${ColorDebug}"
    fi

    if [ -z "${DEF_NO_FORTIFY_SOURCE}" ]; then
        debug " ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorDebug} ${ColorGreen:-${ColorDistinct}}fortify-source${ColorDebug}"
    else
        debug " ${ColorYellow:-${ColorDistinct}}${FAIL_CHAR}${ColorDebug} ${ColorGray:-${ColorDistinct}}fortify-source${ColorDebug}"
    fi

    if [ -z "${DEF_NO_LLVM_LINKER}" ] && [ "YES" = "${CAP_SYS_LLVM_LD}" ]; then
        debug " ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorDebug} ${ColorGreen:-${ColorDistinct}}llvm-lld-linker${ColorDebug}"
        debug " ${ColorYellow:-${ColorDistinct}}${FAIL_CHAR}${ColorDebug} ${ColorGray:-${ColorDistinct}}gnu-gold-linker${ColorDebug}"
        debug " ${ColorYellow:-${ColorDistinct}}${FAIL_CHAR}${ColorDebug} ${ColorGray:-${ColorDistinct}}system-linker${ColorDebug}"
    elif [ -z "${DEF_NO_GOLDEN_LINKER}" ] && [ -n "${DEF_NO_LLVM_LINKER}" ] && [ "YES" = "${CAP_SYS_GOLD_LD}" ]; then
        debug " ${ColorYellow:-${ColorDistinct}}${FAIL_CHAR}${ColorDebug} ${ColorGray:-${ColorDistinct}}llvm-lld-linker${ColorDebug}"
        debug " ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorDebug} ${ColorGreen:-${ColorDistinct}}gnu-gold-linker${ColorDebug}"
        debug " ${ColorYellow:-${ColorDistinct}}${FAIL_CHAR}${ColorDebug} ${ColorGray:-${ColorDistinct}}system-linker${ColorDebug}"
    else
        debug " ${ColorYellow:-${ColorDistinct}}${FAIL_CHAR}${ColorDebug} ${ColorGray:-${ColorDistinct}}llvm-lld-linker${ColorDebug}"
        debug " ${ColorYellow:-${ColorDistinct}}${FAIL_CHAR}${ColorDebug} ${ColorGray:-${ColorDistinct}}gnu-gold-linker${ColorDebug}"
        debug " ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorDebug} ${ColorGreen:-${ColorDistinct}}system-linker${ColorDebug}"
    fi

    # C++ standard used:
    printf "%b\n" "${CXXFLAGS}" | ${GREP_BIN} 'c++11' >/dev/null 2>&1
    if [ "0" = "${?}" ]; then
        debug " ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorDebug} ${ColorGreen:-${ColorDistinct}}C++ standard: std-c++11${ColorDebug}"
    else
        debug " ${ColorYellow:-${ColorDistinct}}${FAIL_CHAR}${ColorDebug} ${ColorGray:-${ColorDistinct}}C++ standard: std-c++11${ColorDebug}"
    fi
    printf "%b\n" "${CXXFLAGS}" | ${GREP_BIN} 'c++14' >/dev/null 2>&1
    if [ "0" = "${?}" ]; then
        debug " ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorDebug} ${ColorGreen:-${ColorDistinct}}C++ standard: std-c++14${ColorDebug}"
    else
        debug " ${ColorYellow:-${ColorDistinct}}${FAIL_CHAR}${ColorDebug} ${ColorGray:-${ColorDistinct}}C++ standard: std-c++14${ColorDebug}"
    fi
    printf "%b\n" "${CXXFLAGS}" | ${GREP_BIN} 'c++17' >/dev/null 2>&1
    if [ "0" = "${?}" ]; then
        debug " ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorDebug} ${ColorGreen:-${ColorDistinct}}C++ standard: std-c++17${ColorDebug}"
    else
        debug " ${ColorYellow:-${ColorDistinct}}${FAIL_CHAR}${ColorDebug} ${ColorGray:-${ColorDistinct}}C++ standard: std-c++17${ColorDebug}"
    fi
    printf "%b\n" "${CXXFLAGS}" | ${GREP_BIN} 'c++20' >/dev/null 2>&1
    if [ "0" = "${?}" ]; then
        debug " ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorDebug} ${ColorGreen:-${ColorDistinct}}C++ standard: std-c++20${ColorDebug}"
    else
        debug " ${ColorYellow:-${ColorDistinct}}${FAIL_CHAR}${ColorDebug} ${ColorGray:-${ColorDistinct}}C++ standard: std-c++20${ColorDebug}"
    fi

    printf "%b\n" "${CFLAGS} ${CXXFLAGS}" | ${EGREP_BIN} 'flto' >/dev/null 2>&1
    if [ "0" = "${?}" ]; then
        debug " ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorDebug} ${ColorGreen:-${ColorDistinct}}link-time-optimizations (LLVM-LTO)${ColorDebug}"
    else
        debug " ${ColorYellow:-${ColorDistinct}}${FAIL_CHAR}${ColorDebug} ${ColorGray:-${ColorDistinct}}link-time-optimizations (LLVM-LTO)${ColorDebug}"
    fi

    printf "%b\n" "${CFLAGS} ${CXXFLAGS}" | ${EGREP_BIN} 'fsanitize=cfi' >/dev/null 2>&1
    if [ "0" = "${?}" ]; then
        debug " ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorDebug} ${ColorGreen:-${ColorDistinct}}control-flow-integrity-sanitizer (LLVM-CFI)${ColorDebug}"
    else
        debug " ${ColorYellow:-${ColorDistinct}}${FAIL_CHAR}${ColorDebug} ${ColorGray:-${ColorDistinct}}control-flow-integrity-sanitizer (LLVM-CFI)${ColorDebug}"
    fi

    # SAFE_STACK check:
    printf "%b\n" "${CFLAGS} ${CXXFLAGS}" | ${EGREP_BIN} 'fsanitize=safe-stack' >/dev/null 2>&1
    if [ "0" = "${?}" ]; then
        debug " ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorDebug} ${ColorGreen:-${ColorDistinct}}safe-stack-sanitizer (LLVM-SAFE_STACK)${ColorDebug}"
    else
        debug " ${ColorYellow:-${ColorDistinct}}${FAIL_CHAR}${ColorDebug} ${ColorGray:-${ColorDistinct}}safe-stack-sanitizer (LLVM-SAFE_STACK)${ColorDebug}"
    fi

    # ASAN check:
    printf "%b\n" "${CFLAGS} ${CXXFLAGS}" | ${EGREP_BIN} 'fsanitize=address' >/dev/null 2>&1
    if [ "0" = "${?}" ]; then
        debug " ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorDebug} ${ColorGreen:-${ColorDistinct}}address-sanitizer (LLVM-ASAN)${ColorDebug}"
    else
        debug " ${ColorYellow:-${ColorDistinct}}${FAIL_CHAR}${ColorDebug} ${ColorGray:-${ColorDistinct}}address-sanitizer (LLVM-ASAN)${ColorDebug}"
    fi

    # -fPIC check:
    printf "%b\n" "${CFLAGS} ${CXXFLAGS}" | ${EGREP_BIN} 'f[Pp][Ii][Cc]' >/dev/null 2>&1
    if [ "0" = "${?}" ]; then
        debug " ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorDebug} ${ColorGreen:-${ColorDistinct}}position-independent-code${ColorDebug}"
    else
        debug " ${ColorYellow:-${ColorDistinct}}${FAIL_CHAR}${ColorDebug} ${ColorGray:-${ColorDistinct}}position-independent-code${ColorDebug}"
    fi

    # -fPIE check:
    printf "%b\n" "${CFLAGS} ${CXXFLAGS}" | ${EGREP_BIN} 'f[Pp][Ii][Ee]' >/dev/null 2>&1
    if [ "0" = "${?}" ]; then
        debug " ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorDebug} ${ColorGreen:-${ColorDistinct}}position-independent-executable${ColorDebug}"
    else
        debug " ${ColorYellow:-${ColorDistinct}}${FAIL_CHAR}${ColorDebug} ${ColorGray:-${ColorDistinct}}position-independent-executable${ColorDebug}"
    fi

    # -fstack-protector check:
    printf "%b\n" "${CFLAGS} ${CXXFLAGS}" | ${EGREP_BIN} 'fstack-protector ' >/dev/null 2>&1
    if [ "0" = "${?}" ]; then
        debug " ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorDebug} ${ColorGreen:-${ColorDistinct}}stack-protector${ColorDebug}"
    else
        debug " ${ColorYellow:-${ColorDistinct}}${FAIL_CHAR}${ColorDebug} ${ColorGray:-${ColorDistinct}}stack-protector${ColorDebug}"
    fi

    # -fstack-protector-strong check:
    printf "%b\n" "${CFLAGS} ${CXXFLAGS}" | ${EGREP_BIN} 'fstack-protector-strong' >/dev/null 2>&1
    if [ "0" = "${?}" ]; then
        debug " ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorDebug} ${ColorGreen:-${ColorDistinct}}stack-protector-strong${ColorDebug}"
    else
        debug " ${ColorYellow:-${ColorDistinct}}${FAIL_CHAR}${ColorDebug} ${ColorGray:-${ColorDistinct}}stack-protector-strong${ColorDebug}"
    fi

    # -fstack-protector-all check:
    printf "%b\n" "${CFLAGS} ${CXXFLAGS}" | ${EGREP_BIN} 'fstack-protector-all' >/dev/null 2>&1
    if [ "0" = "${?}" ]; then
        debug " ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorDebug} ${ColorGreen:-${ColorDistinct}}stack-protector-all${ColorDebug}"
    else
        debug " ${ColorYellow:-${ColorDistinct}}${FAIL_CHAR}${ColorDebug} ${ColorGray:-${ColorDistinct}}stack-protector-all${ColorDebug}"
    fi

    # -fno-strict-overflow check:
    printf "%b\n" "${CFLAGS} ${CXXFLAGS}" | ${EGREP_BIN} 'fno-strict-overflow' >/dev/null 2>&1
    if [ "0" = "${?}" ]; then
        debug " ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorDebug} ${ColorGreen:-${ColorDistinct}}no-strict-overflow${ColorDebug}"
    else
        debug " ${ColorYellow:-${ColorDistinct}}${FAIL_CHAR}${ColorDebug} ${ColorGray:-${ColorDistinct}}no-strict-overflow${ColorDebug}"
    fi

    # -ftrapv check:
    # NOTE: Signed integer overflow raises the signal SIGILL instead of SIGABRT/SIGSEGV:
    printf "%b\n" "${CFLAGS} ${CXXFLAGS}" | ${EGREP_BIN} 'ftrapv' >/dev/null 2>&1
    if [ "0" = "${?}" ]; then
        debug " ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorDebug} ${ColorGreen:-${ColorDistinct}}trap-signed-integer-overflow${ColorDebug}"
    else
        debug " ${ColorYellow:-${ColorDistinct}}${FAIL_CHAR}${ColorDebug} ${ColorGray:-${ColorDistinct}}trap-signed-integer-overflow${ColorDebug}"
    fi

    if [ -z "${DEF_NO_LINKER_DTAGS}" ]; then
        debug " ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorDebug} ${ColorGreen:-${ColorDistinct}}enable-new-dtags${ColorDebug}"
    else
        debug " ${ColorYellow:-${ColorDistinct}}${FAIL_CHAR}${ColorDebug} ${ColorGray:-${ColorDistinct}}enable-new-dtags${ColorDebug}"
    fi

    if [ -z "${DEF_NO_FAST_MATH}" ]; then
        debug " ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorDebug} ${ColorGreen:-${ColorDistinct}}fast-math${ColorDebug}"
    else
        debug " ${ColorYellow:-${ColorDistinct}}${FAIL_CHAR}${ColorDebug} ${ColorGray:-${ColorDistinct}}fast-math${ColorDebug}"
    fi
}


dump_system_capabilities () {
    # NOTE: make sure that this is not the way with IFS instead of echoing on tr in for loops;
    IFS=\n set 2>/dev/null | ${EGREP_BIN} -i 'CAP_SYS_' 2>/dev/null | while IFS= read -r _capab
    do
        if [ -n "${_capab}" ]; then
            debug " ${ColorGreen:-${ColorDistinct}}${SUCCESS_CHAR}${ColorDebug} ${ColorGreen:-${ColorDistinct}}${_capab}${ColorDebug}"
        else
            debug " ${ColorYellow:-${ColorDistinct}}${FAIL_CHAR}${ColorDebug} ${ColorGray:-${ColorDistinct}}${_capab}${ColorDebug}"
        fi
    done
    unset _capab
}


compiler_setup () {
    _default_c="${CC_NAME}"
    _default_cxx="${CXX_NAME}"
    _default_cpp="${CPP_NAME}"

    # NOTE: Darwin case: no clang-cpp but clang -E as preprocesor there:
    if [ ! -x "${PREFIX}/bin/${_default_cpp}" ]; then
        _default_cpp="${_default_c} -E"
    fi
    CC="${_default_c}"
    CXX="${_default_cxx}"
    CPP="${_default_cpp}"
    unset _default_c _default_cxx _default_cpp

    # NOTE: Darwin case: when the default SDK is newer than the running system, use SDK matching the system.
    #       Newer SDK declares functions (f.e. pipe2() and dup3() in macOS 27 SDK) that are weak-linked,
    #       so configure tests detect them, but these are NULL at runtime on older systems:
    if [ "Darwin" = "${SYSTEM_NAME}" ] \
    && [ -z "${SDKROOT}" ]; then
        _os_major="${SYSTEM_VERSION%%.*}"
        _sdk_version="$(xcrun --show-sdk-version 2>/dev/null)"
        _matching_sdk="/Library/Developer/CommandLineTools/SDKs/MacOSX${_os_major}.sdk"
        if [ -n "${_os_major}" ] \
        && [ -n "${_sdk_version}" ] \
        && [ "${_sdk_version%%.*}" -gt "${_os_major}" ]; then
            if [ -d "${_matching_sdk}" ]; then
                SDKROOT="${_matching_sdk}"
                export SDKROOT
                debug "Default SDK: ${ColorDistinct}${_sdk_version}${ColorDebug} is newer than system: ${ColorDistinct}${SYSTEM_VERSION}${ColorDebug}. Using SDK: ${ColorDistinct}${SDKROOT}${ColorDebug}"
            else
                warn "Default SDK: ${ColorDistinct}${_sdk_version}${ColorWarning} is newer than system: ${ColorDistinct}${SYSTEM_VERSION}${ColorWarning}, and no matching SDK found in: ${ColorDistinct}${_matching_sdk}${ColorWarning}. Built software may crash on this system!"
            fi
        fi
        unset _os_major _sdk_version _matching_sdk
    fi

    # TODO: make a alternatives / or capability
    if [ -z "${DEF_NO_CCACHE}" ]; then # ccache is supported by default but it's optional
        if [ -x "${CCACHE_BIN}" ]; then
            CC="${CCACHE_BIN} /usr/bin/${CC}"
            CXX="${CCACHE_BIN} /usr/bin/${CXX}"
        else
            CC="/usr/bin/${CC}"
            CXX="/usr/bin/${CXX}"
        fi
    fi

    # NOTE: Default Linker pick order:
    # 1. LLVM Linker (ld.lld)
    # 2. Gold Linker (ld.gold)
    # 3. Legacy Linker (ld)
    unset _compiler_use_linker_flags
    if [ -z "${DEF_NO_LLVM_LINKER}" ] && [ "YES" = "${CAP_SYS_LLVM_LD}" ]; then
        #
        # NOTE: 64bit hardware architectures supported by LLVM (ld.lld) linker:
        #
        #       aarch64     =>          aarch64elf
        #       amd64       =>          elf_x86_64_fbsd
        #       mips64      =>          elf64btsmip_fbsd
        #       mips64el    =>          elf64ltsmip_fbsd
        #       powerpc64   =>          elf64ppc_fbsd
        #       riscv       =>          elf64riscv
        #       sparc64     =>          elf64_sparc_fbsd
        #

        case "${SYSTEM_ARCH}" in
            aarch64|arm64)
                LD="ld.lld -m aarch64elf"
                ;;

            amd64|x86_64)
                LD="ld.lld -m elf_x86_64_fbsd"
                ;;

            mips64)
                LD="ld.lld -m elf64btsmip_fbsd"
                ;;

            mips64el)
                LD="ld.lld -m elf64ltsmip_fbsd"
                ;;

            powerpc64)
                LD="ld.lld -m elf64ppc_fbsd"
                ;;

            riscv)
                LD="ld.lld -m elf64riscv"
                ;;

            sparc64)
                LD="ld.lld -m elf64_sparc_fbsd"
                ;;
         esac

        _compiler_use_linker_flags="-fuse-ld=lld"


    elif [ -z "${DEF_NO_GOLDEN_LINKER}" ] \
      && [ "YES" = "${CAP_SYS_GOLD_LD}" ]; then

        # Golden linker support:
        case "${SYSTEM_NAME}" in
            FreeBSD|Minix)
                _llvm_pfx="/Software/Gold"
                _llvm_target="$(${_llvm_pfx}/bin/llvm-config --host-target 2>/dev/null || :)"
                if [ -n "${_llvm_target}" ] \
                && [ -d "${_llvm_pfx}/${_llvm_target}" ]; then
                    _compiler_use_linker_flags="-fuse-ld=gold"
                    LD="${LD_BIN}.gold --plugin ${GOLD_SO}"
                    RANLIB="${_llvm_pfx}/${_llvm_target}/bin/ranlib --plugin ${GOLD_SO}"
                    NM="${_llvm_pfx}/${_llvm_target}/bin/nm --plugin ${GOLD_SO}"
                    AR="${_llvm_pfx}/${_llvm_target}/bin/ar"
                    AS="${_llvm_pfx}/${_llvm_target}/bin/as"
                    STRIP="${_llvm_pfx}/${_llvm_target}/bin/strip"
                    debug "GNU-GOLD-LD linker configured."
                else
                    debug "Failed to get LLVM-host-target hint from llvm-config. Got: '${ColorDistinct}${_llvm_target}${ColorDebug}'"
                    unset NM AR AS RANLIB STRIP
                    if [ -x "${GOLD_SO}" ] \
                    && [ -x "${LD_BIN}.gold" ]; then
                        LD="${LD_BIN}.gold --plugin ${GOLD_SO}"
                    else
                        # Fallback:
                        LD="${LD_BIN}"
                    fi
                fi
                unset _llvm_pfx _llvm_target
                ;;

            Darwin)
                unset NM AR AS RANLIB LD STRIP
                ;;

            Linux)
                unset NM AR AS RANLIB LD STRIP
                RANLIB="${RANLIB_BIN}"
                ;;
        esac
    else
        # NOTE: fallback with reset to system defaults - usually regular linker:
        unset NM AR AS RANLIB LD
    fi

    unset DEFAULT_LINKER_FLAGS CMACROS
    if [ -z "${DEF_NO_FORTIFY_SOURCE}" ] \
    && [ -z "${DEBUGBUILD}" ]; then
        CMACROS="${HARDEN_CMACROS}"
    fi

    if [ -z "${DEF_NO_HARDEN_FLAGS}" ]; then
        case "${SYSTEM_NAME}" in
            FreeBSD|OpenBSD)
                DEFAULT_COMPILER_FLAGS="${SINGLE_ERROR_CFLAGS} ${CFLAGS_PRODUCTION} ${HARDEN_CFLAGS} ${CMACROS}"
                DEFAULT_LINKER_FLAGS="${LDFLAGS_PRODUCTION}"
                ;;

            Darwin|Linux)
                DEFAULT_COMPILER_FLAGS="${SINGLE_ERROR_CFLAGS} ${HARDEN_CFLAGS} ${CMACROS}"
                ;;

            Minix)
                # Disabled -fstack-protector-strong - not supported on clang 3.4
                DEFAULT_COMPILER_FLAGS="${SINGLE_ERROR_CFLAGS} ${CFLAGS_PRODUCTION} ${CMACROS}"
                ;;
        esac
    else
        case "${SYSTEM_NAME}" in
            Darwin|Minix)
                DEFAULT_COMPILER_FLAGS="${SINGLE_ERROR_CFLAGS}"
                ;;

            *)
                DEFAULT_COMPILER_FLAGS="${SINGLE_ERROR_CFLAGS} ${CFLAGS_PRODUCTION}"
                DEFAULT_LINKER_FLAGS="${LDFLAGS_PRODUCTION}"
                ;;
        esac
    fi

    # CFLAGS, CXXFLAGS setup:
    set_c_and_cxx_flags "${_compiler_use_linker_flags}"

    # pick version of DWARF format, it's known that dwarf-5 causes build failures on FreeBSD 11.x:
    _dwarf_version="${DEFAULT_DWARF_VERSION}"
    case "${SYSTEM_NAME}-${SYSTEM_VERSION}" in
         FreeBSD-11*)
            _dwarf_version="4"
            ;;
    esac

    # inject debug compiler options
    if [ -n "${DEBUGBUILD}" ]; then
        # NOTE: since we set ASAN_CFLAGS for DEBUG-builds we drop HARDEN_SAFE_STACK_FLAGS if DEBUGBUILD is set
        _dbgflags="-O0 -gdwarf-${_dwarf_version} -glldb" # ${ASAN_CFLAGS}
        debug "DEBUGBUILD is enabled. Additional compiler flags: ${ColorDistinct}${_dbgflags}${ColorDebug}"
        CFLAGS="${CFLAGS} ${_dbgflags}"
        CXXFLAGS="${CXXFLAGS} ${_dbgflags}"
        # LDFLAGS="${LDFLAGS} ${_dbgflags}"
    else
        CFLAGS="${CFLAGS} -gdwarf-${_dwarf_version}"
        CXXFLAGS="${CXXFLAGS} -gdwarf-${_dwarf_version}"
    fi

    if [ -z "${DEF_NO_PIC}" ]; then
        CFLAGS="${CFLAGS} -fPIC"
        CXXFLAGS="${CXXFLAGS} -fPIC"
        # LDFLAGS="-fPIC ${LDFLAGS}"
    fi
    if [ -z "${DEF_NO_PIE}" ]; then
        CFLAGS="${CFLAGS} -fPIE"
        CXXFLAGS="${CXXFLAGS} -fPIE"
        LDFLAGS="${LDFLAGS} -pie"
    fi
    if [ -z "${DEF_NO_LINKER_DTAGS}" ]; then
        CFLAGS="${CFLAGS} -Wl,-rpath=${PREFIX}/lib,--enable-new-dtags"
        CXXFLAGS="${CXXFLAGS} -Wl,-rpath=${PREFIX}/lib,--enable-new-dtags"
        # LDFLAGS="${LDFLAGS} -rpath=${PREFIX}/lib --enable-new-dtags"
    fi
    if [ -z "${DEF_NO_FAST_MATH}" ]; then
        CFLAGS="${CFLAGS} -ffast-math"
        CXXFLAGS="${CXXFLAGS} -ffast-math"
    fi

    if [ -z "${DEF_NO_TRAP_INT_OVERFLOW}" ]; then
        CFLAGS="${CFLAGS} ${HARDEN_OFLOW_CFLAGS}"
        CXXFLAGS="${CXXFLAGS} ${HARDEN_OFLOW_CFLAGS}"
    fi

    # Don't enable safe-stack on unsupported platforms:
    if [ -n "${DEF_USE_SAFE_STACK}" ] \
    && [ -z "${DEBUGBUILD}" ] \
    && [ "Darwin" != "${SYSTEM_NAME}" ] \
    && [ "Linux" != "${SYSTEM_NAME}" ] \
    && [ "Minix" != "${SYSTEM_NAME}" ] \
    && [ "arm64" != "${SYSTEM_ARCH}" ] \
    && [ "aarch64" != "${SYSTEM_ARCH}" ]; then
        CFLAGS="${CFLAGS} ${HARDEN_SAFE_STACK_FLAGS}"
        CXXFLAGS="${CXXFLAGS} ${HARDEN_SAFE_STACK_FLAGS}"
        # LDFLAGS="${LDFLAGS} ${HARDEN_SAFE_STACK_FLAGS}"
    fi

    # Enable LTO only if LLVM LLD linker is available:
    # && [ "arm64" != "${SYSTEM_ARCH}" ] \
    # && [ "aarch64" != "${SYSTEM_ARCH}" ] \
    if [ -n "${DEF_USE_LTO}" ] \
    && [ -z "${DEBUGBUILD}" ] \
    && [ "YES" = "${CAP_SYS_LLVM_LD}" ]; then
        CFLAGS="${CFLAGS} ${LTO_CFLAGS}"
        CXXFLAGS="${CXXFLAGS} ${LTO_CFLAGS}"

        # only when LTO is enabled, we can enable CFI:
        if [ -n "${DEF_USE_CFI}" ]; then
            CFLAGS="${CFLAGS} ${CFI_CFLAGS}"
            CXXFLAGS="${CXXFLAGS} ${CFI_CFLAGS}"
        fi

        # if [ -n "${CAP_SYS_BUILDHOST}" ]; then
        #     warn_about_non_llvm_ld_on_buildhosts () {
        #         warn ""
        #         warn "   + Definition: $(distw "${DEF_NAME}${DEF_SUFFIX}") requested build-feature: $(distw "DEF_USE_LTO=YES")."
        #         warn "   + System linker LD=$(distw "${LD_BIN}") is NOT a modern $(distw "LLVM Linker")."
        #         warn "   ! LLVM linker $(distw "v6+") is required for $(distw "link-time-optimization") build-feature!"
        #         warn "   = If your Build-Host is built on top of the $(distw "11-stable") base-system, try quick workaround shown below and retry failed build process."
        #         warn ""
        #         warn "   \$ $(distw "mv /usr/bin/ld /usr/bin/ld.original && ln -s /usr/bin/ld.lld /usr/bin/ld")"
        #         warn ""
        #     }
        #     # determine if LD is LLD. If not - throw a fat warning with workaround for 11-stable-based build-hosts
        #     try "${LD_BIN} --version 2>&1 | ${GREP_BIN} -E 'LLD [[:digit:]]*.[[:digit:]]*.[[:digit:]]*'" \
        #         || warn_about_non_llvm_ld_on_buildhosts
        # fi
    fi

    # # LTO works on Darwin, but stuff is done slightly different way on macOS…
    # if [ "Darwin" = "${SYSTEM_NAME}" ]; then
    #     # as long as value of "${DEF_USE_LTO}" is unset
    #     # (or simply the value is != "YES"), then it's
    #     # just enabled by default on 64bit
    #     # HardenedBSD/ FreeBSD and Darwin systems.
    #     if [ "YES" = "${DEF_USE_LTO}" ] \
    #     && [ -z "${DEBUGBUILD}" ]; then
    #         CFLAGS="${CFLAGS} ${LTO_CFLAGS}"
    #         CXXFLAGS="${CXXFLAGS} ${LTO_CFLAGS}"

    #         # only when LTO is enabled, we can enable CFI:
    #         if [ -n "${DEF_USE_CFI}" ]; then
    #             CFLAGS="${CFLAGS} ${CFI_CFLAGS}"
    #             CXXFLAGS="${CXXFLAGS} ${CFI_CFLAGS}"
    #         fi
    #     fi
    # fi

    if [ -z "${DEF_NO_SSP_BUFFER_OVERRIDE}" ]; then
        CFLAGS="${CFLAGS} ${SSP_BUFFER_OVERRIDE}"
        CXXFLAGS="${CXXFLAGS} ${SSP_BUFFER_OVERRIDE}"
    fi

    # C++ standard:
    if [ -n "${DEF_USE_CXX11}" ]; then
        unset DEF_USE_CXX14 DEF_USE_CXX17 DEF_USE_CXX20
        CXXFLAGS="${CXXFLAGS} ${CXX11_CXXFLAGS}"
    fi
    if [ -n "${DEF_USE_CXX14}" ]; then
        unset DEF_USE_CXX11 DEF_USE_CXX17 DEF_USE_CXX20
        CXXFLAGS="${CXXFLAGS} ${CXX14_CXXFLAGS}"
    fi
    if [ -n "${DEF_USE_CXX17}" ]; then
        unset DEF_USE_CXX11 DEF_USE_CXX14 DEF_USE_CXX20
        CXXFLAGS="${CXXFLAGS} ${CXX17_CXXFLAGS}"
    fi
    if [ -n "${DEF_USE_CXX20}" ]; then
        unset DEF_USE_CXX11 DEF_USE_CXX14 DEF_USE_CXX17
        CXXFLAGS="${CXXFLAGS} ${CXX20_CXXFLAGS}"
    fi
    if [ -z "${DEF_USE_CXX11}" ] \
    && [ -z "${DEF_USE_CXX14}" ] \
    && [ -z "${DEF_USE_CXX17}" ] \
    && [ -z "${DEF_USE_CXX20}" ]; then
        debug "Using ${ColorDistinct}C++14${ColorDebug} as C++ default standard."
        DEF_USE_CXX14=YES
        CXXFLAGS="${CXXFLAGS} ${CXX14_CXXFLAGS}"
    fi

    if [ -z "${DEF_NO_RETPOLINE}" ]; then
        CFLAGS="${CFLAGS} ${RETPOLINE_CFLAGS}"
        CXXFLAGS="${CXXFLAGS} ${RETPOLINE_CFLAGS}"
        LDFLAGS="${LDFLAGS} -z retpolineplt"
    fi

    # If DEF_LINKER_FLAGS is set on definition side, append it's content to LDFLAGS:
    # if [ -n "${DEF_LINKER_FLAGS}" ]; then
    #     LDFLAGS="${LDFLAGS} ${DEF_LINKER_FLAGS}"
    # fi
    # if [ -n "${DEF_COMPILER_FLAGS}" ]; then
    #     CFLAGS="${CFLAGS} ${DEF_COMPILER_FLAGS}"
    #     CXXFLAGS="${CXXFLAGS} ${DEF_COMPILER_FLAGS}"
    # fi

    # NOTE: some definitions fails on missing values for these:
    AR="${AR:-ar}"
    AS="${AS:-as}"
    NM="${NM:-nm}"
    LD="${LD:-ld}"
    CC="${CC:-cc}"
    CXX="${CXX:-c++}"
    CPP="${CPP:-cpp}"
    RANLIB="${RANLIB:-ranlib}"

    # export definitions critical to compiler environment:
    export CFLAGS CXXFLAGS LDFLAGS LD AR AS NM CC CXX CPP RANLIB
}


create_lock () {
    _bundle_name="${1}"
    _bundle_cap="$(capitalize_abs "${_bundle_name}")"
    if [ -z "${_bundle_name}" ]; then
        error "No bundle name specified to lock!"
    fi
    debug "Acquring bundle-lock for PID: ${ColorDistinct}${SOFIN_PID}${ColorDebug} of bundle: ${ColorDistinct}${_bundle_name}${ColorDebug}"
    try "${MKDIR_BIN} -p '${LOCKS_DIR}'"
    printf "%b\n" "${SOFIN_PID}" > "${LOCKS_DIR}${_bundle_cap}${DEFAULT_LOCK_EXT}"
    unset _bundle_cap _bundle_name
}


acquire_lock_for () {
    _bundles="${*}"
    for _bundle in $(to_iter "${_bundles}"); do
        _bundle="$(capitalize_abs "${_bundle%=*}")" # cut off possible postfix with custom version, f.e.: =1.2.3
        debug "Acquiring lock for bundle: [${ColorDistinct}${_bundle}${ColorDebug}]"
        if [ -f "${LOCKS_DIR}${_bundle}${DEFAULT_LOCK_EXT}" ]; then
            _lock_pid="$(${CAT_BIN} "${LOCKS_DIR}${_bundle}${DEFAULT_LOCK_EXT}" 2>/dev/null)"
            if [ -n "${_lock_pid}" ]; then
                debug "Lock pid: ${ColorDistinct}${_lock_pid}${ColorDebug}. Sofin pid: ${ColorDistinct}${SOFIN_PID}${ColorDebug}, Sofin PPID: ${ColorDistinct}${PPID}${ColorDebug}"
                try "${KILL_BIN} -0 ${_lock_pid}"
                if [ "${?}" = "0" ]; then # NOTE: process is alive
                    if [ "${_lock_pid}" = "${SOFIN_PID}" ] \
                    || [ "${PPID}" = "${_lock_pid}" ]; then
                        debug "Dealing with own process or it's fork, process may continue.."
                    else
                        error "Bundle: ${ColorDistinct}${_bundle}${ColorError} is locked due to background job pid: ${ColorDistinct}${_lock_pid}${ColorError}"
                    fi
                else # NOTE: process is dead
                    debug "Found lock file acquired by dead process. Acquring a new lock.."
                    create_lock "${_bundle}"
                fi
            else
                debug "Lock pid: ${ColorDistinct}none${ColorDebug}, Sofin pid: ${ColorDistinct}${SOFIN_PID}${ColorDebug}"
            fi
        else
            debug "No file lock for bundle: ${ColorDistinct}${_bundle}${ColorDebug}"
            create_lock "${_bundle}"
        fi
    done
    unset _bundle _bundles _lock_pid
}


release_locks () {
    for _lock_file in $(${FIND_BIN} "${LOCKS_DIR}" -name '*.lock' 2>/dev/null); do
        _lock_pid="$(${CAT_BIN} "${_lock_file}")"
        if [ "${_lock_pid}" = "${SOFIN_PID}" ]; then
            debug "Removing lock file: ${ColorDistinct}${_lock_file##*/}${ColorDebug} that contains current pid: ${ColorDistinct}${SOFIN_PID}${ColorDebug}"
            ${RM_BIN} -f "${_lock_file}"
        fi
    done
    unset _lock_pid _lock_file
}


destroy_dead_locks_of_bundle () {
    _pattern="${1}"
    if [ -n "${_pattern}" ]; then
        debug "destroy_dead_locks_of_bundle(): With pattern: '${ColorDistinct}${_pattern}${ColorDebug}'"
        _pid="${SOFIN_PID}"
        for _dlf in $(${FIND_BIN} "${LOCKS_DIR%/}" -mindepth 1 -maxdepth 1 -name "*${_pattern}*${DEFAULT_LOCK_EXT}" -print 2>/dev/null); do
            try "${EGREP_BIN} '^${_pid}$' ${_dlf}" \
                && try "${RM_BIN} -f '${_dlf}'" \
                    && debug "Removed currently owned pid lock: ${ColorDistinct}${_dlf}${ColorDebug}"

            _possiblepid="$(${CAT_BIN} "${_dlf}" 2>/dev/null)"
            if [ -n "${_possiblepid}" ]; then
                try "${KILL_BIN} -0 ${_possiblepid}"
                if [ "${?}" != "0" ]; then
                    try "${RM_BIN} -f '${_dlf}'" \
                        && debug "Pid: ${ColorDistinct}${_pid}${ColorDebug} appears to be already dead. Removed lock file: ${ColorDistinct}${_dlf}${ColorDebug}"
                else
                    debug "Pid: ${ColorDistinct}${_pid}${ColorDebug} is alive. Leaving lock untouched."
                fi
            fi
        done \
            && debug "Finished locks cleanup using pattern: ${ColorDistinct}${_pattern:-''}${ColorDebug} that belong to pid: ${ColorDistinct}${_pid}${ColorDebug}"
    fi
    unset _dlf _pid _possiblepid _pattern
}


update_shell_vars () {
    print_env_status > "${SOFIN_PROFILE}"
    print_shell_vars >> "${SOFIN_PROFILE}"
    print_local_env_vars >> "${SOFIN_PROFILE}"
}


reload_shell () {
    if [ -z "${NO_SIGNAL}" ]; then
        # NOTE: PPID contains pid of parent shell of Sofin
        if [ -n "${PPID}" ]; then
            try "${KILL_BIN} -SIGUSR2 ${PPID}" \
                && debug "Reload signal sent to parent pid: ${ColorDistinct}${PPID}${ColorDebug}"
        else
            debug "Skipped reload_shell() for no ${ColorDistinct}PPID${ColorDebug}"
        fi
    else
        debug "Signal handler skipped on demand: ${ColorDistinct}NO_SIGNAL=${NO_SIGNAL}${ColorDebug}"
    fi
}


update_system_shell_env_files () {
    for _env_file in "${HOME}/.zshenv" "${HOME}/.bashrc"; do
        if [ -f "${_env_file}" ]; then
            ${GREP_BIN} -F 'Sofin launcher function' "${_env_file}" >/dev/null 2>&1
            if [ "${?}" = "0" ]; then
                continue
            else
                printf "\n\n%b\n" "${SOFIN_SHELL_BLOCK}" >> "${_env_file}" \
                    && debug "Environment block appended to file: ${ColorDistinct}${_env_file}${ColorDebug}"
            fi
        else
            printf "\n\n%b\n" "${SOFIN_SHELL_BLOCK}" >> "${_env_file}" \
                && debug "Environment block written to file: ${ColorDistinct}${_env_file}${ColorDebug}"
        fi
    done
    unset _default_envs _env_file
}


load_sysctl_system_defaults () {
    try "${SYSCTL_BIN} -f '${DEFAULT_SYSCTL_CONF}' >/dev/null 2>> ${LOG}" \
        && debug "Restored sysctl system-defaults from: ${ColorDistinct}${DEFAULT_SYSCTL_CONF}${ColorDebug}."
}


load_sysctl_system_production_hardening () {
    if [ -n "${CAP_SYS_HARDENED}" ]; then
        if [ -n "${CAP_SYS_PRODUCTION}" ] \
        || [ -n "${CAP_SYS_WORKSTATION}" ]; then
            debug "No sysctl.conf autoload for production/workstation systems${CHAR_DOTS}"
        elif [ -n "${CAP_SYS_BUILDHOST}" ]; then
            _sp="$(processes_all_sofin)" # Make sure there are no Sofin processes running in background
            if [ -z "${_sp}" ]; then
                load_sysctl_system_defaults
            else
                debug "System security sysctls left intact, since Sofin background tasks were found${CHAR_DOTS}"
            fi
        fi
    fi
}


load_sysctl_buildhost_hardening () {
    if [ -n "${CAP_SYS_HARDENED}" ] \
    && [ -n "${CAP_SYS_BUILDHOST}" ]; then
        try "${SYSCTL_BIN} \
            hardening.pax.segvguard.status=1 \
            hardening.pax.mprotect.status=1 \
            hardening.pax.pageexec.status=1 \
            hardening.pax.disallow_map32bit.status=1 \
            hardening.pax.aslr.status=1 \
            >/dev/null" \
                && debug "load_sysctl_buildhost_hardening(): System-hardening features are DISABLED now! (not enforced by kernel)!"
    elif [ -n "${CAP_SYS_WORKSTATION}" ]; then
        debug "No hardening for workstation systems"
    else
        load_sysctl_system_defaults \
            && debug "Loaded sysctl system defaults"
    fi
}
