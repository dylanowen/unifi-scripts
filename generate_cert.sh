#!/bin/sh

# This script generates a self signed cert for your local unifi controller

# https://gist.github.com/Soarez/9688998
# https://github.com/netty/netty/blob/4.1/handler/src/test/resources/io/netty/handler/ssl/generate-certs.sh#L14
# https://github.com/stevejenkins/unifi-linux-utils/blob/master/unifi_ssl_import.sh


### Guide
#
# Check below for the ways to import the result, but for this lets assume we're using manual import
#
# 1. Run this locally. It builds a CA and then uses that to sign a certificate for unifi.local
#  a. ./generate_cert.sh "/C=US/ST=<state>/L=<city>/O=<organization>/CN=unifi.local"
#
# 2. scp the necessary files over to your unifi controller
#
# 3. run the import command
#
# 4. restart the unifi service
#  a. sudo service unifi restart
#
# Bonus:
#  Import the chain.pem into your keychain and/or other programs that need to trust the controller
#
# Fallback if this doesn't work
#  sudo java -jar /usr/lib/unifi/lib/ace.jar new_cert unifi.local <organization> <city> <state> US
#  # This cert won't be trusted by Chrome though as it doesn't have all the necessary pieces



SUBJECT=${1:-"/CN=unifi.local"}
DAYS=3650

ALIAS="unifi"
PASSWORD="aircontrolenterprise"

CA_KEY="${ALIAS}_ca.key"
CA_CERT="${ALIAS}_ca.pem"

LOCAL_KEY="${ALIAS}.key"
LOCAL_SIGNED_CERT="${ALIAS}.pem"
LOCAL_P12="${ALIAS}-ssl.p12"

CHAIN_FILE="chain.pem"


# Generate a new, self-signed root CA\
openssl req -new -x509 -days $DAYS -nodes -subj "/CN=${ALIAS}" -newkey rsa:2048 -sha512 -out $CA_CERT -keyout $CA_KEY

LOCAL_KEY_TEMP="temp.key"
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
   -out $LOCAL_P12 -passout pass:$PASSWORD \
   -caname root -name $ALIAS

# Cleanup things (we don't need our root key anymore since we've signed everything)
rm $CA_KEY $CA_CERT $LOCAL_KEY


if [ true ]; then
   ### Manual Import

   # Remove files we don't need for manual import
   rm $LOCAL_SIGNED_CERT

   echo "Generated: " $LOCAL_P12 $CHAIN_FILE

   # Output the scp command
   echo
   echo "scp ${LOCAL_P12} pi@unifi.local:~/certs"

   # Output the command to import our keystore
   echo
   echo "sudo keytool -importkeystore -srckeystore ${LOCAL_P12} -srcstoretype PKCS12 \
      -destkeystore /var/lib/unifi/keystore \
      -srcstorepass ${PASSWORD} \
      -deststorepass ${PASSWORD} -destkeypass ${PASSWORD} \
      -alias ${ALIAS} -trustcacerts"

else
   ### Auto Import with Ace (I've never gotten this to work)

   # Remove files we don't need for manual import
   rm $LOCAL_P12

   echo "Generated: " $LOCAL_SIGNED_CERT $CHAIN_FILE

   # Output the scp command
   echo
   echo "scp ${LOCAL_SIGNED_CERT} ${CHAIN_FILE} pi@unifi.local:~/certs"

   # Output the command to import
   echo
   echo "sudo java -jar /usr/lib/unifi/lib/ace.jar import_cert ${LOCAL_SIGNED_CERT} ${CHAIN_FILE}"
fi