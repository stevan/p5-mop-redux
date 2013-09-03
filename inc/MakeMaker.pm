package inc::MakeMaker;

use Moose;
use lib 'inc';
use MMHelper;

extends 'Dist::Zilla::Plugin::MakeMaker::Awesome';
with 'Dist::Zilla::Role::MetaProvider';

override _build_MakeFile_PL_template => sub {
    my ($self) = @_;

    my $tmpl = super();

    my $ccflags = MMHelper::ccflags_dyn();
    $tmpl =~ s/^(WriteMakefile\()/\$WriteMakefileArgs{CCFLAGS} = $ccflags;\n\n$1/m;

    $tmpl =~ s/^(use ExtUtils::MakeMaker)/MMHelper::header_generator() . "\n$1"/em
        or die;

    return $tmpl;
};

sub metadata {
    return { dynamic_config => 1 };
}

override _build_WriteMakefile_args => sub {
    my ($self) = @_;
    my $args = super();

    return {
        %{ $args },
        MMHelper::mm_args(),
    };
};

after register_prereqs => sub {
    my ($self) = @_;

    $self->zilla->register_prereqs(
        { phase => 'configure' },
        'IO::File'           => 0,
        'Devel::CallChecker' => 0,
        'Devel::CallParser'  => 0,
    );
};

1;
