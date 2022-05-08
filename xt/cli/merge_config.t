use strict;
use Test::More;
use lib ".";
use xt::CLI;

subtest 'merge configure dependencies' => sub {
    my $app = cli();

    $app->write_file('cpanfile.snapshot', <<EOF);
# carton snapshot format: version 1.0
DISTRIBUTIONS
  Module-Build-Tiny-0.038
    pathname: L/LE/LEONT/Module-Build-Tiny-0.038.tar.gz
    provides:
      Module::Build::Tiny 0.038
    requirements:
      CPAN::Meta 0
      DynaLoader 0
      Exporter 5.57
      ExtUtils::CBuilder 0
      ExtUtils::Config 0.003
      ExtUtils::Helpers 0.020
      ExtUtils::Install 0
      ExtUtils::InstallPaths 0.002
      ExtUtils::ParseXS 0
      File::Basename 0
      File::Find 0
      File::Path 0
      File::Spec::Functions 0
      Getopt::Long 2.36
      JSON::PP 2
      Pod::Man 0
      TAP::Harness::Env 0
      perl 5.006
      strict 0
      warnings 0
EOF

    $app->write_cpanfile(<<EOF);
requires 'CPAN::Test::Dummy::Perl5::VersionQV';
requires 'Module::Build::Tiny';
EOF

    $app->run_ok("install");
    like $app->stdout, qr/Complete/;
    
    $app->run_ok("list");

    like $app->stdout, qr/Module::Build::Tiny \(0\.038\)/
      or diag $app->stderr;
};

done_testing;
