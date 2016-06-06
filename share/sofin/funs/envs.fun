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
