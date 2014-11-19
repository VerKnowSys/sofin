#/bin/sh

chmod 600 ~/.ssh/id_rsa

. /etc/sofin.conf.sh

set -e

note "Checking remote machine connection (shouldn't take more than a second).."
ssh sofin@verknowsys.com "uname -a"


for software in $(cat software.list); do
    note "Processing software: ${software}"
    USE_BINBUILD=false sofin get ${software}
    if [ -d "/Software/${software}" ]; then
        sofin push ${software}
        sofin remove ${software}
    fi
done
