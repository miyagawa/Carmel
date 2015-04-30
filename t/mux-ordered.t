use 5.008001;
use strict;
use warnings;
use Test::More 0.96;
use Test::FailWarnings;
use Test::Deep '!blessed';
use Test::Fatal;
use Cwd qw/getcwd/;
use File::Temp;

use lib 't/lib';
use CommonTests;

my $cwd         = getcwd;
my $test_mirror = "file:///$cwd/t/CPAN";
my $local_pkg   = "t/CUSTOM/uncompressed";
my $cache       = File::Temp->newdir;

require_ok("CPAN::Common::Index::Mirror");
require_ok("CPAN::Common::Index::LocalPackage");
require_ok("CPAN::Common::Index::Mux::Ordered");

my $mirror_index =
  CPAN::Common::Index::Mirror->new( { cache => $cache, mirror => $test_mirror } );

my $local_index = CPAN::Common::Index::LocalPackage->new(
    { cache => $cache, source => $local_pkg } );

subtest "constructor tests" => sub {
    # no arguments, all defaults
    new_ok(
        'CPAN::Common::Index::Mux::Ordered' => [],
        "new with no args"
    );

    # single resolver specified
    new_ok(
        'CPAN::Common::Index::Mux::Ordered' => [ { resolvers => [$mirror_index] } ],
        "new with single mirror resolver"
    );

    # bad resolver argument
    eval { CPAN::Common::Index::Mux::Ordered->new( { resolvers => "Foo" } ) };
    like(
        $@ => qr/The 'resolvers' argument must be an array reference/,
        "Bad resolver dies with error"
    );

};

subtest "find package" => sub {
    my $index = new_ok(
        'CPAN::Common::Index::Mux::Ordered' =>
          [ { resolvers => [ $local_index, $mirror_index ] } ],
        "new with single mirror resolver"
    );
    test_find_package($index);

    # test finding darkpan from local
    {
        my $expected = {
            'package' => 'ZZZ::Custom',
            'uri'     => 'cpan:///distfile/LOCAL/ZZZ-Custom-1.2.tar.gz',
            'version' => '1.2'
        };
        my $got = $index->search_packages( { package => 'ZZZ::Custom' } );
        is_deeply( $got, $expected, "Found custom package" );
    }

    # test finding something on CPAN, not darkpan
    {
        my $expected = {
            'package' => 'Acme::Bleach',
            'uri'     => 'cpan:///distfile/DCONWAY/Acme-Bleach-1.150.tar.gz',
            'version' => '1.150'
        };
        my $got = $index->search_packages( { package => 'Acme::Bleach' } );
        is_deeply( $got, $expected, "Found package only on CPAN" );
    }

    # test overriding something on CPAN
    {
        my $expected = {
            'package' => 'Acme::Samurai',
            'uri'     => 'cpan:///distfile/LOCAL/Acme-Samurai-0.02.tar.gz',
            'version' => '0.02'
        };
        my $got = $index->search_packages( { package => 'Acme::Samurai' } );
        is_deeply( $got, $expected, "Found package overriding CPAN" );
    }
};

subtest "search package" => sub {
    my $index = new_ok(
        'CPAN::Common::Index::Mux::Ordered' => [ { resolvers => [$mirror_index] } ],
        "new with single mirror resolver"
    );
    test_search_package($index);
};

done_testing;
# COPYRIGHT
# vim: ts=4 sts=4 sw=4 et:
