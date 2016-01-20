#/bin/sh

chmod 600 ~/.ssh/id_rsa

. /etc/sofin.conf.sh

# set -e

note "Checking remote machine connection (shouldn't take more than a second).."
ssh sofin@verknowsys.com "uname -a"

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
