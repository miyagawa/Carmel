package Carmel::Runner;
use strict;
use warnings;

our $UseSystem = 0;

sub new {
    my $class = shift;

    # FIXME absolute path
    local $@;
    eval {
        require ".carmel/MyBootstrap.pm";
    };
    if ($@ && $@ =~ /Can't locate \.carmel\/MyBootstrap\.pm/) {
        die "Could not locate .carmel/MyBootstrap.pm. You need to run `carmel install` first.\n";
    }

    if (-d 'local' && -e 'local/lib/perl5/MyBootstrap.pm') {
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

1;
