
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
    # internal hacking modules
    # needed for implementation
    'B::Hooks::EndOfScope'     => 0,
    'Devel::GlobalDestruction' => 0,
    'MRO::Define'              => 0,
    'Parse::Keyword'           => '0.04',    
    'Scope::Guard'             => 0,
    'Variable::Magic'          => 0,

    # utility modules needed 
    # for implementation
    'Hash::Util::FieldHash'    => 0,
    'Package::Stash'           => 0,
    'Package::Stash::XS'       => '0.27',
    'Module::Runtime'          => 0,
    'Sub::Name'                => 0,

    # general utility modules
    'Carp'                     => 0,
    'List::AllUtils'           => 0,
    'Scalar::Util'             => 0,
    'Sub::Exporter'            => 0,

    # core pragmas
    'mro'                      => 0,
    'overload'                 => 0,
    'parent'                   => 0,
    'strict'                   => 0,
    'warnings'                 => 0,
  },
  'TEST_REQUIRES' => {
    # test modules
    'Test::More'                   => '0.88',
    'Test::Warn'                   => 0,    
    'Test::Fatal'                  => 0,    

    # core utility pragma
    'lib'                          => 0,

    # modules needed in tests
    'FindBin'                      => 0,
    'IO::Handle'                   => 0,
    'Moose'                        => 0,
    'Devel::PartialDump'           => 0,
    'Moose::Util::TypeConstraints' => 0,
    'Path::Class'                  => 0,
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

WriteMakefile(%WriteMakefileArgs);



