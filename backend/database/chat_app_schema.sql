-- Chat App MySQL schema export
-- Compatible with MySQL 8+ and XAMPP MySQL

CREATE DATABASE IF NOT EXISTS chat_app
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE chat_app;

CREATE TABLE IF NOT EXISTS users (
  _id CHAR(36) NOT NULL,
  firstName VARCHAR(255) NOT NULL,
  lastName VARCHAR(255) NOT NULL,
  password VARCHAR(255) NOT NULL,
  email VARCHAR(255) NOT NULL,
  image VARCHAR(1024) DEFAULT 'https://icon-library.com/images/anonymous-avatar-icon/anonymous-avatar-icon-25.jpg',
  createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (_id),
  UNIQUE KEY users_email_unique (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS chats (
  _id CHAR(36) NOT NULL,
  chatName VARCHAR(255) NOT NULL,
  isGroupChat TINYINT(1) NOT NULL DEFAULT 0,
  latestMessageId CHAR(36) DEFAULT NULL,
  groupAdminId CHAR(36) DEFAULT NULL,
  createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (_id),
  KEY chats_latestMessageId_idx (latestMessageId),
  KEY chats_groupAdminId_idx (groupAdminId),
  CONSTRAINT chats_groupAdminId_fk
    FOREIGN KEY (groupAdminId)
    REFERENCES users (_id)
    ON DELETE SET NULL
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS messages (
  _id CHAR(36) NOT NULL,
  senderId CHAR(36) NOT NULL,
  message TEXT NOT NULL,
  chatId CHAR(36) NOT NULL,
  createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (_id),
  KEY messages_senderId_idx (senderId),
  KEY messages_chatId_idx (chatId),
  CONSTRAINT messages_senderId_fk
    FOREIGN KEY (senderId)
    REFERENCES users (_id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT messages_chatId_fk
    FOREIGN KEY (chatId)
    REFERENCES chats (_id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS chat_users (
  chatId CHAR(36) NOT NULL,
  userId CHAR(36) NOT NULL,
  PRIMARY KEY (chatId, userId),
  KEY chat_users_userId_idx (userId),
  CONSTRAINT chat_users_chatId_fk
    FOREIGN KEY (chatId)
    REFERENCES chats (_id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT chat_users_userId_fk
    FOREIGN KEY (userId)
    REFERENCES users (_id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
