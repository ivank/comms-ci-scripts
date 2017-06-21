#! /bin/bash

mkdir ~/.bintray
echo "realm = Bintray API Realm" > ~/.bintray/.credentials
echo "host = api.bintray.com" >> ~/.bintray/.credentials
echo "user = ovo-comms-circleci" >> ~/.bintray/.credentials
echo "password = ${BINTRAY_API_KEY}" >> ~/.bintray/.credentials
