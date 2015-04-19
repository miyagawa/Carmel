use strict;
use Test::More;
use xt::CLI;

subtest 'carmel install' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'Try::Tiny';
EOF
    $app->run("list");
    like $app->stderr, qr/Could not find an artifact for Try::Tiny/;

    $app->run("install");
    $app->run("list");
    like $app->stdout, qr/Try::Tiny \(/;

    $app->write_cpanfile(<<EOF);
requires 'Try::Tiny', '< 0.22';
EOF
    $app->run("list");
    like $app->stderr, qr/Could not find an artifact for Try::Tiny => < 0\.22/;

    $app->run("install");
    $app->run("show", "Try::Tiny");
    like $app->stdout, qr/Try-Tiny-0\.21/;

    $app->run("find", "Try::Tiny");
    my @lines = grep length, split /\n/, $app->stdout;
    is @lines, 2;

    $app->write_cpanfile(<<EOF);
requires 'Try::Tiny', '0.22';
EOF
    $app->run("install");
    like $app->stdout, qr/Using Try::Tiny/;

    $app->run("show", "Try::Tiny");
    like $app->stdout, qr/Try-Tiny-0/;
};

done_testing;
