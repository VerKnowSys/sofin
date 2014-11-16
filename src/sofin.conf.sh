# NOTE: this file is SH shell script
# @author: Daniel (dmilith) Dettlaff (dmilith@verknowsys.com)
#
# global Sofin values:
if [ "${DEBUG}" = "" ]; then
    export DEBUG="false"
fi
if [ "${TRACE}" = "" ]; then
    export TRACE="false"
fi

# setting up definitions repository
readonly DEFAULT_REPOSITORY="http://github.com/VerKnowSys/sofin-definitions.git" # this is official sofin definitions repository
# REPOSITORY is set after determining CACHE_DIR (L300)
# and branch used
if [ "${BRANCH}" = "" ]; then
    export BRANCH="stable"
fi

readonly DEBUG
readonly TRACE
readonly ID_SVD="-un"
readonly HEADER="Sofin v${VERSION} (c) 2o11-2o14 verknowsys.com"
readonly SCRIPT_NAME="/usr/bin/sofin"
readonly SCRIPT_ARGS="$*"
readonly PRIVATE_METADATA_DIR="/Private/"
readonly PRIVATE_METADATA_FILE="Metadata"
readonly HOME_APPS_DIR="Apps/"
readonly DEFAULT_PATH="/bin:/usr/bin:/sbin:/usr/sbin"
readonly DEFAULT_MANPATH="/usr/share/man:/usr/share/openssl/man"
readonly SOFIN_PROFILE="/etc/profile_sofin"
readonly DEPENDENCIES_FILE=".dependencies"
readonly INSTALLED_MARK=".installed"
readonly LOG_LINES_AMOUNT="1000"
readonly DEFAULT_ARCHIVE_EXT=".tar.gz"
readonly SOFIN_DISABLED_INDICATOR_FILE="${HOME}/.sofin-disabled"

# utils software from POSIX base system variables:
PRINTF_BIN="/usr/bin/printf"
KLDLOAD_BIN="/sbin/kldload"
KILL_BIN="/bin/kill"
PWD_BIN="/bin/pwd"
MV_BIN="/bin/mv"
CP_BIN="/bin/cp"
LN_BIN="/bin/ln"
WHICH_BIN="/usr/bin/which"
TAIL_BIN="/usr/bin/tail"
CUT_BIN="/usr/bin/cut"
LS_BIN="/bin/ls"
ID_BIN="/usr/bin/id"
MKDIR_BIN="/bin/mkdir"
MAKE_BIN="/usr/bin/make"
TAR_BIN="/usr/bin/tar"
UNZIP_BIN="/usr/bin/unzip"
CAT_BIN="/bin/cat"
TR_BIN="/usr/bin/tr"
TOUCH_BIN="/usr/bin/touch"
RM_BIN="/bin/rm"
DATE_BIN="/bin/date"
PATCH_BIN="/usr/bin/patch"
SED_BIN="/usr/bin/sed"
CHOWN_BIN="/usr/sbin/chown"
GREP_BIN="/usr/bin/grep"
EGREP_BIN="/usr/bin/egrep"
FETCH_BIN="/usr/bin/fetch -T 3"
UNAME_BIN="/usr/bin/uname"
FIND_BIN="/usr/bin/find"
STRIP_BIN="/usr/bin/strip"
BASENAME_BIN="/usr/bin/basename"
DIRNAME_BIN="/usr/bin/dirname"
SORT_BIN="/usr/bin/sort"
WC_BIN="/usr/bin/wc"
SHA_BIN="/sbin/sha1"
AWK_BIN="/usr/bin/awk"
SLEEP_BIN="/bin/sleep"
SYSCTL_BIN="/sbin/sysctl"
BC_BIN="/usr/bin/bc"
HEAD_BIN="/usr/bin/head"
SERVICE_BIN="/usr/sbin/service"
TEST_BIN="/bin/test"
CHMOD_BIN="/bin/chmod"
SCP_BIN="/usr/bin/scp"
HOST_BIN="/usr/bin/host"
DIG_BIN="/usr/bin/dig"
XARGS_BIN="/usr/bin/xargs"
SOFIN_BIN="/usr/bin/sofin"
SOFIN_VERSION_UTILITY_BIN="/usr/bin/sofin-version-utility"
SOFIN_MICROSECONDS_UTILITY_BIN="/usr/bin/sofin-miliseconds"
SOFIN_LIBBUNDLE_BIN="/usr/bin/sofin-libbundle"
GIT_BIN="/Software/Git/exports/git"
SSH_BIN="/usr/bin/ssh"
DIFF_BIN="/usr/bin/diff"

