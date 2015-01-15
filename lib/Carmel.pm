package Carmel;
use strict;
use 5.010_001;
use version; our $VERSION = version->declare('v0.1.0');

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

  # Runs your perl script with modules from artifacts
  carmel exec perl ...

  # Runs your perl script with a checker to guarantee everything is loaded from Carmel
  carmel exec perl -MDevel::Carmel script.pl

  # prints export PERL5LIB=... etc for shell scripting
  carmel export

  # find a module in repository
  carmel find DBI

  # find a module matching the version query
  carmel find Plack ">= 1.0000, < 1.1000"

  # list all the modules to be loaded
  carmel list

=head1 DESCRIPTION

B<THIS IS EXPERIMENTAL!>

Carmel is yet another CPAN module manager.

Unlike traditional CPAN module installer, Carmel keeps the build of
your dependencies in a central repository, then select the library
paths to include upon runtime.

=head1 HOW IT WORKS

Carmel requires C<cpanminus> with a patch to support keeping build
artifacts. L<https://github.com/miyagawa/cpanminus/pull/429>

With the patch, cpanm will keep the build directory (artifacts) in a
repository, which defaults to C<$HOME/.cpanm/builds>, and your
directory structure would look like:

  $HOME/.cpanm/builds
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

Carmel scans this directory and creates the mapping of which package
belongs to which build directory. Given the list of modules and
requirements (using C<cpanfile> or even better C<cpanfile.snapshot>
from L<Carton>), Carmel lists all the build directories you need, and
then prepend the C<blib> directories to C<PERL5LIB> environment
variables.

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

https://github.com/ingydotnet/only-pm

https://github.com/gugod/perlrocks

=cut
