use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest 'carmel install exit code' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'Plack', '999';
EOF

    $app->run_fails("install");
};

done_testing;

