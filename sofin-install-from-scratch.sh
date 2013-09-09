#!/bin/sh
# © 2o13, by Daniel (dmilith) Dettlaff

PATH="/usr/bin:/bin"
SOURCE="https://codeload.github.com/VerKnowSys/sofin/tar.gz/master"
SYSTEM_NAME="$(uname)"
CURL_BIN="/usr/bin/fetch -o -"
TAR_BIN="/usr/bin/tar"
MV_BIN="/bin/mv"


case "${SYSTEM_NAME}" in
    FreeBSD)
        # default
        ;;

    Darwin)
        CURL_BIN="/usr/bin/curl"
        ;;

    Linux)
        CURL_BIN="/usr/bin/wget -qO-"
        TAR_BIN="/bin/tar"
        ;;

    *)
        printf "Unsupported system found: ${SYSTEM_NAME}. Cannot continue. Please contact dmilith to add support for your system.\n"
        exit 1
        ;;

esac


if [ "$(id -u)" != "0" ]; then
    printf "Sofin installation process requires root access.\n"
    exit 1
fi

printf "Installing / Upgrading Sofin\n"
cwd="$(pwd)"
cd /tmp
${CURL_BIN} ${SOURCE} 2> /dev/null | ${TAR_BIN} xzf - && cd ./sofin-master && ./sofin-install
result="$?"
cd "${cwd}"
if [ "${result}" = "0" ]; then
    printf "Installation finished successfully\n"
else
    printf "Installation failed\n"
fi
