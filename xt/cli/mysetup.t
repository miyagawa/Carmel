use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest 'broken MySetup.pm' => sub {
    my $app = cli();

    $app->write_cpanfile("");
    $app->run_ok("install");

    # seems prove -l doesn't propagate for perl < 5.20 and you get "Can't locate Carmel/Setup.pm"
    if (eval 'use v5.20; 1') {
        $app->run_fails("exec", "prove", "-t", "$TestCLI::DEV/xt/cli/taint.pl");
        like $app->stderr, qr/Insecure dependency/;
    }
    
    $app->dir->child(".carmel/MySetup.pm")->spew("die");
    $app->run_fails("exec", "perl", "-e1");
    unlike $app->stderr, qr/undefined value as an ARRAY/;
};

done_testing;

