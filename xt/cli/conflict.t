use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest 'conflicts in cpanfile and sub-dependencies' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'Path::Tiny';
requires 'Digest::SHA', '< 5'; # Path::Tiny requires 5.45
EOF

    $app->run_fails("install");
    like $app->stderr, qr/conflicting requirement for Digest::SHA: '< 5' <=> '5\.\d+' \(Path-Tiny-/;
};

done_testing;
