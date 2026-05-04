const http = require('http');
const mysql = require('mysql2');

// connexion DB Kubernetes
const db = mysql.createConnection({
  host: 'mariadb',
  user: 'cruise',
  password: 'cruisepass',
  database: 'cruise'
});

db.connect(err => {
  if (err) {
    console.log("DB connection error:", err);
  } else {
    console.log("Connected to MariaDB");
  }
});

const server = http.createServer((req, res) => {

  res.setHeader('Content-Type', 'application/json');
  res.setHeader('Access-Control-Allow-Origin', '*');

  if (req.url === "/db") {

    db.query("SELECT NOW() AS time", (err, results) => {
      if (err) {
        res.end(JSON.stringify({ error: err }));
      } else {
        res.end(JSON.stringify({
          service: "backend-db",
          time: results[0].time
        }));
      }
    });

  } else {
    res.end(JSON.stringify({
      service: "cruise-backend",
      status: "OK",
      message: "Backend Kubernetes fonctionne"
    }));
  }
});

server.listen(3000, () => {
  console.log("Backend running on port 3000");
});