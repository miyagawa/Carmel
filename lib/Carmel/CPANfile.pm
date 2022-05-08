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

sub snapshot_path {
    my $self = shift;
    Path::Tiny->new($self->path . ".snapshot");
}

sub load_snapshot {
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

1;
