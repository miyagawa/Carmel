use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest 'carmel install produces snapshot' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'Class::Tiny', '== 1.003';
EOF

    $app->run_ok("install");

    ok -e $app->dir->child("cpanfile.snapshot");

    like( ($app->snapshot->distributions)[0]->name, qr/Class-Tiny-1\.003/ );

    $app->write_cpanfile(<<EOF);
requires 'Class::Tiny';
EOF

    $app->run_ok("install");
    like $app->stdout, qr/Using Class::Tiny \(1\.003\)/, "Use the version in snapshot";

    my $artifact = $app->repo->find('Class::Tiny', '== 1.003');
    $artifact->path->remove_tree({ safe => 0 });

    $app->run_ok("install");
    like $app->stdout, qr/installed Class-Tiny-1\.003/;

    $app->write_cpanfile(<<EOF);
requires 'Class::Tiny', '== 1.004';
EOF

    $app->run_ok("install");
    $app->run_ok("list");
    like $app->stdout, qr/Class::Tiny \(1\.004\)/, "Bump the version";

    like( ($app->snapshot->distributions)[0]->name, qr/Class-Tiny-1\.004/ );

    $app->write_cpanfile(<<EOF);
requires 'Hash::MultiValue';
EOF

    $app->run_ok("install");

    like( ($app->snapshot->distributions)[0]->name, qr/Hash-MultiValue-/,
          "snapshot does not have modules not used anymore" );
};

subtest 'backpan snapshot modules' => sub {
    my $app = cli();

    $app->write_file('cpanfile.snapshot', <<EOF);
# carton snapshot format: version 1.0
DISTRIBUTIONS
  Parse-PMFile-0.37
    pathname: I/IS/ISHIGAKI/Parse-PMFile-0.37.tar.gz
    provides:
      Parse::PMFile: 0.37
EOF

    $app->write_cpanfile(<<EOF);
requires 'Parse::PMFile';
EOF

    $app->run_ok("install");

    unlike $app->stderr, qr/Can't find an artifact for Parse::PMFile/;
};

subtest 'carmel install on the first run with empty build cache' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'Try::Tiny', '== 0.06';
EOF

    $app->run_ok("install");
    like( ($app->snapshot->distributions)[0]->name, qr/Try-Tiny-0\.06/ );

    for my $v (['Try::Tiny', '0.06'], ['Test::Fatal', '0.016']) {
        my $artifact = $app->repo->find($v->[0], "== $v->[1]");
        $artifact->path->remove_tree({ safe => 0 }) if $artifact;
    }

    # This used to be failing 50% of the time but carmel should auto retry install
    $app->write_cpanfile(<<EOF);
requires 'Try::Tiny';
requires 'Test::Fatal', '== 0.016'; # requires Try::Tiny 0.07
EOF
    $app->run("install");
    unlike $app->stderr, qr/Can't merge requirement/;
    like $app->stdout, qr/Successfully installed Try-Tiny-/;

    like $app->stdout, qr/Successfully installed Test-Fatal-/ or diag $app->stderr;
        
    my($dist) = grep { $_->name =~ /Try-Tiny/ } $app->snapshot->distributions;
    if ($dist && $dist->name =~ /^Try-Tiny-(.*)/) {
        cmp_ok $1, '>', '0.07';
    } else {
        fail 'Try-Tiny not found in the snapshot';
    }
};

done_testing;
