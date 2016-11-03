#!/usr/bin/env python

import sys
sys.path.append("NMSDKpy")
from NaServer import *

cluster = "svlngen4-c01-trad-gen001"
transport = "HTTPS"
port = 443 
style = "CERTIFICATE"
cert = "devops_cert.pem"
key = "devops_cert.key"

s = NaServer(cluster, 1, 30)
s.set_transport_type(transport)
s.set_port(port)
s.set_style(style)
s.set_server_cert_verification(0)
s.set_client_cert_and_key(cert, key)

api = NaElement("system-get-version")
output = s.invoke_elem(api)
if (output.results_status() == "failed"):
    r = output.results_reason()
    print("Failed: " + str(r))
    sys.exit(2)

ontap_version = output.child_get_string("version")
print ("V: " + ontap_version)
