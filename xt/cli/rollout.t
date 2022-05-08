use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest 'carmel rollout' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'Module::CPANfile';
EOF

    $app->run_ok("install");
    $app->run_ok("rollout");
    like $app->stdout, qr/Installing Module-CPANfile-.* to/;

    $app->run_ok("rollout", "-v");
    like $app->stdout, qr/^Installing .*Module\/CPANfile\.pm$/m;

    ok $app->path("local/lib/perl5/Module/CPANfile.pm")->exists;
    ok $app->path("local/bin/cpanfile-dump")->exists;

    $app->run_ok("env");
    my $dir = $app->dir->absolute;
    like $app->stdout, qr!PATH=.*$dir/local/bin:!;

    $app->run_ok("exec", "perl", "-V");
    like $app->stdout, qr!$dir/local/lib/perl5!;
    unlike $app->stdout, qr/::FastINC/;
};

done_testing;
