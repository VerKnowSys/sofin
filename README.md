# Sofin - SOFtware INstaller. Designed for BSD and Darwin.

## Author:
* Daniel (dmilith) Dettlaff (dmilith [at] verknowsys.com). I'm also on #verknowsys @ freenode IRC.


## Contributors:
* Michał (tallica) Lipski


## Thanks:
* Tymon (teamon) Tobolski (ideas of improvements)


## About:
This software is my way of how to get reliable, updatable, bundled, closed-dependency, secure and fully
customizable software for FreeBSD servers. Darwin (Mac OS X) support started with version >=0.14.10. Linux support started with version >=0.24.4 and ended with 0.51.9. If you wish me to continue Linux support, please consider a donation.


## Features:
* Designed to work on all *BSD (FreeBSD >=9.x), *Darwin (OSX >=10.8.x)
* User friendly, clean and clear colorful information. No magic. KISS, DRY, BDD driven development.
* Simple, ~1k LOC solution, written in legacy /bin/sh shell scripting language.
* Every "software" has own definition ("def" file) with defined flat dependency list and basic information.
  Every definition is sh script itself (More in [skeleton.def](https://github.com/VerKnowSys/sofin-definitions/blob/stable/definitions/skeleton.def.sample) and [defaults.def](https://github.com/VerKnowSys/sofin-definitions/blob/stable/definitions/defaults.def))
* Supports selective application installation or from list. (By "install" param. More in [examples](https://github.com/VerKnowSys/sofin#examples)).
* Supports installation of user and system wide applications (more in [examples](https://github.com/VerKnowSys/sofin#examples)).
* Has simple flat dependency managment. Sofin architecture is flexible enough to bundle almost any mix of requirements in application bundle, if only it's supported by given software. No need to install tons of useless/ not needed dependencies just because software supports it.
* Has simple way of creating "lists" of definitions to build. Just create a text file with your definitions in "lists/" directory, create/update definitions snapshot (using sofin-make-defs) and give that list filename to sofin as parameter (more in [examples](https://github.com/VerKnowSys/sofin#examples)).
* Software patches are supported out of the box. The only thing required is to put patches into "definitions/patches/definition_file_name_without_def_extension/" directory. Sofin will do the rest.
* Software bundling. Every application is bundled separately with all dependencies in own root directory. The only external dependencies used by Sofin are those from base system. No other external dependencies allowed at all.
* Supports basic "marking" of status of installed applications/ dependencies to resume broken/ failed/ interrupted installation.
* You may feel safe upgrading only *one* software bundle without headache of "how it affects rest of my software". No application bundle will affect any other. Ever.
* Sofin is designed to not touch any part of system. The only exception is /etc/profile_sofin created after system wide software installation (/Software/) in ServeD system.
* By default Sofin verbosity is limited to minimum. More detailed information is written to LOG file (located in /Software/.cache/install.log by default or /Users/USER_NAME/.cache/install.log)
* Exports. Each app has own ROOT_DIR/exports/ with symlinks to exported software. Exported software are just simple symlinks used to generate PATH environment variable.
* Sofin has own configuration file: [sofin.conf.sh](https://github.com/VerKnowSys/sofin/blob/stable/src/sofin.conf.sh) which is SH script itself.
* Supports parallel builds by default (from version 0.24.5)
* Supports custom callbacks executed in order as follows:
  - APP_AFTER_UNPACK_CALLBACK (executed after software unpack process)
  - APP_AFTER_PATCH_CALLBACK (executed after software patch process)
  - APP_AFTER_CONFIGURE_CALLBACK (executed after software configuration process)
  - APP_AFTER_MAKE_CALLBACK (executed after software compilation process)
  - APP_AFTER_INSTALL_CALLBACK (executed after software installation process)
  - APP_AFTER_EXPORT_CALLBACK (executed after final stage of exporting software executables)
  Each callback can be sh function itself and to be called by name. Look into [sbt.def](https://github.com/VerKnowSys/sofin-definitions/blob/stable/definitions/sbt.def) for an example createLaunchScript().
* Supports collisions between definitions through APP_CONFLICTS_WITH option since version 0.38.0. An example in [ruby.def](https://github.com/VerKnowSys/sofin-definitions/blob/stable/definitions/ruby.def)
* Supports binary builds of software bundles and requirements since 0.47.2
* Since version 0.51.0, Sofin automatically avoids using software binary builds, that won't work on given host. In that case, software will be built from source. Minimum system requirements for binary builds to work, depend on platfrom:
   - FreeBSD: OS version >= 9.1
   - Darwin: OS version >= 12.4
* Supports concurrent, lockless builds. (feature available since 0.54.0).
* Supports custom source of software definitions/ lists (as git repository cloned into cache directory). No more tarballs with definitions (feature available since 0.58.0).
* Supports git repositories as definition source (feature available since 0.60.0). An example in [vifm-devel.def](https://github.com/VerKnowSys/sofin-definitions/blob/stable/definitions/vifm-devel.def)


## Shell (hidden) options:
* USE_UPDATE=false sofin get vim  - will skip definitions update before installing "Vim" bundle (useful in conjuction with "sofin dev" feature)
* USE_BINBUILD=false sofin get vifm  - will skip checking for binary build for "Vifm" bundle.
* USE_UPDATE=false USE_BINBUILD=false sofin get git  - this trick is required to rebuild bundles like "Git". Note that Sofin requires Git to work properly. By default on clean systems, it's trying to fetch initial definitions tarball, that must be purged manually after first run by using "sofin distclean". On ServeD systems Git bundle is always installed by default.


## Examples:
* Install all available software defined in a list called "all":
```bash
sofin install all
```

* Install one software from definition called "ruby.def" for current user:
```bash
sofin install ruby
```

* Install software list called "databases" for current user:
```bash
sofin install databases
```

* Show list of available software:
```bash
sofin available
```

* Show list of installed software:
```bash
sofin fullinstalled
```
or
```bash
sofin installed
```

* Export "ruby" binary from "Passenger" bundle:
```bash
sofin export ruby Passenger
```

* Uninstall installed software "SomeApp"?
```bash
sofin uninstall someApp
```

* Create a list called "databases", with definitions: "postgresql" and "mysql", and install it with Sofin:
```bash
cd Sofin
echo "postgresql\nmysql" > lists/databases
./push-definitions # to create a snapshot and upload it to Your remote respository.
sofin install databases
```


## Differences from [POSIX](https://en.wikipedia.org/wiki/POSIX) and [FHS](https://en.wikipedia.org/wiki/Filesystem_Hierarchy_Standard) standards:
* Sofin provides a slightly different approach to shell PATH variable. By default user PATH variable is overriden to include APP-PREFIX/exports instead of default APP-PREFIX/(s)bin. After each successful software installation sofin will populate APP-PREFIX/exports with relative symlinks to existing binaries of bundle. Application exports are defined in "APP_EXPORTS" variable (available for any definition).
* Sofin suggests empty /usr/local folder. It's caused by POSIX "shared nature" of /usr/local. Sofin was built against this rule to prevent cross requirements between prefixes (/opt/X11 is an exception on Darwin), and to make sure that each software is easily movable between machines with same architecture.
* Each application has own "root" directory (Similar to Mac OS X software in *.app folders).
* Each software bundle includes all dependencies of given software, hence application bundle requires more disk
space than it does with "old fasioned, system wide, shared software".


## Pitfalls/ Limitations:
* Windows isn't supported, but Sofin will run just fine everywhere after a couple of configuration fights.
* Sofin is designed, tested and heavy supported under both 64bit: FreeBSD 9.1 and Darwin 12.2.0, but it should also work on any compliant architectures as well.
* Currently all official Sofin software used by current definitions is mirrored only on [software.verknowsys.com](http://software.verknowsys.com/source).
* Currently some definitions provided by Sofin include a couple of custom patches on software required by VerKnowSys ServeD © System. Patches (if any) usually come from current [FreeBSD ports](http://www.freebsd.org/ports/index.html).
* Some definitions with X11 requirement will need [XQuartz](http://xquartz.macosforge.org/landing/) installation. (Darwin hosts only).


## Installation info (platform specific):

### FreeBSD specific:
  - Install base 64bit system - I used 64bit FreeBSD 9.1 bootonly iso here.
  - Fetch latest package from [this site](http://dmilith.verknowsys.com/Public/Sofin-releases/), unpack and run `bin/install` as root.
  - Install additional base system software. Run:

  ```
  sofin install base # It will put "sofin" into /usr/bin/ and sofin.conf.sh into /etc/
  ```
  - Start using sofin as regular user.

### Darwin/ Mac OS X specific:
  - Install Mac OS X 10.8.
  - Install [XQuartz](http://xquartz.macosforge.org/landing/) (if you want to build definitions that require X11)
  - Fetch latest package from [this site](http://dmilith.verknowsys.com/Public/Sofin-releases/), unpack and run `bin/install` as root.
  - Install additional base system software. Run:

  ```
  sudo sofin install base # It will put "sofin" into /usr/bin/ and sofin.conf.sh into /etc/
  ```
  - Start using sofin as regular user.


## Conflicts/ Problems/ Known issues:
* Latest versions of OSX 10.8/ 10.9 lack GNU compiler (even through Xcode command line utilities, the only available compiler is Clang). Due to this fact, it is required to have installed binaries: `/usr/bin/llvm-gcc` `/usr/bin/llvm-g++` and `/usr/bin/llvm-cpp-4.2` on your system. (Only if you want Sofin to build software that requires GNU compiler). In older versions of Xcode (=<4.1) this compiler is built in and usually resides in `/usr/llvm-gcc-4.2` directory and is linked to `/usr/bin`. I uploaded this compiler taken from my 10.8 system. It's available [here](http://software.verknowsys.com/binary/Darwin-x86_64-common/llvm-gcc-4.2-prebuilt.tar.bz2). Put it anywhere and make symlinks to `/usr/bin` to solve this issue permanently.
* Sofin build mechanism is known to be in conflict with other software managment solutions like: BSD Ports, HomeBrew, MacPorts, Fink. Keep that in mind before reporting problems.
* It's recommended to change shell by doing: `chsh -s /Software/Zsh/exports/zsh` for each user which will use Sofin. It's caused shells that don't read standard default shell initialization scripts like /etc/zshenv.


## FAQ:
* "Definition 'name' is broken and it doesn't build on my system!" - Usually caused by conflicting software, installed in system paths (f.e. /usr/bin, /usr/lib, /usr/local). Sofin implies clean base system.
* "It's not working!". Contribute with a fix!


## License:
* Released under the [BSD](http://opensource.org/licenses/BSD-2-Clause) license.
