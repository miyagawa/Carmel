package Carmel::App;
use strict;
use warnings;

use Carmel;
use Carmel::Runner;
use Carp ();
use Carmel::Builder;
use Carmel::CPANfile;
use Carmel::Environment;
use Carmel::Repository;
use Carmel::Resolver;
use Config qw(%Config);
use CPAN::Meta::Requirements;
use File::pushd qw(pushd);
use Getopt::Long ();
use Module::CPANfile;
use Module::Metadata;
use Path::Tiny ();
use Pod::Usage ();
use Try::Tiny;

# prefer Parse::CPAN::Meta in XS, PP order with JSON.pm
$ENV{PERL_JSON_BACKEND} = 1
  unless defined $ENV{PERL_JSON_BACKEND};

use Class::Tiny {
    verbose => sub { 0 },
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

    if ($cmd eq 'run') {
        return $self->cmd_run(@args);
    }

    my $code = 0;
    try {
        $self->$call(@args);
    } catch {
        warn $_;
        $code = 1;
    };

    return $code;
}

sub env {
    my $self = shift;
    $self->{env} ||= Carmel::Environment->new;
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

    my $reqs = CPAN::Meta::Requirements->new;
    for my $arg (@args) {
        my($module, $version) = split /@/, $arg, 2;
        $reqs->add_string_requirement($module, $version ? "== $version" : 0);
    }

    my $cpanfile = Module::CPANfile->from_prereqs({
        runtime => {
            requires => $reqs->as_string_hash,
        },
    });

    # FIXME: $builder->install() reads mirror info from cpanfile_path
    my $path = Path::Tiny->tempfile;
    $cpanfile->save($path);

    my @artifacts = $self->builder(cpanfile => $cpanfile, cpanfile_path => $path)->install;

    my @failed;
 MODULE:
    for my $module ($reqs->required_modules) {
        my $want = $reqs->requirements_for_module($module);
        for my $artifact (@artifacts) {
            if ($artifact->provides->{$module}) {
                my $version = $artifact->version_for($module);
                $reqs->accepts_module($module => $version)
                  or die "Installed version for $module ($version) doesn't satisfy the requirement: $want\n";
                next MODULE;
            }
        }

        push @failed, $module;
    }

    if (@failed) {
        die "Couldn't install module(s): ", join(", ", @failed), "\n";
    }
}

sub cmd_pin {
    my($self, @args) = @_;
    die "carmel pin is deprecated. Use `carmel update @args` instead\n";
}

sub cmd_update {
    my($self, @args) = @_;

    my $snapshot = $self->env->snapshot
      or die "Can't run carmel update without snapshot. Run `carmel install` first.\n";

    print "---> Checking updates...\n";

    $self->update_or_install($snapshot, @args);
}

sub update_or_install {
    my($self, $snapshot, @args) = @_;

    my $builder = $self->builder;
    my $requirements = $self->requirements;

    my $check = sub {
        my($module, $pathname, $in_args, $version) = @_;

        return if $module eq 'perl';

        my $dist = $builder->search_module($module, $version);
        unless ($dist) {
            if ($version) {
                die "Can't find $module ($version) on CPAN\n";
            } else {
                # workaround bad main package e.g. LWP => libwww::perl
                warn "Can't find $module on CPAN\n";
                return;
            }
        }

        # non-dual core module like "strict.pm"
        # TODO should be $dist->is_perl
        return if $dist->name =~ /^perl-5\.\d+\.\d+$/;

        if (defined $version) {
            try {
                $requirements->add_string_requirement($module, $version);
            } catch {
                my($err) = /illegal requirements(?: .*?): (.*) at/;
                my $old = $requirements->requirements_for_module($module);
                die "Requested version for $module '$version' conflicts with version required in cpanfile '$old': $err\n";
            };
        } else {
            my $want_ver = $dist->version_for($module);
            try {
                $requirements->add_string_requirement($module, $want_ver);
            } catch {
                # there's an update but it conflicts with specs in cpanfile, ignoring
                if ($in_args) {
                    my($err) = /illegal requirements(?: .*?): (.*) at/;
                    my $old = $requirements->requirements_for_module($module);
                    die "The update for $module '$want_ver' conflicts with version required in cpanfile '$old' $err\n";
                }
            };
        }
    };

    if (@args) {
        for my $arg (@args) {
            my($module, $version) = split '@', $arg, 2;
            my $dist = $snapshot ? $snapshot->find($module) : undef;
            if ($dist) {
                $check->($module, $dist->pathname, 1, $version ? "== $version" : undef);
            } elsif (defined $requirements->requirements_for_module($module)) {
                $check->($module, '', 1, $version ? "== $version" : undef);
            } else {
                die "$module is not found in cpanfile or cpanfile.snapshot\n";
            }
        }
    } else {
        my $missing = $requirements->clone;

        my @checks;
        my $resolver = $self->resolver(
            root     => $self->requirements->clone,
            snapshot => $snapshot,
            found    => sub {
                my $artifact = shift;
                for my $pkg (keys %{$artifact->provides}) {
                    $missing->clear_requirement($pkg);
                }
                push @checks, [ $artifact->package, $artifact->install->{pathname}, 0 ];
            },
            missing  => sub {
                my($module, $want_version) = @_;
                $missing->add_string_requirement($module => $want_version);
            },
        );
        $resolver->resolve;

        # snapshot not supplied (first carmel install), or
        # specified in cpanfile but not in snapshot, possibly core module
        for my $module ($missing->required_modules) {
            push @checks, [ $module, '', 0 ];
        }

        for my $args (@checks) {
            $check->(@$args);
        }
    }

    # rebuild the snapshot
    $self->update_dependencies($requirements, $snapshot);
}

