use strict;
use Test::More;
use xt::CLI;

subtest 'carmel exec overwrites ENV' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'Mojolicious';
EOF

    $app->run("exec", "which", "mojo");
    like$app->stdout, qr!Mojolicious-.*/blib/script/mojo!;
};

done_testing;
