use 5.008001;
use strict;
use warnings;
use Test::More 0.96;
use Test::FailWarnings;
use Test::Deep '!blessed';
use Test::Fatal;

use Cwd qw/getcwd/;
use File::Temp;
use File::Spec::Functions qw/catfile/;

use lib 't/lib';
use CommonTests;

my $cwd         = getcwd;
my $test_mirror = "file:///$cwd/t/CPAN";
my $cache       = File::Temp->newdir;
my $mailrc      = "01mailrc.txt";
my $packages    = "02packages.details.txt";

sub new_mirror_index {
    my $index = new_ok(
        'CPAN::Common::Index::Mirror' => [ { cache => $cache, mirror => $test_mirror } ],
        "new with cache and mirror"
    );
}

require_ok("CPAN::Common::Index::Mirror");

subtest "constructor tests" => sub {
    # no arguments, all defaults
    new_ok(
        'CPAN::Common::Index::Mirror' => [],
        "new with no args"
    );

    # cache specified
    new_ok(
        'CPAN::Common::Index::Mirror' => [ { cache => $cache } ],
        "new with cache"
    );

    # mirror specified
    new_ok(
        'CPAN::Common::Index::Mirror' => [ { mirror => $test_mirror } ],
        "new with mirror"
    );

    # both specified
    new_mirror_index;

};

subtest 'refresh and unpack index files' => sub {
    my $index = new_mirror_index;

    for my $file ( $mailrc, "$mailrc.gz", $packages, "$packages.gz" ) {
        ok( !-e catfile( $cache, $file ), "$file not there" );
    }
    ok( $index->refresh_index, "refreshed index" );
    for my $file ( $mailrc, "$mailrc.gz", $packages, "$packages.gz" ) {
        ok( -e catfile( $cache, $file ), "$file is there" );
    }
};

# XXX test that files in cache aren't overwritten?

subtest 'check index age' => sub {
    my $index   = new_mirror_index;
    my $package = $index->cached_package;
    ok( -f $package, "got the package file" );
    my $expected_age = ( stat($package) )[9];
    is( $index->index_age, $expected_age, "index_age() is correct" );
};

subtest 'find package' => sub {
    my $index = new_mirror_index;
    test_find_package($index);
};

subtest 'search package' => sub {
    my $index = new_mirror_index;
    test_search_package($index);
};

subtest 'find author' => sub {
    my $index = new_mirror_index;
    test_find_author($index);
};

subtest 'search author' => sub {
    my $index = new_mirror_index;
    test_search_author($index);
};

done_testing;
# COPYRIGHT
# vim: ts=4 sts=4 sw=4 et:
