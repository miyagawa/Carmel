use strict;
use Test::More;
use lib ".";
use xt::CLI;

use Module::CoreList;

plan skip_all => "perl $] has HTTP::Tiny ne 0.076"
  if $Module::CoreList::version{$]}{"HTTP::Tiny"} ne "0.076";

subtest "should ignore the same version" => sub {
    my $app = cli();

    $app->write_file('cpanfile.snapshot', <<EOF);
# carton snapshot format: version 1.0
DISTRIBUTIONS
  HTTP-Tiny-0.076
    pathname: D/DA/DAGOLDEN/HTTP-Tiny-0.076.tar.gz
    provides:
      HTTP::Tiny 0.076
    requirements:
      Carp 0
      Fcntl 0
      IO::Socket 0
      MIME::Base64 0
      Socket 0
      Time::Local 0
      bytes 0
      perl 5.006
      strict 0
      warnings 0
EOF

    $app->write_cpanfile(<<EOF);
requires 'HTTP::Tinyish';
EOF

    $app->run_ok("install");
    unlike $app->stderr, qr/Can't find an artifact for HTTP::Tiny/;

    $app->run_ok("list");
    unlike $app->stdout, qr/HTTP::Tiny /;
};

done_testing;
