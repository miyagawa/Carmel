use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest 'depends on submodules with version undef' => sub {
    my $app = cli();

    # Dep::UndefModule depend on VersionBump::Undef

    $app->write_cpanfile(<<EOF);
requires 'CPAN::Test::Dummy::Perl5::VersionBump', '== 0.01';
requires 'CPAN::Test::Dummy::Perl5::Deps::UndefModule';
EOF

    $app->run_ok("install");
    $app->dir->child("cpanfile.snapshot")->remove;

    # because it could be random, run it twice
    for (1..2) {
        $app->run_ok("install");
        like $app->stdout, qr/Using CPAN::Test::Dummy::Perl5::Deps::UndefModule/;
        like $app->stdout, qr/Using CPAN::Test::Dummy::Perl5::VersionBump \(0\.01\)/;
        unlike $app->stdout, qr/Using CPAN::Test::Dummy::Perl5::VersionBump \(0\.02\)/;
    }
};

done_testing;
