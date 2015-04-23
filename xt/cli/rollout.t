use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest 'carmel rollout' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'Module::CPANfile';
EOF

    $app->run("install");
    $app->run("rollout");

    ok $app->path("local", "lib", "perl5", "Module", "CPANfile.pm")->exists;
    ok $app->path("local", "bin", "cpanfile-dump")->exists;
};

done_testing;
