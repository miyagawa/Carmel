package Carmel::Runner;
use strict;
use warnings;

our $UseSystem = ($^O eq 'MSWin32');

sub new {
    my $class = shift;

    require Carmel::Setup;
    Carmel::Setup->load;

    my $self = bless {}, $class;

    if (Carmel::Setup->has_local) {
        $self->{local} = Carmel::Setup->environment->{base} . '/local';
    }

    $self;
}

# Note: can't capture carmel exec perl -MModule because it's loaded earlier than PERL5OPT
sub env {
    my $self = shift;

    my $environment = Carmel::Setup->environment;

    if ($self->{local}) {
        return (
            _join(':', PATH => ["$self->{local}/bin"]),
            _join(' ', PERL5OPT => ["-MCarmel::Setup"]),
            PERL_CARMEL_PATH => $environment->{base},
        );
    } else {
        return (
            _join(':', PATH => $environment->{path}),
            _join(' ', PERL5OPT => ["-MCarmel::Setup"]),
            PERL_CARMEL_PATH => $environment->{base},
        );
    }
}

sub execute {
    my($self, @args) = @_;

    shift @args if $args[0] && $args[0] eq '--';

    %ENV = (%ENV, $self->env);
    if ($UseSystem) {
        system @args;
    } else {
        exec @args;
        exit 127; # command not found
    }
}

sub _join {
    my($sep, $env, $list) = @_;
    return unless $list;
    push @$list, $ENV{$env} if $ENV{$env};
    return ($env => join($sep, @$list));
}

1;
