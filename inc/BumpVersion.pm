package inc::BumpVersion;
use Moose;

with 'Dist::Zilla::Role::AfterRelease';

sub after_release {
    my $self = shift;
    system('perl-reversion', '-bump');
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
