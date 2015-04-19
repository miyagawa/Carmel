use strict;
use Test::More;
use xt::CLI;

subtest 'carmel install' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'Mojolicious', '6, <7';
EOF
    $app->run("list");
    like $app->stderr, qr/Could not find an artifact for Mojolicious/;

    $app->run("install");
    $app->run("list");
    like $app->stdout, qr/Mojolicious \(6/;

    $app->write_cpanfile(<<EOF);
requires 'Mojolicious', '< 6';
EOF
    $app->run("list");
    like $app->stderr, qr/Could not find an artifact for Mojolicious => < 6/;

    $app->run("install");
    $app->run("show", "Mojolicious");
    like $app->stdout, qr/Mojolicious-5/;

    $app->run("find", "Mojolicious");
    like $app->stdout, qr/Mojolicious-5/;
    like $app->stdout, qr/Mojolicious-6/;

    $app->write_cpanfile(<<EOF);
requires 'Mojolicious', '6, <7';
EOF
    $app->run("install");
    like $app->stdout, qr/Using Mojolicious \(6/;

    $app->run("show", "Mojolicious");
    like $app->stdout, qr/Mojolicious-6/;
};

done_testing;
