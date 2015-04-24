use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest 'carmel version' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'Digest::SHA1';
EOF

    $app->run("install");
    $app->run("exec", "perl", "-e", "use Digest::SHA1; print 'ok'");
    
    like $app->stdout, qr/ok/ or diag $app->stderr;
};

done_testing;
