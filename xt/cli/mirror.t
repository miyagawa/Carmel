use strict;
use Test::More;
use lib ".";
use xt::CLI;

plan skip_all => "only test with TEST_CLEAN" unless $ENV{TEST_CLEAN};

subtest 'install from mirror' => sub {
    my $app = cli();

    my $cwd = Path::Tiny->cwd;

    $app->write_cpanfile(<<EOF);
mirror 'file://$cwd/xt/mirror';
requires 'HTTP::Tinyish';
EOF

    $app->run("install");
    like $app->stdout, qr/Successfully installed HTTP-Tiny-0\.056/;

    $app->write_cpanfile(<<EOF);
mirror 'file://$cwd/xt/mirror';
requires 'Class::Tiny';
EOF

    $app->run("install");
    like $app->stderr, qr/Couldn't find module .* Class::Tiny/;
};    

done_testing;
