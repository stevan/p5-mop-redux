use v5.14;
use warnings;

use mop;

class Option is abstract {
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

class None extends Option {
    method get              { die "None->get" }
    method get_or_else ($f) { $f->() }
    method or_else     ($f) { $f->() }
    method is_defined       { 0 }
    method is_empty         { 1 }
    method map         ($f) { ref($self)->new }
    method flatmap     ($f) { ref($self)->new }
    method flatten     ($f) { ref($self)->new }
    method foreach     ($f) {}
    method forall      ($f) { 1 }
    method exists      ($f) { 0 }
}

class Some extends Option {
    has $!val;
    method get              { $!val }
    method get_or_else ($f) { $!val }
    method or_else     ($f) { ref($self)->new( val => $!val ) }
    method is_defined       { 1 }
    method is_empty         { 0 }
    method map         ($f) { ref($self)->new( val => $f->( $!val ) ) }
    method flatmap     ($f) { $f->( $!val ) }
    method flatten          { ref($self)->new( val => $!val ) }
    method foreach     ($f) { $f->( $!val ) }
    method forall      ($f) { $f->( $!val ) }
    method exists      ($f) { $f->( $!val ) }
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

=item C<map>

  option match {
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
