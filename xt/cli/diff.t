use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest 'carmel diff' => sub {
    my $app = cli();

    if ($ENV{CI}) {
        $app->cmd_ok("git", "config", "--global", "user.email", 'test@example.com');
        $app->cmd_ok("git", "config", "--global", "user.name", "Test");
    }

    $app->write_cpanfile(<<EOF);
requires 'Class::Tiny', '== 1.006';
EOF

    $app->run_ok("install");
    $app->run_fails("diff");
    like $app->stderr, qr/Can't retrieve snapshot content/;

    $app->cmd_ok("git", "init");
    $app->cmd_ok("git", "add", ".");
    $app->cmd_ok("git", "commit", "-m", "initial");

    $app->write_cpanfile(<<EOF);
requires 'Class::Tiny';
EOF

    $app->run_ok("update");
    $app->run_ok("diff");
    like $app->stdout, qr/Class-Tiny \(1\.006 -> /;

    $app->dir->child('t')->mkpath;
    $app->run_in_dir('t', "diff");
    like $app->stdout, qr/Class-Tiny \(1\.006 -> /;

    $app->run_ok("diff", "-v");
    like $app->stdout, qr/-  DAGOLDEN\/Class-Tiny-1\.006\.tar\.gz/;
};

done_testing;
