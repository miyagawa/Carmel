package Carmel;
use strict;
use 5.010_001;
use version; our $VERSION = version->declare('v0.1.11');

1;
__END__

=encoding utf-8

=head1 NAME

Carmel - CPAN Artifact Repository Manager

=head1 SYNOPSIS

  # Run with a directory with cpanfile or cpanfile.snapshot
  carmel install

  # Manually pull a module if you don't have it
  carmel install DBI@1.633 Plack@1.0000

  # list all the modules to be loaded
  carmel list

  # list all the modules in a tree
  carmel tree

  # show a location where a module is installed
  carmel show Plack

  # Runs your perl script with modules from artifacts
  carmel exec perl ...

  # Requires all your modules in cpanfile in one shot
  carmel exec perl -e 'Carmel::Runtime->require_all'

  # prints export PATH=... etc for shell scripting
  carmel export

  # find a module in a repository
  carmel find DBI

  # find a module matching the version query
  carmel find Plack ">= 1.0000, < 1.1000"


=head1 DESCRIPTION

B<THIS IS EXPERIMENTAL!>

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

Given the list of modules and requirements (using C<cpanfile> or even
better C<cpanfile.snapshot> from L<Carton>), Carmel lists all the
build directories and C<.pm> files you need, and then prepend the
mappings of these files in the C<@INC> hook.

For example, if you have:

  requires 'URI', '== 1.63';

Carmel finds URI package with C<$VERSION> set to 1.63 in
C<URI-1.63/blib/lib> so it will let perl load C<URI.pm> from that
directory.

Instead, if you have:

  requires 'URI';

it will find the latest that satisfies the (empty) requirement, which
is in C<URI-1.64/blib/lib>.

The fact that it prefers the latest, rather than the oldest, might
change in the future once a mechanism to make snapshot is introduced,
since you will not like to upgrade one of the dependencies
unexpectedly.

You have a choice to execute a subprocess from Carmel, by using the
C<exec> sub command. If you prefer a fine grained control, you can
also use C<env> or C<export> command to integrate with your own shell
script wrapper.

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
