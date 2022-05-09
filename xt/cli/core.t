use strict;
use Test::More;
use lib ".";
use xt::CLI;

use Module::CoreList;

plan skip_all => "perl $] has HTTP::Tiny eq 0.056"
  if $Module::CoreList::version{$]}{"HTTP::Tiny"} eq "0.056";

for my $version (qw( 0.056 0.078 )) {
    for my $clean (0, 1) {
        subtest "core modules in snapshots (HTTP::Tiny $version) clean=$clean" => sub { test_it($version, $clean) };
    }
}

subtest "core modules can still be pinned" => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'HTTP::Tiny', '== 0.056';
EOF
    $app->run_ok("install");
    like $app->stdout, qr/HTTP::Tiny \(0\.056\)/;
};

sub test_it {
    my($version, $clean) = @_;

    my $app = cli();

    $app->write_file('cpanfile.snapshot', <<EOF);
# carton snapshot format: version 1.0
DISTRIBUTIONS
  HTTP-Tiny-$version
    pathname: D/DA/DAGOLDEN/HTTP-Tiny-$version.tar.gz
    provides:
      HTTP::Tiny $version
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

    my $is_new = $version > $Module::CoreList::version{$]}{"HTTP::Tiny"};

    unless ($clean) {
        # pull the artifact
        $app->run_ok('inject', "HTTP::Tiny\@$version");
    }

    $app->run_ok("install");
    unlike $app->stderr, qr/Can't find an artifact for HTTP::Tiny/;

    $app->run_ok("list");
    if ($is_new) {
        like $app->stdout, qr/HTTP::Tiny \(\Q$version\E\)/;
    } else {
        unlike $app->stdout, qr/HTTP::Tiny /;
    }
};

done_testing;
