package Carmel::Lock;
use strict;
use warnings;
use Fcntl qw(:flock);
use Class::Tiny qw(path _handle);

sub acquire {
    my $self = shift;

    $self->path->mkpath;

    my $timeout = 3600; # 1h: reasonable?

    my $fh = $self->lockfile->openw or die "Can't open ", $self->lockfile, ": $!";
    $self->_handle($fh);

    while (1) {
        flock $fh, LOCK_EX|LOCK_NB and last;

        my $pid = $self->pid;
        warn "Waiting for another carmel process (pid: $pid) to finish.\n";

        local $SIG{ALRM} = sub {
            die "Couldn't get lock held by $pid for ${timeout}s, giving up.\n";
        };
        alarm $timeout;

        flock $fh, LOCK_EX
          or die "Couldn't get lock held by $pid\n";
    }

    $self->pidfile->spew("$$\n");

    return 1;
}

sub pid {
    my $self = shift;

    if ($self->pidfile->exists) {
        chomp(my $pid = $self->pidfile->slurp);
        return $pid;
    }

    return '';
}

sub lockfile {
    my $self = shift;
    $self->path->child('lock');
}

sub pidfile {
    my $self = shift;
    $self->path->child('pid');
}

sub release {
    my $self = shift;

    return unless $self->_handle;

    $self->_handle->close;
    $self->pidfile->remove;
}

sub DESTROY {
    my $self = shift;
    $self->release;
}

1;
