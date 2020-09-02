FROM python:3.7
USER root
WORKDIR /

RUN mkdir /conf/

RUN apt-get update && apt-get install -y vim
RUN pip3 install git+https://www.github.com/splunk/eventgen.git@7.0.0
RUN mkdir /output

