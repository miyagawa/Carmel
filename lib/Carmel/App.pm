package Carmel::App;
use strict;
use warnings;

use Carmel;
use Carp ();
use Carmel::Repository;
use Config qw(%Config);
use CPAN::Meta::Requirements;
use Getopt::Long ();
use Module::CoreList;
use Module::CPANfile;
use Module::Metadata;
use Path::Tiny ();
use Pod::Usage ();
use Try::Tiny;

use Class::Tiny {
    verbose => sub { 0 },
    perl_arch => sub { "$Config{version}-$Config{archname}" },
};

our $UseSystem = 0; # unit testing

sub parse_options {
    my($self, $args) = @_;

    my $cmd;
    my $parser = Getopt::Long::Parser->new(
        config => [ "no_ignore_case", "pass_through" ],
    );
    $parser->getoptionsfromarray(
        $args,
        "h|help"      => sub { $cmd = 'help' },
        "version"     => sub { $cmd = 'version' },
        "v|verbose!"  => sub { $Carmel::DEBUG = $self->verbose($_[1]) },
    );

    unshift @$args, $cmd if $cmd;
}

sub run {
    my($self, @args) = @_;

    $self->parse_options(\@args);

    my $cmd = shift @args || 'install';
    my $call = $self->can("cmd_$cmd")
      or die "Could not find command '$cmd'";

    try {
        $self->$call(@args);
    } catch {
        warn $_;
        return 255;
    };

    return 0;
}

sub repository_base {
    my $self = shift;
    Path::Tiny->new($ENV{PERL_CARMEL_REPO} || "$ENV{HOME}/.carmel/" . $self->perl_arch);
}

sub cache_dir {
    my $self = shift;
    $self->repository_base->child("cache");
}

sub build_dir {
    my $self = shift;
    $self->repository_base->child("builds");
}

sub repo {
    my $self = shift;
    $self->{repo} ||= $self->build_repo;
}

sub build_repo {
    my $self = shift;
    Carmel::Repository->new(path => $self->build_dir);
}

sub cmd_help {
    my $self = shift;
    print "Carmel version $Carmel::VERSION\n\n";
    Pod::Usage::pod2usage(1);
}

sub cmd_version {
    my $self = shift;
    print "Carmel version $Carmel::VERSION\n";
}

sub cmd_install {
    my($self, @args) = @_;

    if (@args) {
        $self->install(@args);
    } else {
        $self->install_from_cpanfile(@args);
    }
}

sub install_from_cpanfile {
    my $self = shift;

    my $requirements = CPAN::Meta::Requirements->new;
    $self->resolve(
        sub {
            my($artifact) = @_;
            printf "Using %s (%s)\n", $artifact->package, $artifact->version || '0';
        },
        sub {
            my($module, $want_version) = @_;
            $requirements->add_string_requirement($module => $want_version);
        },
    );

    if (my @missing = $requirements->required_modules) {
        my $cpanfile = Module::CPANfile->from_prereqs({
            runtime => {
                requires => $requirements->as_string_hash,
            },
        });
        $self->install_with_cpanfile($cpanfile);
    }

    my @artifacts;
    $self->resolve(sub { push @artifacts, $_[0] });

    # $self->requirements has been upgraded at this point with the whole subreqs
    printf "---> Complete! %d cpanfile dependencies. %d modules installed.\n" .
      "---> Use `carmel show [module]` to see where a module is installed.\n",
      scalar(grep { $_ ne 'perl' } $self->build_requirements->required_modules), scalar(@artifacts);
}

sub is_core {
    my($self, $module, $want_version) = @_;

    return unless exists $Module::CoreList::version{$]+0}{$module};

    CPAN::Meta::Requirements->from_string_hash({ $module => $want_version })
        ->accepts_module($module, $Module::CoreList::version{$]+0}{$module} || '0');
}

sub install_with_cpanfile {
    my($self, $cpanfile) = @_;

    my $path = Path::Tiny->tempfile;
    $cpanfile->save($path);
    $self->install("--installdeps", "--cpanfile", $path, ".");
}

sub fatscript {
    my $self = shift;
    Module::Metadata->find_module_by_name("App::cpanminus::fatscript")
        or die "Can't locate App::cpanminus::fatscript";
}

sub install {
    my($self, @args) = @_;

    my $dir = Path::Tiny->tempdir;
    local $ENV{PERL_CPANM_HOME} = $dir;
    local $ENV{PERL_CPANM_OPT};
    system $^X, $self->fatscript, "--quiet", "--notest", "-L", $self->cache_dir, @args if @args;

    for my $ent ($dir->child("latest-build")->children) {
        next unless $ent->is_dir && $ent->child("blib/meta/install.json")->exists;
        $self->repo->import_artifact($ent);
    }
}

sub cmd_export {
    my($self) = @_;
    my %env = $self->env;
    print "export PATH=$env{PATH} PERL5LIB=$env{PERL5LIB}\n";
}

sub cmd_env {
    my($self) = @_;
    my %env = $self->env;
    print "PATH=$env{PATH}\nPERL5LIB=$env{PERL5LIB}\n";
}

sub cmd_exec {
    my($self, @args) = @_;
    my %env = $self->env;
    %ENV = (%ENV, %env);
    $UseSystem ? system(@args) : exec @args;
}

sub cmd_find {
    my($self, $module, $requirement) = @_;

    my @artifacts = $self->repo->find_all($module, $requirement || '0');
    for my $artifact (@artifacts) {
        printf "%s (%s) in %s\n", $artifact->package, $artifact->version || '0', $artifact->path;
    }
}

