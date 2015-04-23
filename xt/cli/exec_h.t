use strict;
use Test::More;
use xt::CLI;

subtest 'carmel exec cmd -h' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'Carton';
EOF

    $app->run("install");
    $app->run("exec", "carton", "-h");

    like $app->stdout, qr/carton install/ or diag $app->stderr;
    unlike $app->stdout, qr/Carmel/;
};

done_testing;
