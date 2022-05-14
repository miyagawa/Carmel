use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest 'carmel index' => sub {
    my $app = cli();

    $app->run_ok("inject", "Class::Tiny");
    like $app->stdout, qr/installed Class-Tiny/;

    $app->run_ok("inject", 'Class::Tiny@1.006');
    like $app->stdout, qr/installed Class-Tiny-1\.006/;

    $app->run_fails("inject", "nonexistent::module");
    like $app->stderr, qr/Couldn't install module.*nonexistent::module/;

    $app->run_fails("inject", 'Plack@999');
    like $app->stderr, qr/Couldn't install module.*Plack/;
};

done_testing;