OS_VERSION=10
if [ -x "${SOFIN_VERSION_UTILITY_BIN}" ]; then
    export OS_VERSION="$(echo $(${SOFIN_VERSION_UTILITY_BIN}) | ${AWK_BIN} '{ gsub(/\./, ""); print $1; }' )"
    export FULL_SYSTEM_VERSION="$(${SOFIN_VERSION_UTILITY_BIN})"
fi
USERNAME="$(${ID_BIN} ${ID_SVD})"
DEFAULT_LDFLAGS="-fPIC -fPIE"
DEFAULT_COMPILER_FLAGS="-Os -fPIC -fPIE -fno-strict-overflow -fstack-protector-all"

TTY="false"
SUCCESS_CHAR="V"
WARN_CHAR="*"
NOTE_CHAR=">"
ERROR_CHAR="#"
NOTE_CHAR2="-"
if [ -t 1 ]; then
    TTY="true"
    SUCCESS_CHAR="√"
    WARN_CHAR="•"
    NOTE_CHAR="»"
    NOTE_CHAR2="→"
    ERROR_CHAR="✘"
fi
readonly TTY
readonly SUCCESS_CHAR
readonly WARN_CHAR
readonly NOTE_CHAR
readonly ERROR_CHAR


# common functions
# helpers

cecho () {
    if [ "${TTY}" = "true" ]; then # if it's terminal then use colors
        ${PRINTF_BIN} "${2}${1}${reset}\n"
    else
        ${PRINTF_BIN} "${1}\n"
    fi
}


debug () {
    if [ "${DEBUG}" = "true" ]; then
        cecho "# $1" ${magenta} # NOTE: this "#" is required for debug mode to work properly with generation of ~/.profile and /etc/profile_sofin files!
    # else
        # cecho " ~ $1" ${magenta} >> ${LOG}
    fi
}


warn () {
    cecho " ${WARN_CHAR} $1" ${yellow}
}


note () {
    cecho " ${NOTE_CHAR} $1" ${green}
}


error () {
    cecho " ${ERROR_CHAR} $1" ${red}
    exit 1
}


# System specific configuration
readonly SYSTEM_NAME="$(uname)"
readonly SYSTEM_ARCH="$(uname -m)"

# if [ "$(id -u)" != "0" ]; then
#     export USER_TYPE="common" # NOTE: rpath in binaries, XXX: fixme: add support for regular user binary builds
# else
#     export USER_TYPE="root"
# fi


case "${SYSTEM_NAME}" in

    FreeBSD)
        # Default
        readonly FREEBSD_MINIMUM_VERSION="91"
        cpus="$(${SYSCTL_BIN} kern.smp.cpus | ${AWK_BIN} '{printf $2}')"
        export CURL_BIN="/usr/bin/fetch -T 3 -o -"
        export MAKE_OPTS="-j${cpus}"
        if [ ${OS_VERSION} -lt ${FREEBSD_MINIMUM_VERSION} ]; then
            export USE_BINBUILD="false"
        fi

        if [ ${OS_VERSION} -gt 93 ]; then
            export DIG_BIN="/usr/bin/drill"
        fi
        export JAIL_BIN="/usr/sbin/jail"
        export JEXEC_BIN="/usr/sbin/jexec"
        export JLS_BIN="/usr/sbin/jls"

        # XXX: disable ssl verification of https://github.com which fails on FreeBSD by default.
        if [ -x "${GIT_BIN}" ]; then
            ${GIT_BIN} config --global http.sslVerify false
        fi

        # runtime sha
        test -x "${SOFIN_MICROSECONDS_UTILITY_BIN}" && \
        RUNTIME_SHA="$(${PRINTF_BIN} "$(${DATE_BIN})-$(${SOFIN_MICROSECONDS_UTILITY_BIN})" | ${SHA_BIN})"
        ;;

    Darwin)
        # OSX specific configuration
        readonly DARWIN_MINIMUM_VERSION="124"
        export GIT_BIN="/usr/bin/git"
        export CURL_BIN="/usr/bin/curl"
        export FETCH_BIN="/usr/bin/curl --connect-timeout 3 -O"
        export PATCH_BIN="/usr/bin/patch -p0 "
        export DEFAULT_LDFLAGS="-fPIC" # -arch x86_64 fPIE isn't well supported on OSX, but it's not production anyway
        export DEFAULT_COMPILER_FLAGS="-Os -fPIC -fno-strict-overflow -fstack-protector-all" # -arch x86_64
        export SHA_BIN="/usr/bin/shasum"
        export SYSCTL_BIN="/usr/sbin/sysctl"
        export KLDLOAD_BIN="/sbin/kextload"
        cpus=$(${SYSCTL_BIN} machdep.cpu.thread_count | ${AWK_BIN} '{printf $2}')
        export MAKE_OPTS="-j${cpus}"
        unset SERVICE_BIN # not necessary

        if [ ${OS_VERSION} -lt ${DARWIN_MINIMUM_VERSION} ]; then
            export USE_BINBUILD="false"
        fi

        # runtime sha
        test -x "${SOFIN_MICROSECONDS_UTILITY_BIN}" && \
        RUNTIME_SHA="$(${PRINTF_BIN} "$(${DATE_BIN})-$(${SOFIN_MICROSECONDS_UTILITY_BIN})" | ${SHA_BIN} | ${AWK_BIN} '{print $1}')"
        ;;

    Linux)
        # only Debian 6 is supported a.t.m.
        readonly GLIBC_MINIMUM_VERSION="211"
        export CURL_BIN="/usr/bin/wget -qO -"
        export FETCH_BIN="/usr/bin/wget -N"
        export PATCH_BIN="/usr/bin/patch -p0 "
        export UNAME_BIN="/bin/uname"
        export KLDLOAD_BIN="/sbin/modprobe"
        export SHA_BIN="/usr/bin/sha1sum"
        export SED_BIN="/bin/sed"
        export TAR_BIN="/bin/tar"
        export GREP_BIN="/bin/grep"
        export EGREP_BIN="/bin/egrep"
        export BC_BIN="/usr/bin/bc"
        export CHOWN_BIN="/bin/chown"
        export DEFAULT_COMPILER_FLAGS="-Os -fPIC -fno-strict-overflow -fstack-protector-all"
        export DEFAULT_LDFLAGS="-fPIC "
        export TEST_BIN="/usr/bin/test"
        export NPROC_BIN="/usr/bin/nproc"
        export MAKE_OPTS="-j$(${NPROC_BIN})"
        export AWK_BIN="/usr/bin/awk"
        if [ ${OS_VERSION} -lt ${GLIBC_MINIMUM_VERSION} ]; then
            export USE_BINBUILD="false"
        fi
        # runtime sha
        test -x "${SOFIN_MICROSECONDS_UTILITY_BIN}" && \
        RUNTIME_SHA="$(${PRINTF_BIN} "$(${DATE_BIN})-$(${SOFIN_MICROSECONDS_UTILITY_BIN})" | ${SHA_BIN} | ${AWK_BIN} '{print $1}')"
        ;;

