package Carmel::App;
use strict;
use warnings;

use Carmel;
use Carmel::Runner;
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
use File::pushd;
use Try::Tiny;

use Class::Tiny {
    verbose => sub { 0 },
    perl_arch => sub { "$Config{version}-$Config{archname}" },
    runner => sub { Carmel::Runner->new },
};

sub parse_options {
    my($self, $args) = @_;

    return if $args->[0] && $args->[0] eq 'exec';

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
      or die "Could not find command '$cmd': run `carmel help` to see the list of commands.\n";

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

sub repo {
    my $self = shift;
    $self->{repo} ||= $self->build_repo;
}

sub build_repo {
    my $self = shift;
    Carmel::Repository->new(path => $self->repository_base->child('builds'));
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
        $self->install("--reinstall", @args);
    } else {
        $self->install_from_cpanfile(@args);
    }

    $self->dump_bootstrap;
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
      scalar(grep { $_ ne 'perl' } $self->build_requirements(1)->required_modules), scalar(@artifacts);
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
    system $^X, $self->fatscript,
      ($self->verbose ? () : "--quiet"),
      "--notest",
      "--save-dists", $self->repository_base->child('cache'),
      "-L", $self->repository_base->child('perl5'),
      @args;

    for my $ent ($dir->child("latest-build")->children) {
        next unless $ent->is_dir && $ent->child("blib/meta/install.json")->exists;
        $self->repo->import_artifact($ent);
    }
}

sub quote {
    require Data::Dump;

    my $value = transform(@_);
    if (ref $value) {
        Data::Dump::dump($value);
    } else {
        Data::Dump::quote($value);
    }
}

sub transform {
    my $data = shift;

    # stringify elements
    if (ref $data eq 'ARRAY') {
        [map transform($_), @$data];
    } elsif (ref $data eq 'HASH') {
        my %value = map { $_ => transform($data->{$_}) } keys %$data;
        \%value;
    } else {
        "$data";
    }
}

sub dump_bootstrap {
    my($self) = @_;

    my @artifacts;
    $self->resolve(sub { push @artifacts, $_[0] });

    my @inc  = map $_->nonempty_libs, @artifacts;
    my @path = map $_->nonempty_paths, @artifacts;

    my %modules;
    for my $artifact (@artifacts) {
        %modules = (%modules, %{$artifact->module_files});
    }

    my $cpanfile = $self->try_cpanfile
      or Carp::croak "Could not locate 'cpanfile' to load module list.";

    my $prereqs = Module::CPANfile->load($cpanfile)->prereqs->as_string_hash;
    my $bootstrap = "MyBootstrap"; # hide from PAUSE

    my $file = Path::Tiny->new(".carmel/MyBootstrap.pm");
    $file->parent->mkpath;
    $file->spew(<<EOF);
# This file serves dual purpose to load cached data in carmel exec setup phase
# as well as on runtime to change \@INC
package $bootstrap;
use Carmel::Runtime;

# for carmel exec setup
my %environment = (
inc     => @{[ quote \@inc ]},
path    => @{[ quote \@path ]},
base    => @{[ quote(Path::Tiny->cwd) ]},
modules => @{[ quote \%modules ]},
prereqs => @{[ quote $prereqs ]},
);

Carmel::Runtime->environment(\\\%environment);

# for carmel exec runtime
sub import {
  Carmel::Runtime->bootstrap;
}

1;
EOF
}

sub cmd_export {
    my($self) = @_;
    my %env = $self->runner->env;
    print "export ", join(" ", map qq($_="$env{$_}"), keys %env), "\n";
}

sub cmd_env {
    my($self) = @_;
    my %env = $self->runner->env;
    print join "", map qq($_=$env{$_}\n), keys %env;
}

