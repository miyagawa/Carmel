package Carmel::Resolver;
use strict;
use warnings;
use Class::Tiny qw( repo snapshot root seen found missing );

use Module::CoreList;
use Try::Tiny;

sub resolve {
    my $self = shift;

    my $clone = $self->root->clone;
    my $seen  = {};
    my $depth = 0;

    $self->resolve_recurse($clone, $seen, $depth);
}

sub resolve_recurse {
    my($self, $requirements, $seen, $depth) = @_;

    for my $module (sort $requirements->required_modules) {
        next if $module eq 'perl';

        my $want_version = $self->root->requirements_for_module($module);

        my $artifact;
        my $dist;
        if ($dist = $self->find_in_snapshot($module)) {
            $artifact = $self->repo->find_match($module, sub { $_[0]->distname eq $dist->name }, $dist->name);
        } elsif ($self->is_core($module, $want_version)) {
            next;
        } else {
            $artifact = $self->repo->find_match($module, sub { $self->accepts_all($self->root, $_[0]) });
        }

        # FIXME there's a chance different version of the same module can be loaded here
        if ($artifact) {
            warn sprintf "   %s (%s) in %s\n", $module, $artifact->version_for($module), $artifact->path if $Carmel::DEBUG;
            next if $seen->{$artifact->path}++;
            $self->found->($artifact, $depth);

            my $reqs = $artifact->requirements;
            $self->merge_requirements($self->root, $reqs, $artifact->distname);

            $self->resolve_recurse($reqs, $seen, $depth + 1);
        } else {
            $self->missing->($module, $want_version, $dist, $depth);
        }
    }
}

sub is_core {
    my($self, $module, $want_version) = @_;
    return unless exists $Module::CoreList::version{$]+0}{$module};

    my $version = $Module::CoreList::version{$]+0}{$module} || '0';
    CPAN::Meta::Requirements->from_string_hash({ $module => $want_version })
        ->accepts_module($module, $version);
}

sub find_in_snapshot {
    my($self, $module) = @_;

    my $snapshot = $self->snapshot or return;

    if (my $dist = $snapshot->find($module)) {
        warn "@{[$dist->name]} found in snapshot for $module\n" if $Carmel::DEBUG;
        if ($self->accepts_all($self->root, $dist)) {
            return $dist;
        }
    }

    warn "$module not found in snapshot\n" if $Carmel::DEBUG;
    return;
}

sub accepts_all {
    my($self, $reqs, $dist) = @_;

    for my $pkg (keys %{$dist->provides}) {
        my $version = $dist->provides->{$pkg}{version} || '0';
        return unless $reqs->accepts_module($pkg, $version);
    }

    return 1;
}

sub merge_requirements {
    my($self, $reqs, $new_reqs, $where) = @_;

    for my $module ($new_reqs->required_modules) {
        my $new = $new_reqs->requirements_for_module($module);
        try {
            $reqs->add_string_requirement($module, $new);
        } catch {
            my($err) = /illegal requirements(?: .*?): (.*) at/;
            my $old = $reqs->requirements_for_module($module);
            die "Found conflicting requirement for $module: '$old' <=> '$new' ($where): $err\n";
        };
    }
}

1;
