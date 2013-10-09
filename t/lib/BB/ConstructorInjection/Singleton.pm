package BB::ConstructorInjection;
use strict;
use warnings;

use mop;

class BB::ConstructorInjection::Singleton extends BB::ConstructorInjection
                                             with BB::LifeCycle::Singleton { }

no mop;

1;
