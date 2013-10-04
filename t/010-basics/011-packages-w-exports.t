#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

BEGIN {
    eval { require Path::Class; 1 }
        or ($ENV{RELEASE_TESTING}
            ? die
            : plan skip_all => "This test requires Path::Class");
}

=pod

This test shows how you can import functions
into your package, and then use them in your
class this removes the need to import anything
into your class namespace.

=cut

{

    package My::DB::FlatFile;
    use strict;
    use warnings;
    use mop;

    use Path::Class qw[ file ];

    class DataFile {
        has $!path;
        has $!file;
        has $!data;

        method data { $!data }

        method BUILD {
            $!file = file( $!path );
            $!data = [ $!file->slurp( chomp => 1 ) ];
        }
    }
}

my $data_file = My::DB::FlatFile::DataFile->new( path => __FILE__ );
ok( $data_file->isa( 'My::DB::FlatFile::DataFile' ), '... the object is from class My::DB::FlatFile::DataFile' );
ok( $data_file->isa( 'mop::object' ), '... the object is derived from class Object' );
is( $data_file->data->[0], '#!/usr/bin/perl', '... got the first line of the data we expected' );

done_testing;
