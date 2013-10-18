package inc::MakeMaker;
use Moose;

extends 'Dist::Zilla::Plugin::MakeMaker::Awesome';

around _build_MakeFile_PL_template => sub {
    my $orig = shift;
    my $self = shift;

    my $dumper = Data::Dumper->new(
        [ $self->zilla->prereqs->requirements_for(qw(develop requires))->as_string_hash ],
        [ '*DEVELOP_REQUIRES' ]
    );
    $dumper->Sortkeys(1);
    $dumper->Indent(1);
    $dumper->Useqq(1);
    $dumper->Pad('  ');

    my $prereqs = $dumper->Dump =~ s/^\s*//r;

    my $fixup_prereqs = <<PREREQS;
if (\$ENV{RELEASE_TESTING}) {
  my $prereqs
  \$WriteMakefileArgs{BUILD_REQUIRES} = {
    %{ \$WriteMakefileArgs{BUILD_REQUIRES} },
    %DEVELOP_REQUIRES,
  };
}
PREREQS

    my $callparser_h = <<'CALLPARSER_H';
use Devel::CallParser 'callparser1_h', 'callparser_linkable';
use File::Spec::Functions 'abs2rel';
{
    open my $fh, '>', 'callparser1.h' or die $!;
    print { $fh } callparser1_h or die $!;
    close $fh or die $!;
}
my @linkable = map { abs2rel($_) } callparser_linkable;
unshift @linkable, '$(BASEEXT)$(OBJ_EXT)' if @linkable;
$WriteMakefileArgs{OBJECT} = join(' ', @linkable) if @linkable;
$WriteMakefileArgs{clean}{FILES} .= ' callparser1.h';
CALLPARSER_H

    my $template = $self->$orig(@_);
    $template =~ s/(WriteMakefile\()/$fixup_prereqs\n$callparser_h\n$1/;

    return $template;
};

__PACKAGE__->meta->make_immutable;
no Moose;
