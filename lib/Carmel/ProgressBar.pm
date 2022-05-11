package Carmel::ProgressBar;
use strict;
use warnings;
use Class::Tiny qw( quiet width total _prev );

use POSIX qw(ceil);

use parent qw(Exporter);
our @EXPORT = qw(progress);

sub progress {
    my($args, $code) = @_;

    return unless @$args;

    my $class = __PACKAGE__;

    my $self = $class->new(
        width => 50,
        total => scalar(@$args),
        quiet => !-t STDOUT,
    );

    local $| = 1
      unless $self->quiet;

    $self->update(0);

    for my $i (0..$#$args) {
        $code->($args->[$i]);
        $self->update($i+1);
    }

    $self->clear;
}

sub update {
    my($self, $count) = @_;

    return if $self->quiet;

    my $width  = $self->width;
    my $pct    = int(100 * $count / $self->total);
    my $done   = ceil($pct * $width / 100);
    my $head   = $width == $done ? 0 : 1;
    my $remain = ($width - $done - $head);

    my $line = sprintf "[%s%s%s] %3d%%",
      ("=" x $done), (">" x $head), (" " x $remain), $pct;

    return if $self->_prev && $line eq $self->_prev;

    print "\r", $line;
    $self->_prev($line);

    return;
}

sub clear {
    my $self = shift;
    print "\r", " " x ($self->width + 7), "\r";
}

1;
