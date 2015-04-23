use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest 'carmel exec overwrites ENV' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'Mojolicious';
EOF

    $app->run("install");
    $app->run("exec", "which", "mojo");
    like$app->stdout, qr!Mojolicious-.*/blib/script/mojo! or diag $app->stderr;
};

done_testing;
