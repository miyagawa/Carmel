use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest "core moduless with option pins" => sub { test_it() };
subtest "core moduless with option pins + mirror" => sub { test_it(1) };

sub test_it {
    my $mirror = shift;
        
    my $app = cli();

    $app->write_cpanfile(<<EOF);
@{[ $mirror ? "mirror 'https://cpan.metacpan.org/';" : "" ]}
requires 'HTTP::Tiny', 0.078,
  dist => 'DAGOLDEN/HTTP-Tiny-0.078.tar.gz';
EOF

    # this pulls the latest version from CPAN
    $app->run_ok("inject", "HTTP::Tiny");

    $app->run_ok("install");
    like $app->stdout, qr/HTTP::Tiny \(0\.078\)/;
    
    $app->run_ok("update");
    unlike $app->stderr, qr/failed/;
    like $app->stdout, qr/HTTP::Tiny \(0\.078\)/;

    $app->run_ok("reinstall");
    unlike $app->stderr, qr/failed/;
    like $app->stdout, qr/HTTP::Tiny \(0\.078\)/;

};

done_testing;
