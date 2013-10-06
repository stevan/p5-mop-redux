#!perl

use strict;
use warnings;

use Test::More;

use mop;

class BankAccount {
    has $!balance is ro = 0;

    method deposit ($amount) { $!balance += $amount }

    method withdraw ($amount) {
        ($!balance >= $amount)
            || die "Account overdrawn";
        $!balance -= $amount;
    }
}

class CheckingAccount extends BankAccount {
    has $!overdraft_account is ro;

    method withdraw ($amount) {

        my $overdraft_amount = $amount - $self->balance;

        if ( $!overdraft_account && $overdraft_amount > 0 ) {
            $!overdraft_account->withdraw( $overdraft_amount );
            $self->deposit( $overdraft_amount );
        }

        $self->next::method( $amount );
    }
}

my $savings = BankAccount->new( balance => 250 );
isa_ok($savings, 'BankAccount' );

is $savings->balance, 250, '... got the savings balance we expected';

$savings->withdraw( 50 );
is $savings->balance, 200, '... got the savings balance we expected';

$savings->deposit( 150 );
is $savings->balance, 350, '... got the savings balance we expected';

my $checking = CheckingAccount->new(
    overdraft_account => $savings,
);
isa_ok($checking, 'CheckingAccount');
isa_ok($checking, 'BankAccount');

is $checking->balance, 0, '... got the checking balance we expected';

$checking->deposit( 100 );
is $checking->balance, 100, '... got the checking balance we expected';
is $checking->overdraft_account, $savings, '... got the right overdraft account';

$checking->withdraw( 50 );
is $checking->balance, 50, '... got the checking balance we expected';
is $savings->balance, 350, '... got the savings balance we expected';

$checking->withdraw( 200 );
is $checking->balance, 0, '... got the checking balance we expected';
is $savings->balance, 200, '... got the savings balance we expected';

is_deeply(
    mro::get_linear_isa('BankAccount'),
    [ 'BankAccount', 'mop::object' ],
    '... got the expected linear isa'
);

is_deeply(
    mro::get_linear_isa('CheckingAccount'),
    [ 'CheckingAccount', 'BankAccount', 'mop::object' ],
    '... got the expected linear isa'
);

done_testing;



