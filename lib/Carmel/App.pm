package Carmel::App;
use strict;
use warnings;

use Carp ();
use Carmel::Repository;

sub new {
    my $class = shift;
    bless {}, $class;
}

sub run {
    my($self, @args) = @_;

    my $cmd = shift @args || 'install';
    my $call = $self->can("cmd_$cmd")
      or die "Could not find command '$cmd'";

    $self->$call(@args);
}

sub temp_dir {
    ($ENV{TMPDIR} || "/tmp") . "/carmel-" . time() . "." . $$;
}

sub repository_path {
    my $self = shift;
    $ENV{PERL_CARMEL_REPO}
      || (($ENV{PERL_CPANM_HOME} || "$ENV{HOME}/.cpanm") . "/builds");
}

sub build_repo {
    my $self = shift;
    my $repo = Carmel::Repository->new;
    $repo->load($self->repository_path);
    $repo;
}

sub cmd_install {
    my($self, @modules) = @_;

    my @args = @modules ? @modules : ("--installdeps", ".");
    system $^X, "-S", "cpanm", "--reinstall", "-L", $self->temp_dir, @args;
}

sub cmd_export {
    my($self, @args) = @_;
    my %env = $self->env;
    print STDOUT "export PATH=$env{PATH} PERL5LIB=$env{PERL5LIB}\n";
}

sub cmd_env {
    my($self, @args) = @_;
    my %env = $self->env;
    print STDOUT "PATH=$env{PATH}\nPERL5LIB=$env{PERL5LIB}\n";
}

sub cmd_exec {
    my($self, @args) = @_;
    my %env = $self->env;
    %ENV = (%env, %ENV);
    exec @args;
}

sub cmd_find {
    my($self, $module, $requirement) = @_;

    my @artifacts = $self->build_repo->find_all($module, $requirement || '0');
    for my $artifact (@artifacts) {
        printf "%s (%s) at %s\n", $artifact->package, $artifact->version || '0', $artifact->path;
    }
}

sub cmd_list {
    my($self, $module, $want) = @_;

    for my $artifact ($self->resolve) {
        printf "%s (%s) at %s\n", $artifact->package, $artifact->version || '0', $artifact->path;
    }
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

sub build_requirements {
    my($self, @args) = @_;

    # TODO support more explicit way to load the list of modules

    if (my $snapshot = $self->try_snapshot) {
        require Carton::Snapshot;
        my $snapshot = Carton::Snapshot->new(path => $snapshot);
        return $self->snapshot_to_requirements($snapshot);
    }

    if (my $cpanfile = $self->try_cpanfile) {
        require Module::CPANfile;
        return Module::CPANfile->load($cpanfile)->prereqs->merged_requirements;
    }

    return;
}

sub snapshot_to_requirements {
    my($self, $snapshot) = @_;

    $snapshot->load;

    my $requirements = CPAN::Meta::Requirements->new;
    for my $package ($snapshot->packages) {
        if ($package->version && $package->version ne 'undef') {
            $requirements->exact_version($package->name, $package->version);
        } else {
            $requirements->add_minimum($package->name, '0');
        }
    }

    $requirements;
}

sub resolve {
    my($self, $requirements) = @_;

    $requirements ||= $self->build_requirements
      or Carp::croak "Could not locate 'cpanfile' to load module list.";

    my $repo = $self->build_repo;

    my(@artifacts, %seen);

    for my $module ($requirements->required_modules) {
        next if $module eq 'perl';
        my $want_version = $requirements->requirements_for_module($module);
        if (my $artifact = $repo->find($module, $want_version, $requirements)) {
            next if $seen{$artifact->path}++;
            push @artifacts, $artifact;
            # TODO: recurse into $artifact's own runtime dependencies
        } else {
            Carp::carp "Could not find an artifact for $module => $want_version";
        }
    }

    return @artifacts;
}

sub env {
    my($self, @args) = @_;

    my @artifacts = $self->resolve(@args);
    return (
        PATH => join(":", (map $_->paths, @artifacts), ($ENV{PATH} || '')),
        PERL5LIB => join(":", (map $_->libs, @artifacts), ($ENV{PERL5LIB} || '')),
    );
}

1;
