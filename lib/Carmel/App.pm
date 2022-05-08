package Carmel::App;
use strict;
use warnings;

use Carmel;
use Carmel::Runner;
use Carp ();
use Carmel::Builder;
use Carmel::Repository;
use Carmel::Resolver;
use Config qw(%Config);
use CPAN::Meta::Requirements;
use Getopt::Long ();
use Module::CPANfile;
use Module::Metadata;
use Path::Tiny ();
use Pod::Usage ();
use Try::Tiny;

use Class::Tiny {
    verbose => sub { 0 },
    perl_arch => sub { "$Config{version}-$Config{archname}" },
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

    my $code = 0;
    try {
        $self->$call(@args);
    } catch {
        warn $_;
        $code = 1;
    };

    return $code;
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
    $self->builder->install("--reinstall", @args);
}

sub cmd_pin {
    my($self, @args) = @_;

    unless (@args) {
        die "Usage: carmel pin Module\@version ...\n";
    }

    my $snapshot = $self->snapshot
      or die "Can't run carmel pin without snapshot. Run `carmel install` first.\n";

    my $requirements = $self->requirements;
    for my $arg (@args) {
        my($module, $version) = split '@', $arg, 2;
        unless (defined $version) {
            die "Usage: carmel pin Module\@version ...\n";
        }
        my $dist = $snapshot->find($module)
          or die "$module is not found in the snapshot.\n";
        try {
            $requirements->add_string_requirement($module, "== $version");
        } catch {
            my($err) = /illegal requirements(?: .*?): (.*) at/;
            my $old = $requirements->requirements_for_module($module);
            die "Found conflicting requirement for $module: '$old' <=> '== $version': $err\n";
        };
    }

    $self->update_dependencies($requirements, $snapshot);
}

sub cmd_update {
    my($self, @args) = @_;

    my $snapshot = $self->snapshot
      or die "Can't run carmel update without snapshot. Run `carmel install` first.\n";

    for my $module (@args) {
        my $dist = $snapshot->find($module)
          or die "$module is not found in the snapshot.\n";
    }

    if (@args) {
        for my $module (@args) {
            $snapshot->remove_distributions(sub {
                my $dist = shift;
                $dist->provides_module($module);
            });
        }
        my $builder = $self->builder(snapshot => $snapshot);
        $builder->install(@args);
    } else {
        # remove everything from the snapshot
        $snapshot->remove_distributions(sub { 1 });
        my $cpanfile = $self->try_cpanfile
          or die "Can't locate 'cpanfile' to load module list.\n";

        my $builder = $self->builder(
            cpanfile => Module::CPANfile->load($cpanfile),
            snapshot => $snapshot,
        );
        $builder->install;
    }

    # rebuild the snapshot
    $self->update_dependencies($self->requirements, $snapshot);
}

sub cmd_install {
    my($self, @args) = @_;

    die "Usage: carmel install\n" if @args;

    $self->update_dependencies($self->requirements, $self->snapshot);
}

sub update_dependencies {
    my($self, $root_reqs, $snapshot) = @_;

    my @artifacts = $self->install($root_reqs, $snapshot);
    $self->dump_bootstrap(\@artifacts);
    $self->save_snapshot(\@artifacts);
}

sub install {
    my($self, $root_reqs, $snapshot) = @_;

    my $requirements = CPAN::Meta::Requirements->new;

    $self->resolver(
        root => $root_reqs,
        snapshot => $snapshot,
        found => sub {
            my($artifact) = @_;
            printf "Using %s (%s)\n", $artifact->package, $artifact->version || '0';
        },
        missing => sub {
            my($module, $want_version, $dist) = @_;
            $requirements->add_string_requirement($module => $want_version);
        },
    )->resolve;

    if (my @missing = $requirements->required_modules) {
        my $cpanfile = Module::CPANfile->from_prereqs({
            runtime => {
                requires => $requirements->as_string_hash,
            },
        });
        print "---> Installing new dependencies: ", join(", ", @missing), "\n";
        my $builder = $self->builder(cpanfile => $cpanfile, snapshot => $snapshot);
        $builder->install;
    }

    my @artifacts;
    $self->resolver(
        found    => sub { push @artifacts, $_[0] },
        root     => $root_reqs,
        snapshot => $snapshot,
    )->resolve;

    # $root_reqs has been mutated at this point. Reload requirements
    printf "---> Complete! %d cpanfile dependencies. %d modules installed.\n" .
      "---> Use `carmel show [module]` to see where a module is installed.\n",
      scalar(grep { $_ ne 'perl' } $self->requirements->required_modules), scalar(@artifacts);

    return @artifacts;
}

