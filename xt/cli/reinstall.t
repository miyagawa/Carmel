use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest 'carmel reinstall' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'HTTP::Tiny';
requires 'Class::Tiny';
EOF

    $app->run_fails("reinstall");
    like $app->stderr, qr/Run `carmel install` first/;

    $app->run_ok("install");
    $app->run_ok("reinstall");

    like $app->stdout, qr/installed HTTP-Tiny-/;
    like $app->stdout, qr/installed Class-Tiny-/;

    $app->run_fails("reinstall", "Plack");
    like $app->stderr, qr/not found in cpanfile.snapshot/;
};

done_testing;
