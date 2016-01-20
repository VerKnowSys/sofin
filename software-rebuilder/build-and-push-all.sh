#/bin/sh

chmod 600 ~/.ssh/id_rsa

. /etc/sofin.conf.sh

# set -e

note "Checking remote machine connection (shouldn't take more than a second).."
ssh sofin@verknowsys.com "uname -a"

if [ "${SYSTEM_NAME}" = "FreeBSD" ]; then
    ${UNAME_BIN} -a | ${GREP_BIN} "HBSD" >/dev/null 2>&1
    if [ "$?" = "0" ]; then
        note "Setting pageexec and mprotect to 1 for build purposes"
        sysctl hardening.pax.pageexec.status=1
        sysctl hardening.pax.mprotect.status=1
    fi
fi

for software in $(cat software.list); do
    note "________________________________"
    note "Processing software: ${software}"
    s rm ${software}
    s build ${software}
    if [ -d "/Software/${software}" ]; then
        s push ${software}
        s rm ${software}
    fi
    note "-------------------------------"
done
