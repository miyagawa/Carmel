package Devel::Carmel;
use Config;
use Module::CoreList;

sub bootstrap {
    my($class, $inc) = @_;
    unshift @INC, @$inc, __PACKAGE__->new($inc);
}

sub _package {
    my $file = shift;
    $file =~ s/\.pm$//;
    $file =~ s!/!::!g;
    $file;
}

sub new {
    my($class, $inc) = @_;
    bless {
        inc => $inc,
        corelist => {},
    }, $class;
}

sub Devel::Carmel::INC {
    my($self, $file) = @_;

    # Config_heavy.pl etc.
    return if $file =~ /\.pl$/;

    my $mod = _package($file);
    my @caller = caller 0;

    # eval { require Module }
    return if $caller[3] =~ /^\(eval/ or defined $caller[6];

    # core module calling another module is considered core, too.
    # FIXME: Updated core module might call a non-core package
    if ($self->{corelist}{$caller[0]}) {
        $self->{corelist}{$mod} = 1;
        return;
    }

    # core module
    if ($Module::CoreList::version{$]+0}{$mod}) {
        $self->{corelist}{$mod} = 1;
        return;
    }

    # Module::Runtime::use_package_optimistically tries to parse this message.
    die "Can't locate $file in \@INC with Carmel artifacts (You may need to add `requires '$mod';` to your cpanfile and run carmel install) (\@INC contains: @{$self->{inc}}) at $caller[1] line $caller[2].\n";
}

1;

__END__
