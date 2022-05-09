use strict;
use Test::More;
use lib ".";
use xt::CLI;

use Module::CoreList;

plan skip_all => "perl $] has HTTP::Tiny 0.056"
  if $Module::CoreList::version{$]}{"HTTP::Tiny"} eq "0.056";

subtest 'core modules in snapshots' => sub {
    my $app = cli();

    $app->write_file('cpanfile.snapshot', <<EOF);
# carton snapshot format: version 1.0
DISTRIBUTIONS
  HTTP-Tiny-0.056
    pathname: D/DA/DAGOLDEN/HTTP-Tiny-0.056.tar.gz
    provides:
      HTTP::Tiny 0.056
    requirements:
      Carp 0
      Fcntl 0
      IO::Socket 0
      MIME::Base64 0
      Socket 0
      Time::Local 0
      bytes 0
      perl 5.006
      strict 0
      warnings 0
EOF

    $app->write_cpanfile(<<EOF);
requires 'HTTP::Tinyish';
EOF

    # pull the artifact
    $app->run_ok('inject', 'HTTP::Tiny@0.056');

    $app->run_ok("install");
    unlike $app->stderr, qr/Can't find an artifact for HTTP::Tiny/;

    $app->run_ok("list");
    like $app->stdout, qr/HTTP::Tiny \(0\.056\)/;

 SKIP: {
        skip "HTTP::Tiny core verison < 0.056", 4
          if $Module::CoreList::version{$]}{"HTTP::Tiny"} < 0.056;
        skip "only runs under TEST_CLEAN", 4
          unless $ENV{TEST_CLEAN};

        # remove the build artifact
        $app->dir->child('.carmel/builds/HTTP-Tiny-0.056')->remove_tree({ safe => 0 });

        # #47 now, 0.056 artifact is removed, but is pinned in the snapshot
        # Carmel should now upgrade it to the core version and remove it from the snapshot
        $app->run_ok("install");
        unlike $app->stderr, qr/Can't find an artifact for HTTP::Tiny/;

        $app->run_ok("list");
        unlike $app->stdout, qr/HTTP::Tiny \(0\.056/;
    }
};

done_testing;
