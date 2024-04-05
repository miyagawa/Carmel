# NAME

Carmel - CPAN Artifact Repository Manager

# SYNOPSIS

    # Run with a directory with cpanfile
    carmel install

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

    # pin modules to specific versions
    carmel update DBI@1.633 Plack@1.0000

    # show diffs for cpanfile.snapshot in a nice way
    carmel diff

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

# WORKFLOW

## Development

During the development, run `carmel install` when you setup a new environment,
and any time you make changes to `cpanfile`. This will update your build
artifacts, and saves the changes to `cpanfile.snapshot`. Commit the snapshot
file in version control system so that you can reproduce the exact same versions
across machines.

`carmel exec` makes it easy to run your application using the versions in
`cpanfile` and `cpanfile.snapshot` dynamically.

    # On your development environment
    > cat cpanfile
    requires 'Plack', '0.9980';
    requires 'Starman', '0.2000';

    > carmel install
    > echo /.carmel >> .gitignore
    > git add cpanfile cpanfile.snapshot .gitignore
    > git commit -m "Add Plack and Starman"

    # On a new setup, or another developer's machine
    > git pull
    > carmel install
    > carmel exec starman -p 8080 myapp.psgi

    # Add a new dependency
    > echo "requires 'Try::Tiny';" >> cpanfile
    > carmel install
    > git commit -am 'Add Try::Tiny'

    # Update Plack to the latest
    > carmel update Plack

## Production Deployments

Carmel allows you to manage all the dependencies the same way across development
environments and production environments. However, there might be cases where
you want to avoid running your application with `carmel exec` in production, to
avoid the overhead with large number of include paths, or to avoid installing
Carmel in the production hosts. Carmel provides two easy ways to avoid depending
on Carmel on the deploy target environments.

### carmel rollout

`carmel rollout` rolls out the build artifacts into a regular perl5 library
path in `local`. Once the rollout is complete, you can include the path just
like a regular [local::lib](https://metacpan.org/pod/local%3A%3Alib) directory.

    # Production environment: Roll out to ./local
    > carmel rollout
    > perl -Ilocal/lib/perl5 local/bin/starman -p 8080 myapp.psgi

You can run `carmel rollout` in a CI system to create the `local` directory
next to your application code for a linux package (e.g. deb package), or Docker
containers.

### carmel package

`carmel package` (similar to `carton bundle`) creates a directory with
tarballs and CPAN-style package index files, which you can pass to [cpanm](https://metacpan.org/pod/cpanm) on a
target machine. This way, you only need `cpanm`, which is available as a
self-contained single executable, to bootstrap the installation on a host with a
stock perl.

    # Vendor all the packages to vendor/cache
    > carmel package
    > git add vendor/cache
    > git commit -m 'Vendor all the tarballs'

    # Remote environment (CI etc.)
    > git clone https://.../myapp.git && cd myapp

    # Install the modules to ./local (like carmel rollout)
    > cpanm -L ./local --from $PWD/vendor/cache -nq --installdeps .

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

# CAVEATS / KNOWN ISSUES

- If you run multiple instances of `carmel`, or hit Ctrl-C to interrupt the cpanm
install session, Carmel might get into a state where some modules have been
installed properly, while some modules in the dependency chain are
missing. Carmel checks if there's another process running simultaneously using a
lock file to prevent this problem, but make sure you let it finish the
installation to get the full builds properly.
- There're certain dependencies that get missed during the initial `carmel
install`, and you'll see the error message "Can't find an artifact for
Foo".

    Please report it to the issue tracker if you can reliably reproduce this type of
    errors. [https://github.com/miyagawa/Carmel/issues/74](https://github.com/miyagawa/Carmel/issues/74) has a list of known
    modules that could cause problems like this.

- In some situation, you might encounter conflicts in version resolutions, between
what's pinned in the snapshot and a new version that's needed when you introduce
a new module.

    For example, suppose you have:

        # cpanfile
        requires 'Foo';
        requires 'Bar'; # which requires Foo >= 1.001

    Without a snapshot file, Carmel has no trouble resolving the correct versions
    for this combination. But if you have:

        # cpanfile.snapshot
        Foo-1.000

    The first time you run `carmel install`, Carmel will try to install Foo-1.000,
    because that's the version pinned in the snapshot, while trying to pull the
    module Bar, which would conflict with that version of Foo.

    This can happen 50% of the time, because if cpanm (called internally by Carmel)
    installs Bar first, then the resolution is done correctly and the version in the
    snapshot would be skipped, and the snapshot will be updated accordingly. This is
    due to perl's hash randomization after Perl 5.18.

    To avoid this, you're recommended to run `carmel install` **before making any
    changes to cpanfile**. That will put the build caches to satisfy what's in
    cpanfile and the snapshot. After that, adding a new dependency will likely reuse
    what's in the build cache, while adding a new dependency can update the
    transient dependency (for Foo) without having conflicts.

    If you encounter conflicts like this, you can work around it by:

    - Run `carmel update Foo` to pull the latest version of Foo from CPAN, ignoring what's in the snapshot.
    - Update `cpanfile` to explicitly update the version requirement for `Foo`.

- Carmel doesn't support Taint mode (`-T`). You'll see an error message
`Insecure dependency in require while running with -T switch`.

# COMPARISONS WITH SIMILAR TOOLS

## Carton

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
    doesn't honor the snapshot on a regular install command, if whatever version in
    `local` already satisfies the version in `cpanfile`.

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

## cpm

[App::cpm](https://metacpan.org/pod/App%3A%3Acpm) is an excellent standalone CPAN installer.

- Like [Carton](https://metacpan.org/pod/Carton), cpm installs the dependencies declared in `cpanfile` to
`local`. Carmel installs them into a build cache, and doesn't use `local`
directory for state management. You can run `carmel rollout` to copy the
dependencies to `local` directory.
- cpm installs the modules in parallel, which makes the installation very
fast. Like Carmel, cpm also manages its build artifacts cache, so a module that
has previously been installed would be very fast to install, since there's no build
process.
- Unlike Carton and Carmel, cpm doesn't have the ability to manage
`cpanfile.snapshot` file on its own. It can read the snapshot however, so it's
possible to use Carmel in a development environment, and then use `cpm
install` instead of `carmel install` and `carmel rollout`, if all you need is
to build out a perl5 library path out of `cpanfile` and `cpanfile.snapshot` in
the source code repository.

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
