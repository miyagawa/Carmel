use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest 'carmel exec cmd -h' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'Module::CPANfile';
EOF

    $app->run("install");
    $app->run("exec", "cpanfile-dump", "-h");

    like $app->stdout, qr/cpanfile-dump/ or diag $app->stderr;
    unlike $app->stdout, qr/Carmel/;
};

done_testing;
