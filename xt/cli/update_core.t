use strict;
use Test::More;
use lib ".";
use xt::CLI;

use Module::CoreList;

plan skip_all => "HTTP::Tiny is not in core or is possibly the latest"
  if ($Module::CoreList::version{$]}{"HTTP::Tiny"} || 999) > 0.080;

subtest 'carmel install now installs core module if there is a new version' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'HTTP::Tiny';
EOF

    $app->run_ok("install");
    $app->run_ok("list");
    like $app->stdout, qr/HTTP::Tiny \(/;
};

subtest 'carmel update updates core modules' => sub {
    my $app = cli();

    # this creates an empty snapshot
    $app->write_cpanfile('');
    $app->run_ok("install");

    # now add HTTP::Tiny, it will use the core version
    # BUG: this is actually an inconsistent behavior from first-run
    $app->write_cpanfile(<<EOF);
requires 'HTTP::Tiny';
EOF

    $app->run_ok("install");
    $app->run_ok("list");
    unlike $app->stdout, qr/HTTP::Tiny \(/;

    # now, carmel update will update it because it's in cpanfile
    $app->run_ok("update");
    $app->run_ok("list", "HTTP::Tiny");
    like $app->stdout, qr/HTTP::Tiny \(/;
};

done_testing;
