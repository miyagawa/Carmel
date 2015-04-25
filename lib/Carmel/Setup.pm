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
        if ($@ && $@ =~ /Can't locate .*\.carmel\/MySetup\.pm/) {
            $err = "Could not locate .carmel/MySetup.pm in $path. You need to run `carmel install` first.\n";
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
