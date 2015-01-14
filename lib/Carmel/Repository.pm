package Carmel::Repository;
use strict;
use version ();
use DirHandle;
use Carmel::Artifact;
use CPAN::Meta::Requirements;
use JSON ();

sub new {
    my $class = shift;
    bless {}, $class;
}

sub read_json {
    my $file = shift;
    open my $fh, "<", $file or die "$file: $!";
    JSON::decode_json(join '', <$fh>);
}

sub load {
    my($self, $dir) = @_;

    my $dh = DirHandle->new($dir) or return;
    while (my $ent = $dh->read) {
        next unless -d "$dir/$ent" && -e "$dir/$ent/blib";

        my $install = $self->_install_info("$dir/$ent");
        while (my($package, $data) = each %{ $install->{provides} }) {
            $self->add($package, "$dir/$ent", $data->{version}, $install->{version});
        }
    }
}

sub _install_info {
    my($self, $dir) = @_;

    my $file = "$dir/blib/meta/install.json";

    # cpanm build artifact
    if (-e $file) {
        return read_json($file);
    }

    # CPAN.pm build artifact
    if (-e "$dir.yml") {
        require Carmel::InstallInfo;
        Carmel::InstallInfo->build($dir, $file);
        return read_json($file);
    }

    die "Could not read build artifact from $dir";
}

sub add {
    my($self, $package, $path, $version, $dist_version) = @_;

    if (my $artifact = $self->lookup($package, $version)) {
        if ($self->_compare($dist_version, $artifact->dist_version) > 0) {
            $self->{$package}{$version} = [ $path, $dist_version ];
        }
    } else {
        $self->{$package}{$version} = [ $path, $dist_version ];
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
