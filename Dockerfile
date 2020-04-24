FROM alpine:3.11

ADD ./init.sh /

RUN chmod +x /init.sh && /init.sh
