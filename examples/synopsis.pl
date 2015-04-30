#!/usr/bin/env perl
use v5.10;
use strict;
use warnings;

use CPAN::Common::Index::Mux::Ordered;
use Data::Dumper;

my $index = CPAN::Common::Index::Mux::Ordered->assemble(
    MetaDB => {},
    Mirror => { mirror => "http://cpan.cpantesters.org" },
);

my $result = $index->search_packages( { package => "Moose" } );

print Dumper($result);

