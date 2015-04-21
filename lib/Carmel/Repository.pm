package Carmel::Repository;
use strict;
use version ();
use DirHandle;
use Carmel::Artifact;
use CPAN::Meta::Requirements;
use File::Copy::Recursive ();
use JSON ();

sub new {
    my($class, $path) = @_;
    my $self = bless {
        path => Path::Tiny->new($path),
    }, $class;
    $self->load_artifacts;
    $self;
}

sub path { $_[0]->{path} }

sub import_artifact {
    my($self, $dir) = @_;

    my $dest = $self->path->child($dir->basename);
    File::Copy::Recursive::dircopy($dir, $dest);

    $self->load($dest);
}

sub read_json {
    my $file = shift;
    JSON::decode_json($file->slurp);
}

sub load_artifacts {
    my $self = shift;
    return unless $self->path->exists;

    for my $ent ($self->path->children) {
        if ($ent->is_dir && $ent->child("blib")->exists) {
            $self->load($ent);
        }
    }
}

sub load {
    my($self, $dir) = @_;

    my $install = $self->_install_info($dir);
    while (my($package, $data) = each %{ $install->{provides} }) {
        $self->add($package, $dir, $data->{version}, $install);
    }
}

sub _install_info {
    my($self, $dir) = @_;

    my $file = $dir->child("blib/meta/install.json");
    if ($file->exists) {
        return read_json($file);
    }

    die "Could not read build artifact from $dir";
}

sub add {
    my($self, $package, $path, $version, $install) = @_;

    if (my $artifact = $self->lookup($package, $version)) {
        if ($self->_compare($install->{version}, $artifact->dist_version) > 0) {
            $self->{$package}{$version} = [ $path, $install ];
        }
    } else {
        $self->{$package}{$version} = [ $path, $install ];
    }
}

sub find {
    my($self, $package, $want_version) = @_;
    $self->_find($package, $want_version);
}

sub find_all {
    my($self, $package, $want_version) = @_;
    $self->_find($package, $want_version, 1);
}

sub _find {
    my($self, $package, $want_version, $all) = @_;

    # shortcut exact requirement
    if ($want_version =~ s/^==\s*//) {
        return $self->lookup($package, $want_version);
    }

    my $reqs = CPAN::Meta::Requirements->from_string_hash({ $package => $want_version });
    my @artifacts;

    for my $artifact ($self->list($package)) {
        if ($reqs->accepts_module($package, $artifact->version)) {
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

    # XXX room for optimizations
    map { $_->[1] }
      sort { $b->[0] <=> $a->[0] }
        map { [
            version::->parse($_ || '0'),
            Carmel::Artifact->new($package, $_, @{$self->{$package}{$_}})
            ] } keys %{$self->{$package}};
}

sub lookup {
    my($self, $package, $version) = @_;
    $version = version->parse($version)->numify;
    if ($self->{$package}{$version}) {
        return Carmel::Artifact->new($package, $version, @{$self->{$package}{$version}});
    }
    return;
}

sub _compare {
    my($self, $ver_a, $ver_b) = @_;

    my $ret = eval { version::->parse($ver_a) <=> version::->parse($ver_b) };
    if ($@) {
        # FIXME I'm sure there's a better/more correct way
        $ret = "$ver_a" cmp "$ver_b";
    }

    $ret;
}

1;
