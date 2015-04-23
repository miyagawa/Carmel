use strict;
use Test::More;
use xt::CLI;

subtest 'carmel index' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'Path::Tiny';
EOF

    $app->run("install");
    $app->run("index");
    like $app->stdout, qr/^Written-By: *Carmel v.*$/m or diag $app->stderr;
    like $app->stdout, qr/^Path::Tiny *\S+ *.*\/Path-Tiny-.*\.tar\.gz$/m or diag $app->stderr;
};

done_testing;
