package Carmel;
use strict;
use 5.012000;
use version; our $VERSION = version->declare('v0.9.2');

1;
__END__

=encoding utf-8

=head1 NAME

Carmel - CPAN Artifact Repository Manager

=head1 SYNOPSIS

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

  # pin modules tp specific versions
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

=head1 DESCRIPTION

Carmel is yet another CPAN module manager.

Unlike traditional CPAN module installer, Carmel keeps the build of
your dependencies in a central repository, then select the library
paths to include upon runtime in development.

Carmel also allows you to rollout all the files in a traditional perl INC
directory structure, which is useful to use in a production environment, such as
containers.

=head1 WORKFLOW

=head2 Development

During the development, run C<carmel install> when you setup a new environment,
and any time you make changes to C<cpanfile>. This will update your build
artifacts, and saves the changes to C<cpanfile.snapshot>. Commit the snapshot
file in version control system so that you can reproduce the exact same versions
across machines.

C<carmel exec> makes it easy to run your application using the versions in
C<cpanfile> and C<cpanfile.snapshot> dynamically.

  # On your development environment
  > cat cpanfile
  requires 'Plack', '0.9980';
  requires 'Starman', '0.2000';

  > carmel install
  > echo /.carmel >> .gitignore
  > git add cpanfile cpanfile.snapshot .gitignore
  > git commit -m "add Plack and Starman"

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

=head2 Production Deployments

Carmel allows you to manage all the dependencies the same way across development
environments and production environments. However, there might be cases where
you want to avoid running your application with C<carmel exec> in production, to
avoid the overhead with large number of include paths, or to avoid installing
Carmel in the production hosts. Carmel provides two easy ways to avoid depending
on Carmel on the deploy target environments.

=head3 carmel rollout

C<carmel rollout> rolls out the build artifacts into a regular perl5 library
path in C<local>. Once the rollout is complete, you can include the path just
like a regular L<local::lib> directory.

  # Production environment: Roll out to ./local
  > carmel rollout
  > perl -Ilocal/lib/perl5 local/bin/starman -p 8080 myapp.psgi

You can run C<carmel rollout> in a CI system to create the C<local> directory
next to your application code for a linux package (e.g. deb package), or Docker
containers.

=head3 carmel package

C<carmel package> (similar to C<carton bundle>) creates a directory with
tarballs and CPAN-style package index files, which you can pass to L<cpanm> on a
target machine. This way, you only need C<cpanm>, which is available as a
self-contained single executable, to bootstrap the installation on a host with a
stock perl.

  # Vendor all the packages to vendor/cache
  > carmel package
  > git add vendor/cache
  > git commit -m 'Vendor all the tarballs'

  # Remote environment (CI etc.)
  > git clone https://.../myapp.git && cd myapp

  # Install the modules to ./local (like carmel rollout)
  > cpanm -L ./local --from file://$PWD/vendor/cache -nq --installdeps .

=head1 HOW IT WORKS

Carmel will keep the build directory (artifacts) after a cpanm
installation in a repository, which defaults to C<$HOME/.carmel/{version}-{archname}/builds>,
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

Given the list of modules and requirements from C<cpanfile>, C<carmel install>
computes which versions satisfy the requirements best, and if there isn't,
installs the modules from CPAN to put it to the artifact repository. The
computed mappings are preserved as a snapshot in C<cpanfile.snapshot>.

Once the snapshot is created, each following C<carmel> command runs uses both
C<cpanfile> and C<cpanfile.snapshot> to determine the best versions to satisfy
the requirements. When you update C<cpanfile> to bump a version or add a new
module, C<carmel> will install the new dependencies and update the snapshot
accordingly.

C<carmel exec> command, like C<install> command, lists the build directories and
C<.pm> files you need from the repository, and then prepend the mappings of
these files in the C<@INC> hook. This is a handy way to run a perl program using
the dependencies pinned by Carmel, without changing any include path.

C<carmel update> command allows you to selectively update a dependency while
preserving other dependencies in the snapshot. C<carmel update Plack> for
example pulls the latest version of Plack from CPAN (and its dependencies, if it
needs a newer version than pinned in the snapshot), and updates the snapshot
properly. Running C<carmel update> without any arguments would update all the
modules in C<cpanfile>, including its dependencies.

On a production environment, you might want to use the C<carmel rollout>
command, which saves all the files included in the C<cpanfile>, pinned with
C<cpanfile.snapshot>, to the C<local> directory. This directory can be included
like a regular perl's library path, with C<PERL5LIB=/path/to/local/lib/perl5>,
or with C<use lib>, and you don't need to use C<carmel> command in production
this way.

=head2 SNAPSHOT SUPPORT

As of v0.1.29, Carmel supports saving and loading snapshot file in
C<cpanfile.snapshot>, in a compatible format with L<Carton>. Versions
saved in the snapshot file will be preserved across multiple runs of
Carmel across machines, so that versions frozen in one environment can
be committed to a source code repository, and can be reproduced in
another box, so long as the perl version and architecture is the same.

=head1 CAVEATS / KNOWN ISSUES

=over 4

