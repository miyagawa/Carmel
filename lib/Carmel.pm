package Carmel;
use strict;
use 5.012000;
use version; our $VERSION = version->declare('v0.1.41');

1;
__END__

=encoding utf-8

=head1 NAME

Carmel - CPAN Artifact Repository Manager

=head1 SYNOPSIS

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

=head1 DESCRIPTION

Carmel is yet another CPAN module manager.

Unlike traditional CPAN module installer, Carmel keeps the build of
your dependencies in a central repository, then select the library
paths to include upon runtime.

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

Given the list of modules and requirements using C<cpanfile>, Carmel
lists all the build directories and C<.pm> files you need, and then
prepend the mappings of these files in the C<@INC> hook.

For example, if you have:

  requires 'URI', '== 1.63';

Carmel finds URI package with C<$VERSION> set to 1.63 in
C<URI-1.63/blib/lib> so it will let perl load C<URI.pm> from that
directory.

Instead, if you have:

  requires 'URI';

it will find the latest that satisfies the (empty) requirement, which
is in C<URI-1.64/blib/lib>.

You have a choice to execute a subprocess from Carmel, by using the
C<exec> sub command. If you prefer a fine grained control, you can
also use C<env> or C<export> command to integrate with your own shell
script wrapper.

=head2 SNAPSHOT SUPPORT

As of v0.1.29, Carmel supports saving and loading snapshot file in
C<cpanfile.snapshot>, in a compatible format with L<Carton>. Versions
saved in the snapshot file will be preserved across multiple runs of
Carmel across machines, so that versions frozen in one environment can
be committed to a source code repository, and can be reproduced in
another box, so long as the perl version and architecture is the same.

=head1 DIFFERENCES WITH CARTON

Carmel shares the goal of Carton, where you can manage your dependencies by
declaring them in C<cpanfile>, and pinning them in C<cpanfile.snapshot>. Most of
the commands work the same way, so Carmel can most effectively a drop-in
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
C<carmel rollout> command, and it's very safe to run multiple times. Running
C<carmel install> after pulling the changes to the snapshot file will always
install the correct dependencies from the snapshot file, as compared to Carton,
which doesn't honor the snapshot on a regular install command.

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
