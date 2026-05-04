FROM alpine:3.20

RUN apk add --no-cache nodejs npm

WORKDIR /app

COPY package.json .
COPY server.js .

RUN npm install

EXPOSE 3000

CMD ["npm", "start"]
