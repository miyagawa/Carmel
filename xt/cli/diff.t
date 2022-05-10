use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest 'carmel diff' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'Class::Tiny', '== 1.006';
EOF

    $app->run_ok("install");
    $app->run_fails("diff");
    like $app->stderr, qr/Can't retrieve snapshot content/;

    $app->cmd("git", "init");
    $app->cmd("git", "add", ".");
    $app->cmd("git", "commit", "-m", "initial");

    $app->write_cpanfile(<<EOF);
requires 'Class::Tiny';
EOF

    $app->run_ok("update");
    $app->run_ok("diff");
    like $app->stdout, qr/Class-Tiny \(1\.006 -> /;

    $app->dir->child('t')->mkpath;
    $app->run_in_dir('t', "diff");
    like $app->stdout, qr/Class-Tiny \(1\.006 -> /;
      
};

done_testing;
