use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest 'carmel install with cpanfile requirements count' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'HTTP::Server::Simple';
EOF

    $app->run_ok("install");
    like $app->stdout, qr/Complete! 1 cpanfile dependencies\./ or diag $app->stderr;
};

done_testing;
