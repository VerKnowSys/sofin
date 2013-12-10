#!/bin/sh
# helper functions to sync software tarballs between multiple hosts
# @author: Daniel (dmilith) Dettlaff (dmilith@verknowsys.com)


# NOTE: this function takes (capitalized) bundle name builts and pushes binary software bundle to remote repository
binbuild () {
  build_user_name="build-user"

  if [ "${1}" = "" ]; then
    printf "You must give software name as param!\n"
    return
  fi

  name="${1}"
  bundle_name="$(printf "${name}" | cut -c1 | tr '[a-z]' '[A-Z]')$(printf "${name}" | sed 's/^[a-zA-Z]//')"

  for i in phoebe.verknowsys.com; do
    ssh ${build_user_name}@${i} "rm -rf ~/Apps"
  done

   for i in phoebe.verknowsys.com; do
    ssh ${build_user_name}@${i} "sofin clean; sofin reload; sofin remove ${name}; sofin get ${name} && sofin push ${bundle_name} && printf 'done\n'"
   done
}


# NOTE: this function is local helper to run gather-source() on remote mirror host
src () {
  test "$1" = "" && echo "No http source given" && exit 1
  ssh sofin@v "source ~/.functions.sh && gather-source $1"
}


# NOTE: this function must be running on mirror side:
gather-source () {
    if [ "$1" = "" ]; then
        printf "Missing archive URL!\n"
        exit 1
    fi
    readonly fetch_bin="curl --progress-bar -C - -k -L -O"
    readonly default_port="60022"
    readonly user_name="sofin"
    readonly default_source_path="/Mirror/software/source"
    readonly default_host="software.verknowsys.com"
    readonly archive_name="$(basename "$1")"

    for mirror in $(host ${default_host} | awk '{print $3}'); do
        printf "Synchronizing ${archive_name} with ${mirror}\n"
        ssh -p ${default_port} "${user_name}@${mirror}" "cd ${default_source_path} && ${fetch_bin} '$1'"
    done

    case "$(uname)" in
        Linux)
            sha1sum "${default_source_path}/${archive_name}"
            ;;

        FreeBSD)
            sha1 -q "${default_source_path}/${archive_name}"
            ;;

        *)
            shasum "${default_source_path}/${archive_name}"
            ;;
    esac
}
