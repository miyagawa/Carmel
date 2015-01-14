package Carmel::App;
use strict;
use warnings;

use Carmel;
use Carp ();
use Carmel::Repository;
use CPAN::Meta;
use CPAN::Meta::Requirements;
use Module::CoreList;

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
    my($self, $module, $requirement) = @_;

    my $requirements;
    if ($module) {
        $requirement =~ s/^@/==/ if $requirement;
        $self->install_module([ $module, $requirement ]);
        $requirements = CPAN::Meta::Requirements->from_string_hash({ $module => $requirement || '0' });
    } else {
        $requirements = $self->build_requirements
          or Carp::croak "Could not locate 'cpanfile' to load module list.";
    }

    $self->resolve_recursive(
        $requirements, {},
        sub { printf "You have %s (%s) in %s\n", $_[0]->package, $_[0]->version || '0', $_[0]->path },
        sub { $self->install_module(@_) },
    );
}

sub is_core {
    my($self, $module, $want_version) = @_;

    unless (exists $Module::CoreList::version{$]+0}{$module}) {
        return;
    }

    my $accepts = CPAN::Meta::Requirements->from_string_hash({ $module => $want_version })
        ->accepts_module($module, $Module::CoreList::version{$]+0}{$module} || '0');

    # This might not be true, but a good indicator that is dual-live
    my $upstream_is_cpan = ($Module::CoreList::upstream{$module} || '') eq 'cpan';

    $accepts && !$upstream_is_cpan;
}

sub install_module {
    my($self, @modules) = @_;

    my $repo = $self->build_repo;

    my @args;
    for my $pair (@modules) {
        my($module, $requirement) = @$pair;
        my @artifacts = $repo->find_all($module, $requirement || '0');
        if (@artifacts) {
            printf "You have %s (%s) in %s\n", $module, $artifacts[0]->version || '0', $artifacts[0]->path;
        } else {
            push @args, ($requirement ? "$module~$requirement" : $module);
        }
    }

    system $^X, "-S", "cpanm", "--notest", "--reinstall", "-l", $self->temp_dir, @args if @args;
}

sub cmd_export {
    my($self, @args) = @_;
    my %env = $self->env;
    print "export PATH=$env{PATH} PERL5LIB=$env{PERL5LIB}\n";
}

sub cmd_env {
    my($self, @args) = @_;
    my %env = $self->env;
    print "PATH=$env{PATH}\nPERL5LIB=$env{PERL5LIB}\n";
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
        printf "%s (%s) in %s\n", $artifact->package, $artifact->version || '0', $artifact->path;
    }
}

sub cmd_list {
    my($self) = @_;

    for my $artifact ($self->resolve) {
        printf "%s (%s) in %s\n", $artifact->package, $artifact->version || '0', $artifact->path;
    }
}

sub cmd_index {
    my $self = shift;
    $self->write_index(*STDOUT);
}

sub write_index {
    my($self, $fh) = @_;

    my @packages;
    for my $artifact ($self->resolve) {
        while (my($package, $data) = each %{$artifact->install->{provides}}) {
            push @packages, {
                package => $package,
                version => $data->{version} || 'undef',
                pathname => $artifact->install->{pathname},
            }
        }
    }

    print $fh <<EOF;
File:         02packages.details.txt
URL:          http://www.perl.com/CPAN/modules/02packages.details.txt
Description:  Package names found in Carmel build artifacts
Columns:      package name, version, path
Intended-For: Automated fetch routines, namespace documentation.
Written-By:   Carmel $Carmel::VERSION
Line-Count:   @{[ $#packages + 1 ]}
Last-Updated: @{[ scalar localtime ]}

EOF

    for my $p (@packages) {
        print $fh sprintf "%s %s  %s\n", pad($p->{package}, 32), pad($p->{version}, 10, 1), $p->{pathname};
    }
}

sub pad {
    my($str, $len, $left) = @_;

    my $howmany = $len - length($str);
    return $str if $howmany <= 0;

    my $pad = " " x $howmany;
    return $left ? "$pad$str" : "$str$pad";
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
        return Module::CPANfile->load($cpanfile)->prereqs->merged_requirements(['runtime'],['requires']);
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

sub resolve_recursive {
    my($self, $requirements, $seen, $cb, $missing_cb) = @_;

    my $repo = $self->build_repo;
    my $recurse;

    my @missing;
    for my $module (sort $requirements->required_modules) {
        next if $module eq 'perl';

        my $want_version = $requirements->requirements_for_module($module);
        if ($self->is_core($module, $want_version)) {
            next;
        } elsif (my $artifact = $repo->find($module, $want_version)) {
            next if $seen->{$artifact->path}++;
            $cb->($artifact);
            my $meta = CPAN::Meta->load_file($artifact->path . "/MYMETA.json");
            $requirements->add_requirements($meta->effective_prereqs->merged_requirements(['runtime'], ['requires']));
        } else {
            push @missing, [ $module, $want_version ];
        }

        $recurse++;
    }

    $missing_cb->(@missing) if @missing;
    $self->resolve_recursive($requirements, $seen, $cb, $missing_cb) if $recurse;
}

sub resolve {
    my($self, $requirements) = @_;

    $requirements ||= $self->build_requirements
      or Carp::croak "Could not locate 'cpanfile' to load module list.";

    my @artifacts;
    $self->resolve_recursive($requirements, {}, sub { push @artifacts, @_ }, sub { $self->warn_missing(@_) });

    @artifacts;
}

sub warn_missing {
    my($self, @missing) = @_;

    for my $missing (@missing) {
        Carp::carp "Could not find an artifact for $missing->[0] => $missing->[1]";
    }
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
