package Carmel::Runtime;
use strict;

our $UseSystem = 0;

sub new {
    my $class = shift;

    # FIXME absolute path
    require ".carmel/Carmel/Bootstrap.pm";
        
    bless {}, $class;
}

# Note: can't capture carmel exec perl -MModule because it's loaded earlier than PERL5OPT
sub env {
    my $self = shift;
    return (
        _join(PATH => Carmel::Bootstrap->path),
        PERL5OPT => "-I" . Carmel::Bootstrap->base . " -MCarmel::Bootstrap",
    );
}

sub execute {
    my($self, @args) = @_;
    my %env = $self->env;
    %ENV = (%ENV, %env);
    $UseSystem ? system(@args) : exec @args;
}

sub _join {
    my($env, @list) = @_;
    push @list, $ENV{$env} if $ENV{$env};
    return ($env => join(":", @list));
}

1;