esac


readonly SOFTWARE_ROOT_DIR="/Software/"
SOFTWARE_DIR="/Software/"
SYSTEM_HOME_DIR="/SystemUsers/"
CACHE_DIR="${SYSTEM_HOME_DIR}.cache/"
BINBUILDS_CACHE_DIR="${CACHE_DIR}binbuilds/"
DEFINITIONS_DIR="${CACHE_DIR}definitions/definitions/"
HOME_DIRS="${HOME}/.."
LOG="${CACHE_DIR}install.log"
LISTS_DIR="${CACHE_DIR}definitions/lists/"
DEFAULTS="${DEFINITIONS_DIR}defaults.def"
readonly BUILD_USER_NAME="build-user"
BUILD_USER_HOME="/7a231cbcbac22d3ef975e7b554d7ddf09b97782b/${BUILD_USER_NAME}"

readonly CURRENT_USER_UID="$(${ID_BIN} -u)"
if [ "${CURRENT_USER_UID}" != "0" ]; then
    if [ "${HOME}" != "${BUILD_USER_HOME}" ]; then
        if [ "$(${FIND_BIN} ${HOME_DIRS} -maxdepth 1 2>/dev/null | ${WC_BIN} -l | ${TR_BIN} -d ' ')" = "0" ]; then
            error "No user home dir found? Critial error. No entries in ${HOME_DIRS}? Fix it and retry."
            exit 1
        fi
        readonly USER_DIRNAME="$(${FIND_BIN} ${HOME_DIRS} -maxdepth 1 -uid "${CURRENT_USER_UID}" 2> /dev/null)" # get user dir by uid and ignore access errors

        # additional check for multiple dirs with same UID (illegal)
        readonly USER_DIR_AMOUNT="$(echo "${USER_DIRNAME}" | ${WC_BIN} -l | ${TR_BIN} -d ' ')"
        debug "User dirs amount: ${USER_DIR_AMOUNT}"
        if [ "${USER_DIR_AMOUNT}" != "1" ]; then
            error "Found more than one user with same uid in ${HOME_DIRS}! That's illegal. Fix it an retry."
            error "Conflicting users: $(echo "${USER_DIRNAME}" | ${TR_BIN} '\n' ' ')"
            exit 1
        fi
        debug "User dirname: ${USER_DIRNAME}"
        export USERNAME="$(${BASENAME_BIN} ${USER_DIRNAME})"
    else
        export USERNAME="${BUILD_USER_NAME}"
    fi

    # also explicit check if virtual user exists in home dir:
    if [ "${USERNAME}" = "" ]; then
        error "No user homedir found in: ${HOME_DIRS} for user: '${USERNAME}'"
        exit 1
    fi
    readonly METADATA_FILE="${HOME}${PRIVATE_METADATA_DIR}${PRIVATE_METADATA_FILE}"
    if [ -f "${METADATA_FILE}" ]; then
        debug "ServeD System found. Username set to: ${USERNAME}. Home directory: ${HOME}"
        debug "Loading user metdata from ${METADATA_FILE}"
        . "${METADATA_FILE}"
        readonly export SVD_FULL_NAME="${SVD_FULL_NAME}"
        #
        # TODO: FIXME: 2013-03-19 15:34:07 - dmilith - fill metadata and define values of it...
        # ...
        #
    else
        debug "No metadata found in: ${METADATA_FILE} for user: ${USERNAME}. No additional user data accessible."
    fi
