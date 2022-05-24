package Carmel::Difftool;
use strict;
use warnings;

use Carton::Snapshot;
use CPAN::DistnameInfo;
use version;
use Class::Tiny;
use Capture::Tiny qw(capture);
use Path::Tiny;

use constant RED => 31;
use constant GREEN => 32;
use constant YELLOW => 33;
use constant PURPLE => 35;

sub should_color {
    -t STDOUT && !$ENV{NO_COLOR};
}

sub color {
    my($code, $text) = @_;
    return $text unless should_color();
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

    if ($Carmel::DEBUG) {
        $self->text_diff(\%dists);
    } else {
        $self->simple_diff(\%dists);
    }
}

sub text_diff {
    my($self, $dists) = @_;

    my @text;
    for my $dist (sort { lc($a) cmp lc($b) } keys %$dists) {
        for my $idx (0, 1) {
            if ($dists->{$dist}[$idx]) {
                $text[$idx] .= "$dist\n  " . $dists->{$dist}[$idx]->pathname . "\n";
            }
        }
    }

    $self->git_diff(@text);
}

sub git_diff {
    my($self, @text) = @_;

    my @files = map {
        my $temp = Path::Tiny->tempfile;
        $temp->spew($_);
        $temp;
    } @text;

    my @options;
    @options = ("--color") if should_color();

    my($stdout, $stderr, $code) = capture { system("git", "diff", @options, @files) };
    print $stdout;
}

sub simple_diff {
    my($self, $dists) = @_;

    for my $dist (sort { lc($a) cmp lc($b) } keys %$dists) {
        $self->dist_diff($dist, @{$dists->{$dist}});
    }
}

sub dist_diff {
    my($self, $dist, $old, $new) = @_;

    # unchanged
    return if $old && $new && $old->distvname eq $new->distvname;

    # added
    if (!$old && $new) {
        printf "%s %s (%s)\n",
          color(YELLOW, 'A'),
          $dist, color(GREEN, $new->version);
        return;
    }

    # deleted
    if ($old && !$new) {
        printf "%s %s (%s)\n",
          color(YELLOW, 'D'),
          $dist, color(RED, $old->version);
        return;
    }

    printf "%s %s (%s -> %s)\n",
      color(GREEN, 'M'),
      $dist, color(RED, $old->version), color(GREEN, $new->version);
}

1;
