# cacherun

Execute a command and cache it's results for later use. The cached output is reused until a user defined expiration time has elapsed, then
the command is executed again and the updates results are cached.

This swift implementation was inspired by [runcached](https://github.com/jazzl0ver/runcached)


## Synopsis

```
OVERVIEW: Returns the cached output of "commmand" when executed within "--cache-time" seconds

USAGE: cacherun --cache-time 60 command <flags> <args>

OPTIONS:
  --cache-time, -c     cached output expiration time in seconds
  --delete-cache, -d   deletes all the files assocated to the command identified by <cacheid>
  --list-caches, -l    display information about the commands currently cached
  --reset-cache, -r    resets the cache files for the command identified by <cacheid>, forcing the command to be executed the next time it's run
  --help               Display available options

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