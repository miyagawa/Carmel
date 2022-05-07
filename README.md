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

    # update Plack to the latest
    carmel update Plack

    # update all the modules in the snapshot
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
paths to include upon runtime in development.

Carmel also allows you to rollout all the files in a traditional perl INC
directory structure, which is useful to use in a production environment, such as
containers.

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

Given the list of modules and requirements from `cpanfile`, `carmel install`
computes which versions satisfy the requirements best, and if there isn't,
installs the modules from CPAN to put it to the artifact repository. The
computed mappings are preserved as a snapshot in `cpanfile.snapshot`.

Once the snapshot is created, each following `carmel` command runs uses both
`cpanfile` and `cpanfile.snapshot` to determine the best versions to satisfy
the requirements. When you update `cpanfile` to bump a version or add a new
module, `carmel` will install the new dependencies and update the snapshot
accordingly.

`carmel exec` command, like `install` command, lists the build directories and
`.pm` files you need from the repository, and then prepend the mappings of
these files in the `@INC` hook. This is a handy way to run a perl program using
the dependencies pinned by Carmel, without changing any include path.

`carmel update` command allows you to selectively update a dependency while
preserving other dependencies in the snapshot. `carmel update Plack` for
example pulls the latest version of Plack from CPAN (and its dependencies, if it
needs a newer version than pinned in the snapshot), and updates the snapshot
properly. Running `carmel update` without any arguments would update all the
modules in `cpanfile`, including its dependencies.

On a production environment, you might want to use the `carmel rollout`
command, which saves all the files included in the `cpanfile`, pinned with
`cpanfile.snapshot`, to the `local` directory. This directory can be included
like a regular perl's library path, with `PERL5LIB=/path/to/local/lib/perl5`,
or with `use lib`, and you don't need to use `carmel` command in production
this way.

## SNAPSHOT SUPPORT

As of v0.1.29, Carmel supports saving and loading snapshot file in
`cpanfile.snapshot`, in a compatible format with [Carton](https://metacpan.org/pod/Carton). Versions
saved in the snapshot file will be preserved across multiple runs of
Carmel across machines, so that versions frozen in one environment can
be committed to a source code repository, and can be reproduced in
another box, so long as the perl version and architecture is the same.

# DIFFERENCES WITH CARTON

Carmel shares the same goal with Carton, where you can manage your dependencies
by declaring them in `cpanfile`, and pinning them in `cpanfile.snapshot`. Most
of the commands work the same way, so Carmel can most effectively be a drop-in
replacement for Carton, if you're currently using it.

Here's a few key differences between Carmel and Carton:

- Carton _does not_ manage what's currently being installed in `local`
directory. It just runs `cpanm` command with `-L local`, with a hope that
nothing has changed the directory except Carton, and whatever is in the
directory won't conflict with the snapshot file. This can easily conflict when
`cpanfile.snapshot` is updated by multiple developers or when you continuously
update the dependencies across multiple machines.

    Carmel manages all the dependencies for your project in the Carmel repository
    under `$HOME/.carmel`, and nothing is installed under your project directory on
    development. The `local` directory is only created when you request it via
    `carmel rollout` command, and it's safe to run multiple times. Running `carmel
    install` after pulling the changes to the snapshot file will always install the
    correct dependencies from the snapshot file, as compared to Carton, which
    doesn't honor the snapshot on a regular install command.

- Carton has no easy way to undo a change once you update a version of a module in
`local`, because which version is actually selected is only preserved as a file
inside the directory, that's not managed by Carton. To undo a change you have to
remove the entire `local` directory to start over.

    Carmel preserves this information to the `cpanfile.snapshot` file, and every
    invocation of Carmel resolves the dependencies declared in `cpanfile` and
    pinned in `cpanfile.snapshot` dynamically, to create a stable dependency tree,
    without relying on anything in a directory under your project other than the
    snapshot file. Undoing the change in `cpanfile.snapshot` file immediately
    reverts the change.

# COMMUNITY

- [https://github.com/miyagawa/Carmel](https://github.com/miyagawa/Carmel)

    Code repository, Wiki and Issue Tracker

# AUTHOR

Tatsuhiko Miyagawa <miyagawa@bulknews.net>

# COPYRIGHT

Copyright 2015- Tatsuhiko Miyagawa

# LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# SEE ALSO

[App::cpanminus](https://metacpan.org/pod/App%3A%3Acpanminus) [Carton](https://metacpan.org/pod/Carton)