# TODO remove. just here for testing
sub cmd_exec {
    my($self, @args) = @_;
    $self->runner->execute(@args);
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

sub cmd_rollout {
    my $self = shift;

    require ExtUtils::Install;
    require ExtUtils::InstallPaths;

    my @artifacts;
    $self->resolve(sub { push @artifacts, $_[0] });

    my $install_base = Path::Tiny->new("local")->absolute;
    $install_base->remove_tree({ safe => 0 }) if $install_base->exists;

    for my $artifact (@artifacts) {
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

    Path::Tiny->new(".carmel/MyBootstrap.pm")->copy("local/lib/perl5/MyBootstrap.pm");
}

sub cmd_package {
    my $self = shift;

    my $index = $self->build_index;

    my $source_base = $self->repository_base->child('cache');
    my $target_base = Path::Tiny->new('vendor/cache');

    my %done;
    my $success = 0;
    for my $package ($index->packages) {
        next if $done{$package->pathname}++;

        my $source = $source_base->child('authors/id', $package->pathname);
        my $target = $target_base->child('authors/id', $package->pathname);

        if ($source->exists) {
            print "Copying ", $package->pathname, "\n";
            $target->parent->mkpath;
            $source->copy($target);
            $success++;
        } else {
            require File::Fetch;
            print "Fetching ", $package->pathname, " from CPAN.\n";
            my $fetch = File::Fetch->new(uri => "http://www.cpan.org/authors/id/" . $package->pathname);
            $fetch->fetch(to => $target->parent) or warn $fetch->error;
        }
    }

    require IO::Compress::Gzip;
    my $index_file = $target_base->child('modules/02packages.details.txt.gz');
    $index_file->parent->mkpath;

    warn "Writing $index_file\n";
    my $out = IO::Compress::Gzip->new($index_file->openw)
      or die "gzip failed: $IO::Compress::Gzip::GzipError";
    $index->write($out);

    print "---> Complete! $success distributions are packaged in vendor/cache\n";
}

sub cmd_index {
    my $self = shift;
    $self->build_index->write(*STDOUT);
}

sub build_index {
    my $self = shift;

    require Carton::Index;
    require Carton::Package;

    my $index = Carton::Index->new(generator => "Carmel $Carmel::VERSION");

    $self->resolve(sub {
        my $artifact = shift;
        while (my($pkg, $data) = each %{$artifact->provides}) {
            my $package = Carton::Package->new($pkg, $data->{version} || 'undef', $artifact->install->{pathname});
            $index->add_package($package);
        }
    });

    $index;
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
    my($self, $skip_snapshot) = @_;

    my $cpanfile = $self->try_cpanfile
      or Carp::croak "Could not locate 'cpanfile' to load module list.";

    my $requirements = Module::CPANfile->load($cpanfile)
      ->prereqs->merged_requirements(['runtime', 'test', 'develop'], ['requires']);

    return $requirements if $skip_snapshot;

    if (my $snapshot = $self->try_snapshot) {
        require Carton::Snapshot;
        my $snapshot = Carton::Snapshot->new(path => $snapshot);
        $self->apply_snapshot($requirements, $snapshot);
    }

    $requirements;
}

sub merge_requirements {
    my($self, $reqs, $new_reqs, $where) = @_;

    for my $module ($new_reqs->required_modules) {
        my $new = $new_reqs->requirements_for_module($module);
        try {
            $reqs->add_string_requirement($module, $new);
        } catch {
            my($err) = /illegal requirements: (.*) at/;
            my $old = $reqs->requirements_for_module($module);
            die "Found conflicting requirement for $module: '$old' <=> '$new' ($where): $err";
        };
    }
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
        $self->merge_requirements($requirements, $dist->requirements, $dist->name);
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
            warn sprintf "   %s (%s) in %s\n", $module, $artifact->version_for($module), $artifact->path if $self->verbose;
            next if $seen->{$artifact->path}++;
            $cb->($artifact, $depth);

            my $reqs = $artifact->requirements;
            $self->merge_requirements($root_reqs, $reqs, $artifact->distname);

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

1;
