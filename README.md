# cacherun

Execute a command and cache it's results for later use. The cached output is reused until a user defined expiration time has elapsed, then
the command is executed again and the updates results are cached.

This swift implementation was inspired by [runcached](https://github.com/jazzl0ver/runcached)


## Synopsis

`cacherun --cache-time N command arg0 arg1 ... argN`

Where:
- `N` is the cache expiration time in seconds
- `command` is the command (or full path to an executable) to run
- `arg0 arg1 ... argN` are the arguments to `command`

## Description

`cacherun` is macOS centric, unlike [runcached](https://github.com/jazzl0ver/runcached). The cache file
and run run time execution files required by `cacherun` are stored in the user's `Caches` directory within
their home folder (`~Library/Caches`). If for some reason, that folder can't be created or found, `/tmp` 
is used. 

`cacherun` is built using [Swift Package Manager](https://swift.org/package-manager/). To install, all that
should be required for macOS is to clone the repository and from within your local repo, issue the command

`swift build -c release`

and copy the resulting binary `.build/release/cacherun` somewhere into your shell path.