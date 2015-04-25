package Carmel::Preload;
use strict;
use Module::Runtime;

unless (%Carmel::Setup::) {
    require Carp;
    Carp::croak("Can't detect Carmel environment. You have to use Carmel::Preload under `carmel exec` or after `use Carmel::Setup`");
}

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

__END__

=head1 NAME

Carmel::Preload - preloads all modules declared in cpanfile

=head1 SYNOPSIS

  # program running under carmel exec, or after use Carmel::Setup
  use Carmel::Preload;

=head1 DESCRIPTION

Carmel::Preload scans your cpanfile and preloads all the modules
declared as C<requires>. By default, only the prereqs listed in
C<runtime> phase will be loaded, but you can pass in other phases such
as C<test> or C<develop> via its import arguments, i.e.

  use Carmel::Preload qw(test develop);

=cut

