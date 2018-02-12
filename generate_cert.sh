#!/bin/sh

# This script generates a self signed cert for your local unifi controller

# https://gist.github.com/Soarez/9688998
# https://github.com/netty/netty/blob/4.1/handler/src/test/resources/io/netty/handler/ssl/generate-certs.sh#L14
# https://github.com/stevejenkins/unifi-linux-utils/blob/master/unifi_ssl_import.sh

SUBJECT=${1:-"/CN=unifi.local"}
DAYS=3650

CA_KEY="unifi_ca.key"
CA_CERT="unifi_ca.pem"

LOCAL_KEY_TEMP="unifi.temp.key"
LOCAL_KEY="unifi.key"
LOCAL_SIGNED_CERT="unifi-signed.pem"

CHAIN_FILE="chain.pem"
KEYSTORE="keystore.p12"

ALIAS="unifi"
PASSWORD="aircontrolenterprise"

# Generate a new, self-signed root CA
openssl req -extensions v3_ca -new -x509 -days $DAYS -nodes -subj "/CN=${ALIAS}" -newkey rsa:2048 -sha512 -out $CA_CERT -keyout $CA_KEY

# Generate a certificate/key for the server to use for Hostname Verification via unifi.local
openssl req -new -keyout $LOCAL_KEY_TEMP -nodes -newkey rsa:2048 -subj $SUBJECT | \
    openssl x509 -req -CAkey $CA_KEY -CA $CA_CERT -days $DAYS -set_serial $RANDOM -sha512 -extfile v3.ext -out $LOCAL_SIGNED_CERT
openssl pkcs8 -topk8 -inform PEM -outform PEM -in $LOCAL_KEY_TEMP -out $LOCAL_KEY -nocrypt
rm $LOCAL_KEY_TEMP

# Create our cert chain pem file
cat $CA_CERT > $CHAIN_FILE
cat $LOCAL_SIGNED_CERT >> $CHAIN_FILE

# Create our keystore for import
openssl pkcs12 -export \
   -in $LOCAL_SIGNED_CERT \
   -inkey $LOCAL_KEY \
   -CAfile $CHAIN_FILE \
   -out $KEYSTORE -passout pass:$PASSWORD \
   -caname root -name $ALIAS

# Cleanup things (we don't need our root key anymore since we've signed everything)
rm $CA_KEY $CA_CERT $LOCAL_KEY

# talk about our needed files
echo "Generated: " $KEYSTORE $LOCAL_SIGNED_CERT $CHAIN_FILE

# Output the command to import our keystore
echo "keytool -importkeystore -srckeystore ${KEYSTORE} -srcstoretype PKCS12 \
   -destkeystore keystore \
   -srcstorepass ${PASSWORD} \
   -deststorepass ${PASSWORD} -destkeypass ${PASSWORD} \
   -alias ${ALIAS} -trustcacerts"