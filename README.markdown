## Author:
    Daniel (dmilith) Dettlaff (dmilith [at] verknowsys.com)
    I'm also on #freebsd and #scala.pl @ freenode IRC.


## About:
    This software is my way of how to get reliable, updatable, bundled, closed-dependency and fully customizable software for FreeBSD servers.

    
## Features:
    * Simple, <500LOC solution, based on legacy /bin/sh shell scripting language.
    * Designed to work on all *BSD, but currently maintained and tested on FreeBSD only (>= 9.0-STABLE).
    * Every "software" has own definition ("def" file) with defined flat dependency list and basic data. Every definition is sh script itself (More in skeleton.def and defaults.def files)
    * Simple flat dependency managment. It's flexible enough to bundle almost any mix of requirements in bundle.
    * Simple way of creating "lists" of definitions to build. Just create a text file with your definitions list and give it to sofin as param and it will do the rest. It's that simple.
    * Software patches are supported automatically. The only thing required is to put patches into "definitions/patches/definition_file_name/" directory. Sofin will do the rest.
    * Every application is bundled separately with all dependencies in own root directory. The only external dependencies allowed are from base BSD system. No external dependencies allowed at all.
    * To install only one definition instead of a list, use "one" param.
    * To install user owned application in user home dir, use "user" param.
    * To create definitions snapshot file use sofin-make-defs script from this repository.
    * All software will is built from scratch, but each requirement/dependency is marked as installed when it finishes, so it won't build everything from scratch every time.
    * To see usage, run sofin without any params.
    
    
## Pitfalls/ Limitations:
    * Because every software bundle has own root dir, no ld information is provided by default by system, so software which uses shared libraries will require to set "LD_LIBRARY_PATH" for ld linker. To generate this variable for currently installed software just spawn sofin with "getshellld" param. To get user side values give it additional param of user name (f.e. sofin getshellld username).
    * To generate "PATH" variable from installed software use "getshellpath" param. To get user side values give it additional param of user name (f.e. sofin getshellpath username).
    * Currently only "tar.gz" archives files are cached and supported. In case of using different archive type a failure will happen.
    * Any kind of sha/md5 checksumming isn't supported at all.
    * Currently VerKnowSys.com repository is hardcoded into script. To maintain own definitions You may just fork and create own defs which I just merge into this repository or create own one somewhere.


## License:
    Released under the BSD license.
