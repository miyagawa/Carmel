package Carmel::Builder;
use strict;
use warnings;
use Class::Tiny qw( snapshot cpanfile cpanfile_path repository_base collect_artifact );
use Path::Tiny;
use File::pushd;

sub tempdir {
    my $self = shift;
    $self->{tempdir} ||= $self->build_tempdir;
}

sub build_tempdir {
    my %opts = ();
    $opts{CLEANUP} = $ENV{PERL_FILE_TEMP_CLEANUP}
      if exists $ENV{PERL_FILE_TEMP_CLEANUP};

    Path::Tiny->tempdir(%opts);
}

sub install {
    my($self, @args) = @_;

    my @cmd;
    if ($self->cpanfile) {
        my $path = Path::Tiny->tempfile;
        $self->cpanfile->save($path);
        @cmd = ("--cpanfile", $path, "--installdeps", ".");
    } else {
        @cmd = @args;
    }

    if ($self->snapshot) {
        my $path = Path::Tiny->tempfile;
        $self->snapshot->write_index($path);
        unshift @cmd,
          "--mirror-index", $path,
          "--cascade-search",
          "--mirror", "http://cpan.metacpan.org";
    }

    local $ENV{PERL_CPANM_HOME} = $self->tempdir;
    local $ENV{PERL_CPANM_OPT};

    my $cpanfile = $self->cpanfile_path
      or die "Can't locate 'cpanfile' to load module list.\n";

    # one mirror for now
    my $mirror = Module::CPANfile->load($cpanfile)->mirrors->[0];

    # cleanup perl5 in case it was left from previous runs
    my $lib = $self->repository_base->child('perl5');
    $lib->remove_tree({ safe => 0 });

    require Menlo::CLI::Compat;

    my $cli = Menlo::CLI::Compat->new;
    $cli->parse_options(
        ($Carmel::DEBUG ? () : "--quiet"),
        ($mirror ? ("-M", $mirror) : ()),
        "--notest",
        "--save-dists", $self->repository_base->child('cache'),
        "-L", $lib,
        "--no-static-install",
        @cmd,
    );

    $cli->run;

    for my $ent ($self->tempdir->child("latest-build")->children) {
        next unless $ent->is_dir && $ent->child("blib/meta/install.json")->exists;
        $self->collect_artifact->($ent);
    }

    $lib->remove_tree({ safe => 0 });
}

sub search_module {
    my($self, $module, $version) = @_;

    local $ENV{PERL_CPANM_HOME} = $self->tempdir;
    local $ENV{PERL_CPANM_OPT};

    my $cpanfile = $self->cpanfile_path
      or die "Can't locate 'cpanfile' to load module list.\n";

    # one mirror for now
    my $mirror = Module::CPANfile->load($cpanfile)->mirrors->[0];

    require Menlo::CLI::Compat;
    require Carton::Dist;

    my $cli = Menlo::CLI::Compat->new;
    $cli->parse_options(
        ($Carmel::DEBUG ? () : "--quiet"),
        ($mirror ? ("-M", $mirror) : ()),
        "--info",
        "--save-dists", $self->repository_base->child('cache'),
        ".",
    );

    my $dist = $cli->search_module($module, $version);
    if ($dist) {
        return Carton::Dist->new(
            name => $dist->{distvname},
            pathname => $dist->{pathname},
            provides => {
                $dist->{module} => {
                    version => $dist->{module_version},
                },
            },
            version => $dist->{version},
        );
    }

    return;
}

sub rollout {
    my($self, $install_base, $artifacts) = @_;

    require ExtUtils::Install;
    require ExtUtils::InstallPaths;

    for my $artifact (@$artifacts) {
        my $dir = pushd $artifact->path;

        my $paths = ExtUtils::InstallPaths->new(install_base => $install_base);

        printf "Installing %s to %s\n", $artifact->distname, $install_base;

        # ExtUtils::Install writes to STDOUT
        open my $fh, ">", \my $output;
        my $old; $old = select $fh unless $Carmel::DEBUG;

        my %result;
        ExtUtils::Install::install([
            from_to => $paths->install_map,
            verbose => 0,
            dry_run => 0,
            uninstall_shadows => 0,
            skip => undef,
            always_copy => 1,
            result => \%result,
        ]);

        select $old unless $Carmel::DEBUG;
    }
}

1;
