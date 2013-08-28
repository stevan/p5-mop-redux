#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use mop;

class MetaMeta extends mop::class { }
class Meta extends mop::class meta MetaMeta { }
class Foo meta Meta { }
class Bar meta Meta is closed { }
class Foo::Sub extends Foo { }
class Bar::Sub extends Bar { }

isa_ok(mop::get_meta('Foo'), 'Meta');
isa_ok(mop::get_meta(mop::get_meta('Foo')), 'MetaMeta');
isa_ok(mop::get_meta(mop::get_meta(mop::get_meta('Foo'))), 'mop::class');

isa_ok(mop::get_meta('Bar'), 'Meta');
isa_ok(mop::get_meta(mop::get_meta('Bar')), 'MetaMeta');
isa_ok(mop::get_meta(mop::get_meta(mop::get_meta('Bar'))), 'mop::class');

isa_ok(mop::get_meta('Foo::Sub'), 'Meta');
isa_ok(mop::get_meta(mop::get_meta('Foo::Sub')), 'MetaMeta');
isa_ok(mop::get_meta(mop::get_meta(mop::get_meta('Foo::Sub'))), 'mop::class');

isa_ok(mop::get_meta('Bar::Sub'), 'Meta');
isa_ok(mop::get_meta(mop::get_meta('Bar::Sub')), 'MetaMeta');
isa_ok(mop::get_meta(mop::get_meta(mop::get_meta('Bar::Sub'))), 'mop::class');

done_testing;
