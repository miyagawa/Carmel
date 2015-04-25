package Carmel::Preload;
use strict;
use Module::Runtime;

sub import {
    my($class, @phase) = @_;

    my $modules = $class->required_modules(@phase);
    while (my($module, $version) = each %$modules) {
        next if $module eq 'perl';
        Module::Runtime::use_module($module, $version);
    }

    1;
}

sub required_modules {
    my($class, @phase) = @_;

    my %modules;
    for my $phase ('runtime', @phase) {
        %modules = (%modules, %{Carmel::Setup->environment->{prereqs}{$phase}{requires} || {}});
    }

    \%modules
}

1;

