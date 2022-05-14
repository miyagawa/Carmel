package Carmel::Runner;
use strict;
use warnings;

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
    my($self, @cmd) = @_;

    shift @cmd if $cmd[0] && $cmd[0] eq '--';

    %ENV = (%ENV, $self->env);
    exec @cmd;
    exit 127; # command not found
}

sub run {
    my($self, @cmd) = @_;

    shift @cmd if $cmd[0] && $cmd[0] eq '--';

    local %ENV = (%ENV, $self->env);
    system @cmd;
}

sub _join {
    my($sep, $env, $list) = @_;
    return unless $list;
    push @$list, $ENV{$env} if $ENV{$env};
    return ($env => join($sep, @$list));
}

1;
