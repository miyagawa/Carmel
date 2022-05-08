use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest 'conflicts in cpanfile and sub-dependencies' => sub {
    my $app = cli();

    # FIXME: should install it first so that merge happens inside Carmel
    # FIXME: otherwise cpanm will give the errors from CMR
    $app->write_cpanfile(<<EOF);
requires 'Path::Tiny';
EOF
    $app->run("install");

    $app->write_cpanfile(<<EOF);
requires 'Path::Tiny';
requires 'Digest::SHA', '< 5'; # Path::Tiny requires 5.45
EOF

    $app->run_fails("install");
    like $app->stderr, qr/conflicting requirement for Digest::SHA: '< 5' <=> '5\.\d+' \(Path-Tiny-/;
};

done_testing;
