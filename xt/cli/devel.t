use strict;
use Test::More skip_all => 'Test::Harness munges PERL5LIB';
use xt::CLI;

subtest 'carmel install' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'Try::Tiny';
EOF

    $app->run("install");
    $app->run("exec", "perl", "-MDevel::Carmel", "-e", "use Moose; warn \$INC{'Moose.pm'}");

    like $app->stderr, qr/Can't locate Moose.pm/;
};

done_testing;
