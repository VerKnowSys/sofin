# Sofin - SOFtware INstaller. Designed for BSD and Darwin.

## Author:
* Daniel (dmilith) Dettlaff (@dmilith). I'm also on freenode IRC.


## Contributors:
* Michał (tallica) Lipski


## Thanks:
* Tymon (teamon) Tobolski (ideas of improvements)


## About:
This software is my way of how to get reliable, updatable, bundled, closed-dependency, secure and fully
customizable software for FreeBSD servers. Darwin (Mac OS X) support started with version >=0.14.10. Linux support started with version >=0.24.4 and ended with 0.51.9. If you wish me to continue Linux support, please consider a donation.


## Features:
* Designed to work on all *BSD (FreeBSD >=11.x), *Darwin (OSX >=10.11.x)
* User friendly, clean and clear colorful information. No magic. KISS, DRY, BDD driven development.
* Simple, ~1.5k LOC solution, written in legacy /bin/sh shell scripting language.
* Every "software" has own definition ("def" file) with defined flat dependency list and basic information.
  Every definition is sh script itself (More in [skeleton.def](https://github.com/VerKnowSys/sofin-definitions/blob/stable/definitions/skeleton.def.sample) and [defaults.def](https://github.com/VerKnowSys/sofin-definitions/blob/stable/definitions/defaults.def))
* Supports selective application installation or from list. (By "install" param. More in [examples](https://github.com/VerKnowSys/sofin#examples)).
* Has simple flat dependency management. Sofin architecture is flexible enough to bundle almost any mix of requirements in application bundle, if only it's supported by given software. No need to install tons of useless/ not needed dependencies just because software supports it.
* Has simple way of creating "lists" of definitions to build. (more in [examples](https://github.com/VerKnowSys/sofin#examples)).
* Software patches are supported out of the box. The only thing required is to put patches into "definitions/patches/definition_file_name_without_def_extension/" directory (there's also system specific patches support. For OSX you have to put your patches into Darwin/ under patches/yourdefinition/ directory). Sofin will do the rest (patch levels [-p] from 0..5 are supported OOTB).
* Software bundling. Every application is bundled separately with all dependencies in own "root directory". The only external dependencies used by Sofin are those from base system. No other external dependencies allowed at all.
* Supports basic "marking" of status of installed applications/ dependencies to resume broken/ failed/ interrupted installation.
* You may feel safe upgrading only *one* software bundle without headache of "how it affects rest of my software". No application bundle will affect any other. Ever.
* Sofin is designed to not touch any part of system. The only exception is /etc/profile_sofin created on installation.
* By default Sofin verbosity is limited to minimum. More detailed information is written to LOG file (located in ~/.cache/install.log. Quick access to them by `sofin log`)
* Exports. Each app has own ROOT_DIR/exports/ with symlinks to exported binaries. Exported binaries are just simple symlinks used to generate PATH environment variable.
* Sofin has own configuration file: [sofin.conf.sh](https://github.com/VerKnowSys/sofin/blob/stable/src/sofin.conf.sh) which is SH script itself.
* Supports custom callbacks executed in order as follows:
  - APP_AFTER_UNPACK_CALLBACK (executed after software unpack process)
  - APP_AFTER_PATCH_CALLBACK (executed after software patch process)
  - APP_AFTER_CONFIGURE_CALLBACK (executed after software configuration process)
  - APP_AFTER_MAKE_CALLBACK (executed after software compilation process)
  - APP_AFTER_INSTALL_CALLBACK (executed after software installation process)
  - APP_AFTER_EXPORT_CALLBACK (executed after final stage of exporting software binaries)
  Each callback can be sh function itself and to be called by name. Look into [sbt.def](https://github.com/VerKnowSys/sofin-definitions/blob/stable/definitions/sbt.def) for an example createLaunchScript().
* Supports collisions between definitions through APP_CONFLICTS_WITH option since version 0.38.0. An example in [ruby.def](https://github.com/VerKnowSys/sofin-definitions/blob/stable/definitions/ruby.def)
* Supports binary builds of software bundles since 0.47.2
* Since version 0.51.0, Sofin automatically avoids using software binary builds, that won't work on given host. In that case, software will be built from source. Minimum system requirements for binary builds to work, depend on platfrom:
   - FreeBSD: OS version >= 9.1
   - Darwin: OS version >= 12.4
* Supports concurrent, lockless builds. (feature available since 0.54.0).
* Supports custom source of software definitions/ lists (as git repository cloned into cache directory). More in examples below.
* Supports git repositories as definition source (feature available since 0.60.0). An example in [vifm-devel.def](https://github.com/VerKnowSys/sofin-definitions/blob/stable/definitions/vifm-devel.def)


## Shell (hidden) options:
* Will skip definitions update before installing "Vim" bundle:
```bash
USE_UPDATE=false sofin get Vim
```


* Will skip checking for binary build for "Vifm" bundle.
```bash
USE_BINBUILD=false sofin get Vifm
# or just:
# sofin build Vifm
```


* This trick is required to rebuild bundles like "Git". Note that Sofin requires Git to work properly. By default on clean systems, it's trying to fetch initial definitions tarball, that must be purged manually after first run by using "sofin distclean". On ServeD systems Git bundle is always installed by default.
```bash
USE_UPDATE=false sofin build Git
```


## Examples:
* By default Sofin uses: BRANCH=stable and REPOSITORY=http://github.com/VerKnowSys/sofin-definitions.git. To reset to defaults, do: `REPOSITORY= sofin setup`. To set custom Sofin definitions repository on given branch do:
```bash
REPOSITORY=git://some.where.com:YourDefinitions.git BRANCH=mybranch sofin setup
```

* When you need to quickly test your bundle definition called "Something" (useful if you're testing definitions and you don't want to commit definition changes to definitions repository):
```bash
sofin dev something      # lowercase - it's definition file name
# [paste your definition here and hit ctrl-d]
sofin build Something    # camel case - it's name of software bundle
```

* Install all available software defined in a list called "all":
```bash
sofin install all
```

* Install one software from definition called "ruby.def" for current user:
```bash
sofin install Ruby
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
sofin uninstall SomeApp
```

* Create own list called "databases", with definitions: "Postgresql" and "Rubinius", and install it with Sofin:
```bash
echo "Postgresql\nRubinius" > ~/.cache/definitions/lists/databases
sofin install databases
```


## Differences from [POSIX](https://en.wikipedia.org/wiki/POSIX) and [FHS](https://en.wikipedia.org/wiki/Filesystem_Hierarchy_Standard) standards:
* Sofin provides a slightly different approach to shell PATH variable. By default user PATH variable is overriden to include APP-PREFIX/exports instead of default APP-PREFIX/(s)bin. After each successful software installation sofin will populate APP-PREFIX/exports with relative symlinks to existing binaries of bundle. Application exports are defined in "APP_EXPORTS" variable (available for any definition).
* Sofin suggests empty /usr/local folder. It's caused by POSIX "shared nature" of /usr/local. Sofin was built against this rule to prevent cross requirements between prefixes, and to make sure that each software is easily movable between machines with same architecture.
* Each application has own "root" directory (Similarly to Mac OS X software in *.app folders).
* Each software bundle includes all dependencies of given software, hence application bundle requires more disk
space than it does with "old fasioned, system wide, shared software".


## Pitfalls/ Limitations:
* Support for root software will be continuously dropped from support, because it's a bad habit.
* Sofin assumes that /Software is owned by single non-root user.
* Sofin assumes that /User is user data directory. On OSX, if you don't have /User directory, you might want to do `sudo ln -s ~ /User`. It will be also required under vanilla versions of FreeBSD. Under ServeD-OS each worker user is located under /User by default.


## Installation info (platform specific):

### FreeBSD specific:
  - Install base 64bit system - I used 64bit FreeBSD 10.X bootonly iso here.
  - Fetch latest package from [this site](http://dmilith.verknowsys.com/Public/Sofin-releases/), unpack and run `bin/install` as root.
  - Start using sofin as regular user.

### Darwin/ Mac OS X specific:
  - Install Mac OS X 10.9, 10.10 or 10.11 (currently supported)
  - Fetch latest package from [this site](http://dmilith.verknowsys.com/Public/Sofin-releases/), unpack and run `bin/install` as root.
  - Start using sofin as regular user.


## Conflicts/ Problems/ Known issues:
* Sofin build mechanism is known to be in conflict with other software managment solutions like: BSD Ports, HomeBrew, MacPorts, Fink. Keep that in mind before reporting problems.
* It's recommended to change shell by doing: `chsh -s /Software/Zsh/exports/zsh` for each user which will use Sofin. It's caused shells built the way, they don't read default shell initialization scripts like /etc/zshenv for Zsh.


## License:
* Released under the [BSD](http://opensource.org/licenses/BSD-2-Clause) license.
