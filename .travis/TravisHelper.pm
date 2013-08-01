package TravisHelper;
use strict;
use warnings;
use Exporter 'import';
our @EXPORT = qw(clone_repos installdeps test);

use Cwd 'cwd';

# note: there are a couple shortcuts in here that assume that p5-mop-redux
# itself has no author tests and doesn't use dzil. if either of those stop
# being true, a few things will probably need to be adjusted.

my $mop_dir = cwd;
# XXX we should probably not be setting this while testing p5-mop-redux itself,
# but i don't think it will hurt anything at the moment
$ENV{PERL5LIB} = $ENV{PERL5LIB}
    ? join(":", "$mop_dir/lib", $ENV{PERL5LIB})
    : "$mop_dir/lib";

(my $mop_repo = $mop_dir) =~ s{^.*/([^/]+/[^/]+)/?$}{$1};
my @repos = (
    [ 'stevan/Plack',                       'master'       ],
    [ 'stevan/Forward-Routes-p5-mop-redux', 'master'       ],
    [ 'stevan/http-headers-actionpack',     'p5-mop'       ],
    [ 'perigrin/promises-perl',             'p5-mop'       ],
    [ 'perigrin/http-thin-useragent',       'p5-mop-redux' ],
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
        if (-e 'Makefile.PL' || -e 'Build.PL') {
            _system(qw(cpanm --installdeps -q --notest .));
        }
        elsif (-e 'dist.ini') {
            _system("cpanm -q --notest Dist::Zilla");
            _system("dzil authordeps --missing | cpanm -q --notest");
            _system("dzil listdeps --missing | grep -v 'find abstract in' | cpanm -q --notest");
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
        if (-e 'Build.PL') {
            _system("perl Build.PL && ./Build test");
        }
        elsif (-e 'Makefile.PL') {
            _system("perl Makefile.PL && make test");
        }
        elsif (-e 'dist.ini') {
            _system("dzil test");
        }
        else {
            _system("prove -lr t");
        }
    }
}

sub _system {
    print join(" ", @_), "\n";
    system(@_);
}

1;
