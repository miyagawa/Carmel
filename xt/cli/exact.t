use strict;
use Test::More;
use xt::CLI;

subtest 'carmel install with exact' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'Try::Tiny', '== 0.22';
EOF

    $app->run("install");
    $app->run("list");

    like $app->stdout, qr/Try::Tiny \(0\.22\)/ or diag $app->stderr;
};

done_testing;
