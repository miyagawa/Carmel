use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest 'carmel exec -- ls' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'Module::CPANfile';
EOF

    $app->run_ok("install");
    $app->run_ok("exec", "--", "perl -V");

    like $app->stdout, qr/perl5/ or diag $app->stderr;
};

done_testing;
