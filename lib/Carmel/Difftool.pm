package Carmel::Difftool;
use strict;
use warnings;

use Carton::Snapshot;
use CPAN::DistnameInfo;
use version;
use Class::Tiny;

use constant RED => 31;
use constant GREEN => 32;

sub color {
    my($code, $text) = @_;
    return $text unless -t STDOUT && !$ENV{NO_COLOR};
    return "\e[${code}m${text}\e[0m";
}

sub load_snapshot {
    my($self, $file, $dists, $index) = @_;

    defined $file
      or die "Usage: carmel difftool LOCAL REMOTE\n";

    my $snapshot = Carton::Snapshot->new(path => $file);
    $snapshot->load;

    for my $dist ($snapshot->distributions) {
        (my $path = $dist->pathname) =~ s!^[A-Z]/[A-Z]{2}/!!;
        my $info = CPAN::DistnameInfo->new($path);
        $dists->{$info->dist}[$index] = $info;
    }
}

sub diff {
    my($self, @args) = @_;

    my %dists;
    $self->load_snapshot($args[0], \%dists, 0);
    $self->load_snapshot($args[1], \%dists, 1);

    for my $dist (sort keys %dists) {
        $self->print_diff($dist, @{$dists{$dist}});
    }
}

sub print_diff {
    my($self, $dist, $old, $new) = @_;

    # unchanged
    return if $old && $new && $old->distvname eq $new->distvname;

    # added
    if (!$old && $new) {
        if ($Carmel::DEBUG) {
            printf "%s (%s)\n%s\n", $dist,
              color(GREEN, $new->version),
              color(GREEN, "+ " . $new->pathname);
        } else {
            printf "+ %s (%s)\n", $dist, color(GREEN, $new->version);
        }
        return;
    }

    # removed
    if ($old && !$new) {
        if ($Carmel::DEBUG) {
            printf "%s (%s)\n%s\n", $dist,
              color(RED, $old->version),
              color(RED, "- " . $old->pathname);
        } else {
            printf "- %s (%s)\n", $dist, color(RED, $old->version);
        }
        return;
    }

    if ($Carmel::DEBUG) {
        printf "%s (%s -> %s)\n%s\n%s\n", $dist,
          color(RED, $old->version), color(GREEN, $new->version),
          color(RED, "- " . $old->pathname), color(GREEN, "+ " . $new->pathname);
    } else {
        printf "  %s (%s -> %s)\n", $dist, color(RED, $old->version), color(GREEN, $new->version);
    }
}

1;
