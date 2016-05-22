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
      or die "Can't find command '$cmd': run `carmel help` to see the list of commands.\n";

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

    my $home = $ENV{HOME} || $ENV{HOMEPATH};
    Path::Tiny->new($ENV{PERL_CARMEL_REPO} || "$home/.carmel/" . $self->perl_arch);
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

sub cmd_inject {
    my($self, @args) = @_;
    $self->install("--reinstall", @args);
}

sub cmd_update {
    my($self, @args) = @_;

    die "Usage: carmel update\n" if @args; # TODO supprot args

    my @artifacts = $self->install_from_cpanfile(1);
    $self->dump_bootstrap(\@artifacts);
    $self->save_snapshot(\@artifacts);
}

sub cmd_install {
    my($self, @args) = @_;

    die "Usage: carmel install\n" if @args;

    my @artifacts = $self->install_from_cpanfile;
    $self->dump_bootstrap(\@artifacts);
    $self->save_snapshot(\@artifacts);
}

sub install_from_cpanfile {
    my($self, $no_snapshot) = @_;

    my $requirements = CPAN::Meta::Requirements->new;
    $self->resolve(
        sub {
            my($artifact) = @_;
            printf "Using %s (%s)\n", $artifact->package, $artifact->version || '0';
        },
        sub {
            my($module, $want_version, $dist) = @_;
            if ($dist) {
                # TODO pass $dist->distfile to cpanfile
                my $ver = $dist->version_for($module) || '0';
                $want_version = $ver ? "== $ver" : $ver;
            }
            $requirements->add_string_requirement($module => $want_version);
        },
        1, # strict
        $no_snapshot,
    );

    if (my @missing = $requirements->required_modules) {
        my $cpanfile = Module::CPANfile->from_prereqs({
            runtime => {
                requires => $requirements->as_string_hash,
            },
        });
        print "---> Installing new dependencies: ", join(", ", @missing), "\n";
        $self->install_with_cpanfile($cpanfile);
    }

    my @artifacts;
    $self->resolve(sub { push @artifacts, $_[0] }, undef, 0, $no_snapshot);

    # $self->requirements has been upgraded at this point with the whole subreqs
    printf "---> Complete! %d cpanfile dependencies. %d modules installed.\n" .
      "---> Use `carmel show [module]` to see where a module is installed.\n",
      scalar(grep { $_ ne 'perl' } $self->build_requirements->required_modules), scalar(@artifacts);

    return @artifacts;
}

sub is_core {
    my($self, $module, $want_version) = @_;
    return unless exists $Module::CoreList::version{$]+0}{$module};
    $self->accepts($module, $want_version, $Module::CoreList::version{$]+0}{$module});
}

sub install_with_cpanfile {
    my($self, $cpanfile) = @_;

    my $path = Path::Tiny->tempfile;
    $cpanfile->save($path);
    $self->install("--installdeps", "--cpanfile", $path, ".");
}

sub install {
    my($self, @args) = @_;

    my %file_temp = ();
    $file_temp{CLEANUP} = $ENV{PERL_FILE_TEMP_CLEANUP}
      if exists $ENV{PERL_FILE_TEMP_CLEANUP};

    my $dir = Path::Tiny->tempdir(%file_temp);
    local $ENV{PERL_CPANM_HOME} = $dir;
    local $ENV{PERL_CPANM_OPT};

    require Menlo::CLI::Compat;

    my $cli = Menlo::CLI::Compat->new(
        ($self->verbose ? () : "--quiet"),
        "--notest",
        "--save-dists", $self->repository_base->child('cache'),
        "-L", $self->repository_base->child('perl5'),
        @args,
    );
    $cli->run;

    for my $ent ($dir->child("latest-build")->children) {
        next unless $ent->is_dir && $ent->child("blib/meta/install.json")->exists;
        $self->repo->import_artifact($ent);
    }

    $self->repository_base->child('perl5')->remove_tree({ safe => 0 });
}

