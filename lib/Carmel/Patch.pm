package Carmel::Patch;
use strict;
use warnings;

my %patches;

sub add {
    my($class, $name, $patch) = @_;
    $patches{$name} = $class->new($name, $patch);
}

sub new {
    my($class, $name, $hooks) = @_;

    (my $pkg = $name) =~ s/([^A-Za-z0-9_])/sprintf "_%x", ord($1)/eg;
    $pkg = "Carmel::Artifact::$pkg";

    no strict 'refs';
    @{"$pkg\::ISA"} = qw( Carmel::Artifact );

    for my $hook (keys %$hooks) {
        *{"$pkg\::$hook"} = $hooks->{$hook};
    }

    return $pkg;
}

sub lookup {
    my($class, $distname) = @_;
    $patches{$distname};
}

__PACKAGE__->add(
    'Time-Piece-MySQL-0.06' => {
        init => sub {
            my $self = shift;
            delete $self->install->{provides}{"Time::Piece"};
        },
    },
);

1;
