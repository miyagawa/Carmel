use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest 'carmel show #5' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'URI';
requires 'URI::Escape';
EOF

    $app->run_ok("install");
    $app->run_ok("show", "URI::Escape");
    like $app->stdout, qr/URI \(/;

    $app->run_ok("show", "URI");
    like $app->stdout, qr/URI \(/;
};

done_testing;

