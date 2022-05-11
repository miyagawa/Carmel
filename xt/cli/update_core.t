use strict;
use Test::More;
use lib ".";
use xt::CLI;

use Module::CoreList;

plan skip_all => "HTTP::Tiny is not in core or is possibly the latest"
  if ($Module::CoreList::version{$]}{"HTTP::Tiny"} || 999) > 0.080;

subtest 'carmel update core-module with empty cpanfile' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'HTTP::Tiny';
EOF

    $app->run_ok("install");
    $app->run_ok("list");
    is $app->stdout, '';

    $app->run_ok("update", "HTTP::Tiny");
    $app->run_ok("list", "HTTP::Tiny");
    like $app->stdout, qr/HTTP::Tiny \(/;
};

subtest 'carmel update with empty cpanfile' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'HTTP::Tiny';
EOF

    $app->run_ok("install");
    $app->run_ok("list");

    $app->run_ok("update");
    $app->run_ok("list", "HTTP::Tiny");
    like $app->stdout, qr/HTTP::Tiny \(/;
};


done_testing;
