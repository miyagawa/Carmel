use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest 'carmel install' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'Try::Tiny';
EOF

    $app->run_ok("install");
    $app->run_fails("exec", "perl", "-e", "use Moose; warn \$INC{'Moose.pm'}");
    like $app->stderr, qr/Can't locate Moose.pm/;
};

done_testing;
