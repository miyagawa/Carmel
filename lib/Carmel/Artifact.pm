package Carmel::Artifact;
use strict;
use Carmel::Patch;
use CPAN::Meta;
use JSON ();
use Path::Tiny ();

sub load {
    my($class, $dir) = @_;

    my $path = Path::Tiny->new($dir);
    my $patch = Carmel::Patch->lookup($path->basename);

    my $self = bless { path => $path }, $patch || $class;
    $self->init();
    $self;
}

sub init {}

sub path { $_[0]->{path} }

sub install {
    my $self = shift;
    $self->{install} ||= $self->_build_install;
}

sub _build_install {
    my $self = shift;

    my $file = $self->path->child("blib/meta/install.json");
    if ($file->exists) {
        return JSON::decode_json($file->slurp);
    }

    die "Can't read build artifact from ", $self->path;
}

sub provides {
    my $self = shift;
    $self->install->{provides};
}

# "cpanm" => ".../blib/script/cpanm"
sub executables {
    my $self = shift;
    $self->_find_files(sub { shift !~ /\.exists$/ }, $self->paths);
}

# "Foo/Bar.pm" => ".../blib/lib/Foo/Bar.pm"
sub module_files {
    my $self = shift;
    $self->_find_files(sub { shift =~ /\.pm$/ }, $self->libs);
}

sub _find_files {
    my($self, $what, @dirs) = @_;

    my %found;
    for my $dir (@dirs) {
        $dir->visit(
            sub {
                my($path, $state) = @_;
                if ($path->is_file && $what->($path)) {
                    $found{$path->relative($dir)->stringify} = $path;
                }
                return; # continue
            },
            { recurse => 1 },
        );
    }

    %found;
}

sub package {
    my $self = shift;
    $self->install->{name};
}

sub version {
    my $self = shift;
    $self->version_for($self->package);
}

sub version_for {
    my($self, $package) = @_;
    version::->parse( $self->provides->{$package}{version} || '0' );
}

sub distname {
    $_[0]->path->basename;
}

sub dist_version {
    $_[0]->install->{version};
}

sub blib {
    $_[0]->path->child("blib");
}

sub paths {
    my $self = shift;
    ($self->blib->child("script"), $self->blib->child("bin"));
}

sub libs {
    my $self = shift;
    ($self->blib->child("arch"), $self->blib->child("lib"));
}

sub nonempty_paths {
    my $self = shift;
    grep $self->_nonempty($_), $self->paths;
}

sub nonempty_libs {
    my $self = shift;
    grep $self->_nonempty($_), $self->libs;
}

sub sharedir_libs {
    my $self = shift;
    grep $_->child('auto/share')->exists, $self->libs;
}

sub meta {
    my $self = shift;
    $self->{meta} ||= CPAN::Meta->load_file($self->path->child("MYMETA.json"));
}

sub requirements {
    my $self = shift;
    $self->requirements_for([qw( configure build runtime )], ['requires']);
}

sub requirements_for {
    my($self, $phases, $types) = @_;
    $self->meta->effective_prereqs->merged_requirements($phases, $types);
}

sub _nonempty {
    my($self, $path) = @_;

    my $bool;
    $path->visit(
        sub {
            my($path, $state) = @_;
            if ($path->is_file && $path !~ /\.exists$/) {
                $bool = 1;
                return \0;
            }
        },
        { recurse => 1 },
    );

    return $bool;
}

1;
