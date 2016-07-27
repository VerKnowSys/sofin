
load_requirements () {
    # load base facts
    . share/sofin/facts/core.fact
    . share/sofin/facts/paths.fact

    # these two loaded only for colorful output:
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
    compiler_setup
    build_sofin_natives
    install_sofin_files
    update_env_files
}


# No-Op one for installer:
update_defs () {
    debug "Skipping definitions update in installation process."
}


build_sofin_natives () {
    _okch="$(distinct n "${ColorParams}${SUCCESS_CHAR}")"
    note "Building.."
    for _prov in ${SOFIN_PROVIDES}; do
        if [ -f "src/${_prov}.cc" ]; then
            run "${CXX_COMPILER_NAME} ${DEFAULT_COMPILER_FLAGS} -o bin/${_prov} src/${_prov}.cc" && \
                note "  ${_okch} src/${_prov}.cc"
        fi
    done
}


install_sofin_files () {
    _okch="$(distinct n "${ColorParams}${SUCCESS_CHAR}")"
    note "Installing.."
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
        note "  ${_okch} native utils"

    run "${CP_BIN} -vfR share/sofin ${PREFIX}usr/share/" && \
        note "  ${_okch} facts and functions"

    run "${INSTALL_BIN} -v src/s.sh ${PREFIX}usr/bin/s" && \
        note "  ${_okch} sofin launcher" && \
            note "Sofin installed with version: $(distinct n "${SOFIN_VERSION}")\n"

    note "Type: $(distinct n "s usage") for help."
    note "Read: $(distinct n "https://bitbucket.org/verknowsys/sofin") for more details."
}
