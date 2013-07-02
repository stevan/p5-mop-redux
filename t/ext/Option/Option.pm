use v5.14;
use warnings;

use mop;

class Option {
    method get;
    method get_or_else;
    method or_else;
    method is_defined;
    method is_empty;
    method map;
    method flatmap;
    method flatten;
    method foreach;
    method forall;
    method exists;
}

class None (extends => 'Option') {
    method get              { die "None->get" }
    method get_or_else ($f) { $f->() }
    method or_else     ($f) { $f->() }
    method is_defined       { 0 }
    method is_empty         { 1 }
    method map         ($f) { $class->new }
    method flatmap     ($f) { $class->new }
    method flatten     ($f) { $class->new }
    method foreach     ($f) {}
    method forall      ($f) { 1 }
    method exists      ($f) { 0 }
}

class Some (extends => 'Option') {
    has $x;
    method get              { $x }
    method get_or_else ($f) { $x }
    method or_else     ($f) { $class->new( x => $x ) }
    method is_defined       { 1 }
    method is_empty         { 0 }
    method map         ($f) { $class->new( x => $f->( $x ) ) }
    method flatmap     ($f) { $f->( $x ) }
    method flatten     ($f) { $class->new( x => $x ) }
    method foreach     ($f) { $f->( $x ) }
    method forall      ($f) { $f->( $x ) }
    method exists      ($f) { $f->( $x ) }
}

1;

__END__

=pod

=over 4

=item C<get>

  option match
    case None    => die
    case Some(x) => x
  }

=item C<get_or_else>

  option match {
    case None    => foo
    case Some(x) => x
  }

=item C<or_else>

  option match {
    case None    => foo
    case Some(x) => Some(x)
  }

=item C<is_defined>

  option match {
    case None    => false
    case Some(_) => true
  }

=item C<is_empty>

  option match {
    case None    => true
    case Some(_) => false
  }

=item C<map';
  option match>

    case None    => None
    case Some(x) => Some(foo(x))
  }

=item C<flatmap>

  option match {
    case None    => None
    case Some(x) => foo(x)
  }

=item C<flatten>

  option match {
   case None    => None
   case Some(x) => x
  }

=item C<foreach>

  option match {
    case None    => {}
    case Some(x) => foo(x)
  }

=item C<forall>

  option match {
    case None    => true
    case Some(x) => foo(x)
  }


=item C<exists>

  option match {
    case None    => false
    case Some(x) => foo(x)
  }

=back

=cut
