use strict;
use Test::More;
use xt::CLI;

subtest 'carmel install with cpanfile requirements count' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'HTTP::Server::Simple';
EOF

    $app->run("install");
    like $app->stdout, qr/Complete! 1 cpanfile dependencies\./;
};

done_testing;
