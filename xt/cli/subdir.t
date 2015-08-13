use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest 'carmel command with sub-dirs' => sub {
    my $app = cli();

    $app->dir->child('x')->mkpath;

    $app->write_cpanfile(<<EOF);
requires 'HTTP::Server::Simple';
EOF

    $app->run_in_dir('x', "install");
    like $app->stdout, qr/Complete! 1 cpanfile dependencies\./ or diag $app->stderr;

    $app->run_in_dir('x', "list");
    like $app->stdout, qr/HTTP::Server::Simple/;

    $app->run_in_dir('x', 'exec', 'perl', '-V');
    like $app->stdout, qr/HTTP-Server-Simple-/;
};

done_testing;
