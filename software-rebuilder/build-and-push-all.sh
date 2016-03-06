#/bin/sh

chmod 600 ~/.ssh/id_rsa

. /etc/s.conf
. /var/ServeD-OS/setup-buildhost
setup_buildhost

test ! -x /Software/Ccache/bin/ccache || s i Ccache

note "Checking remote machine connection (shouldn't take more than a second).."
ssh sofin@verknowsys.com "uname -a"
set +e

for software in $(cat software.list); do
    if [ "${software}" = "------" ]; then
        note "Finished task."
        exit 0
    fi
    note "________________________________"
    note "Resetting Sofin definitions"
    s reset
    note "Processing software: ${software}"
    s rm ${software}
    s deploy ${software} && \
    s rm ${software} && \
    sed -i '' -e "/${software}/d" software.list
    note "--------------------------------"
done