=item *

If you run multiple instances of C<carmel>, or hit Ctrl-C to interrupt the cpanm
install session, Carmel might get into a state where some modules have been
installed properly, while some modules in the dependency chain are
missing. Carmel checks if there's another process running simultaneously using a
lock file to prevent this problem, but make sure you let it finish the
installation to get the full builds properly.

=item *

There're certain dependencies that get missed during the initial C<carmel
install>, and you'll see the error message "Can't find an artifact for
Foo".

Please report it to the issue tracker if you can reliably reproduce this type of
errors. L<https://github.com/miyagawa/Carmel/issues/74> has a list of known
modules that could cause problems like this.

=item *

In some situation, you might encounter conflicts in version resolutions, between
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

The first time you run C<carmel install>, Carmel will try to install Foo-1.000,
because that's the version pinned in the snapshot, while trying to pull the
module Bar, which would conflict with that version of Foo.

This can happen 50% of the time, because if cpanm (called internally by Carmel)
installs Bar first, then the resolution is done correctly and the version in the
snapshot would be skipped, and the snapshot will be updated accordingly. This is
due to perl's hash randomization after Perl 5.18.

To avoid this, you're recommended to run C<carmel install> B<before making any
changes to cpanfile>. That will put the build caches to satisfy what's in
cpanfile and the snapshot. After that, adding a new dependency will likely reuse
what's in the build cache, while adding a new dependency can update the
transient dependency (for Foo) without having conflicts.

If you encounter conflicts like this, you can work around it by:

=over 8

=item *

Run C<carmel update Foo> to pull the latest version of Foo from CPAN, ignoring what's in the snapshot.

=item *

Update C<cpanfile> to explicitly update the version requirement for C<Foo>.

=back

=item *

Carmel doesn't support Taint mode (C<-T>). You'll see an error message
C<Insecure dependency in require while running with -T switch>.

=back

=head1 COMPARISONS WITH SIMILAR TOOLS

=head2 Carton

Carmel shares the same goal with Carton, where you can manage your dependencies
by declaring them in C<cpanfile>, and pinning them in C<cpanfile.snapshot>. Most
of the commands work the same way, so Carmel can most effectively be a drop-in
replacement for Carton, if you're currently using it.

Here's a few key differences between Carmel and Carton:

=over 4

=item *

Carton I<does not> manage what's currently being installed in C<local>
directory. It just runs C<cpanm> command with C<-L local>, with a hope that
nothing has changed the directory except Carton, and whatever is in the
directory won't conflict with the snapshot file. This can easily conflict when
C<cpanfile.snapshot> is updated by multiple developers or when you continuously
update the dependencies across multiple machines.

Carmel manages all the dependencies for your project in the Carmel repository
under C<$HOME/.carmel>, and nothing is installed under your project directory on
development. The C<local> directory is only created when you request it via
C<carmel rollout> command, and it's safe to run multiple times. Running C<carmel
install> after pulling the changes to the snapshot file will always install the
correct dependencies from the snapshot file, as compared to Carton, which
doesn't honor the snapshot on a regular install command, if whatever version in
C<local> already satisfies the version in C<cpanfile>.

=item *

Carton has no easy way to undo a change once you update a version of a module in
C<local>, because which version is actually selected is only preserved as a file
inside the directory, that's not managed by Carton. To undo a change you have to
remove the entire C<local> directory to start over.

Carmel preserves this information to the C<cpanfile.snapshot> file, and every
invocation of Carmel resolves the dependencies declared in C<cpanfile> and
pinned in C<cpanfile.snapshot> dynamically, to create a stable dependency tree,
without relying on anything in a directory under your project other than the
snapshot file. Undoing the change in C<cpanfile.snapshot> file immediately
reverts the change.

=back

=head2 cpm

L<App::cpm> is an excellent standalone CPAN installer.

=over 4

=item *

Like L<Carton>, cpm installs the dependencies declared in C<cpanfile> to
C<local>. Carmel installs them into a build cache, and doesn't use C<local>
directory for state management. You can run C<carmel rollout> to copy the
dependencies to C<local> directory.

=item *

cpm installs the modules in parallel, which makes the installation very
fast. Like Carmel, cpm also manages its build artifacts cache, so a module that
has previously been installed would be very fast to install, since there's no build
process.

=item *

Unlike Carton and Carmel, cpm doesn't have the ability to manage
C<cpanfile.snapshot> file on its own. It can read the snapshot however, so it's
possible to use Carmel in a development environment, and then use C<cpm
install> instead of C<carmel install> and C<carmel rollout>, if all you need is
to build out a perl5 library path out of C<cpanfile> and C<cpanfile.snapshot> in
the source code repository.

=back

=head1 COMMUNITY

=over 4

=item L<https://github.com/miyagawa/Carmel>

Code repository, Wiki and Issue Tracker

=back

=head1 AUTHOR

Tatsuhiko Miyagawa E<lt>miyagawa@bulknews.netE<gt>

=head1 COPYRIGHT

Copyright 2015- Tatsuhiko Miyagawa

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<App::cpanminus> L<Carton>

=cut
