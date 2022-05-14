package Carmel::Setup;
use strict;
use Carmel;

my($path, $environment);

sub has_local {
    -e "$path/local/.carmel";
}

sub environment { $environment }

sub load {
    # TODO look for cpanfile?
    $path = $ENV{PERL_CARMEL_PATH} || '.';

    my $err;
    {
        local $@;
        eval {
            require "$path/.carmel/MySetup.pm";
        };
        if ($@) {
            if ($@ =~ /Can't locate .*\.carmel\/MySetup\.pm/) {
                $err = "Can't locate .carmel/MySetup.pm in '$path'. You need to run `carmel install` first.\n";
            } else {
                $err = $@;
            }
        }
    }

    die $err if $err;

    $environment = \%Carmel::MySetup::environment;
}

sub import {
    my $class = shift;

    $class->load;

    if ($class->has_local) {
        # after rollout, either via carmel exec or use Carmel::Setup
        require lib;
        lib->import("$path/local/lib/perl5");
    } else {
        require Carmel::Runtime;
        Carmel::Runtime->bootstrap($environment->{modules}, $environment->{inc});
    }
}

1;

__END__

=head1 NAME

Carmel::Setup - Configures Carmel environment within a perl application

=head1 SYNOPSIS

  # in your perl application code, before using any modules
  use Carmel::Setup;
  use Plack;

=head1 DESCRIPTION

Carmel::Setup allows you to confgure Carmel environment within a perl
code, so that you don't need to call C<carmel exec> to run your program.

=head2 Difference with carmel exec

C<carmel exec> adds C<-MCarmel::Setup> to C<PERL5OPT>, which means all
the perl program, including third party commands spawned off of your
program (via C<system> etc.) will also use the Carmel environment.
That may or may not be what you want, and calling Carmel::Setup manually
in your own code gives you the choice of bypassing C<carmel exec>.

=head1 SEE ALSO

L<Carmel::Preload>

=cut
