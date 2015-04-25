package Carmel::Setup;
use strict;

my $path;

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
}

sub import {
    my $class = shift;

    $class->load;

    if (-e "$path/local/.carmel") {
        # after rollout, either via carmel exec or use Carmel::Setup
        require lib;
        lib->import("$path/local/lib/perl5");
    } else {
        Carmel::Runtime->bootstrap;
    }
}

1;
