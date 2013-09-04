package Backward::Routes::Resource;
use v5.16;
use warnings;
use mop;

class Plural extends Backward::Routes::Resource {
    has $!id_constraint;
}

1;