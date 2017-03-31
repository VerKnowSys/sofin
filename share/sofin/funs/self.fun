
load_requirements () {
    # load base facts
    . share/sofin/facts/core.fact
    . share/sofin/facts/paths.fact

    # these two loaded only for colorful output:
    . share/sofin/facts/system.fact
    . share/sofin/facts/terminal.fact
    . share/sofin/facts/sofin.fact

    # load functions
    . share/sofin/funs/core.fun
    . share/sofin/funs/commons.fun
    . share/sofin/funs/envs.fun
    . share/sofin/funs/internals.fun
    . share/sofin/funs/cleaners.fun
    . share/sofin/funs/caches.fun
}


install_sofin () {
    permnote "Installing Software Installer, version: $(distn "${SOFIN_VERSION}")"
    if [ -n "${PREFIX}" ]; then
        permnote "Installing to given PREFIX: $(distn "${PREFIX}")"
    fi
    CAP_SYS_PRODUCTION=YES
    compiler_setup && \
        build_sofin_natives && \
            install_sofin_files && \
                note "Installation successful."
    update_system_shell_env_files
}


# No-Op one for installer:
update_defs () {
    debug "Skipping definitions update in installation process."
}


build_sofin_natives () {
    _okch="$(distn "${SUCCESS_CHAR}" "${ColorParams}")"
    permnote "Building native utils.."
    compiler_setup
    for _prov in ${SOFIN_PROVIDES}; do
        if [ -f "src/${_prov}.cc" ]; then
            run "${CXX_COMPILER_NAME} ${COMMON_COMPILER_FLAGS} -o bin/${_prov} src/${_prov}.cc" && \
                permnote "  ${_okch} src/${_prov}.cc"
        fi
    done
}


install_sofin_files () {
    set -e
    _okch="$(distn "${SUCCESS_CHAR}" "${ColorParams}")"
    permnote "Installing.."
    if [ -n "${PREFIX}" ]; then
        for _a_destph in "${PREFIX}" "${PREFIX}etc" "${PREFIX}usr/bin"; do
            try "${MKDIR_BIN} -p ${_a_destph}"
        done
    else
        PREFIX="/"
    fi
    for _prov in ${SOFIN_PROVIDES}; do
        if [ -f "bin/${_prov}" ]; then
            run "${INSTALL_BIN} -v bin/${_prov} ${PREFIX}usr/bin"
            run "${RM_BIN} -f bin/${_prov}"
        fi
    done && \
        permnote "  ${_okch} native utils"

    run "${CP_BIN} -vfR share/sofin ${PREFIX}usr/share/" && \
        permnote "  ${_okch} facts and functions"

    run "${INSTALL_BIN} -v src/s.sh ${PREFIX}usr/bin/s" && \
        permnote "  ${_okch} sofin launcher" && \
        permnote "Type: $(distn "s usage") for help." && \
        note "Read: $(distn "https://github.com/VerKnowSys/sofin") for more details." && \
            return 0
    return 1
}
