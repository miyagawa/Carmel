# NAME

Carmel - CPAN Artifact Repository Manager

# SYNOPSIS

    # Run with a directory with cpanfile or META.json
    carmel install

    # Manually pull the modules
    carmel install DBI@1.633 Plack@1.0032

    # Runs your perl script with modules from artifacts
    carmel exec perl ...

    # prints export PERL5LIB=... etc for shell scripting
    carmel export

    # find a module in repository
    carmel find DBI

    # find a module matching the version query
    carmel find Plack ">= 1.0000, < 1.1000"

    # list all the modules to be loaded
    carmel list

# DESCRIPTION

**THIS IS EXPERIMENTAL!**

Carmel is yet another CPAN module manager.

Unlike traditional CPAN module installer, Carmel keeps the build of
your dependencies in a central repository, then select the library
paths to include upon runtime.

# HOW IT WORKS

Carmel requires `cpanminus` with a patch to support keeping build
artifacts. [https://github.com/miyagawa/cpanminus/pull/429](https://github.com/miyagawa/cpanminus/pull/429)

With the patch, cpanm will keep the build directory (artifacts) in a
repository, which defaults to `$HOME/.cpanm/builds`, and your
directory structure would look like:

    $HOME/.cpanm/builds
      Plack-1.0033/
        blib/
          arch/
          lib/
      URI-1.64/
        blib/
          arch/
          lib/
      URI-1.63/
        blib/
          arch/
          lib/

Carmel scans this directory and creates the mapping of which package
belongs to which build directory. Given the list of modules and
requirements (using `cpanfile` or even better `cpanfile.snapshot`
from [Carton](https://metacpan.org/pod/Carton)), Carmel lists all the build directories you need, and
then prepend the `blib` directories to `PERL5LIB` environment
variables.

You have a choice to exec a sub process from Carmel, by using the
`exec` sub command. If you prefer full control, you can also use
`env` or `export` command to integrate with your own shell script
wrapper.

# AUTHOR

Tatsuhiko Miyagawa <miyagawa@bulknews.net>

# COPYRIGHT

Copyright 2015- Tatsuhiko Miyagawa

# LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# SEE ALSO

[App::cpanminus](https://metacpan.org/pod/App::cpanminus) [Carton](https://metacpan.org/pod/Carton)

https://github.com/ingydotnet/only-pm

https://github.com/gugod/perlrocks
