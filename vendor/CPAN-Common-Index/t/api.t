use 5.008001;
use strict;
use warnings;
use Test::More 0.96;
use Test::FailWarnings;

my @backends = map { "CPAN::Common::Index::$_" } qw(
  Mux::Ordered
  Mirror
  LocalPackage
  MetaDB
);

my @required = qw(
  search_packages
  search_authors
);

for my $mod (@backends) {
    require_ok($mod);
    can_ok( $mod, @required );
}

done_testing;
# COPYRIGHT
# vim: ts=4 sts=4 sw=4 et:
