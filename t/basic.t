#!perl
use strict;
use warnings;
my @dmap_files;
BEGIN { @dmap_files = <t/*.dmap> }
use Test::More tests => 2 + @dmap_files;
use Net::DAAP::DMAP qw( dmap_unpack );
BEGIN { use_ok( "Net::DAAP::DMAP::Pack", 'dmap_pack' ) }

is( $Net::DAAP::DMAP::Pack::types{mper}{NAME}, 'dmap.persistentid',
    "extracted the DAAP dictionary from Net::DAAP::DMAP" );

sub is_binary ($$;$) {
    $_[0] =~ s{([^[:print:]])}{sprintf "<%02x>", ord $1}ge;
    $_[1] =~ s{([^[:print:]])}{sprintf "<%02x>", ord $1}ge;
    goto &is;
}
if (eval "use Data::HexDump; use Test::Differences; 1") {
    no warnings 'redefine';
    *is_binary = sub ($$;$) {
        my ($value, $expected, $reason) = @_;
        eq_or_diff( HexDump( $value ), HexDump( $expected ), $reason );
    };
}


for my $file (@dmap_files) {
    local $TODO = "Fix Net::DAAP::DMAP to understand the new content codes"
      if  $file =~ /server-info/;
    my $data = do { open my $fh, '<', $file; local $/; <$fh> };
    is_binary( dmap_pack( dmap_unpack( $data ) ), $data, "$file round trips" );
}
