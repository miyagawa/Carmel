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

  # Run with a directory with cpanfile or META.json
  carmel install

  # Manually pull the modules
  carmel install DBI@1.633 Plack@1.0032

  # Runs your perl script with modules from artifacts
  carmel exec perl ...

  # prints export PERL5LIB=... etc for shell scripting
  carmel export

=head1 DESCRIPTION

B<THIS IS EXPERIMENTAL!>

Carmel is yet another CPAN module manager.

Unlike traditional CPAN module installer, Carmel keeps the build of
your dependencies in a central repository, then select the library
paths to include upon runtime.

=head1 CAVEATS

Carmel requires C<cpanminus> with a patch to support keeping build artifacts. L<https://github.com/miyagawa/cpanminus/pull/429>

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
