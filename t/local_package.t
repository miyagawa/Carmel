use 5.008001;
use strict;
use warnings;
use Test::More 0.96;
use Test::FailWarnings;
use Test::Deep '!blessed';
use Test::Fatal;

use Cwd qw/getcwd/;
use Path::Tiny;

use lib 't/lib';
use CommonTests;

my $cwd          = getcwd;
my $cache        = Path::Tiny->tempdir;
my $localgz      = path(qw/t CUSTOM mypackages.gz/);
my $local        = path(qw/t CUSTOM uncompressed/);
my $packages     = "mypackages";
my $uncompressed = "uncompressed";

sub new_local_index {
    my $index = new_ok(
        'CPAN::Common::Index::LocalPackage' => [ { cache => $cache, source => $localgz } ],
        "new with cache and local gz"
    );
}

sub new_uncompressed_local_index {
    my $index = new_ok(
        'CPAN::Common::Index::LocalPackage' => [ { cache => $cache, source => $local } ],
        "new with cache and local uncompressed"
    );
}

require_ok("CPAN::Common::Index::LocalPackage");

subtest "constructor tests" => sub {
    # no arguments, all defaults
    like(
        exception { CPAN::Common::Index::LocalPackage->new() },
        qr/'source' parameter must be provided/,
        "new with no args dies because source is required"
    );

    # missing file
    like(
        exception {
            CPAN::Common::Index::LocalPackage->new( { source => 'LDJFLKDJLJDLKD' } );
        },
        qr/index file .* does not exist/,
        "new with invalid source dies"
    );

    # source specified
    new_ok(
        'CPAN::Common::Index::LocalPackage' => [ { source => $localgz } ],
        "new with source"
    );

    # both specified
    new_local_index;

    # uncompressed variant
    new_uncompressed_local_index;
};

subtest 'refresh and unpack index files' => sub {
    my $index = new_local_index;

    ok( !path( $cache, $packages )->exists, "$packages not in cache" );

    ok( $index->refresh_index, "refreshed index" );

    ok( path( $cache, $packages )->exists, "$packages in cache" );
};

subtest 'refresh and unpack uncompressed index files' => sub {
    my $index = new_uncompressed_local_index;

    ok( !path( $cache, $uncompressed )->exists, "$uncompressed not in cache" );

    ok( $index->refresh_index, "refreshed index" );

    ok( path( $cache, $uncompressed )->exists, "$uncompressed in cache" );
};

# XXX test that files in cache aren't overwritten?

subtest 'check index age' => sub {
    my $index   = new_local_index;
    my $package = $index->cached_package;
    ok( -f $package, "got the package file" );
    my $expected_age = ( stat($package) )[9];
    is( $index->index_age, $expected_age, "index_age() is correct" );
};

subtest 'find package' => sub {
    my $index = new_local_index;
    test_find_package($index);
};

subtest 'search package' => sub {
    my $index = new_local_index;
    test_search_package($index);
};

done_testing;
# COPYRIGHT
# vim: ts=4 sts=4 sw=4 et:
