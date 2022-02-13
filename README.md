# NAME

Carmel - CPAN Artifact Repository Manager

# SYNOPSIS

    # Run with a directory with cpanfile
    carmel install

    # Manually pull a module if you don't have it
    carmel inject DBI@1.633 Plack@1.0000

    # list all the modules to be loaded
    carmel list

    # list all the modules in a tree
    carmel tree

    # show a location where a module is installed
    carmel show Plack

    # update snapshot
    carmel update

    # Runs your perl script with modules from artifacts
    carmel exec perl ...

    # Requires all your modules in cpanfile in one shot
    carmel exec perl -e 'use Carmel::Preload;'

    # Roll out the currently selected modules into ./local
    carmel rollout

    # package modules tarballs and index into ./vendor/cache
    carmel package

    # use Carmel packages inside a script (without carmel exec)
    perl -e 'use Carmel::Setup; ...'

    # prints export PATH=... etc for shell scripting
    carmel export

    # find a module in a repository
    carmel find DBI

    # find a module matching the version query
    carmel find Plack ">= 1.0000, < 1.1000"

# DESCRIPTION

Carmel is yet another CPAN module manager.

Unlike traditional CPAN module installer, Carmel keeps the build of
your dependencies in a central repository, then select the library
paths to include upon runtime.

# HOW IT WORKS

Carmel will keep the build directory (artifacts) after a cpanm
installation in a repository, which defaults to `$HOME/.carmel/{version}-{archname}/builds`,
and your directory structure would look like:

    $HOME/.carmel/5.20.1-darwin-2level/builds
      Plack-1.0033/
        blib/
          arch/
          lib/
      URI-1.64/
        blib/
          arch/
          lib/
      URI-1.63/
        blib/
          arch/
          lib/

Carmel scans this directory and creates the mapping of which version
of any package belongs to which build directory.

Given the list of modules and requirements using `cpanfile`, Carmel
lists all the build directories and `.pm` files you need, and then
prepend the mappings of these files in the `@INC` hook.

For example, if you have:

    requires 'URI', '== 1.63';

Carmel finds URI package with `$VERSION` set to 1.63 in
`URI-1.63/blib/lib` so it will let perl load `URI.pm` from that
directory.

Instead, if you have:

    requires 'URI';

it will find the latest that satisfies the (empty) requirement, which
is in `URI-1.64/blib/lib`.

You have a choice to execute a subprocess from Carmel, by using the
`exec` sub command. If you prefer a fine grained control, you can
also use `env` or `export` command to integrate with your own shell
script wrapper.

## SNAPSHOT SUPPORT

As of v0.1.29, Carmel supports saving and loading snapshot file in
`cpanfile.snapshot`, in a compatible format with [Carton](https://metacpan.org/pod/Carton). Versions
saved in the snapshot file will be preserved across multiple runs of
Carmel across machines, so that versions frozen in one environment can
be committed to a source code repository, and can be reproduce in
another box, so long as the perl version and architecture is the same.

# COMMUNITY

- [https://github.com/miyagawa/Carmel](https://github.com/miyagawa/Carmel)

    Code repository, Wiki and Issue Tracker

- [irc://irc.perl.org/#cpanm](irc://irc.perl.org/#cpanm)

    IRC chat room

# AUTHOR

Tatsuhiko Miyagawa <miyagawa@bulknews.net>

# COPYRIGHT

Copyright 2015- Tatsuhiko Miyagawa

# LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# SEE ALSO

[App::cpanminus](https://metacpan.org/pod/App%3A%3Acpanminus) [Carton](https://metacpan.org/pod/Carton)
