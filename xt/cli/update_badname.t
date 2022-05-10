use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest 'carmel update from main module with version = 0/undef' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'CPAN::Test::Dummy::Perl5::MakeMakerBadName', '== 0.02';
EOF

    $app->run_ok("install");
    $app->run_ok("update");
    like $app->stderr, qr/Can't find CPAN::.* on CPAN/;
};

done_testing;
