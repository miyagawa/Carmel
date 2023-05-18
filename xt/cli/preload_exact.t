use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest 'Carmel::Preload' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'JSON::MaybeXS', '== 1.001';
EOF

    $app->run_ok("install");
    $app->run_ok("exec", "perl", "-e", 'use Carmel::Preload; print $INC{"JSON/MaybeXS.pm"}');

    like $app->stdout, qr!/JSON-.*/blib/lib/JSON/MaybeXS\.pm! or diag $app->stderr;
};

done_testing;
