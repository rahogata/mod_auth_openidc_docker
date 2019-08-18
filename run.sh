#!/bin/sh

docker run --name openidc_docker -d -p 80:80 rahogata/mod_auth_openidc_docker:alpine
