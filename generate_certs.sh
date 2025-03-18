#!/bin/bash

# Get the LAN IP address
LAN_IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n 1)
if [ -z "$LAN_IP" ]; then
    echo "Could not detect LAN IP address"
    exit 1
fi

echo "Detected LAN IP: $LAN_IP"

# Create certs directory if it doesn't exist
mkdir -p certs

# Create config file for Root CA
cat > certs/root-ca.conf << EOF
[req]
default_bits = 4096
prompt = no
default_md = sha256
x509_extensions = v3_ca
distinguished_name = dn

[dn]
C = US
ST = State
L = City
O = My Root CA
OU = My Root CA Division
CN = My Root CA

[v3_ca]
basicConstraints = critical,CA:TRUE
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
EOF

# Create config for server certificate
cat > certs/server.conf << EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = v3_req
distinguished_name = dn

[dn]
C = US
ST = State
L = City
O = My Organization
OU = My Division
CN = localhost

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
DNS.2 = *.localhost
DNS.3 = $LAN_IP
IP.1 = 127.0.0.1
IP.2 = ::1
IP.3 = $LAN_IP
EOF

# Generate Root CA private key and certificate
openssl genrsa -out certs/root-ca.key 4096
openssl req -x509 -new -nodes -key certs/root-ca.key -sha256 -days 3650 -out certs/root-ca.crt -config certs/root-ca.conf

# Generate server private key and CSR
openssl genrsa -out certs/private.key 2048
openssl req -new -key certs/private.key -out certs/server.csr -config certs/server.conf

# Sign the server certificate with our Root CA
openssl x509 -req -in certs/server.csr -CA certs/root-ca.crt -CAkey certs/root-ca.key -CAcreateserial \
    -out certs/certificate.crt -days 365 -sha256 \
    -extensions v3_req -extfile certs/server.conf

# Set proper permissions
chmod 644 certs/certificate.crt certs/root-ca.crt
chmod 600 certs/private.key certs/root-ca.key

# Clean up
rm certs/server.csr certs/root-ca.srl certs/*.conf

echo "Certificates have been generated in the certs directory"
echo ""
echo "Your certificates now include the following addresses:"
echo "- localhost"
echo "- *.localhost"
echo "- $LAN_IP"
echo ""
echo "To trust these certificates in Chrome:"
echo "1. Open Chrome and go to chrome://settings/security"
echo "2. Click on 'Manage certificates'"
echo "3. Go to the 'Authorities' tab"
echo "4. Click 'Import'"
echo "5. Select the 'certs/root-ca.crt' file (NOT certificate.crt)"
echo "6. Check all boxes when prompted and click 'OK'"
echo "7. Restart Chrome completely"
echo ""
echo "You can now access your site using:"
echo "- https://localhost:6052"
echo "- https://$LAN_IP:6052" 