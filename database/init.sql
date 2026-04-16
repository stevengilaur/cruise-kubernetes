-- Création de la base de données
CREATE DATABASE IF NOT EXISTS tododb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Utilisation de la base
USE tododb;

-- Création de l'utilisateur applicatif (pas root !)
CREATE USER IF NOT EXISTS 'todouser'@'%' IDENTIFIED BY 'todopassword';
GRANT ALL PRIVILEGES ON tododb.* TO 'todouser'@'%';
FLUSH PRIVILEGES;

-- Création de la table todos
CREATE TABLE IF NOT EXISTS todos (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  title      VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Données de test initiales
INSERT INTO todos (title) VALUES
  ('Configurer le cluster Kubernetes'),
  ('Créer la registry privée'),
  ('Déployer les pods');
