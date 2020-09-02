FROM ubuntu:18.04

RUN apt-get update -qq && apt-get install -qq -y make bash curl wget tar git python3 python-pip ca-certificates
RUN pip install --upgrade setuptools

RUN wget -nv -O splunk-appinspect.tar.gz http://download.splunk.com/misc/appinspect/splunk-appinspect-1.7.0.tar.gz \
 && pip -q install splunk-appinspect.tar.gz
