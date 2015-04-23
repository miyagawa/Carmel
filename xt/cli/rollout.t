use strict;
use Test::More;
use xt::CLI;

subtest 'carmel rollout' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'Module::CPANfile';
EOF

    $app->run("install");
    $app->run("rollout");

    ok $app->dir->child("local", "lib", "perl5", "Module", "CPANfile.pm")->exists;
    ok $app->dir->child("local", "bin", "cpanfile-dump")->exists;
};

done_testing;
