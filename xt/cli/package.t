use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest 'carmel package' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'Class::Tiny';
EOF

    $app->run("install");

    $app->run("package");
    ok $app->stdout =~ m!Copying (.*Class-Tiny-.*\.tar\.gz)$!m
      or diag $app->stdout;

    ok $app->dir->child('vendor/cache/modules/02packages.details.txt.gz')->exists;
    ok $app->dir->child('vendor/cache/authors/id', $1)->exists;
};

done_testing;