fi


# if [ "${USER_TYPE}" != "root" ]; then
#     export SOFTWARE_DIR="${HOME}/${HOME_APPS_DIR}"
#     export CACHE_DIR="${HOME}/.cache/"
#     export BINBUILDS_CACHE_DIR="${CACHE_DIR}binbuilds/"
#     export LOG="${CACHE_DIR}install.log"
#     export DEFINITIONS_DIR="${CACHE_DIR}definitions/definitions/"
#     export LISTS_DIR="${CACHE_DIR}definitions/lists/"
#     export DEFAULTS="${DEFINITIONS_DIR}defaults.def"
# fi

# more values
readonly BINBUILDS_CACHE_DIR
readonly SOFTWARE_DIR
readonly LOCK_FILE="${SOFTWARE_DIR}.sofin.lock"
readonly LOG
readonly CACHE_DIR
# readonly DEFINITIONS_DIR
readonly LISTS_DIR
readonly DEFAULTS
readonly USERNAME
readonly DEFAULT_LDFLAGS
readonly DEFAULT_COMPILER_FLAGS
readonly MAKE_OPTS
readonly MAIN_PORT="60022"
readonly MAIN_USER="sofin"
readonly MAIN_SOFTWARE_PREFIX="/Mirror"
readonly MAIN_SOFTWARE_ADDRESS="software.verknowsys.com"
readonly MAIN_SOURCE_REPOSITORY="http://${MAIN_SOFTWARE_ADDRESS}/source/"
readonly MAIN_BINARY_REPOSITORY="http://${MAIN_SOFTWARE_ADDRESS}/binary/"
readonly CCACHE_BIN_OPTIONAL="${SOFTWARE_ROOT_DIR}Ccache/exports/ccache"


# last repository cache setup:
export REPOSITORY_CACHE_FILE="${CACHE_DIR}.last_repository.pos"
if [ "${REPOSITORY}" = "" ]; then # :this value is given by user as shell param
    ${MKDIR_BIN} -p "${CACHE_DIR}"
    if [ -f "${REPOSITORY_CACHE_FILE}" ]; then
        export REPOSITORY="$(${CAT_BIN} ${REPOSITORY_CACHE_FILE})"
    else
        ${PRINTF_BIN} "${DEFAULT_REPOSITORY}\n" > ${REPOSITORY_CACHE_FILE}
        export REPOSITORY="${DEFAULT_REPOSITORY}"
    fi
fi


# ANSI color definitions
readonly red='\033[31;40m'
readonly green='\033[32;40m'
readonly yellow='\033[33;40m'
readonly blue='\033[34;40m'
readonly magenta='\033[35;40m'
readonly cyan='\033[36;40m'
readonly gray='\033[37;40m'
readonly white='\033[38;40m'
readonly reset='\033[0m'


check_command_result () {
    if [ -z "$1" ]; then
        error "No param given for check_command_result()!"
        exit 1
    fi
    if [ "$1" = "0" ]; then
        debug "CORRECT"
    else
        error
        error "FAILURE. Run $(${BASENAME_BIN} ${SCRIPT_NAME}) log to see what went wrong."
        exit 1
    fi
}


check_root () {
    if [ "$(id -u)" != "0" ]; then
        error "This command should be run as root."
        exit 1
    fi
}


check_os () {
    case "${SYSTEM_NAME}" in
        FreeBSD)
            ;;

        Darwin)
            ;;

        Linux)
            ;;

        *)
            error "Currently only FreeBSD, Darwin and Debian hosts are supported."
            exit
            ;;

    esac
}


# validate environment availability or crash
validate_env () {
    env | ${GREP_BIN} '_BIN=/' | while IFS= read -r envvar
    do
        var_value="$(${PRINTF_BIN} "${envvar}" | ${AWK_BIN} '{sub(/^[A-Z_]*=/, ""); print $1}')"
        if [ ! -x "${var_value}" ]; then
            error "Required binary is unavailable: ${envvar}"
            exit 1
        fi
    done || exit 1
}
