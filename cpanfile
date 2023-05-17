requires 'perl', '5.014000';

requires 'JSON';
requires 'Class::Tiny', '1.001';
requires 'CPAN::Meta::Requirements', '2.129';
requires 'Module::CoreList';
requires 'Module::CPANfile', '1.1000';
requires 'Module::Runtime', '0.014';
requires 'Module::Metadata', '1.000003';
requires 'Path::Tiny', '0.068';
requires 'Try::Tiny', '0.20';
requires 'File::Copy::Recursive';
requires 'CPAN::DistnameInfo';

requires 'File::pushd', '1.009';
requires 'ExtUtils::Install', '1.47';
requires 'ExtUtils::InstallPaths';

requires 'Carton', 'v1.0.35';

# vendor
requires 'Menlo::CLI::Compat', '1.9018';

on test => sub {
    requires 'Test::More', '0.96';
};

on develop => sub {
    requires 'Test::Requires';
    requires 'Capture::Tiny';
};
