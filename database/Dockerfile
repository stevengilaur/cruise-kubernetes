FROM alpine:3.20

RUN apk add --no-cache mariadb mariadb-client bash

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 3306

ENTRYPOINT ["/entrypoint.sh"]