sub cmd_install {
    my($self, @args) = @_;

    die "Usage: carmel install\n" if @args;

    my $snapshot = $self->env->snapshot;
    if ($snapshot) {
        $self->update_dependencies($self->requirements, $snapshot);
    } else {
        print "---> Installing modules...\n";
        $self->update_or_install($snapshot);
    }
}

sub update_dependencies {
    my($self, $root_reqs, $snapshot) = @_;

    my @artifacts = $self->install($root_reqs, $snapshot);
    $self->dump_bootstrap(\@artifacts);
    $self->save_snapshot(\@artifacts);
}

sub resolve_dependencies {
    my($self, $root_reqs, $missing, $snapshot) = @_;

    my @artifacts;
    $self->resolver(
        root     => $root_reqs,
        snapshot => $snapshot,
        found    => sub {
            my $artifact = shift;
            printf "Using %s (%s)\n", $artifact->package, $artifact->version || '0';
            push @artifacts, $artifact;
        },
        missing  => sub {
            my($module, $want_version) = @_;
            $missing->add_string_requirement($module => $want_version);
        },
    )->resolve;

    return @artifacts;
}

sub is_identical_requirement {
    my($self, $old, $new) = @_;

    return unless $old;

    # not super accurate but enough
    join(',', sort $old->required_modules) eq join(',', sort $new->required_modules);
}

sub try_install {
    my($self, $root_reqs, $snapshot) = @_;

    my $prev;
    while (1) {
        my $missing = CPAN::Meta::Requirements->new;
        my @artifacts = $self->resolve_dependencies($root_reqs, $missing, $snapshot);

        if (!$missing->required_modules) {
            return @artifacts;
        }

        if ($self->is_identical_requirement($prev, $missing)) {
            my $prereqs = $missing->as_string_hash;
            my $requirements = join ", ", map "$_ => @{[ $prereqs->{$_} || '0' ]}", keys %$prereqs;
            die "Can't find an artifact for $requirements\n" .
              "You need to run `carmel install` first to get the modules installed and artifacts built.\n";
        }

        $prev = $missing;

        my $cpanfile = Module::CPANfile->from_prereqs({
            runtime => {
                requires => $missing->as_string_hash,
            },
        });
        print "---> Installing new dependencies: ", join(", ", $missing->required_modules), "\n";
        my $builder = $self->builder(cpanfile => $cpanfile, snapshot => $snapshot);
        $builder->install;
    }
}

sub install {
    my($self, $root_reqs, $snapshot) = @_;

    my @artifacts = $self->try_install($root_reqs, $snapshot);

    # $root_reqs has been mutated at this point. Reload requirements
    printf "---> Complete! %d cpanfile dependencies. %d modules installed.\n",
      scalar(grep { $_ ne 'perl' } $self->requirements->required_modules), scalar(@artifacts);

    return @artifacts;
}

