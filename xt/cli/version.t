use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest 'carmel version' => sub {
    my $app = cli();

    $app->run_ok("version");
    like $app->stdout, qr/Carmel version v[\d\.]+$/m or diag $app->stderr;
};

done_testing;
