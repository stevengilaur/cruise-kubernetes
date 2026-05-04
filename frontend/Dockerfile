FROM alpine:3.20

WORKDIR /srv/www

COPY index.html .
COPY app.js .

EXPOSE 8080

CMD ["busybox", "httpd", "-f", "-p", "8080", "-h", "/srv/www"]