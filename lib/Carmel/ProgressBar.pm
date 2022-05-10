package Carmel::ProgressBar;
use strict;
use warnings;
use Class::Tiny;

use parent qw(Exporter);
our @EXPORT = qw(progress);

sub progress {
    my($args, $code) = @_;

    my $do = -t STDOUT && eval { require Term::ProgressBar; 1 };

    my $progress = $do
      ? Term::ProgressBar->new({ count => scalar(@$args) })
      : __PACKAGE__->new;

    my $i;
    for my $arg (@$args) {
        $code->($arg);
        $progress->update(++$i);
    }
}

sub update {}

1;
