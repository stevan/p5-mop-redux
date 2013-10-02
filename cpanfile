# core
requires 'Carp'                  => 0;
requires 'Hash::Util::FieldHash' => 0;
requires 'Scalar::Util'          => 0;
requires 'mro'                   => 0;
requires 'overload'              => 0;
requires 'parent'                => 0;
requires 'perl'                  => 5.016;
requires 'strict'                => 0;
requires 'version'               => 0;
requires 'warnings'              => 0;

build_requires 'B::Deparse'  => 0;
build_requires 'FindBin'     => 0;
build_requires 'IO::Handle'  => 0;
build_requires 'Test::Fatal' => 0;
build_requires 'Test::More'  => 0.88;
build_requires 'if'          => 0;
build_requires 'lib'         => 0;

# parser
requires 'B::Hooks::EndOfScope' => 0;
requires 'Parse::Keyword'       => 0.04;
requires 'Scope::Guard'         => 0;
requires 'Sub::Name'            => 0;
requires 'twigils'              => 0;
requires 'Variable::Magic'      => 0;

# mro
requires 'Devel::GlobalDestruction' => 0;
requires 'MRO::Define'              => 0;

# other
requires 'Module::Runtime'    => 0;
requires 'Package::Stash'     => 0;
requires 'Package::Stash::XS' => 0.27;

author_requires 'Devel::StackTrace'            => 0;
author_requires 'Moose'                        => 0;
author_requires 'Moose::Util::TypeConstraints' => 0;
author_requires 'Path::Class'                  => 0;
author_requires 'Test::EOL'                    => 0;
author_requires 'Test::NoTabs'                 => 0;
author_requires 'Test::Pod'                    => 1.41;
