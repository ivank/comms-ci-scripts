#! /bin/bash

mkdir ~/.bintray
echo "realm = Bintray API Realm" > ~/.bintray/.credentials
echo "host = api.bintray.com" >> ~/.bintray/.credentials
echo "user = ${BINTRAY_USER:="ovo-comms-circleci@ovotech"}" >> ~/.bintray/.credentials
echo "password = ${BINTRAY_API_KEY}" >> ~/.bintray/.credentials
