use strict;
use Test::More;
use xt::CLI;

subtest 'distribution with ShareDir' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'Mojolicious::Plugin::Humane';
EOF

    $app->run("install");
    $app->run("exec", "perl", "-e", "use File::ShareDir; print File::ShareDir::dist_dir('Mojolicious-Plugin-Humane')");

    like $app->stdout, qr!builds/Mojolicious-Plugin-Humane-.*/blib/lib/auto/share/dist/Mojolicious-Plugin-Humane!;
};

done_testing;