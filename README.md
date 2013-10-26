[![Build Status](https://travis-ci.org/stevan/p5-mop-redux.png?branch=master)](https://travis-ci.org/stevan/p5-mop-redux)
[![Coverage Status](https://coveralls.io/repos/stevan/p5-mop-redux/badge.png?branch=master)](https://coveralls.io/r/stevan/p5-mop-redux?branch=master)

A(nother) MOP for Perl 5
============

This is a second attempt at building a MOP for Perl 5, this time with
significantly scaled back ambition.

The goal is to still have the same syntax, but to make the MOP itself
much less complicated, therefore hopefully making the implementation
ultimately more maintainable. Additionally this is being built from
the start to be compatible with old-style Perl 5 objects and to try
to lean on existing Perl conventions instead of inventing a bunch of
new things.

Contributing
------------

* Port existing Perl projects to use mop; tell us what breaks.
