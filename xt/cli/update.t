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

    like( ($app->snapshot->distributions)[0]->name, qr/Class-Tiny-1\.00[6-9]/ );

    $app->run("list");
    like $app->stdout, qr/Class::Tiny \(1\.00[6-9]\)/, "Bump the version";
};

subtest 'carmel update module' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'Class::Tiny', '== 1.003';
requires 'Try::Tiny', '== 0.28';
EOF

    $app->run("install");
    like( $app->snapshot->find("Class::Tiny")->name, qr/Class-Tiny-1\.003/ );

    $app->write_cpanfile(<<EOF);
requires 'Class::Tiny', '1.003';
requires 'Try::Tiny', '0.28';
EOF

    $app->run("install");
    like $app->stdout, qr/Using Class::Tiny \(1\.003\)/, "Use the version in snapshot";
    like $app->stdout, qr/Using Try::Tiny \(0\.28\)/, "Use the version in snapshot";

    $app->run("update", "Class::Tiny");
    like $app->stdout, qr/Using Try::Tiny \(0\.28\)/, "Try::Tiny is not affected";
    like( $app->snapshot->find("Class::Tiny")->name, qr/Class-Tiny-1\.00[6-9]/ );
    like( $app->snapshot->find("Try::Tiny")->name, qr/Try-Tiny-0\.28/ );

    $app->run("list");
    like $app->stdout, qr/Class::Tiny \(1\.00[6-9]\)/, "Bump the version";
    like $app->stdout, qr/Try::Tiny \(0\.28\)/, "Bump the version";

    $app->run("update", "Try::Tiny");
    like( $app->snapshot->find("Class::Tiny")->name, qr/Class-Tiny-1\.00[6-9]/ );
    like( $app->snapshot->find("Try::Tiny")->name, qr/Try-Tiny-/ );
    unlike( $app->snapshot->find("Try::Tiny")->name, qr/Try-Tiny-0\.28/ );

    $app->run("update", "HTTP::Tiny");
    like $app->stderr, qr/HTTP::Tiny is not found in the snapshot/;
};

done_testing;
