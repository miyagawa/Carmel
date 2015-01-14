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

# DESCRIPTION

**THIS IS EXPERIMENTAL!**

Carmel is yet another CPAN module manager.

Unlike traditional CPAN module installer, Carmel keeps the build of
your dependencies in a central repository, then select the library
paths to include upon runtime.

# CAVEATS

Carmel requires `cpanminus` with a patch to support keeping build artifacts. [https://github.com/miyagawa/cpanminus/pull/429](https://github.com/miyagawa/cpanminus/pull/429)

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