sub cmd_show {
    my $self = shift;
    $self->cmd_list(@_);
}

sub cmd_list {
    my($self, @args) = @_;

    if (my $module = shift @args) {
        $self->show_module($module);
        return;
    }

    my @artifacts;
    $self->resolve(sub { push @artifacts, $_[0] });

    for my $artifact (sort { $a->package cmp $b->package } @artifacts) {
        printf "%s (%s)\n", $artifact->package, $artifact->version || '0';
    }
}

sub show_module {
    my($self, $module) = @_;

    eval {
        $self->resolve(sub {
            my $artifact = shift;
            if ($module eq $artifact->package) {
                printf "%s (%s) in %s\n", $artifact->package, $artifact->version || '0', $artifact->path;
                die "__FOUND__\n";
            }
        });
        die "Could not find a module named '$module' in the cpanfile dependencies.\n";
    };

    die $@ if $@ && $@ ne "__FOUND__\n";
}

sub cmd_tree {
    my($self) = @_;

    $self->resolve(sub {
        my($artifact, $depth) = @_;
        printf "%s%s (%s)\n", (" " x $depth), $artifact->package, $artifact->version || '0';
    });

}

sub cmd_index {
    my $self = shift;
    $self->write_index(*STDOUT);
}

sub write_index {
    my($self, $fh) = @_;

    require Carton::Index;
    require Carton::Package;

    my $index = Carton::Index->new(generator => "Carmel $Carmel::VERSION");

    $self->resolve(sub {
        my $artifact = shift;
        while (my($pkg, $data) = each %{$artifact->install->{provides}}) {
            my $package = Carton::Package->new($pkg, $data->{version} || 'undef', $artifact->install->{pathname});
            $index->add_package($package);
        }
    });

    $index->write($fh);
}

sub try_snapshot {
    my $self = shift;

    if (my $cpanfile = $self->try_cpanfile) {
        return "$cpanfile.snapshot" if -e "$cpanfile.snapshot";
    }
    return;
}

sub try_cpanfile {
    my $self = shift;
    return $ENV{PERL_CARMEL_CPANFILE} if $ENV{PERL_CARMEL_CPANFILE};
    return 'cpanfile' if -e 'cpanfile';
    return;
}

sub requirements {
    my $self = shift;
    $self->{requirements} ||= $self->build_requirements;
}

sub build_requirements {
    my $self = shift;

    my $cpanfile = $self->try_cpanfile
      or Carp::croak "Could not locate 'cpanfile' to load module list.";

    my $requirements = Module::CPANfile->load($cpanfile)
      ->prereqs->merged_requirements(['runtime', 'test'], ['requires']);

    if (my $snapshot = $self->try_snapshot) {
        require Carton::Snapshot;
        my $snapshot = Carton::Snapshot->new(path => $snapshot);
        $self->apply_snapshot($requirements, $snapshot);
    }

    $requirements;
}

sub apply_snapshot {
    my($self, $requirements, $snapshot) = @_;
    $snapshot->load;
    $self->apply_snapshot_recursively($requirements, $snapshot, [$requirements->required_modules]);
}

sub apply_snapshot_recursively {
    my($self, $requirements, $snapshot, $modules) = @_;

    for my $module (@$modules) {
        my $dist = $snapshot->find($module) or next;
        my $version = $dist->version_for($module);
        # FIXME in carmel update, conflicting version requirement should be ignored
        $requirements->exact_version($module, $version);
        $requirements->add_requirements($dist->requirements);
        $self->apply_snapshot_recursively($requirements, $snapshot, [$dist->requirements->required_modules]);
    }
}

sub resolve_recursive {
    my($self, $root_reqs, $requirements, $seen, $cb, $missing_cb, $depth) = @_;

    # TODO rather than mutating $root_reqs directly, we should create a new object
    # that allows accessing the result $requirements
    for my $module (sort $requirements->required_modules) {
        next if $module eq 'perl';

        my $want_version = $root_reqs->requirements_for_module($module);
        next if $self->is_core($module, $want_version);

        warn "$depth: Resolving $module ($want_version)\n" if $self->verbose;

        # FIXME there's a chance different version of the same module can be loaded here
        if (my $artifact = $self->repo->find($module, $want_version)) {
            warn sprintf "=> %s (%s) in %s\n", $module, $artifact->version_for($module), $artifact->path if $self->verbose;
            next if $seen->{$artifact->path}++;
            $cb->($artifact, $depth);

            my $reqs = $artifact->requirements;
            $root_reqs->add_requirements($reqs);

            $self->resolve_recursive($root_reqs, $reqs, $seen, $cb, $missing_cb, $depth + 1);
        } else {
            $missing_cb->($module, $want_version, $depth);
        }
    }
}

sub resolve {
    my($self, $cb, $missing_cb) = @_;
    $missing_cb ||= sub {
        my($module, $want_version, $depth) = @_;
        die "Could not find an artifact for $module => $want_version\nYou need to run `carmel install` first to get the modules installed and artifacts built.\n";
    };
    $self->resolve_recursive($self->requirements, $self->requirements->clone, {}, $cb, $missing_cb, 0);
}

sub env {
    my($self) = @_;

    my @artifacts;
    $self->resolve(sub { push @artifacts, $_[0] });
    return (
        _join(PATH => map $_->paths, @artifacts),
        _join(PERL5LIB => map $_->libs, @artifacts),
    );
}

sub _join {
    my($env, @list) = @_;
    push @list, $ENV{$env} if $ENV{$env};
    return ($env => join(":", @list));
}

1;
