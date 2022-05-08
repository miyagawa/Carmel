use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest 'carmel install with v-strings' => sub {
    my $app = cli(clean => 1);

    $app->write_cpanfile(<<EOF);
requires 'CPAN::Test::Dummy::Perl5::VersionQV', 'v0.1.0';
EOF

    $app->run_ok("install");
    like $app->stdout, qr/Successfully installed CPAN-Test-Dummy-Perl5/ or diag $app->stderr;
    is $app->stderr, '';

    $app->run_ok("list");
    like $app->stdout, qr/CPAN::Test::Dummy::Perl5::VersionQV \(0\.001000\)/;

    $app->write_cpanfile(<<EOF);
requires 'CPAN::Test::Dummy::Perl5::VersionQV', '== v0.1.0';
EOF

    $app->run_ok("list");
    like $app->stdout, qr/CPAN::Test::Dummy::Perl5::VersionQV \(0\.001000\)/;
};

done_testing;
