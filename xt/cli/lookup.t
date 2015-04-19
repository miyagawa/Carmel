use strict;
use Test::More;
use xt::CLI;

subtest 'carmel install with v-strings' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'CPAN::Test::Dummy::Perl5::VersionQV';
EOF

    $app->run("install");
    like $app->stdout, qr/Successfully installed CPAN-Test-Dummy-Perl5/;
    is $app->stderr, '';

    $app->run("list");
    is $app->stdout, "CPAN::Test::Dummy::Perl5::VersionQV (0.001000)\n";
};

done_testing;
