use strict;
use warnings;

package CommonTests;

use Exporter;
use Test::More;

our @ISA    = qw/Exporter/;
our @EXPORT = qw(
  test_find_package
  test_search_package
  test_find_author
  test_search_author
);

sub test_find_package {
    my $index = shift;

    my @cases = (
        {
            label  => 'query on package File::Marker',
            query  => { package => "File::Marker" },
            result => {
                package => 'File::Marker',
                version => '0.13',
                uri     => 'cpan:///distfile/DAGOLDEN/File-Marker-0.13.tar.gz',
            },
        },
        {
            label  => 'query on package dist::zilla',
            query  => { package => "dist::zilla" },
            result => undef,                         # should not match case insensitively
        },
        {
            label  => 'query on package without version ',
            query  => { package => "Moo::Role" },
            result => {
                package => 'Moo::Role',
                version => 'undef',
                uri     => 'cpan:///distfile/MSTROUT/Moo-1.001000.tar.gz',
            },
        },
        {
            label  => 'query on package in a perl distribution',
            query  => { package => 'attributes', },
            result => {
                package => 'attributes',
                version => '0.2',
                uri     => 'cpan:///distfile/FLORA/perl-5.17.4.tar.bz2',
            },
        },
        {
            label  => 'query on package duplicated in another case',
            query  => { package => 'if', },
            result => {
                package => 'if',
                version => '0.0601',
                uri     => 'cpan:///distfile/ILYAZ/modules/if-0.0601.tar.gz'
            },
        },
    );

    for my $c (@cases) {
        my $got = $index->search_packages( $c->{query} );
        is_deeply( $got, $c->{result}, $c->{label} ) or diag explain $got;
    }
}

sub test_search_package {
    my $index = shift;

    my @cases = (
        {
            label  => 'query on package',
            query  => { package => qr/e::Marker$/, },
            result => [
                {
                    package => 'File::Marker',
                    version => '0.13',
                    uri     => 'cpan:///distfile/DAGOLDEN/File-Marker-0.13.tar.gz',
                }
            ],
        },
        {
            label => 'query on package and version',
            query => {
                package => qr/Marker$/,
                version => 0.13,
            },
            result => [
                {
                    package => 'File::Marker',
                    version => '0.13',
                    uri     => 'cpan:///distfile/DAGOLDEN/File-Marker-0.13.tar.gz',
                }
            ],
        },
        {
            label  => 'query on dist',
            query  => { dist => qr/1\.4404\.tar\.gz$/, },
            result => [
                {
                    'package' => 'Parse::CPAN::Meta',
                    'uri'     => 'cpan:///distfile/DAGOLDEN/Parse-CPAN-Meta-1.4404.tar.gz',
                    'version' => '1.4404'
                }
            ],
        },
    );

    for my $c (@cases) {
        my @got = $index->search_packages( $c->{query} );
        is_deeply( \@got, $c->{result}, $c->{label} ) or diag explain \@got;
    }
}

sub test_find_author {
    my $index = shift;

    my @cases = (
        {
            label  => 'query on DAGOLDEN',
            query  => { id => 'DAGOLDEN' },
            result => {
                id       => 'DAGOLDEN',
                fullname => 'David Golden',
                email    => 'dagolden@cpan.org',
            },
        },
        {
            label  => 'query on aashu (with CENSORED email)',
            query  => { id => 'aashu' },
            result => {
                id       => 'AASHU',
                fullname => 'Ashutosh Sharma',
                email    => 'CENSORED',
            },
        },
    );

    for my $c (@cases) {
        my $got = $index->search_authors( $c->{query} );
        is_deeply( $got, $c->{result}, $c->{label} ) or diag explain $got;
    }
}

sub test_search_author {
    my $index = shift;

    my @cases = (
        {
            label  => 'query id on qr/DAGOLD/',
            query  => { id => qr/DAGOLD/, },
            result => [
                {
                    id       => 'DAGOLDEN',
                    fullname => 'David Golden',
                    email    => 'dagolden@cpan.org',
                },
            ],
        },
        {
            label  => 'query email on qr/dagolden/',
            query  => { email => qr/dagolden/ },
            result => [
                {
                    id       => 'DAGOLDEN',
                    fullname => 'David Golden',
                    email    => 'dagolden@cpan.org',
                },
            ],
        },
        {
            label  => 'query fullname on qr/Golden$/',
            query  => { fullname => qr/Golden$/ },
            result => [
                {
                    id       => 'DAGOLDEN',
                    fullname => 'David Golden',
                    email    => 'dagolden@cpan.org',
                },
            ],
        },
    );

    for my $c (@cases) {
        my @got = $index->search_authors( $c->{query} );
        is_deeply( \@got, $c->{result}, $c->{label} ) or diag explain \@got;
    }
}

1;

