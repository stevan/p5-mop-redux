
use strict;
use warnings;

use 5.016000;

use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  "ABSTRACT" => "A meta-object protocol for Perl 5",
  "AUTHOR" => "Stevan Little <stevan\@iinterative.com>",
  "BUILD_REQUIRES" => {},
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.30"
  },
  "DISTNAME" => "p5-mop-redux",
  "EXE_FILES" => [],
  "LICENSE" => "perl",
  "NAME" => "p5::mop::redux",
  "PREREQ_PM" => {
    "B::Hooks::EndOfScope" => 0,
    "Clone" => 0,
    "Devel::GlobalDestruction" => 0,
    "Hash::Util::FieldHash" => 0,
    "List::AllUtils" => 0,
    "MRO::Define" => 0,
    "Module::Runtime" => 0,
    "Package::Stash" => 0,
    "Parse::Keyword" => 0,
    "Scalar::Util" => 0,
    "Scope::Guard" => 0,
    "Sub::Exporter" => 0,
    "Sub::Install" => 0,
    "Sub::Name" => 0,
    "Variable::Magic" => 0,
    "mro" => 0,
    "overload" => 0,
    "parent" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "Data::Dumper" => 0,
    "FindBin" => 0,
    "IO::Handle" => 0,
    "Moose" => 0,
    "Moose::Util::TypeConstraints" => 0,
    "Path::Class" => 0,
    "Test::BuilderX" => 0,
    "Test::BuilderX::Output" => 0,
    "Test::BuilderX::Test" => 0,
    "Test::BuilderX::TestPlan" => 0,
    "Test::Fatal" => 0,
    "Test::Moose" => 0,
    "Test::More" => "0.88",
    "Test::Requires" => 0,
    "Test::Warn" => 0,
    "if" => 0,
    "lib" => 0
  },
  "VERSION" => "0.01",
  "test" => {
    "TESTS" => "t/*.t t/001-examples/*.t t/010-basics/*.t t/030-roles/*.t t/050-non-mop-integration/*.t t/100-internals/*.t t/110-oddities/*.t t/120-bugs/*.t t/150-parser-tests/*.t t/200-meta/*.t t/300-ext/Option/*.t t/300-ext/Test-BuilderX/*.t t/400-traits/*.t"
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



