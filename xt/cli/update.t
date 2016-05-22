use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest 'carmel update' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'Class::Tiny', '== 1.003';
EOF

    $app->run("install");
    like( ($app->snapshot->distributions)[0]->name, qr/Class-Tiny-1\.003/ );

    $app->write_cpanfile(<<EOF);
requires 'Class::Tiny';
EOF

    $app->run("install");
    like $app->stdout, qr/Using Class::Tiny \(1\.003\)/, "Use the version in snapshot";

    $app->run("update");

    like( ($app->snapshot->distributions)[0]->name, qr/Class-Tiny-1\.004/ );

    $app->run("list");
    like $app->stdout, qr/Class::Tiny \(1\.004\)/, "Bump the version";
};

done_testing;
