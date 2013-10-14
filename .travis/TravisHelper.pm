package TravisHelper;
use strict;
use warnings;
use Exporter 'import';
our @EXPORT = qw(clone_repos installdeps test);

use Cwd 'cwd';

my $mop_dir = cwd;
# XXX we should probably not be setting this while testing p5-mop-redux itself,
# but i don't think it will hurt anything at the moment
$ENV{PERL5LIB} = $ENV{PERL5LIB}
    ? join(":", "$mop_dir/lib", $ENV{PERL5LIB})
    : "$mop_dir/lib";

$ENV{RELEASE_TESTING} = 1;
# for the HTTP::Thin::UserAgent test suite
$ENV{LIVE_HTTP_TESTS} = 1;

(my $mop_repo = $mop_dir) =~ s{^.*/([^/]+/[^/]+)/?$}{$1};
my @repos = (
    [ 'stevan/Plack',                       'master'              ],
    [ 'stevan/Forward-Routes-p5-mop-redux', 'master'              ],
    [ 'stevan/http-headers-actionpack',     'p5-mop'              ],
    [ 'stevan/BreadBoard',                  'p5-mop'              ],
    [ 'iinteractive/promises-perl',         'p5-mop'              ],
    [ 'perigrin/http-thin-useragent',       'p5-mop-redux'        ],
    [ 'doy/reply',                          'p5-mop'              ],
    [ 'dams/Action-Retry',                  'experimental/p5-mop' ],
    [ 'stevan/react',                       'master'              ],
    [ 'zakame/hashids.pm',                  'p5-mop'              ],
);
my @dirs = ($mop_repo, (map { $_->[0] } @repos));

sub each_repo (&) {
    my ($block) = @_;
    _each($block, @repos);
}

sub each_dir (&) {
    my ($block) = @_;
    _each(sub {
        my $cwd = cwd;
        print "Entering $_\n";
        chdir($_);
        my $ret = $block->();
        chdir($cwd);
        $ret;
    }, @dirs);
}

sub _each {
    my ($code, @list) = @_;
    chdir("../..");
    my $exit = 0;
    for (@list) {
        $exit += $code->();
    }
    $exit ? 1 : 0;
}

sub clone_repos {
    each_repo {
        _system(
            "git", "clone",
            "git://github.com/$_->[0]",
            "-b", $_->[1],
            $_->[0]
        );
    }
}

sub installdeps {
    each_dir {
        if (-e 'dist.ini' && !/Plack/) {
            _cpanm(qw(cpanm -q --notest Dist::Zilla)) ||
            _cpanm("dzil authordeps --missing | cpanm -q --notest") ||
            _cpanm("dzil listdeps --author --missing | grep -v 'find abstract in' | grep -v '^mop\$' | cpanm -q --notest");
        }
        elsif (-e 'Makefile.PL' || -e 'Build.PL') {
            _cpanm(qw(cpanm --installdeps -q --notest --with-develop .));
        }
        else {
            warn "Don't know how to install deps";
            warn "Cannot find any of Build.PL, Makefile.PL, or dist.ini";
            warn "Continuing, but this probably won't work";
            return 0;
        }
    }
}

sub test {
    each_dir {
        # these fail release tests
        local $ENV{RELEASE_TESTING}
            if /Plack|http-headers-actionpack|BreadBoard/;

        my $failed = 0;

        if (-e 'dist.ini' && !/Plack/) {
            my $cmd = "dzil test";
            $cmd .= ' --all'
                unless /Plack|http-headers-actionpack|BreadBoard/;
            $failed ||= _system($cmd);
        }
        elsif (-e 'Build.PL') {
            $failed ||= _system("perl Build.PL && ./Build test");
        }
        elsif (-e 'Makefile.PL') {
            $failed ||= _system("perl Makefile.PL && make test");
        }
        else {
            $failed ||= _system("prove -lr t");
        }

        if (-e 'xt' && !-e 'dist.ini') {
            $failed ||= _system("prove -lr xt");
        }

        return $failed;
    }
}

sub _system {
    print join(" ", @_), "\n";
    system(@_);
}

sub _cpanm {
    my $ret = _system(@_);
    _system('cat', "$ENV{HOME}/.cpanm/build.log") if $ret;
    return $ret;
}

1;
