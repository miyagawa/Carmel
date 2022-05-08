use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest 'prove -l' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'Test::More';
EOF

    $app->path("lib/MyApp.pm")->spew(<<EOF);
package MyApp;
1;
EOF

    $app->path("t/basic.t")->spew(<<EOF);
use strict;
use MyApp;
use Test::More tests => 1;

ok 1, \$INC{"MyApp.pm"};
EOF

    $app->run_ok("install");
    $app->run_ok("exec", "prove", "-l", "t");

    like $app->stdout, qr/All tests successful/ or diag $app->stderr;
};

done_testing;
