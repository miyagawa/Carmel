use strict;
use Test::More;
use lib ".";
use xt::CLI;

use Capture::Tiny qw(capture);

subtest 'carmel binstubs' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'Module::CPANfile';
EOF

    $app->run("install");
    $app->run("binstubs", "Module::CPANfile");

    ok $app->dir->child("bin/cpanfile-dump")->exists;

    $app->run_any("bin/cpanfile-dump");
    like $app->stdout, qr/Module::CPANfile/ or diag $app->stderr;
};

done_testing;
