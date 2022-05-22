package xt::CLI;
use strict;
use base qw(Exporter);
our @EXPORT = qw(run cli);

sub cli {
    my $cli = TestCLI->new(clean => $ENV{TEST_CLEAN}, @_);
    $cli->dir( Path::Tiny->tempdir(CLEANUP => !$ENV{NO_CLEANUP}) );
    warn "Temp directory: ", $cli->dir, "\n" if $ENV{NO_CLEANUP};
    $cli;
}

package TestCLI;
use Carmel::App;
use Capture::Tiny qw(capture);
use File::pushd ();
use Path::Tiny;
use Test::More;

our $DEV = Path::Tiny->new(".")->absolute;

use Class::Tiny qw( dir stdout stderr exit_code clean );

sub BUILD {
    my $self = shift;
    $self->{dir} = File::pushd::pushd $self->dir;
}

sub write_file {
    my($self, $file, @args) = @_;
    $self->dir->child($file)->spew(@args);
}

sub write_cpanfile {
    my($self, @args) = @_;
    $self->write_file(cpanfile => @args);
}

sub path {
    my($self, @args) = @_;
    my $path = $self->dir->child(@args);
    $path->parent->mkpath unless $path->parent->exists;
    $path;
}

sub snapshot {
    my $self = shift;

    require Carton::Snapshot;
    my $snapshot = Carton::Snapshot->new(path => $self->dir->child("cpanfile.snapshot"));
    $snapshot->load;

    $snapshot;
}

sub repo {
    my $self = shift;

    my $pushd = File::pushd::pushd $self->dir;
    local $ENV{PERL_CARMEL_REPO} = $self->dir->child(".carmel")
      if $self->{clean};

    Carmel::Environment->new->repo;
}

sub cmd_in_dir {
    my($self, $dir, @args) = @_;
    local $self->{dir} = $self->dir->child($dir);
    $self->run(@args);
}

sub cmd {
    my($self, @args) = @_;

    my $pushd = File::pushd::pushd $self->dir;
    my @capture = capture {
        my $code = system @args;
        $self->exit_code($code);
    };

    $self->stdout($capture[0]);
    $self->stderr($capture[1]);
}

sub cmd_ok {
    my($self, @args) = @_;

    $self->cmd(@args);

    local $Test::Builder::Level = $Test::Builder::Level + 1;
    is $self->exit_code, 0, "carmel @args succeeded"
      or diag $self->stderr;
}

sub run_in_dir {
    my($self, $dir, @args) = @_;
    local $self->{dir} = $self->dir->child($dir);
    $self->run(@args);
}

sub run {
    my($self, @args) = @_;

    my $pushd = File::pushd::pushd $self->dir;
    local $ENV{PERL_CARMEL_REPO} = $self->dir->child(".carmel")
      if $self->{clean};

    my @capture = capture {
        my $code = $self->run_cli(@args);
        $self->exit_code($@ ? 255 : $code);
        warn $@ if $@;
    };

    $self->stdout($capture[0]);
    $self->stderr($capture[1]);
}

sub run_cli {
    my($self, @cmd) = @_;

    if ($cmd[0] eq "exec") {
        system $^X, "-I$DEV/lib", "$DEV/script/carmel", @cmd;
    } else {
        eval { Carmel::App->new->run(@cmd) };
    }
}

sub run_ok {
    my($self, @args) = @_;

    $self->run(@args);

    local $Test::Builder::Level = $Test::Builder::Level + 1;
    is $self->exit_code, 0, "carmel @args succeeded"
      or diag $self->stderr;
}

sub run_fails {
    my($self, @args) = @_;

    $self->run(@args);

    local $Test::Builder::Level = $Test::Builder::Level + 1;
    isnt $self->exit_code, 0, "carmel @args failed"
      or diag $self->stderr;
}

sub run_any {
    my($self, @args) = @_;

    my $pushd = File::pushd::pushd $self->dir;
    my @capture = capture { system @args };

    $self->stdout($capture[0]);
    $self->stderr($capture[1]);
}

1;

