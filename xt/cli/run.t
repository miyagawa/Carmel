use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest 'carmel run' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'Class::Tiny', '== 1.006';
EOF

    $app->run_ok("install");
    $app->run_ok("run", "perl", "-e", "use Class::Tiny");

    $app->run_fails("run", "perl", "-e", "use Class::Tiny 1.008");
    $app->run_fails("run", "perl", "-e", "use Module::CPANfile");

};

done_testing;
