package Carmel::Environment;
use strict;
use warnings;
use Config;
use Path::Tiny;
use Carmel::CPANfile;
use Carmel::Repository;

use Class::Tiny {
    perl_arch => sub { "$Config{version}-$Config{archname}" },
    repository_base => sub { $_[0]->build_repository_base },
    repo => sub { $_[0]->build_repo },
    home => sub { Path::Tiny->new($ENV{HOME} || $ENV{HOMEPATH}) },
    cpanfile => sub { $_[0]->build_cpanfile },
    snapshot => sub { $_[0]->build_snapshot },
};

sub build_repository_base {
    my $self = shift;
    Path::Tiny->new($ENV{PERL_CARMEL_REPO} || $self->home->child(".carmel/" . $self->perl_arch));
}

sub build_repo {
    my $self = shift;
    Carmel::Repository->new(path => $self->repository_base->child('builds'));
}

sub build_cpanfile {
    my $self = shift;
    my $path = Path::Tiny->new($self->locate_cpanfile);
    Carmel::CPANfile->new(path => $path->absolute);
}

sub locate_cpanfile {
    my $self = shift;

    my $path = $ENV{PERL_CARMEL_CPANFILE};
    if ($path) {
        return $path;
    }

    my $current  = Path::Tiny->cwd;
    my $previous = '';

    until ($current eq '/' or $current eq $previous) {
        my $try = $current->child('cpanfile');
        return $try if $try->is_file;
        ($previous, $current) = ($current, $current->parent);
    }

    return 'cpanfile'; # fallback, most certainly fails later
}

sub build_snapshot {
    my $self = shift;

    my $path = $self->snapshot_path;
    if ($path && $path->exists) {
        require Carton::Snapshot;
        my $snapshot = Carton::Snapshot->new(path => $path);
        $snapshot->load;
        return $snapshot;
    }

    return;
}

sub snapshot_path {
    my $self = shift;
    Path::Tiny->new($self->cpanfile->path . ".snapshot");
}

1;
