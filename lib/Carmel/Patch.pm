package Carmel::Patch;
use strict;
use warnings;

use parent 'Exporter';
our @EXPORT = qw(patch);

my %patches;

sub patch {
    my($name, $patch) = @_;
    $patches{$name} = __PACKAGE__->new($name, $patch);
}

sub new {
    my($class, $name, $hooks) = @_;

    (my $pkg = $name) =~ s/([^A-Za-z0-9_])/sprintf "_%x", ord($1)/eg;
    $pkg = "Carmel::Artifact::$pkg";

    no strict 'refs';
    @{"$pkg\::ISA"} = ("Carmel::Artifact");

    for my $hook (keys %$hooks) {
        *{"$pkg\::$hook"} = $hooks->{$hook};
    }

    return $pkg;
}

sub lookup {
    my($class, $distname) = @_;
    $patches{$distname};
}

unless ($ENV{PERL_CARMEL_NO_DEFAULT_PATCHES}) {
    require Carmel::DefaultPatches;
}

1;
