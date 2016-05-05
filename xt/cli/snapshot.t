use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest 'carmel install produces snapshot' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'Class::Tiny';
EOF

    $app->run("install");

    ok -e $app->dir->child("cpanfile.snapshot");

    require Carton::Snapshot;
    my $snapshot = Carton::Snapshot->new(path => $app->dir->child("cpanfile.snapshot"));
    $snapshot->load;

    like( ($snapshot->distributions)[0]->name, qr/Class-Tiny/ );
};

done_testing;