sub cmd_reinstall {
    my($self, @args) = @_;

    my @modules = @args ? @args : $self->requirements->required_modules;

    my $snapshot = $self->env->snapshot
      or die "Can't run carmel reinstall without snapshot. Run `carmel install` first.\n";

    my $reqs = CPAN::Meta::Requirements->new;
    for my $module (@modules) {
        if (my $dist = $snapshot->find($module)) {
            $reqs->add_string_requirement($module, $dist->version_for($module));
        } elsif (@args) {
            die "$module is not found in cpanfile.snapshot\n";
        }
    }

    my $cpanfile = Module::CPANfile->from_prereqs({
        runtime => {
            requires => $reqs->as_string_hash,
        },
    });

    $self->builder(cpanfile => $cpanfile, snapshot => $snapshot)->install;
    $self->cmd_install;
}

sub builder {
    my($self, @args) = @_;

    Carmel::Builder->new(
        repository_base => $self->env->repository_base,
        cpanfile_path => $self->env->cpanfile->path,
        collect_artifact => sub { $self->env->repo->import_artifact(@_) },
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

    require Carton::Snapshot;
    require Carton::Dist;

    my $snapshot = Carton::Snapshot->new(path => $self->env->snapshot_path);

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

    my $prereqs = $self->env->cpanfile->load->prereqs->as_string_hash;
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

sub cmd_run {
    my($self, @args) = @_;
    Carmel::Runner->new->run(@args);
}

# Usually carmel exec is handled in carmel script, not here
sub cmd_exec {
    my($self, @args) = @_;
    Carmel::Runner->new->execute(@args);
}

sub cmd_find {
    my($self, $module, $requirement) = @_;

    my @artifacts = $self->env->repo->find_all($module, $requirement || '0');
    for my $artifact (@artifacts) {
        printf "%s (%s) in %s\n", $artifact->package, $artifact->version || '0', $artifact->path;
    }
}

sub cmd_show {
    my($self, $module) = @_;

    $module or die "Usage: carmel show Module\n";

    my $artifact = $self->artifact_for($module);
    printf "%s (%s) in %s\n", $artifact->package, $artifact->version || '0', $artifact->path
      if $artifact;
}

sub cmd_info {
    my $self = shift;
    $self->cmd_show(@_);
}

sub cmd_list {
    my $self = shift;

    my @artifacts;
    $self->resolve(sub { push @artifacts, $_[0] });

    for my $artifact (sort { $a->package cmp $b->package } @artifacts) {
        printf "%s (%s)\n", $artifact->package, $artifact->version || '0';
    }
}

sub cmd_look {
    my($self, $module) = @_;

    $module or die "Usage: carmel look Module\n";

    my $shell = $ENV{SHELL}
      or die "Can't determine shell from SHELL variable\n";

    my $artifact = $self->artifact_for($module);

    my $dir = pushd $artifact->path;
    system $shell;
}

sub cmd_diff {
    my $self = shift;

    my $snapshot_path = $self->env->snapshot_path->relative;

    # Don't check if .git exists, and let git(2) handle the error

    if ($ENV{PERL_CARMEL_USE_DIFFTOOL}) {
        my $cmd = 'carmel difftool';
        $cmd .= ' -v' if $self->verbose;

        system 'git', 'difftool', '--no-prompt',
          '--extcmd', $cmd, $snapshot_path;
    } else {
        require Carmel::Difftool;

        my $content = `git show HEAD:$snapshot_path`
          or die "Can't retrieve snapshot content (not in git repository?)\n";
        my $path = Path::Tiny->tempfile;
        $path->spew($content);

        my $diff = Carmel::Difftool->new;
        $diff->diff($path, $snapshot_path);
    }
}

sub cmd_difftool {
    my($self, @args) = @_;

    require Carmel::Difftool;

    my $diff = Carmel::Difftool->new;
    $diff->diff(@args);
}

sub resolve {
    my($self, $cb) = @_;
    $self->resolver(found => $cb)->resolve;
}

sub resolver {
    my($self, @args) = @_;

    Carmel::Resolver->new(
        repo     => $self->env->repo,
        root     => $self->requirements,
        snapshot => scalar $self->env->snapshot,
        missing  => sub { $self->missing_default(@_) },
        @args,
    );
}

sub missing_default {
    my($self, $module, $want_version, $depth) = @_;
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

    my $source_base = $self->env->repository_base->child('cache');
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
              $package->pathname, $source_base, $self->env->repository_base;
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

sub requirements {
    my $self = shift;

    return $self->env->cpanfile->load->prereqs
      ->merged_requirements(['runtime', 'test', 'develop'], ['requires']);
}

1;
