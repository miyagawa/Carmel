# https://github.com/miyagawa/Carmel/issues/89
use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest 'Time::Piece::MySQL' => sub {
    my $app = cli();

    $app->write_cpanfile(<<'EOF');
requires 'Time::Piece::MySQL';
requires 'Test::MockTime';
EOF

    $app->run_ok('install');
};

done_testing;

