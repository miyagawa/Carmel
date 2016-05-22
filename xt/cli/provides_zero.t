use strict;
use Test::More;
use lib ".";
use xt::CLI;

use Carton::Snapshot;

subtest 'carmel install picks up the right version' => sub {
    my $app = cli();

    $app->write_cpanfile(<<EOF);
requires 'Router::Simple', '== 0.16';
EOF

    $app->run("install");

    # blow away the artifact
    my $artifact = $app->repo->find_match(
        'Router::Simple',
        sub { $_[0]->distname eq 'Router-Simple-0.16' },
    );
    $artifact->path->remove_tree({ safe => 0 });

    # depend on submodule with version: undef
    $app->write_cpanfile(<<EOF);
requires 'Router::Simple::Declare';
EOF

    # Tries to install Router-Simple-0.16 via Router::Simple::Declare=0
    # but CPAN has Router-Simple-0.17
    $app->run("install");

 TODO: {
        local $TODO = 'Cannot pass distfile to cpanm';
        unlike $app->stderr, qr/Can't find an artifact for Router::Simple/;
    }
};

done_testing;
