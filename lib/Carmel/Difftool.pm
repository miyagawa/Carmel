package Carmel::Difftool;
use strict;
use warnings;

use Carton::Snapshot;
use CPAN::DistnameInfo;
use version;
use Class::Tiny {
    env => sub { Carmel::Environment->new },
};

use Capture::Tiny qw(capture);
use Path::Tiny;

use constant RED => 31;
use constant GREEN => 32;
use constant YELLOW => 33;

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

    # TODO support simple diff
    # $self->simple_diff(\%dists);

    my $fh = $self->pager_output;

    for my $dist (sort { lc($a) cmp lc($b) } keys %dists) {
        $self->dist_diff($fh, $dist, @{$dists{$dist}});
    }
}

sub dist_diff {
    my($self, $fh, $dist, $old, $new) = @_;

    my @dists = ($old->distvname, $new->distvname);

    # show only modified
    return unless $old && $new && $dists[0] ne $dists[1];

    # TODO: find_dist() could fail when distvname contains TRIAL #84
    my @artifacts = map $self->env->repo->find_dist('', $_), @dists;
    unless (@artifacts == 2) {
        die "Couldn't find artifacts for ", join(", ", @dists), "\n";
    }

    # TODO: support full diffs including t/?
    my @paths;
    if (my $changes = $self->locate_changes($artifacts[0]->path)) {
        push @paths, [ map $_->path->child($changes), @artifacts ];
    }

    push @paths, [ map $_->path->child('blib/lib'), @artifacts ];

    my @options;
    @options = ("--color") if should_color();

    for my $pairs (@paths) {
        my($stdout, $stderr, $code) = capture { system("git", "diff", @options, @$pairs) };
        print $fh $stdout;
    }
}

sub locate_changes {
    my($self, $path) = @_;

    my $found;

    $path->visit(sub {
        my($f, $state) = @_;

        if ($f->is_file && $f->basename =~ /^(?:Changes|Changelog|History)\b/i) {
            $found = $f;
        }
    });

    return $found->basename;
}

sub pager_output {
    my $self = shift;

    # stdout is not tty
    return \*STDOUT if !-t STDOUT;

    my $pager = $ENV{PERL_CARMEL_PAGER} || $ENV{PAGER};
    return \*STDOUT unless $pager;

    open my $fh, "|-", $pager;
    return $fh;
}

sub simple_diff {
    my($self, $dists) = @_;

    for my $dist (sort { lc($a) cmp lc($b) } keys %$dists) {
        $self->simple_dist_diff($dist, @{$dists->{$dist}});
    }
}

sub simple_dist_diff {
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

1;