sub quote {
    my $indent = shift;
    $indent = " " x $indent;

    require Data::Dumper;
    my $val = Data::Dumper->new([transform(@_)], [])
      ->Sortkeys(1)->Terse(1)->Indent(1)->Dump;

    chomp $val;
    $val =~ s/^/$indent/mg if $indent;
    $val =~ s/^ *//;
    $val;
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

sub save_snapshot {
    my($self, $artifacts) = @_;

    require Carton::Dist;
    require Carton::Snapshot;

    my $cpanfile = $self->try_cpanfile;
    my $snapshot = Carton::Snapshot->new(path => $cpanfile . ".snapshot");

    for my $artifact (@$artifacts) {
        my $dist = Carton::Dist->new(
            name => $artifact->distname,
            pathname => $artifact->install->{pathname},
            provides => $artifact->provides,
            version => $artifact->version,
            requirements => $artifact->requirements,
        );
        $snapshot->add_distribution($dist);
    }

    $snapshot->save;
}

sub dump_bootstrap {
    my($self, $artifacts) = @_;

    my @inc  = map $_->nonempty_libs, @$artifacts;
    my @path = map $_->nonempty_paths, @$artifacts;

    my(%execs);
    for my $artifact (@$artifacts) {
        my %bins = $artifact->executables;
        $execs{$artifact->package} = \%bins if %bins;
    }

    my %modules;
    for my $artifact (@$artifacts) {
        %modules = (%modules, $artifact->module_files);
    }

    my $cpanfile = $self->try_cpanfile
      or Carp::croak "Can't locate 'cpanfile' to load module list.";

    my $prereqs = Module::CPANfile->load($cpanfile)->prereqs->as_string_hash;
    my $package = "Carmel::MySetup"; # hide from PAUSE

    my $file = Path::Tiny->new(".carmel/MySetup.pm");
    $file->parent->mkpath;
    $file->spew(<<EOF);
# DO NOT EDIT! Auto-generated via carmel install.
package $package;

our %environment = (
  'inc' => @{[ quote 2, \@inc ]},
  'path' => @{[ quote 2, \@path ]},
  'execs' => @{[ quote 2, \%execs ]},
  'base' => @{[ quote(2, Path::Tiny->cwd) ]},
  'modules' => @{[ quote 2, \%modules ]},
  'prereqs' => @{[ quote 2, $prereqs ]},
);

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
        my $artifact = $self->artifact_for($module);
        printf "%s (%s) in %s\n", $artifact->package, $artifact->version || '0', $artifact->path
          if $artifact;
        return;
    }

    my @artifacts;
    $self->resolve(sub { push @artifacts, $_[0] });

    for my $artifact (sort { $a->package cmp $b->package } @artifacts) {
        printf "%s (%s)\n", $artifact->package, $artifact->version || '0';
    }
}

sub artifact_for {
    my($self, $module) = @_;

    my $found;
    eval {
        $self->resolve(sub {
            my $artifact = shift;
            if ($module eq $artifact->package) {
                $found = $artifact;
                die "__FOUND__\n";
            }
        });
        die "Can't find a module named '$module' in the cpanfile dependencies.\n";
    };

    die $@ if $@ && $@ ne "__FOUND__\n";
    return $found;
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

    Path::Tiny->new("local/.carmel")->touch;
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
            print "Fetching ", $package->pathname, " from CPAN\n";
            my $fetch = File::Fetch->new(uri => "http://backpan.perl.org/authors/id/" . $package->pathname);
            if ($fetch->fetch(to => $target->parent)) {
                $success++;
            } else {
                warn $fetch->error;
            }
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
            my $package = Carton::Package->new($pkg, $data->{version}, $artifact->install->{pathname});
            $index->add_package($package);
        }
    });

    $index;
}

sub cmd_binstubs {
    my($self, @package) = @_;

    die "Usage: carmel binstubs Module [...]\n" unless @package;

    for my $package (@package) {
        my $artifact = $self->artifact_for($package);
        my %execs = $artifact->executables;
        for my $bin (keys %execs) {
            my $path = Path::Tiny->new("bin/$bin");
            $path->parent->mkpath;
            $path->spew(<<EOF);
#!/usr/bin/env perl
# This file was generated by Carmel
use Carmel::Setup;
my \$res = do Carmel::Setup->bin_path('@{[ $artifact->package ]}', '$bin');
if (!defined \$res and my \$err = \$@ || \$!) { die \$err }
EOF
            $path->chmod(0755);
        }
    }
}

sub try_cpanfile {
    my $self = shift;
    $self->locate_cpanfile($ENV{PERL_CARMEL_CPANFILE});
}