sub builder {
    my($self, @args) = @_;

    Carmel::Builder->new(
        repository_base => $self->repository_base,
        cpanfile_path => scalar $self->try_cpanfile,
        collect_artifact => sub { $self->repo->import_artifact(@_) },
        verbose => $self->verbose,
        @args,
    );
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
            # compatibility with Carton snapshot
            requirements => $artifact->requirements_for([qw( configure build runtime )], ['requires']), 
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
      or die "Can't locate 'cpanfile' to load module list.\n";

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
    my %env = Carmel::Runner->new->env;
    print "export ", join(" ", map qq($_="$env{$_}"), sort keys %env), "\n";
}

sub cmd_env {
    my($self) = @_;
    my %env = Carmel::Runner->new->env;
    print join "", map qq($_=$env{$_}\n), sort keys %env;
}

# TODO remove. just here for testing
sub cmd_exec {
    my($self, @args) = @_;
    Carmel::Runner->new->execute(@args);
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

sub resolve {
    my($self, $cb) = @_;
    $self->resolver(found => $cb)->resolve;
}

sub resolver {
    my($self, @args) = @_;

    Carmel::Resolver->new(
        repo     => $self->repo,
        root     => $self->requirements,
        snapshot => scalar $self->snapshot,
        missing  => sub { $self->missing_default(@_) },
        verbose  => $self->verbose,
        @args,
    );
}

sub missing_default {
    my($self, $module, $want_version, $dist, $depth) = @_;
    die "Can't find an artifact for $module => $want_version\n" .
      "You need to run `carmel install` first to get the modules installed and artifacts built.\n";
}

sub artifact_for {
    my($self, $module) = @_;

    my $found;
    eval {
        $self->resolve(sub {
            my $artifact = shift;
            if (exists $artifact->provides->{$module}) {
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

    my @artifacts;
    $self->resolve(sub { push @artifacts, $_[0] });

    # TODO safe atomic rename
    my $install_base = Path::Tiny->new("local")->absolute;
    $install_base->remove_tree({ safe => 0 }) if $install_base->exists;

    $self->builder->rollout($install_base, \@artifacts);

    $install_base->child(".carmel")->touch;
}

sub cmd_package {
    my $self = shift;

    my $index = $self->build_index;

    my $source_base = $self->repository_base->child('cache');
    my $target_base = Path::Tiny->new('vendor/cache');

    my %done;
    my @found;
    for my $package ($index->packages) {
        next if $done{$package->pathname}++;

        my $source = $source_base->child('authors/id', $package->pathname);
        my $target = $target_base->child('authors/id', $package->pathname);

        if ($source->exists) {
            push @found, sub {
                print "Copying ", $package->pathname, "\n";
                $target->parent->mkpath;
                $source->copy($target);
            };
        } else {
            die sprintf "%s not found in %s.\n" .
              "Run `carmel install` to fix this. If that didn't resolve the issue, try removing %s\n",
              $package->pathname, $source_base, $self->repository_base;
        }
    }

    for my $copy (@found) {
        $copy->();
    }

    require IO::Compress::Gzip;
    my $index_file = $target_base->child('modules/02packages.details.txt.gz');
    $index_file->parent->mkpath;

    warn "Writing $index_file\n";
    my $out = IO::Compress::Gzip->new($index_file->openw)
      or die "gzip failed: $IO::Compress::Gzip::GzipError";
    $index->write($out);

    print "---> Complete! ", scalar(@found), " distributions are packaged in vendor/cache\n";
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

    my $cpanfile = $self->try_cpanfile
      or die "Can't locate 'cpanfile' to load module list.\n";

    return Module::CPANfile->load($cpanfile)
      ->prereqs->merged_requirements(['runtime', 'test', 'develop'], ['requires']);
}

sub snapshot {
    my $self = shift;

    my $cpanfile = $self->try_cpanfile;
    if ($cpanfile && -e "$cpanfile.snapshot") {
        require Carton::Snapshot;
        my $snapshot = Carton::Snapshot->new(path => "$cpanfile.snapshot");
        $snapshot->load;
        return $snapshot;
    }

    return;
}

1;
