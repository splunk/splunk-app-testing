FROM splunk/splunk:8.0.1 
USER root
WORKDIR /opt/splunk

ENV SPLUNK_HOME /opt/splunk
ENV SPLUNK_ETC /opt/splunk/etc
ENV SPLUNK_START_ARGS --accept-license
ENV SPLUNK_ENABLE_LISTEN 9997
ENV SPLUNK_ADD tcp 1514
ENV SPLUNK_PASSWORD newPassword

COPY ./test.txt ${SPLUNK_HOME}/etc/apps/
COPY config/user-prefs.conf ${SPLUNK_HOME}/etc/users/admin/user-prefs/local/user-prefs.conf
COPY config/passwd ${SPLUNK_HOME}/etc/passwd
