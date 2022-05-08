use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest 'carmel install' => sub {
    my $app = cli(clean => 1);

    $app->write_cpanfile(<<EOF);
requires 'Try::Tiny';
EOF
    $app->run_fails("list");
    like $app->stderr, qr/Can't find an artifact for Try::Tiny/;

    $app->run_ok("install");
    $app->run_ok("list");
    like $app->stdout, qr/Try::Tiny \(/ or diag $app->stderr;

    $app->write_cpanfile(<<EOF);
requires 'Try::Tiny', '< 0.22';
EOF
    $app->run_fails("list");
    like $app->stderr, qr/Can't find an artifact for Try::Tiny => < 0\.22/;

    $app->run_ok("install");
    $app->run_ok("show", "Try::Tiny");
    like $app->stdout, qr/Try-Tiny-0\.21/ or diag $app->stderr;

    $app->run_ok("find", "Try::Tiny");
    my @lines = grep length, split /\n/, $app->stdout;
    is @lines, 2;

    $app->write_cpanfile(<<EOF);
requires 'Try::Tiny', '0.22';
EOF
    $app->run_ok("install");
    like $app->stdout, qr/Using Try::Tiny/ or diag $app->stderr;

    $app->run_ok("show", "Try::Tiny");
    like $app->stdout, qr/Try-Tiny-0/ or diag $app->stderr;
};

done_testing;
