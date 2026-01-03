# cacherun

Execute a command and cache it's results for later use. The cached output is reused until a user defined expiration time has elapsed, then
the command is executed again and the updates results are cached.

This swift implementation was inspired by [runcached](https://github.com/jazzl0ver/runcached)


## Synopsis

```
OVERVIEW: Returns the cached output of "commmand" when executed within "--cache-time" seconds

USAGE: cache-run [--cache-time <cache-time>] [--list-caches] [--delete-cache <delete-cache>] [--delete-all] [--reset-cache <reset-cache>] [--reset-all] [--version] [--show-help] [<user-command> ...]

EXAMPLE: cacherun --cache-time 60 howhot conditions 49002

ARGUMENTS:
  <user-command>          command <flags> <args>

OPTIONS:
  -c, --cache-time <cache-time>
                          cached output expiration time in seconds (default: 60)
  -l, --list-caches       display information about the commands currently cached
  -d, --delete-cache <delete-cache>
                          deletes all the files assocated to the command identified by <cacheid>
  --delete-all            delete all files for all cached commands
  -r, --reset-cache <reset-cache>
                          resets the cache files for the command identified by <cacheid>, forcing the
                          command to be executed the next time it's run
  --reset-all             reset all the output for all cached commands.
  --version               Show version and exit
  -H, --show-help         Show help and exit. NOTE: ignore standard `--help' flag
  -h, --help              Show help information.  (See Notes)


POSITIONAL ARGUMENTS:
  command              command arg0 arg1 ... argn
```

## Description

`cacherun` is macOS centric, unlike [runcached](https://github.com/jazzl0ver/runcached). The cache file
and run run time execution files required by `cacherun` are stored in the user's `Caches` directory within
their home folder (`~Library/Caches`). If for some reason, that folder can't be created or found, `/tmp` 
is used. 

`cacherun` is built using [Swift Package Manager](https://swift.org/package-manager/). To install, all that
should be required for macOS is to clone the repository and from within your local repo, issue the command

`swift build -c release`

and copy the resulting binary `.build/release/cacherun` somewhere into your shell path.

## Notes

There's one quirk regarding the standard `--help` flag. `ArgumentParser` seems to execute `run()` before it executes the standard help command. Passing `--help` to `cacherun` acts as if it's a command to execute and cache. Until this is addressed, use `-H` or `--show-help` for help.