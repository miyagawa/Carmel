use strict;
use Test::More;
use lib ".";
use xt::CLI;

plan skip_all => "only test with TEST_CLEAN" unless $ENV{TEST_CLEAN};

subtest 'carmel install from snapshot' => sub {
    my $app = cli();

    for my $spec ('0', '1.007', '==1.007') {
        $app->write_cpanfile(<<EOF);
requires 'Class::Tiny', '$spec';
EOF

        $app->run_ok("install");
        $app->dir->child(".carmel")->remove_tree({ safe => 0 });

        $app->run_ok("install");
    }
};

done_testing;
