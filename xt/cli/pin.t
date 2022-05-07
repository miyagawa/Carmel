use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest 'carmel pin' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'Class::Tiny';
EOF

    $app->run("install");

    like( $app->snapshot->find("Class::Tiny")->name, qr/Class-Tiny-/ );
    unlike( $app->snapshot->find("Class::Tiny")->name, qr/Class-Tiny-1\.003/ );

    $app->run("pin", 'Class::Tiny@1.003');

    $app->run("list");
    like $app->stdout, qr/Class::Tiny \(1\.003\)/, "Use the version specified via pin";

    like( $app->snapshot->find("Class::Tiny")->name, qr/Class-Tiny-1\.003/ );
};

done_testing;
