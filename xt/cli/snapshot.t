use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest 'carmel install produces snapshot' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'Class::Tiny', '== 1.003';
EOF

    $app->run("install");

    ok -e $app->dir->child("cpanfile.snapshot");

    like( ($app->snapshot->distributions)[0]->name, qr/Class-Tiny-1\.003/ );

    $app->write_cpanfile(<<EOF);
requires 'Class::Tiny';
EOF

    $app->run("install");
    like $app->stdout, qr/Using Class::Tiny \(1\.003\)/, "Use the version in snapshot";

    my $artifact = $app->repo->find('Class::Tiny', '== 1.003');
    $artifact->path->remove_tree({ safe => 0 });

    $app->run("install");
    like $app->stdout, qr/installed Class-Tiny-1\.003/;

    $app->write_cpanfile(<<EOF);
requires 'Class::Tiny', '1.004';
EOF

    $app->run("install");
    $app->run("list");
    like $app->stdout, qr/Class::Tiny \(1\.004\)/, "Bump the version";

    like( ($app->snapshot->distributions)[0]->name, qr/Class-Tiny-1\.004/ );

    $app->write_cpanfile(<<EOF);
requires 'Hash::MultiValue';
EOF

    $app->run("install");

    like( ($app->snapshot->distributions)[0]->name, qr/Hash-MultiValue-/,
          "snapshot does not have modules not used anymore" );
};

subtest 'backpan snapshot modules' => sub {
    my $app = cli();

    $app->write_file('cpanfile.snapshot', <<EOF);
# carton snapshot format: version 1.0
DISTRIBUTIONS
  Carp-1.36
    pathname: R/RJ/RJBS/Carp-1.36.tar.gz
    provides:
      Carp 1.36
      Carp::Heavy 1.36
    requirements:
      Config 0
      Exporter 0
      ExtUtils::MakeMaker 0
      IPC::Open3 1.0103
      Test::More 0
      overload 0
      parent 0
      strict 0
      warnings 0
EOF

    $app->write_cpanfile(<<EOF);
requires 'Carp';
EOF

    $app->run("install");

    unlike $app->stderr, qr/Can't find an artifact for Carp/;
};


done_testing;
