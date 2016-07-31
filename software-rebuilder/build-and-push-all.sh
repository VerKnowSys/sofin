#/bin/sh

. /usr/share/sofin/loader

if [ "FreeBSD" = "${SYSTEM_NAME}" ]; then
    try "${CHMOD_BIN} 600 ~/.ssh/id_rsa"
    . /var/ServeD-OS/setup-buildhost
    setup_buildhost
fi

${TEST_BIN} ! -x /Software/Ccache/bin/ccache || ${SOFIN_BIN} i Ccache

note "Checking remote machine connection (shouldn't take more than a second).."
run "${SSH_BIN} sofin@verknowsys.com uname -a"

set +e

_working_state_file="/tmp/processing-software.list"
if [ ! -f "${_working_state_file}" ]; then
    note "Creating new file: $(distinct n "${_working_state_file}")"
    run "${CP_BIN} -v software.list ${_working_state_file}"
fi

for software in $(${CAT_BIN} ${_working_state_file} 2>/dev/null); do
    if [ "${software}" = "------" ]; then
        note "Finished task."
        exit
    fi
    note "________________________________"

    if [ "FreeBSD" = "${SYSTEM_NAME}" ]; then
        ${SOFIN_BIN} reset && \
            note "Sofin definitions reset for production host type"
    fi

    note "Processing software: $(distinct n "${software}")"
    ${SOFIN_BIN} rm ${software}
    DEVEL=YES ${SOFIN_BIN} deploy ${software} && \
    ${SOFIN_BIN} rm ${software} && \
    ${SED_BIN} -i '' -e "/${software}/d" ${_working_state_file}
    note "--------------------------------"
done
