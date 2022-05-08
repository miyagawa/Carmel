use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest 'dependency on subdep with version 0' => sub {
    my $app = cli();

    $app->write_cpanfile('');
    $app->run('inject', 'Module::CPANfile@1.0002'); 

    $app->write_cpanfile(<<EOF);
requires 'Module::CPANfile::Environment';
EOF

    $app->run("install");
    $app->run("show", "Module::CPANfile");

    unlike $app->stdout, qr!Module::CPANfile \(1\.0002! or diag $app->stderr;
};

done_testing;
