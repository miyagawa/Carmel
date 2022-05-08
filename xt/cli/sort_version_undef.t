use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest 'dependency on subdep with version 0' => sub {
    my $app = cli();

    $app->write_cpanfile('');
    $app->run_ok('inject', 'Module::CPANfile'); 
    $app->run_ok('inject', 'Module::CPANfile@1.0002'); 

    $app->write_cpanfile(<<EOF);
requires 'Module::CPANfile::Environment';
EOF

    $app->run_ok("install");
    $app->run_ok("show", "Module::CPANfile");

    unlike $app->stdout, qr!Module::CPANfile \(1\.0002! or diag $app->stderr;
};

done_testing;
