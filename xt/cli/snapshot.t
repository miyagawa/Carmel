use strict;
use Test::More;
use lib ".";
use xt::CLI;

use Carton::Snapshot;

subtest 'carmel install produces snapshot' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'Class::Tiny', '== 1.003';
EOF

    $app->run("install");

    ok -e $app->dir->child("cpanfile.snapshot");

    my $snapshot = Carton::Snapshot->new(path => $app->dir->child("cpanfile.snapshot"));
    $snapshot->load;

    like( ($snapshot->distributions)[0]->name, qr/Class-Tiny-1\.003/ );

    $app->write_cpanfile(<<EOF);
requires 'Class::Tiny';
EOF

    $app->run("install");
    like $app->stdout, qr/Using Class::Tiny \(1\.003\)/, "Use the version in snapshot";

    $app->write_cpanfile(<<EOF);
requires 'Class::Tiny', '1.004';
EOF

    $app->run("install");
    $app->run("list");
    like $app->stdout, qr/Class::Tiny \(1\.004\)/, "Do not use the version in snapshot";

    $snapshot = Carton::Snapshot->new(path => $app->dir->child("cpanfile.snapshot"));
    $snapshot->load;

    like( ($snapshot->distributions)[0]->name, qr/Class-Tiny-1\.004/ );
};

done_testing;