sub locate_cpanfile {
    my($self, $path) = @_;

    if ($path) {
        return Path::Tiny->new($path)->absolute;
    }

    my $current  = Path::Tiny->cwd;
    my $previous = '';

    until ($current eq '/' or $current eq $previous) {
        my $try = $current->child('cpanfile');
        return $try->absolute if $try->is_file;
        ($previous, $current) = ($current, $current->parent);
    }

    return;
}

sub requirements {
    my $self = shift;
    $self->{requirements} ||= $self->build_requirements;
}

sub build_requirements {
    my $self = shift;

    my $cpanfile = $self->try_cpanfile
      or Carp::croak "Can't locate 'cpanfile' to load module list.";

    return Module::CPANfile->load($cpanfile)
      ->prereqs->merged_requirements(['runtime', 'test', 'develop'], ['requires']);
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

sub resolve_recursive {
    my($self, $root_reqs, $requirements, $snapshot, $seen, $cb, $missing_cb, $strict, $depth) = @_;

    # TODO rather than mutating $root_reqs directly, we should create a new object
    # that allows accessing the result $requirements
    for my $module (sort $requirements->required_modules) {
        next if $module eq 'perl';

        my $want_version = $root_reqs->requirements_for_module($module);

        my $artifact;
        my $dist;
        if ($dist = $self->find_in_snapshot($snapshot, $module, $root_reqs)) {
            $artifact = $self->repo->find_match($module, sub { $_[0]->distname eq $dist->name });
            $artifact ||= $self->repo->find($module, $want_version) unless $strict;
        } elsif ($self->is_core($module, $want_version)) {
            next;
        } else {
            $artifact = $self->repo->find($module, $want_version);
        }

        # FIXME there's a chance different version of the same module can be loaded here
        if ($artifact) {
            warn sprintf "   %s (%s) in %s\n", $module, $artifact->version_for($module), $artifact->path if $self->verbose;
            next if $seen->{$artifact->path}++;
            $cb->($artifact, $depth);

            my $reqs = $artifact->requirements;
            $self->merge_requirements($root_reqs, $reqs, $artifact->distname);

            $self->resolve_recursive($root_reqs, $reqs, $snapshot, $seen, $cb, $missing_cb, $strict, $depth + 1);
        } else {
            $missing_cb->($module, $want_version, $dist, $depth);
        }
    }
}

sub resolve {
    my($self, $cb, $missing_cb, $strict, $no_snapshot) = @_;
    $missing_cb ||= sub {
        my($module, $want_version, $dist, $depth) = @_;
        die "Can't find an artifact for $module => $want_version\n" .
            "You need to run `carmel install` first to get the modules installed and artifacts built.\n";
    };

    my $snapshot = $no_snapshot ? undef : $self->snapshot;

    $self->resolve_recursive($self->requirements, $self->requirements->clone, $snapshot,
                             {}, $cb, $missing_cb, $strict, 0);
}

sub find_in_snapshot {
    my($self, $snapshot, $module, $reqs) = @_;

    return unless $snapshot;

    if (my $dist = $snapshot->find($module)) {
        warn "@{[$dist->name]} found in snapshot for $module\n" if $self->verbose;
        if ($self->accepts_all($reqs, $dist)) {
            return $dist;
        }
    }

    warn "$module not found in snapshot\n" if $self->verbose;

    return;
}

sub accepts_all {
    my($self, $reqs, $dist) = @_;

    my @packages = keys %{$dist->provides};

    for my $pkg (@packages) {
        my $version = $dist->provides->{$pkg}{version} || '0';
        return unless $reqs->accepts_module($pkg, $version);
    }

    return 1;
}

sub accepts {
    my($self, $module, $want_version, $version) = @_;

    CPAN::Meta::Requirements->from_string_hash({ $module => $want_version })
        ->accepts_module($module, $version || '0');
}

sub snapshot {
    my $self = shift;

    my $cpanfile = $self->try_cpanfile;
    if (-e "$cpanfile.snapshot") {
        require Carton::Snapshot;
        my $snapshot = Carton::Snapshot->new(path => "$cpanfile.snapshot");
        $snapshot->load;
        return $snapshot;
    }

    return;
}

1;
