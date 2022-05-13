use strict;
use Test::More;
use lib ".";
use xt::CLI;


subtest "core modules can still be pinned" => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
mirror 'https://cpan.metacpan.org/';
requires 'HTTP::Tiny', 0.078,
  dist => 'DAGOLDEN/HTTP-Tiny-0.078.tar.gz';
EOF
    $app->run_ok("install");
    like $app->stdout, qr/HTTP::Tiny \(0\.078\)/;
};

done_testing;
