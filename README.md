# Sofin - SOFtware INstaller. Designed for HardenedBSD-driven production systems - like svdOS.

## Author:
* Daniel (dmilith) Dettlaff (@dmilith). I'm also on freenode IRC.


## Contributors:
* Michał (tallica) Lipski
* Bartosz (bart) Kośnik


## Thanks:
* Tymon (teamon) Tobolski (ideas of improvements)
* Stephan Brumme (Small-Lz4)


## About:
This software is my way of how to get reliable, updatable, bundled, closed-dependency, secure and fully
customizable software for HardenedBSD/FreeBSD servers. Darwin (Mac OS X) support started with version >=0.14.10. Linux support started with version >=0.24.4, ended with version 1.0.17. No more Linux support is planned.


## Features:
* Designed to work on all *BSD (HardenedBSD/FreeBSD >=11.x), *Darwin (OSX >=10.11.x), support for Minix/NetBSD/OpenBSD platforms is comming as well.
* User friendly, clean and clear colorful information. No magic. KISS, DRY, BDD driven development.
* Simple, modular solution, written in legacy /bin/sh shell scripting language.
* Every "software" has own definition ("def" file) with defined flat dependency list and basic information.
  Every definition is sh script itself (More in [skeleton.def](https://github.com/VerKnowSys/sofin-definitions/blob/stable/definitions/skeleton.def.sample) and [defaults.def](https://github.com/VerKnowSys/sofin-definitions/blob/stable/definitions/defaults.def))
* Supports selective application installation or from list. (More in [examples](https://github.com/VerKnowSys/sofin#examples)).
* Has simple flat dependency management. Sofin architecture is flexible enough to bundle almost any mix of requirements in application bundle, if only it's supported by given software. No need to get tons of useless/ not needed dependencies just because software supports it.
* Has simple way of creating "lists" of definitions to build. (more in [examples](https://github.com/VerKnowSys/sofin#examples)).
* Source patches are supported out of the box. The only thing required is to put patches into "definitions/patches/smallcase_definition_name_without_def_extension/" directory (there's also system specific patches support. For OSX you have to put your patches in patches/yourdefinition/Darwin/ directory. It can also be: "Linux" and "FreeBSD"). Sofin will use these patches automagically (It tries with patch levels from -p0 to -p5 for each patch file). Software patch applies on bundle at build time, before configuration phase.
* Software bundling. Every application is bundled separately with all dependencies in own "root directory". The only external dependencies used by Sofin are those from base system. No other external dependencies allowed at all.
* Supports basic "marking" of status of installed applications/ dependencies to resume broken/ failed/ interrupted build process.
* You may feel safe upgrading only *one* software bundle without headache of "how it affects rest of my software". No application bundle will affect any other. Ever.
* Sofin is designed to not touch nor interfere with any part of already installed base system (shell configuration might be considered an exception)
* By default Sofin verbosity is limited to minimum. More detailed information is written to log files (located in ~/.cache/logs/. Quick access to them by `s log pattern`)
* Exports. Each app has own ROOT_DIR/exports/ with symlinks to exported binaries. Exported binaries are just simple symlinks used to generate PATH environment variable.
* Supports custom callbacks executed in order as follows:
  - DEF_AFTER_UNPACK_METHOD (executed after software unpack process)
  - DEF_AFTER_PATCH_METHOD (executed after software patch process)
  - DEF_AFTER_CONFIGURE_METHOD (executed after software configuration process)
  - DEF_AFTER_MAKE_METHOD (executed after software compilation process)
  - DEF_AFTER_INSTALL_METHOD (executed after software installation process)
  - DEF_AFTER_EXPORT_METHOD (executed after final stage of exporting software binaries)
  Each callback can be sh function itself and to be called by name. Look into [sbt.def](https://github.com/VerKnowSys/sofin-definitions/blob/stable/definitions/sbt.def) for an example createLaunchScript().
* Supports collisions between definitions through DEF_CONFLICTS_WITH option since version 0.38.0. An example in [ruby.def](https://github.com/VerKnowSys/sofin-definitions/blob/stable/definitions/ruby.def)
* Supports binary builds of software bundles since 0.47.2
* Since version 0.51.0, Sofin automatically avoids using software binary builds, that won't work on given host. In that case, software will be built from source. Minimum system requirements for binary builds to work, depend on platfrom:
   - HardenedBSD: OS version >= 9.1
   - Darwin: OS version >= 12.4
* Supports concurrent, lockless builds. (feature available since 0.54.0).
* Supports custom source of software definitions/ lists (as git repository cloned into cache directory). More in examples below.
* Supports git repositories as definition source (feature available since 0.60.0). An example in [vifm-devel.def](https://github.com/VerKnowSys/sofin-definitions/blob/stable/definitions/vifm-devel.def)


## Shell (hidden) options:
* Will skip definitions update before installing "Vim" bundle:
```bash
USE_UPDATE=NO s get Vim
```


* Will skip checking for binary build for "Vifm" bundle.
```bash
USE_BINBUILD=NO s get Vifm
# or just:
# s build Vifm
```


* This trick is required to rebuild bundles like "Git". Note that Sofin requires Git to work properly. By default on clean systems, it's trying to fetch initial definitions tarball, that must be purged manually after first run by using "s distclean". On ServeD systems Git bundle is always installed by default.
```bash
USE_UPDATE=NO s build Git
```


## Examples:
* By default Sofin uses: BRANCH=stable and REPOSITORY=http://github.com/VerKnowSys/s-definitions.git. To reset to defaults, do: `REPOSITORY= s setup`. To set custom Sofin definitions repository on given branch do:
```bash
REPOSITORY=git://some.where.com:YourDefinitions.git BRANCH=mybranch s setup
```

* When you need to quickly test your bundle definition called "Something" (useful if you're testing definitions and you don't want to commit definition changes to definitions repository):
```bash
s dev something      # lowercase - it's definition file name
# [paste your definition here and hit ctrl-d]
s build Something    # camel case - it's name of software bundle
```

* Install all available software defined in a list called "all":
```bash
s get all
```

* Install one software from definition called "ruby.def" for current user:
```bash
s get Ruby
```

* Install software list called "databases" for current user:
```bash
s get databases
```

* Show list of available software:
```bash
s avail
```

* Show list of installed software:
```bash
s fullinstalled
```
or
```bash
s installed
```

* Export "ruby" binary from "Passenger" bundle:
```bash
s export ruby Passenger
```

* Uninstall installed software "SomeBundle"?
```bash
s remove SomeBundle
```

* Create own list called "databases", with definitions: "Postgresql" and "Rust", and get it with Sofin:
```bash
echo "Postgresql\nRust" > ~/.cache/definitions/lists/databases
s get databases
```

## Usage examples (screenshots are worth more than 1000 words):


![pic.1](https://raw.githubusercontent.com/VerKnowSys/sofin/master/imgs/pic1.png?raw=true)
> pic.1: Example of how to override/ create a software definition. Command was: `s dev elixir && s deploy Elixir` (followed by ctrl-d)


![pic.2](https://raw.githubusercontent.com/VerKnowSys/sofin/master/imgs/pic2.png?raw=true)
> pic.2: Example of build + deploy task in progress. Command was: `s d Elixir` (same as: `s deploy Elixir`).


![pic.3](https://raw.githubusercontent.com/VerKnowSys/sofin/master/imgs/pic3.png?raw=true)
> pic.3: Example of software installation from binary bundle (if available). Command was: `s up` and `s i Elixir` (same as: `s install Elixir` or `s get Elixir` or `s pick Elixir` or `s use Elixir`).



## Differences from [POSIX](https://en.wikipedia.org/wiki/POSIX) and [FHS](https://en.wikipedia.org/wiki/Filesystem_Hierarchy_Standard) standards:
* Sofin provides a slightly different approach to shell PATH variable. By default user PATH variable is overriden to include DEF_PREFIX/exports instead of default DEF_PREFIX/(s)bin. After each successful software installation sofin will populate DEF_PREFIX/exports with relative symlinks to existing binaries of bundle. Application exports are defined in "DEF_EXPORTS" variable (available for any definition).
* Sofin suggests empty /usr/local folder. It's caused by POSIX "shared nature" of /usr/local. Sofin was built against this rule to prevent cross requirements between prefixes, and to make sure that each software is easily movable between machines with same architecture.
* Each application has own "root" directory (Similarly to Mac OS X software in .app folders).
* Each software bundle includes all dependencies of given software, hence application bundle requires more disk
space than it does with "old fasioned, system wide, shared software".


## Pitfalls/ Limitations:
* Support for root software will be continuously dropped from support, because it's a bad habit.
* Sofin assumes that /Software is owned by single non-root user. (In ServeD OS, each user has his own /Software mounted from 'zroot/Software/USER' private dataset).
* Sofin assumes that /User is user data directory. On OSX, if you don't have /User directory, you might want to do `sudo ln -s ~ /User`. It will be also required under vanilla versions of HardenedBSD. Under ServeD-OS each worker user is located under /User by default (mounted from 'zroot/User/USER' dataset).


## Installation info (platform specific):

### HardenedBSD specific (no git available in vanilla):
  - Install base 64bit system - I used 64bit HardenedBSD 11.X bootonly iso here.
  - Fetch latest package from [this site](http://dmilith.verknowsys.com/Public/Sofin-releases/), unpack and run `bin/install` as root.
  - Type `s get Zsh`, then when it finishes, do: `grep 'Software/Zsh' /etc/shells || sudo echo '/Software/Zsh/exports/zsh' >> /etc/shells; sudo chsh -s /Software/Zsh/exports/zsh ${USER}` to change your shell, to one that is supported by default by Sofin.
  - Start using Sofin as regular user.

### Darwin/ Mac OS X specific:
  - Install Mac OS X 10.11+ with Command utilities package or Xcode installed.
  - Type `sudo mkdir /Software; sudo chown ${USER} /Software; git clone https://github.com/VerKnowSys/sofin && cd sofin && bin/install` in your terminal, and you're ready to go.


## Conflicts/ Problems/ Known issues:
* Sofin build mechanism is known to be in conflict with other software managment solutions like: BSD Ports, HomeBrew, MacPorts, Fink. Keep that in mind before reporting problems, cause they're the root of true evil on your OS :)


## Major changes since 1.0:
* Pedantic mode by default - any command (called by Sofin), that throws non 0 exit code, has to be wrapped with try() or retry()
* Internal design reworked from ground up to be more in "functional" / "modular" fashion.
* System capabilities detected and used, instead of non-DRY checks over and over again.
* Tests running by default.


## License:
* Released under the [BSD](http://opensource.org/licenses/BSD-2-Clause) license.
* Used a :bus:


### In memory of:
* Zofia Dettlaff
