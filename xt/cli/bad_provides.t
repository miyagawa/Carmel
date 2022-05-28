use strict;
use Test::More;
use lib ".";
use xt::CLI;

# https://github.com/miyagawa/Carmel/issues/89
subtest 'Time::Piece::MySQL' => sub {
    my $app = cli();

    $app->write_cpanfile(<<'EOF');
requires 'Time::Piece::MySQL';
requires 'Test::MockTime';
EOF

    $app->run_ok('install');
};

# https://github.com/miyagawa/Carmel/issues/71
subtest 'Proc::PID::File::Fcntl' => sub {
    my $app = cli();

    $app->write_cpanfile(<<'EOF');
requires 'Proc::PID::File::Fcntl';
EOF

    $app->run_ok('install');
};

done_testing;
