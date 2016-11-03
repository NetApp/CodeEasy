#!/usr/bin/perl -w

use lib 'NMSDK';
use NaServer;

$cert = "devops_cert.pem";
$key = "devops_cert.key";
$cluster = "svlngen4-c01-trad-gen001";

$server = new NaServer($cluster, 1, 30);
$server->set_transport_type('HTTPS');
$server->set_port('443');
$server->set_style('CERTIFICATE');
$server->set_server_cert_verification(0);
$server->set_client_cert_and_key($cert, $key);

$output = $server->invoke('system-get-version');
if ($output->results_status() eq "failed") {
	die "Error: ", $output->results_reason();
}

$version = $output->child_get_string('version');
print "V: $version\n";
