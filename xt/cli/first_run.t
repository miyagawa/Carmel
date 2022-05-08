use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest 'transit build dependencies not installed on the first run' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'Apache::LogFormat::Compiler';
EOF

    $app->run_ok("install");
    like $app->snapshot->find("Module::Build::Tiny")->name, qr/Module-Build-Tiny/;
};

done_testing;
