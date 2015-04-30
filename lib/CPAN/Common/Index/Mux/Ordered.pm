use 5.008001;
use strict;
use warnings;

package CPAN::Common::Index::Mux::Ordered;
# ABSTRACT: Consult indices in order and return the first result

our $VERSION = '0.007';

use parent 'CPAN::Common::Index';

use Class::Tiny qw/resolvers/;

use Module::Load ();

=attr resolvers

    An array reference of CPAN::Common::Index::* objects

=cut

sub BUILD {
    my $self = shift;

    my $resolvers = $self->resolvers;
    $resolvers = [] unless defined $resolvers;
    if ( ref $resolvers ne 'ARRAY' ) {
        Carp::croak("The 'resolvers' argument must be an array reference");
    }
    for my $r (@$resolvers) {
        if ( !eval { $r->isa("CPAN::Common::Index") } ) {
            Carp::croak("Resolver '$r' is not a CPAN::Common::Index object");
        }
    }
    $self->resolvers($resolvers);

    return;
}

=method assemble

    $index = CPAN::Common::Index::Mux::Ordered->assemble(
        MetaDB => {},
        Mirror => { mirror => "http://www.cpan.org" },
    );

This class method provides a shorthand for constructing a multiplexer.
The arguments must be pairs of subclass suffixes and arguments.  For
example, "MetaDB" means to use "CPAN::Common::Index::MetaDB".  Empty
arguments must be given as an empty hash reference.

=cut

sub assemble {
    my ( $class, @backends ) = @_;

    my @resolvers;

    while (@backends) {
        my ( $subclass, $config ) = splice @backends, 0, 2;
        my $full_class = "CPAN::Common::Index::${subclass}";
        eval { Module::Load::load($full_class); 1 }
          or Carp::croak($@);
        my $object = $full_class->new($config);
        push @resolvers, $object;
    }

    return $class->new( { resolvers => \@resolvers } );
}

sub validate_attributes {
    my ($self) = @_;
    my $resolvers = $self->resolvers;
    return 1;
}

# have to think carefully about the sematics of regex search when indices
# are stacked; only one result for any given package (or package/version)
sub search_packages {
    my ( $self, $args ) = @_;
    Carp::croak("Argument to search_packages must be hash reference")
      unless ref $args eq 'HASH';
    my @found;
    if ( $args->{name} and ref $args->{name} eq '' ) {
        # looking for exact match, so we just want the first hit
        for my $source ( @{ $self->resolvers } ) {
            if ( my @result = $source->search_packages($args) ) {
                # XXX double check against remaining $args
                push @found, @result;
                last;
            }
        }
    }
    else {
        # accumulate results from all resolvers
        my %seen;
        for my $source ( @{ $self->resolvers } ) {
            my @result = $source->search_packages($args);
            push @found, grep { !$seen{ $_->{package} }++ } @result;
        }
    }
    return wantarray ? @found : $found[0];
}

# have to think carefully about the sematics of regex search when indices
# are stacked; only one result for any given package (or package/version)
sub search_authors {
    my ( $self, $args ) = @_;
    Carp::croak("Argument to search_authors must be hash reference")
      unless ref $args eq 'HASH';
    my @found;
    if ( $args->{name} and ref $args->{name} eq '' ) {
        # looking for exact match, so we just want the first hit
        for my $source ( @{ $self->resolvers } ) {
            if ( my @result = $source->search_authors($args) ) {
                # XXX double check against remaining $args
                push @found, @result;
                last;
            }
        }
    }
    else {
        # accumulate results from all resolvers
        my %seen;
        for my $source ( @{ $self->resolvers } ) {
            my @result = $source->search_authors($args);
            push @found, grep { !$seen{ $_->{package} }++ } @result;
        }
    }
    return wantarray ? @found : $found[0];
}

1;

=for Pod::Coverage attributes validate_attributes search_packages search_authors BUILD

=head1 SYNOPSIS

    use CPAN::Common::Index::Mux::Ordered;
    use Data::Dumper;

    $index = CPAN::Common::Index::Mux::Ordered->assemble(
        MetaDB => {},
        Mirror => { mirror => "http://cpan.cpantesters.org" },
    );

=head1 DESCRIPTION

This module multiplexes multiple CPAN::Common::Index objects, returning
results in order.

For exact match queries, the first result is returned. For search queries,
results from each index object are concatenated.

=cut

# vim: ts=4 sts=4 sw=4 et:
