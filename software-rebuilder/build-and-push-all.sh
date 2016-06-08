#/bin/sh

. /usr/share/sofin/loader

${CHMOD_BIN} 600 ~/.ssh/id_rsa
. /var/ServeD-OS/setup-buildhost
setup_buildhost

${TEST_BIN} ! -x /Software/Ccache/bin/ccache || ${SOFIN_BIN} i Ccache

note "Checking remote machine connection (shouldn't take more than a second).."
${SSH_BIN} sofin@verknowsys.com "uname -a"

set +e

for software in $(${CAT_BIN} software.list); do
    if [ "${software}" = "------" ]; then
        note "Finished task."
        exit
    fi
    note "________________________________"
    note "Resetting Sofin definitions"
    ${SOFIN_BIN} reset
    note "Processing software: ${software}"
    ${SOFIN_BIN} rm ${software}
    ${SOFIN_BIN} deploy ${software} && \
    ${SOFIN_BIN} rm ${software} && \
    ${SED_BIN} -i '' -e "/${software}/d" software.list
    note "--------------------------------"
done
