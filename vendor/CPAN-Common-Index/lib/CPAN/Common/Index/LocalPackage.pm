use 5.008001;
use strict;
use warnings;

package CPAN::Common::Index::LocalPackage;
# ABSTRACT: Search index via custom local CPAN package flatfile

our $VERSION = '0.007';

use parent 'CPAN::Common::Index::Mirror';

use Class::Tiny qw/source/;

use Carp;
use IO::Uncompress::Gunzip ();
use Path::Tiny;

=attr source (REQUIRED)

Path to a local file in the form of 02packages.details.txt.  It may
be compressed with a ".gz" suffix or it may be uncompressed.

=attr cache

Path to a local directory to store a (possibly uncompressed) copy
of the source index.  Defaults to a temporary directory if not
specified.

=cut

sub BUILD {
    my $self = shift;

    my $file = $self->source;
    if ( !defined $file ) {
        Carp::croak("'source' parameter must be provided");
    }
    elsif ( !-f $file ) {
        Carp::croak("index file '$file' does not exist");
    }

    return;
}

sub cached_package {
    my ($self) = @_;
    my $package = path( $self->cache, path( $self->source )->basename );
    $package =~ s/\.gz$//;
    $self->refresh_index unless -r $package;
    return $package;
}

sub refresh_index {
    my ($self) = @_;
    my $source = path( $self->source );
    if ( $source =~ /\.gz$/ ) {
        ( my $uncompressed = $source->basename ) =~ s/\.gz$//;
        $uncompressed = path( $self->cache, $uncompressed );
        if ( !-f $uncompressed or $source->stat->mtime > $uncompressed->stat->mtime ) {
            IO::Uncompress::Gunzip::gunzip( map { "$_" } $source, $uncompressed )
              or Carp::croak "gunzip failed: $IO::Uncompress::Gunzip::GunzipError\n";
        }
    }
    else {
        my $dest = path( $self->cache, $source->basename );
        $source->copy($dest)
          if !-e $dest || $source->stat->mtime > $dest->stat->mtime;
    }
    return 1;
}

sub search_authors { return }; # this package handles packages only

1;

=for Pod::Coverage attributes validate_attributes search_packages search_authors
cached_package BUILD

=head1 SYNOPSIS

  use CPAN::Common::Index::LocalPackage;

  $index = CPAN::Common::Index::LocalPackage->new(
    { source => "mypackages.details.txt" }
  );

=head1 DESCRIPTION

This module implements a CPAN::Common::Index that searches for packages in a local
index file in the same form as the CPAN 02packages.details.txt file.

There is no support for searching on authors.

=cut

# vim: ts=4 sts=4 sw=4 et:
