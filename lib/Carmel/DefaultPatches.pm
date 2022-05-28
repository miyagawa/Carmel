package Carmel::DefaultPatches;
use strict;
use Carmel::Patch qw(patch);

patch 'Time-Piece-MySQL-0.06' => {
    init => sub {
        my $self = shift;
        delete $self->install->{provides}{"Time::Piece"};
    },
};

patch 'Proc-PID-File-Fcntl-1.01' => {
    init => sub {
        my $self = shift;
        $self->install->{provides}{"Proc::PID::File::Fcntl"}{version} = "1.01";
    },
};

1;
