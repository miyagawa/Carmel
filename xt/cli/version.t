use strict;
use Test::More;
use xt::CLI;

subtest 'carmel --version' => sub {
    my $app = cli();

    $app->run("version");
    like $app->stdout, qr/Carmel version v[\d\.]+$/m;
};

done_testing;
