use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest 'carmel update from main module with version = 0/undef' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'LWP', '== 6.35';
EOF

    $app->run_ok("install");
    $app->run_ok("update");
};

done_testing;
