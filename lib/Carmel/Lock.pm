package Carmel::Lock;
use strict;
use warnings;

use Fcntl qw(:flock);
use Class::Tiny qw( path _handle );

sub acquire {
    my $self = shift;

    my $path = $self->path;
    $path->parent->mkpath;

    my $fh = $path->opena or die "$path: $!";
    $self->_handle($fh);
    
    while (1) {
        # try non-blocking first to show warning
        flock $fh, LOCK_EX|LOCK_NB and last;

        # don't use slurp since it opens with LOCK_SH
        chomp( my $pid = $path->openr->getline );
        warn "Waiting for another carmel command (pid:$pid) to finish.\n";

        local $SIG{ALRM} = sub { die "Timing out. Remove the file $path if this is a stale lock.\n" };
        alarm 3600; # make this an environment var?

        flock $fh, LOCK_EX or die "lock failed: $!";

        last;
    }

    truncate $fh, 0;
    print $fh "$$\n";
    $fh->flush;
}

sub DESTROY {
    my $self = shift;
    $self->release;
}

sub release {
    my $self = shift;
    $self->_handle->close if $self->_handle;
}

1;
