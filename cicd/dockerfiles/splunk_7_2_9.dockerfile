FROM splunk/splunk:7.2.9
USER root
WORKDIR /opt/splunk

ENV SPLUNK_HOME /opt/splunk
ENV SPLUNK_ETC /opt/splunk/etc
ENV SPLUNK_START_ARGS --accept-license
ENV SPLUNK_ENABLE_LISTEN 9997
ENV SPLUNK_ADD tcp 1514
ENV SPLUNK_PASSWORD newPassword

ADD config/user-prefs.conf /opt/splunk/etc/users/admin/user-prefs/local/

COPY etc/system/local/authorize.conf ${SPLUNK_HOME}/etc/system/local/authorize.conf
COPY etc/passwd ${SPLUNK_HOME}/etc/passwd
COPY etc/apps/100-whisper-searchhead ${SPLUNK_HOME}/etc/apps/100-whisper-searchhead
COPY etc/apps/GARANTE/ ${SPLUNK_HOME}/etc/apps/GARANTE

RUN apt-get update && apt-get install -y vim libssl-dev golang

