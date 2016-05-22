use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest 'depends on submodules' => sub {
    my $app = cli();

    # HTTP::Async requires HTTP::Server::Simple::CGI

    $app->write_cpanfile(<<EOF);
requires 'HTTP::Server::Simple', '== 0.50';
requires 'Net::Server::SS::PreFork';
EOF

    $app->run("install");
    $app->dir->child("cpanfile.snapshot")->remove;

    # because it's random, run it twice
 TODO: {
        local $TODO = "Artifact provides are not compared with root cpanfile requirement";
        for (1..2) {
            $app->run("install");
            like $app->stdout, qr/Using HTTP::Server::Simple \(0\.50\)/;
            unlike $app->stdout, qr/Using HTTP::Server::Simple \(0\.51\)/;
        }
    }
};

done_testing;
