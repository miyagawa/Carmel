package Carmel::Builder;
use strict;
use warnings;
use Class::Tiny qw( snapshot cpanfile cpanfile_path repository_base collect_artifact verbose );
use Path::Tiny;
use File::pushd;

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

    my %file_temp = ();
    $file_temp{CLEANUP} = $ENV{PERL_FILE_TEMP_CLEANUP}
      if exists $ENV{PERL_FILE_TEMP_CLEANUP};

    my $dir = Path::Tiny->tempdir(%file_temp);
    local $ENV{PERL_CPANM_HOME} = $dir;
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
        ($self->verbose ? () : "--quiet"),
        ($mirror ? ("-M", $mirror) : ()),
        "--notest",
        "--save-dists", $self->repository_base->child('cache'),
        "-L", $lib,
        "--no-static-install",
        @cmd,
    );

    $cli->run;

    for my $ent ($dir->child("latest-build")->children) {
        next unless $ent->is_dir && $ent->child("blib/meta/install.json")->exists;
        $self->collect_artifact->($ent);
    }

    $lib->remove_tree({ safe => 0 });
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
        my $old; $old = select $fh unless $self->verbose;

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

        select $old unless $self->verbose;
    }
}

1;
