#!/bin/bash

# ToDo 
# 1. commandline options
# 2. how to handle passphrases

# Usage:
#
# generateCRSfromList.sh
#
# This script is used to bulk generate client keys and CSR for use in LMW2 MKK DL for WM-TAB
#
# Purpose: This script generates unique configuration files and generates keys and CSRs.
# because each configuration is saved a record of wat was used is kept.
#
#
# CSR configuration template see: ${CSR_CONFIG_TEMPLATE}
#
#[ req ]
# default_md = sha256
# default_bits = 2048
# distinguished_name = req_distinguished_name
# prompt="no"

# [ req_distinguished_name ]
# CN = {{Common_Name}}
# emailAddress = {{Contact_Email}}
# O = RWS
# L = Delft
# C = NL

# [ client ]
# basicConstraints = CA:FALSE
# nsCertType = client, email
# nsComment = "OpenSSL LMW TAB-WM Client Certificate"
# keyUsage = critical, nonRepudiation, digitalSignature, keyEncipherment
# extendedKeyUsage = clientAuth, emailProtection

CSR_LIST="./csrinput.list"
CSR_CONFIG_POST_FILE="openssl.cfg"
CSR_CONFIG_TEMPLATE="./sslconfig.template"

function generatecsr {
    while IFS="" read -r LINE || [ -n "${LINE}" ]
    do
        echo "Processing line: ${LINE}"
        LINEARRAY=(${LINE})
        CONTACT_EMAIL=${LINEARRAY[1]}
        KEY_NAME=${LINEARRAY[0]}
        FILE_NAME="${KEY_NAME}(${CONTACT_EMAIL})"
        
        cat ${CSR_CONFIG_TEMPLATE} | sed "s/{{Common_Name}}/$(echo ${KEY_NAME} | sed -e 's/\\/\\\\/g; s/\//\\\//g; s/&/\\\&/g')/g" > "./tmp/${FILE_NAME}${CSR_CONFIG_POST_FILE}"
        cat "./tmp/${FILE_NAME}${CSR_CONFIG_POST_FILE}" | sed "s/{{Contact_Email}}/$(echo ${CONTACT_EMAIL} | sed -e 's/\\/\\\\/g; s/\//\\\//g; s/&/\\\&/g')/g" > "./cfg/${FILE_NAME}${CSR_CONFIG_POST_FILE}"
        rm "./tmp/${FILE_NAME}${CSR_CONFIG_POST_FILE}"

        if [[ -f ./private/${KEY_NAME}.key ]] ; then
            echo "ERROR: Private key \"./private/${KEY_NAME}.key\" already exists, not overwriting"
        else
            if [[ -f ./csr/${KEY_NAME}.csr ]] ; then
                echo "ERROR: CSR file \"./csr/${KEY_NAME}.csr\" already exists, not overwriting"
            else
                openssl req -config "./cfg/${FILE_NAME}${CSR_CONFIG_POST_FILE}" -new -newkey rsa:2048 -nodes -keyout ./private/${FILE_NAME}.key -out ./csr/${FILE_NAME}.csr -reqexts client
                if [[ $? -ne 0 ]] ; then
                    echo "ERROR: Executing openssql req -config \"${CSR_CONFIG}\" failed"
                    exit 1
                fi
                echo "Created ./private/${KEY_NAME}.key"
                echo "Created ./csr/${KEY_NAME}.csr"
            fi
        fi

        #if debug
        #openssl req -text -in ${KEY_NAME}.csr -noout
    done < ${CSR_LIST}
}

function createpkcs12 {
    while IFS="" read -r KEY_NAME || [ -n "${KEY_NAME}" ]
    do
        printf '%s\n' "${KEY_NAME}"
        openssl pkcs12 -export -out ./pkcs12/${KEY_NAME}.p12 -inkey ./private/${KEY_NAME}.key -in ./certs/${KEY_NAME}.cer -certfile RWSCACert.cer
        if [[ $? -ne 0 ]] ; then
            echo "ERROR: Executing openssql pkcs12 -export -out \"./pkcs12/${KEY_NAME}.p12\" failed"
            exit 1
        fi
        echo "Created ./pkcs12/${KEY_NAME}.p12"
    done < ${CSR_LIST}
}

# MAIN

if [ "$#" -ne 1 ]; then
    echo "ERROR: Missing or too many arguments Usage: ./generateCRSfromList.sh generatecsr | createpkcs12"
    exit 1
fi
COMMAND=$1 

mkdir -p ./cfg
mkdir -p ./private
mkdir -p ./certs
mkdir -p ./csr
mkdir -p ./pkcs12
mkdir -p ./tmp

if [[ ! -f ${CSR_LIST} ]] ; then
    echo "ERROR: File \"${CSR_LIST}\" is NOT found, aborting."
    exit 1
fi

if [[ ! -f ${CSR_CONFIG_TEMPLATE} ]] ; then
    echo "ERROR: File \"${CSR_CONFIG_TEMPLATE}\" is NOT found, aborting."
    exit 1
fi

case ${COMMAND} in
    generatecsr) generatecsr;;
    createpkcs12) createpkcs12;;
    *) echo "ERROR: Wrong argument Usage: ./generateCRSfromList.sh generatecsr | createpkcs12";;
esac

