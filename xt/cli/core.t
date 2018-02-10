use strict;
use Test::More;
use lib ".";
use xt::CLI;

use Module::CoreList;

plan skip_all => "perl $] has HTTP::Tiny 0.056"
  if $Module::CoreList::version{$]}{"HTTP::Tiny"} eq "0.056";

subtest 'core modules in snapshots' => sub {
    my $app = cli();

    $app->write_file('cpanfile.snapshot', <<EOF);
# carton snapshot format: version 1.0
DISTRIBUTIONS
  HTTP-Tiny-0.056
    pathname: D/DA/DAGOLDEN/HTTP-Tiny-0.056.tar.gz
    provides:
      HTTP::Tiny 0.056
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

    # Perl::Build depends on HTTP::Tiny 0
    $app->write_cpanfile(<<EOF);
requires 'Perl::Build';
EOF

    # FIXME: we can't inject optional core dependencies properly
 TODO: {
        local $TODO = "Can't inject core-but-frozen deps to Menlo";
        for (1..2) {
            $app->run("install");
            unlike $app->stderr, qr/Can't find an artifact for HTTP::Tiny/;
        }
    }

    $app->run("list");
    like $app->stdout, qr/HTTP::Tiny \(0\.056\)/;
};

done_testing;
