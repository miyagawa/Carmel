package Carmel::InstallInfo;
use strict;
use File::Find;
use ExtUtils::Manifest;
use CPAN::DistnameInfo;
use File::pushd;
use CPAN::Meta;
use Parse::PMFile;
use YAML;

sub build {
    my($class, $dir, $file) = @_;

    my $yaml = YAML::LoadFile("$dir.yml");
    my $dist_info = CPAN::DistnameInfo->new("$yaml->{distribution}{ID}");

    my $info = {
        version => $dist_info->version,
        provides => $class->_scan_provides($dir),
        dist => $dist_info->distvname,
        name => $yaml->{distribution}{CALLED_FOR},
        pathname => $dist_info->pathname,
        target => $yaml->{distribution}{CALLED_FOR},
    };

    mkdir "$dir/blib/meta", 0777 unless -e "$dir/blib/meta";
    open my $fh, ">", $file or die "$file: $!";
    print $fh JSON::encode_json($info);
}

sub _scan_provides {
    my($class, $dir) = @_;

    my $pushd = File::pushd::pushd $dir;

    my($meta_file) = grep -e, "META.json", "META.yml";
    my $meta = CPAN::Meta->load_file($meta_file);

    my $try = sub {
        my $file = shift;
        return 0 if $file =~ m!^(?:x?t|inc|local|perl5|fatlib|_build)/!;
        return 1 unless $meta->{no_index};
        return 0 if grep { $file =~ m!^$_/! } @{$meta->{no_index}{directory} || []};
        return 0 if grep { $file eq $_ } @{$meta->{no_index}{file} || []};
        return 1;
    };

    my @found_files;
    if (-e "$dir/MANIFEST") {
        my $manifest = eval { ExtUtils::Manifest::manifind() } || {};
        @found_files = sort { lc $a cmp lc $b } keys %$manifest;
    } else {
        my @files;
        my $finder = sub {
            my $name = $File::Find::name;
            $name =~ s!\.[/\\]!!;
            push @files, $name;
        };
        File::Find::find($finder, ".");
        @found_files = sort { lc $a cmp lc $b } @files;
    }

    my @files = grep { /\.pm(?:\.PL)?$/ && $try->($_) } @found_files;

    my $provides = {};

    for my $file (@files) {
        my $parser = Parse::PMFile->new($meta, { UNSAFE => 1, ALLOW_DEV_VERSION => 1 });
        my $packages = $parser->parse($file);

        while (my($package, $meta) = each %$packages) {
            $provides->{$package} ||= {
                file => $meta->{infile},
                ($meta->{version} eq 'undef') ? () : (version => $meta->{version}),
            };
        }
    }

    return $provides;
}

1;
