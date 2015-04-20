use strict;
use Test::More;
use xt::CLI;

subtest 'carmel install with v-strings' => sub {
    my $app = cli(clean => 1);

    $app->write_cpanfile(<<EOF);
requires 'CPAN::Test::Dummy::Perl5::VersionQV', 'v0.1.0';
EOF

    $app->run("install");
    like $app->stdout, qr/Successfully installed CPAN-Test-Dummy-Perl5/;
    is $app->stderr, '';

    $app->run("list");
    is $app->stdout, "CPAN::Test::Dummy::Perl5::VersionQV (0.001000)\n";

    $app->write_cpanfile(<<EOF);
requires 'CPAN::Test::Dummy::Perl5::VersionQV', '== v0.1.0';
EOF

    $app->run("list");
    is $app->stdout, "CPAN::Test::Dummy::Perl5::VersionQV (0.001000)\n";
};

done_testing;
