use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest 'distribution with ShareDir' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'File::ShareDir';
EOF

    $app->run_ok("install");
    $app->run_ok("exec", "perl", "-e", "use File::ShareDir; print File::ShareDir::dist_dir('File-ShareDir')");

    like $app->stdout, qr!builds/File-ShareDir-.*/blib/lib/auto/share/dist/File-ShareDir! or diag $app->stderr;
};

done_testing;
