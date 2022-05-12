use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest 'carmel install/update with non-dual core modules' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'strict';
requires 'UNIVERSAL';
EOF

    $app->run_ok("install");
    $app->run_ok("list");
    is $app->stdout, '';

    $app->run_ok("update");
};

done_testing;
