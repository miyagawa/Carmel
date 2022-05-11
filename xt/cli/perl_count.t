use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest 'install count is wrong if "perl" is in the cpanfile' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'perl', '5.10.1';
requires 'Path::Tiny';
EOF


    $app->run_ok("install");
    unlike $app->stderr, qr/Can't find perl on CPAN/;
    like $app->stdout, qr/1 cpanfile dependencies/ or diag $app->stderr;
};

done_testing;
