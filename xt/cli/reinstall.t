use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest 'carmel reinstall' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'HTTP::Tiny';
requires 'Class::Tiny';
requires 'Try::Tiny', '== 0.30';
EOF

    $app->run_fails("reinstall");
    like $app->stderr, qr/Run `carmel install` first/;

    $app->run_ok("install");

    if ($ENV{TEST_CLEAN}) {
        $app->dir->child(".carmel/builds/Try-Tiny-0.30/blib/lib/Try/Tiny.pm")->spew("die");
        $app->run_fails("exec", "perl", "-e", 'use Try::Tiny; warn $INC{"Try/Tiny.pm"}');
        like $app->stderr, qr/Died at/;
    }

    $app->run_ok("reinstall");

    like $app->stdout, qr/installed HTTP-Tiny-/;
    like $app->stdout, qr/installed Class-Tiny-/;
    like $app->stdout, qr/installed Try-Tiny-0\.30/;

    if ($ENV{TEST_CLEAN}) {
        ok $app->dir->child(".carmel/builds/Try-Tiny-0.30/blib/lib/Try/Tiny.pm")->exists;
    }

    $app->run_ok("exec", "perl", "-e", 'use Try::Tiny; print $INC{"Try/Tiny.pm"}');

    $app->run_fails("reinstall", "Plack");
    like $app->stderr, qr/not found in cpanfile.snapshot/;
};

done_testing;
