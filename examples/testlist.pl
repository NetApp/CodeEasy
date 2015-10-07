#!/usr/bin/perl

my $useNaServer;
my $useNaErrno;
BEGIN { $useNaServer = eval { require NaServer }; }
BEGIN { $useNaErrno = eval { require NaErrno }; }

my $Cluster = "10.1.1.1";
my $User = "admin";
my $Password = "password";
my $MAX_RECORDS = 100;

#
# Name: vGetcDOTList()
# Func: Note that Perl is a lot more forgiving with long object lists than ONTAP is.  As a result,
#	  we have the luxury of returning the entire set of objects back to the caller.  Get all the
#	  objects rather than waiting.
#
sub vGetcDOTList
{
	my ( $zapiServer, $zapiCall, @optArray ) = @_;
	my @list;
	my $done = 0;
	my $tag = 0;
	my $zapi_results;

	while ( !$done ) {
		print "Attempting to collect " . ( $tag ? "more " : "" ) . "API results for $zapiCall from vserver ...\n";
		if ( $tag ) {
			if ( @optArray ) {
				$zapi_results = $zapiServer->invoke( $zapiCall, "tag", $tag, "max-records", $MAX_RECORDS, @optArray );
			} else {
				$zapi_results = $zapiServer->invoke( $zapiCall, "tag", $tag, "max-records", $MAX_RECORDS );
			}
		} else {
			if ( @optArray ) {
				$zapi_results = $zapiServer->invoke( $zapiCall, "max-records", $MAX_RECORDS, @optArray );
			} else {
				$zapi_results = $zapiServer->invoke( $zapiCall, "max-records", $MAX_RECORDS );
			}
		}
		if ( $zapi_results->results_status() eq "failed" ) {
			print "ERROR: ONTAP API call $zapiCall failed: " . $zapi_results->results_reason() . "\n";
			return( 0 );
		}

		$tag = $zapi_results->child_get_string( "next-tag" );
		my $list_attrs = $zapi_results->child_get( "attributes-list" );
		if ( $list_attrs ) {
			my @list_items = $list_attrs->children_get();
			if ( @list_items ) {
				push( @list, @list_items );
			}
		}
		if ( !$tag ) {
			$done = 1;
		}
	}
	return( @list );
}

if ( !$useNaServer ) {
	print( "Perl module NaServer not available!\n" );
	exit( 1 );
}

if ( !$useNaErrno ) {
	print( "Perl module NaErrno not available!\n" );
	exit( 1 );
}

print "Creating login to storage controller/vserver " . $Cluster . " ...\n";
$zapiServer = NaServer->new( $Cluster, 1, 1 );
$zapiServer->set_admin_user( $User, $Password );
$zapiServer->set_transport_type( 'HTTPS' );
my $results = $zapiServer->invoke( "system-get-ontapi-version" );
if ( $results->results_status() eq "failed" ) {
	print "ERROR: ONTAP API connection to " . $Cluster . " failed: " . $results->results_reason() . "\n";
	exit( 1 );
}
print "ONTAP Version: " . $results->child_get_string( "major-version" ) . "." . $results->child_get_string( "minor-version" ) . "\n";

my @list = vGetcDOTList( $zapiServer, "net-interface-get-iter" );
foreach my $val ( @list ) {
	my $lifaddr = $val->child_get_string( "address" );
	print "Address: " . $lifaddr . "\n";
}

my @vlist = vGetcDOTList( $zapiServer, "volume-get-iter" );
foreach $tattr ( @vlist ) {
	$vol_id_attrs = $tattr->child_get( "volume-id-attributes" );
	if ( $vol_id_attrs ) {
		$jpath = $vol_id_attrs->child_get_string( "junction-path" );
		print "Name: " . $vol_id_attrs->child_get_string( "name" ) . ", Junction Path: " . $jpath . "\n";
	}
}
