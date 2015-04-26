package Carmel::Runtime;
use strict;
use Config;

sub bootstrap {
    my($class, $modules, $inc) = @_;

    my %allows = qw( Carmel/Preload.pm 1 Module/Runtime.pm 1 );
    my %site   = ($Config{sitearchexp} => 1, $Config{sitelibexp} => 1);

    for (@INC) {
        $_ = Carmel::Runtime::SiteINC->new($_, \%allows)
          if $site{$_};
    }

    unshift @INC,
      Carmel::Runtime::FastINC->new(%$modules),
      @{$inc};
}

sub require_all {
    my($class, @phase) = @_;
    die "Deprecated. Use Carmel::Preload instead.";
}

package Carmel::Runtime::SiteINC;

sub new {
    my($class, $path, $allows) = @_;
    bless {
        path => $path,
        allows => $allows,
    }, $class;
}

sub Carmel::Runtime::SiteINC::INC {
    my($self, $file) = @_;

    if ($self->{allows}{$file}) {
        open my $fh, '<', "$self->{path}/$file"
          or return;
        $INC{$file} = "$self->{path}/$file";
        return $fh;
    }
}

package Carmel::Runtime::FastINC;

sub new {
    my($class, %modules) = @_;
    bless \%modules, $class;
}

sub Carmel::Runtime::FastINC::INC {
    my($self, $file) = @_;

    if ($self->{$file}) {
        if (open my $fh, '<', $self->{$file}) {
            $INC{$file} = $self->{$file};
            return $fh;
        }
        warn "Can't locate $file in $self->{$file}: $!";
        return;
    }
}

1;
