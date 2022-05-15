package Carmel::Lock;
use strict;
use warnings;
use Path::Tiny ();
use Class::Tiny qw(path locked _warned);

sub acquire {
    my $self = shift;

    $self->path->parent->mkpath;

    my $timeout = 3600; # 1h: reasonable?
    my $i;

    while ($i++ < $timeout) {
        $self->try_lock and return 1;
        $self->check_stale;
        sleep 1;
    }

    die "Couldn't get lock held by ", $self->pid, " for ${timeout}s, giving up.\n";
}

sub try_lock {
    my $self = shift;


    mkdir $self->path, 0777 or return;
    $self->pidfile->spew("$$\n");

    $self->locked(1);

    return 1;
}

sub check_stale {
    my $self = shift;

    my $pid = $self->pid;

    if (kill 0, $pid) {
        # pid is still running
        $self->warn_stale;
        return;
    }

    warn "Can't send signal to possibley state pid $pid. Cleaning up." if $Carmel::DEBUG;

    $self->path->remove_tree({ safe => 0 })
      or die "Couldn't remove lock directory ", $self->path, ": $!";

    return 1;
}

sub warn_stale {
    my $self = shift;

    return if $self->_warned;

    my $pid = $self->pid;

    warn sprintf <<EOF, $pid, $pid, $self->path;
Waiting for another carmel process (pid: %d) to finish.
If you believe this is a stale lock, run:

    kill %d
    rm -rf %s

EOF

    $self->_warned(1);
}

sub pid {
    my $self = shift;
    chomp(my $pid = $self->pidfile->slurp);
    return $pid;
}

sub pidfile {
    my $self = shift;
    $self->path->child('pid');
}

sub release {
    my $self = shift;
    return unless $self->locked;
    $self->path->remove_tree({ safe => 0 }); 
}

sub DESTROY {
    my $self = shift;
    $self->release;
}

1;
