package Net::DAAP::DMAP::Pack;
use strict;
use warnings;
use Net::DAAP::DMAP;
use Math::BigInt;
use Carp;
use base 'Exporter';
our @EXPORT_OK = qw( dmap_pack );
our $VERSION = '1.20';

# okay, this is evil, and fragile, but then this data shouldn't be
# hidden in a lexical as it is in Net::DAAP::DMAP
our %types;
{
    open my $fh, $INC{"Net/DAAP/DMAP.pm"};
    while (<$fh>) { last if /^__DATA__$/ }
    local $/;
    %types = %{ eval <$fh> };
}

my $original_update_content_codes = \&Net::DAAP::DMAP::update_content_codes;
*Net::DAAP::DMAP::update_content_codes = sub {
    my $dmap = shift;
    print "I are cheating\n";
    $original_update_content_codes->( $dmap );
};

our %by_name = map { $_->{NAME} => $_ } values %types;

our %pack_types = (
     1 => 'c',
     3 => 'n',
     5 => 'N',
     7 => "64-bit - not handled by pack",
     9 => 'a*',
    10 => 'N',
    11 => 'nn',
    12 => "container - not handled by pack",
);
use constant bigint    => 7;
use constant container => 12;

=head1 NAME

Net::DAAP::DMAP::Pack - Write DMAP encoded data

=head1 SYNOPSIS

 use Net::DAAP::DMAP qw( dmap_unpack );
 use Net::DAAP::DMAP::Pack qw( dmap_pack );
 my $data = '...';
 is( dmap_pack( dmap_unpack( $data ) ), $data, "round trips" );

=head1 DESCRIPTION

Net::DAAP::DMAP::Pack contains a dmap_pack routine, which is strangely
missing from Net::DAAP::DMAP, since its pod says:

 =head1 NAME

 Net::DAAP::DMAP - Perl module for reading and writing DAAP structures

Consult the Net::DAAP::DMAP documentation for an explanation of the
data structure used by dmap_pack and dmap_unpack.

=cut

sub dmap_pack {
    my $struct = shift;
    my $out = '';

    for my $pair (@$struct) {
        my ($name, $value) = @$pair;
        # Net::DAAP::DMAP doesn't populate the name when its decoded
        # something it doesn't know the content-code of, like aeSV
        # which is new to 4.5
        unless ($name) {
            carp "element without a name - skipping";
            next;
        }
        # or, it may be we don't know what kind of thing this is
        unless (exists $by_name{ $name }) {
            carp "we don't know the type for '$name' elements - skipping";
            next;
        }

        my $tag  = $by_name{ $name }{ID};
        my $type = $by_name{ $name }{TYPE};
        #print "$name => $tag $type $pack_types{$type}\n";
        #$SIG{__WARN__} = sub { die @_ };
        if ($type == container) {
            $value = dmap_pack( $value );
        }
        elsif ($type == bigint) {
            my $high = Math::BigInt->new( $value )->brsft(32)."";
            my $low  = Math::BigInt->new( $value )->band(0xFFFFFFFF)."";
            $value = pack( "N2", $high, $low );
        }
        else {
            no warnings 'uninitialized';
            $value = pack( $pack_types{$type}, $value );
        }
        my $length = do { use bytes; length $value };
        $out .= $tag . pack("N", $length) . $value;
    }
    return $out;
}


1;
__END__

=head1 TODO

=over

=item

Fiddle with Net::DAAP::DMAP's default dictionary, since it doesn't
know about new tags like C<aeSV>, and Net::DAAP::Client doesn't
download /content-codes

=item

Allow the tag name to be used when packing, so you can write

 dmap_pack([[ mlog => [[ mstt => 200 ], [ mlid => 42 ]] ]]);

rather than:

 dmap_pack([[ 'dmap.loginresponse' => [
                 [ 'dmap.status' =>  200 ],
                 [ 'dmap.sessionid' => 42 ],
              ],
           ]]);

Which is somewhat tedious.

=back

=head1 AUTHOR

Richard Clamp <richardc@unixbeard.net>

=head1 COPYRIGHT

Copyright 2004 Richard Clamp.  All Rights Reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

Net::DAAP::DMAP

=cut
