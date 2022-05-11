use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest 'carmel install picks up the right version' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'CPAN::Test::Dummy::Perl5::VersionBump', '== 0.01';
EOF

    $app->run_ok("install");

    # blow away the artifact
    my $artifact = $app->repo->find_match(
        'CPAN::Test::Dummy::Perl5::VersionBump',
        sub { $_[0]->version eq '0.01' },
    );
    $artifact->path->remove_tree({ safe => 0 });

    # depend on submodule with version: undef
    $app->write_cpanfile(<<EOF);
requires 'CPAN::Test::Dummy::Perl5::VersionBump::Undef';
EOF

    $app->run_ok("install");

    unlike $app->stderr, qr/Can't find an artifact for CPAN::Test::Dummy::Perl5::VersionBump::Undef/;
    is( ($app->snapshot->distributions)[0]->name, "CPAN-Test-Dummy-Perl5-VersionBump-0.01",
        "snapshot version is restored" );
};

done_testing;
