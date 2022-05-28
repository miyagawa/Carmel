package Carmel::Repository;
use strict;
use version ();
use DirHandle;
use Carmel::Artifact;
use CPAN::Meta::Requirements;
use File::Copy::Recursive ();

use Class::Tiny qw( packages );

sub BUILD {
    my($self, $args) = @_;
    $self->path($args->{path});
    $self->packages({});
}

sub path {
    my $self = shift;
    if (@_ ){
        $self->{path} = Path::Tiny->new($_[0]);
    } else {
        $self->{path};
    }
}

sub import_artifact {
    my($self, $dir) = @_;

    my $dest = $self->path->child($dir->basename);

    local $File::Copy::Recursive::RMTrgDir = 2;
    File::Copy::Recursive::dircopy($dir, $dest)
      or die "Failed copying $dir -> $dest";

    return $self->load($dest);
}

sub load_artifacts {
    my $self = shift;
    return unless $self->path->exists;

    for my $ent ($self->path->children) {
        if ($ent->is_dir && $ent->child("blib")->exists) {
            warn "-> Loading artifact from $ent\n" if $Carmel::DEBUG;
            $self->load($ent);
        }
    }
}

sub load {
    my($self, $dir) = @_;

    my $artifact = Carmel::Artifact->load($dir);
    while (my($package, $data) = each %{ $artifact->provides }) {
        $self->add($package, $artifact);
    }

    return $artifact;
}

sub add {
    my($self, $package, $artifact) = @_;
    push @{$self->{packages}{$package}}, $artifact;
}

sub find {
    my($self, $package, $want_version) = @_;
    $self->_find($package, $want_version);
}

sub find_all {
    my($self, $package, $want_version) = @_;
    $self->_find($package, $want_version, 1);
}

sub find_dist {
    my($self, $package, $distname) = @_;

    my $dir = $self->path->child($distname);
    if ($dir->exists) {
        return Carmel::Artifact->load($dir);
    }

    return $self->find_match($package, sub { $_[0]->distname eq $distname });
}

sub find_match {
    my($self, $package, $cb) = @_;

    for my $artifact ($self->list($package)) {
        return $artifact if $cb->($artifact);
    }

    return;
}

sub _find {
    my($self, $package, $want_version, $all) = @_;

    my $reqs = CPAN::Meta::Requirements->from_string_hash({ $package => $want_version });
    my @artifacts;

    for my $artifact ($self->list($package)) {
        if ($reqs->accepts_module($package, $artifact->version_for($package))) {
            if ($all) {
                push @artifacts, $artifact;
            } else {
                return $artifact;
            }
        }
    }

    return @artifacts if $all;
    return;
}

sub list {
    my($self, $package) = @_;

    $self->load_artifacts unless $self->{_loaded}++;

    map { $_->[2] }
      sort { $b->[0] <=> $a->[0] || $b->[1] <=> $a->[1] } # sort by the package version, then the main package version
        map { [ $_->version_for($package), $_->version, $_ ] }
          @{$self->{packages}{$package}};
}

1;
