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

    $app->run("install");
    $app->run("show", "URI::Escape");
    is $app->exit_code, 0 or diag $app->stderr;
    like $app->stdout, qr/URI \(/;

    $app->run("show", "URI");
    is $app->exit_code, 0 or diag $app->stderr;
    like $app->stdout, qr/URI \(/;
};

done_testing;

