use strict;
use warnings;
use inc::Module::Install;

name 'p5-mop-redux';
all_from 'lib/mop.pm';
license 'perl';

requires 'MRO::Define'              => 0;
requires 'Sub::Name'                => 0;
requires 'Devel::Declare'           => 0;
requires 'B::Hooks::EndOfScope'     => 0;
requires 'Devel::GlobalDestruction' => 0;
requires 'Hash::Util::FieldHash'    => 0;
requires 'Variable::Magic'          => 0;
requires 'Package::Stash'           => 0;
requires 'Carp'                     => 0;
requires 'Clone'                    => 0;
requires 'Scalar::Util'             => 0;
requires 'Data::Dumper'             => 0;
requires 'parent'                   => 0;

build_requires 'Test::More'     => 0;
build_requires 'Test::Fatal'    => 0;
build_requires 'Test::Warnings' => 0;
build_requires 'Test::Warn'     => 0;
build_requires 'Test::Moose'    => 0;
build_requires 'Path::Class'    => 0;

tests('t/*.t t/*/*.t t/300-ext/*/*.t');

WriteAll();
