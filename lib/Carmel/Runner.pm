package Carmel::Runner;
use strict;

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
        
    bless {}, $class;
}

# Note: can't capture carmel exec perl -MModule because it's loaded earlier than PERL5OPT
sub env {
    return (
        _join(PATH => Carmel::Bootstrap->path),
        PERL5OPT => "-I" . Carmel::Bootstrap->base . " -MMyBootstrap",
    );
}

sub execute {
    my($self, @args) = @_;
    %ENV = (%ENV, $self->env);
    $UseSystem ? system(@args) : exec @args;
}

sub _join {
    my($env, @list) = @_;
    push @list, $ENV{$env} if $ENV{$env};
    return ($env => join(":", @list));
}

1;

