package Backward;
use v5.16;
use warnings;
use mop;

use Backward::Routes::Match;
use Backward::Routes::Resource;

class Routes {

    method add_resource {
        $self->_add_plural_resource()
    }

    method _add_plural_resource {
        Backward::Routes::Resource::Plural->new
    }

}

1;