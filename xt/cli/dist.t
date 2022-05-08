use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest 'dist support' => sub {
    my $app = cli();

    # TODO: needs == since newer version might have already satisfy the version
    $app->write_cpanfile(<<EOF);
requires 'Try::Tiny', '== 0.29',
  dist => 'ETHER/Try-Tiny-0.29.tar.gz';
EOF

    $app->run_ok("install");
    $app->run_ok("list");
    like $app->stdout, qr/Try::Tiny \(0\.29\)/;

};

done_testing;
