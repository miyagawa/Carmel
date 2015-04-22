use strict;
use Test::More;
use xt::CLI;

subtest 'Carmel::Runtime->require_all' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'JSON';
EOF

    $app->run("install");
    $app->run("exec", "perl", "-e", 'Carmel::Runtime->require_all; print $INC{"JSON.pm"}');

    like $app->stdout, qr!/JSON-.*/blib/lib/JSON\.pm!;
};

done_testing;
