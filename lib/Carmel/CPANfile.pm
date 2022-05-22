package Carmel::CPANfile;
use strict;
use warnings;
use Module::CPANfile;
use Class::Tiny qw( path );

sub load {
    my $self = shift;

    $self->path->exists
      or die "Can't locate 'cpanfile' to load module list.\n";

    Module::CPANfile->load($self->path);
}

1;
