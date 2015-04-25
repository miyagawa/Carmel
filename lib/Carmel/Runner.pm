package Carmel::Runner;
use strict;
use warnings;

our $UseSystem = 0;

sub new {
    my $class = shift;

    require Carmel::Setup;
    Carmel::Setup->load;

    if (-e 'local/.carmel') {
        Carmel::Runtime->environment->{local} = Carmel::Runtime->environment->{base} . '/local';
    }

    bless {}, $class;
}

# Note: can't capture carmel exec perl -MModule because it's loaded earlier than PERL5OPT
sub env {
    my %env = Carmel::Runtime->bootstrap_env;
    return (
        _join(':', PATH => $env{PATH}),
        _join(':', PERL5LIB => $env{PERL5LIB}),
        _join(' ', PERL5OPT => $env{PERL5OPT}),
        _value(PERL_CARMEL_PATH => $env{PERL_CARMEL_PATH}),
    );
}

sub execute {
    my($self, @args) = @_;
    %ENV = (%ENV, $self->env);
    $UseSystem ? system(@args) : exec @args;
}

sub _join {
    my($sep, $env, $list) = @_;
    return unless $list;
    push @$list, $ENV{$env} if $ENV{$env};
    return ($env => join($sep, @$list));
}

sub _value {
    my($env, $value) = @_;
    return unless defined $value;
    return ($env => $value);
}

1;
