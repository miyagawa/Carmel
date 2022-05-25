package Carmel::Builder;
use strict;
use warnings;
use Class::Tiny qw( snapshot cpanfile cpanfile_path repository_base collect_artifact ), {
    mirror => sub { $_[0]->build_mirror },
};

use Carmel;
use Path::Tiny;
use File::pushd;
use Carmel::Lock;
use Carton::Dist;
use CPAN::DistnameInfo;
use Menlo::Index::Mirror;
use HTTP::Tinyish;

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

sub build_mirror {
    my $self = shift;

    # FIXME: we could set the mirror option to $self->cpanfile in the caller
    my $cpanfile = $self->cpanfile_path
      or die "Can't locate 'cpanfile' to load module list.\n";

    # one mirror for now
    Module::CPANfile->load($cpanfile)->mirrors->[0];
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
    }

    local $ENV{PERL_CPANM_HOME} = $self->tempdir;
    local $ENV{PERL_CPANM_OPT};

    my $mirror = $self->mirror;

    my $lock = Carmel::Lock->new(path => $self->repository_base->child('run'));
    $lock->acquire;

    # cleanup perl5 in case it was left from previous runs
    my $lib = $self->repository_base->child('perl5');
    $lib->remove_tree({ safe => 0 });

    require Menlo::CLI::Compat;

    my $cli = Menlo::CLI::Compat->new;
    $cli->parse_options(
        ($Carmel::DEBUG ? () : "--quiet"),
        ($mirror ? ("-M", $mirror) : ("--mirror", "https://cpan.metacpan.org/")),
        "--notest",
        "--save-dists", $self->repository_base->child('cache'),
        "-L", $lib,
        "--no-static-install",
        @cmd,
    );

    $cli->run;

    my @artifacts;
    for my $ent ($self->tempdir->child("latest-build")->children) {
        next unless $ent->is_dir && $ent->child("blib/meta/install.json")->exists;
        push @artifacts, $self->collect_artifact->($ent);
    }

    $lib->remove_tree({ safe => 0 });

    return @artifacts;
}

sub search_module {
    my($self, $module, $version) = @_;

    local $ENV{PERL_CPANM_HOME} = $self->tempdir;
    local $ENV{PERL_CPANM_OPT};

    my $cli = $self->cached_cli;

    if ($version && $version =~ /==|<|!/) {
        my $dist = $cli->search_module($module, $version)
          or return;

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
    } else {
        my $res = $self->index->search_packages({ package => $module })
          or return;

        (my $path = $res->{uri}) =~ s!^cpan:///distfile/!!;
        my $info = CPAN::DistnameInfo->new($path);

        return Carton::Dist->new(
            name => $info->distvname,
            pathname => $info->pathname,
            provides => {
                $res->{package} => {
                    version => $res->{version},
                },
            },
            version => $info->version,
        );
    }
}

sub cached_cli {
    my $self = shift;
    $self->{cli} ||= $self->build_cli();
}

sub build_cli {
    my $self = shift;

    my $mirror = $self->mirror;

    require Menlo::CLI::Compat;

    my $cli = Menlo::CLI::Compat->new;
    $cli->parse_options(
        ($Carmel::DEBUG ? () : "--quiet"),
        ($mirror ? ("-M", $mirror) : ()),
        "--info",
        "--save-dists", $self->repository_base->child('cache'),
        ".",
    );

    # This needs to be done to setup http backends for mirror #52
    $cli->setup_home;
    $cli->init_tools;

    return $cli;
}

sub index {
    my $self = shift;
    $self->{index} ||= $self->build_index;
}

sub build_index {
    my $self = shift;

    my $mirror = $self->mirror || "https://cpan.metacpan.org/";

    # Use $cli->mirror to support file: URLs
    return Menlo::Index::Mirror->new({
        mirror  => $mirror,
        fetcher => sub { $self->cached_cli->mirror(@_) },
    });
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
