use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest 'distribution with ShareDir' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'Plack';
EOF

    $app->run("install");
    warn $app->stderr;
    $app->run("exec", "perl", "-e", "use File::ShareDir; print File::ShareDir::dist_dir('Plack')");

    like $app->stdout, qr!builds/Plack-.*/blib/lib/auto/share/dist/Plack! or diag $app->stderr;
};

done_testing;
