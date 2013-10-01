
use 5.016000;

use strict;
use warnings;

use ExtUtils::MakeMaker 6.30;

my %WriteMakefileArgs = (
  'ABSTRACT'           => 'A meta-object protocol for Perl 5',
  'DISTNAME'           => 'p5-mop-redux',
  'AUTHOR'             => 'Stevan Little <stevan.little@iinterative.com>',
  'LICENSE'            => 'perl',
  'NAME'               => 'mop',
  'VERSION'            => '0.01',
  'BUILD_REQUIRES'     => {},
  'CONFIGURE_REQUIRES' => { 'ExtUtils::MakeMaker' => '6.30' },
  'EXE_FILES'          => [],
  'PREREQ_PM'          => {
    # core
    'Carp'                  => 0,
    'Exporter'              => 0,
    'Hash::Util::FieldHash' => 0,
    'Scalar::Util'          => 0,
    'mro'                   => 0,
    'overload'              => 0,
    'parent'                => 0,
    'strict'                => 0,
    'version'               => 0,
    'warnings'              => 0,

    # parser
    'B::Hooks::EndOfScope' => 0,
    'Parse::Keyword'       => 0.04,
    'Scope::Guard'         => 0,
    'Sub::Name'            => 0,
    'twigils'              => 0,
    'Variable::Magic'      => 0,

    # mro
    'Devel::GlobalDestruction' => 0,
    'MRO::Define'              => 0,

    # other
    'Module::Runtime'    => 0,
    'Package::Stash'     => 0,
    'Package::Stash::XS' => 0.27,
  },
  'TEST_REQUIRES' => {
    # core
    'Test::Fatal' => 0,
    'Test::More'  => 0.88,
    'if'          => 0,
    'lib'         => 0,

    # other
    'B::Deparse' => 0,
    'FindBin'    => 0,
    'IO::Handle' => 0,
  },
  'test' => {
    'TESTS' => 't/*.t t/*/*.t t/300-ext/*/*.t'
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  my $tr = delete $WriteMakefileArgs{TEST_REQUIRES};
  my $br = $WriteMakefileArgs{BUILD_REQUIRES};
  for my $mod ( keys %$tr ) {
    if ( exists $br->{$mod} ) {
      $br->{$mod} = $tr->{$mod} if $tr->{$mod} > $br->{$mod};
    }
    else {
      $br->{$mod} = $tr->{$mod};
    }
  }
}

unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

if ($ENV{RELEASE_TESTING}) {
    $WriteMakefileArgs{TEST_REQUIRES} = {
        %{ $WriteMakefileArgs{TEST_REQUIRES} },
        'Devel::StackTrace'            => 0,
        'Moose'                        => 0,
        'Moose::Util::TypeConstraints' => 0,
        'Path::Class'                  => 0,
        'Test::EOL'                    => 0,
        'Test::NoTabs'                 => 0,
        'Test::Pod'                    => 1.41,
    };
}

WriteMakefile(%WriteMakefileArgs);



