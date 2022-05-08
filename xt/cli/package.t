use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest 'carmel package' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'Class::Tiny';
EOF

    $app->run_ok("install");

    $app->run_ok("package");
    ok $app->stdout =~ m!Copying (.*Class-Tiny-.*\.tar\.gz)$!m
      or diag $app->stdout;

    ok $app->dir->child('vendor/cache/modules/02packages.details.txt.gz')->exists;
    ok $app->dir->child('vendor/cache/authors/id', $1)->exists;
};

subtest 'remove package cache' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'Class::Tiny';
EOF

    $app->run_ok("install");

    if ($ENV{TEST_CLEAN}) {
        $app->dir->child('.carmel/cache')->remove_tree({ safe => 0 });

        $app->run_fails("package");
        like $app->stderr, qr/not found in/;
    }
};

done_testing;
