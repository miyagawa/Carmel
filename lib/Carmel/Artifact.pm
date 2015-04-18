package Carmel::Artifact;
use strict;
use CPAN::Meta;

sub new {
    my($class, @args) = @_;
    bless [ @args ], $class;
}

sub package { $_[0]->[0] }
sub version { $_[0]->[1] || '0' }
sub path    { $_[0]->[2] }
sub install { $_[0]->[3] }

sub dist_version {
    $_[0]->install->{version};
}

sub blib {
    "$_[0]->[2]/blib";
}

sub paths {
    my $self = shift;
    ($self->blib . "/script", $self->blib . "/bin");
}

sub libs {
    my $self = shift;
    ($self->blib . "/arch", $self->blib . "/lib");
}

sub meta {
    my $self = shift;
    CPAN::Meta->load_file($self->path . "/MYMETA.json");
}

sub requirements {
    my $self = shift;
    $self->meta->effective_prereqs->merged_requirements(['runtime'], ['requires']);
}

1;
