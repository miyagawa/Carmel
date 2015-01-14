package Carmel::Artifact;
use strict;

sub new {
    my($class, $package, $version, $path, $dist_version) = @_;
    bless [ $package, $version, $path, $dist_version ], $class;
}

sub package { $_[0]->[0] }
sub version { $_[0]->[1] || '0' }
sub path    { $_[0]->[2] }
sub dist_version { $_[0]->[3] }

sub blib {
    "$_->[2]/blib";
}

sub paths {
    my $self = shift;
    ($self->blib . "/script", $self->blib . "/bin");
}

sub libs {
    my $self = shift;
    ($self->blib . "/arch", $self->blib . "/lib");
}

1;
