use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest 'carmel update with empty cpanfile' => sub {
    my $app = cli();

    $app->write_cpanfile('');

    $app->run_ok("install");
    $app->run_ok("update");
};

done_testing;
