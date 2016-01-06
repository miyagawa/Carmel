requires 'perl', '5.012000';

requires 'JSON';
requires 'Class::Tiny', '1.001';
requires 'CPAN::Meta::Requirements', '2.129';
requires 'CPAN::Meta::Prereqs', '2.132830';
requires 'Module::CoreList';
requires 'Module::CPANfile', '1.1000';
requires 'Module::Runtime', '0.014';
requires 'Module::Metadata', '1.000003';
requires 'Path::Tiny', '0.068';
requires 'Try::Tiny', '0.20';
requires 'File::Copy::Recursive';

requires 'File::pushd', '1.009';
requires 'ExtUtils::Install', '1.47';
requires 'ExtUtils::InstallPaths';

requires 'Carton', 'v1.0.13';

# vendor
requires 'Menlo', '1.9000';
requires 'CPAN::Common::Index', '0.006';
requires 'File::HomeDir', '1.00';

on test => sub {
    requires 'Test::More', '0.96';
};

on develop => sub {
    requires 'Test::Requires';
    requires 'Capture::Tiny';
};
