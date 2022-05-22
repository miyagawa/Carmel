package Carmel::Environment;
use strict;
use warnings;
use Config;
use Path::Tiny;
use Carmel::Repository;

use Class::Tiny {
    perl_arch => sub { "$Config{version}-$Config{archname}" },
    repository_base => sub { $_[0]->build_repository_base },
    repo => sub { $_[0]->build_repo },
    home => sub { Path::Tiny->new($ENV{HOME} || $ENV{HOMEPATH}) },
};

sub build_repository_base {
    my $self = shift;
    Path::Tiny->new($ENV{PERL_CARMEL_REPO} || $self->home->child(".carmel/" . $self->perl_arch));
}

sub build_repo {
    my $self = shift;
    Carmel::Repository->new(path => $self->repository_base->child('builds'));
}

1;









1;
