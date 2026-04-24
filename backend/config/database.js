const mysql = require("mysql2/promise");
const { Sequelize } = require("sequelize");

const sequelize = new Sequelize(
  process.env.MYSQL_DATABASE,
  process.env.MYSQL_USER,
  process.env.MYSQL_PASSWORD,
  {
    host: process.env.MYSQL_HOST || "127.0.0.1",
    port: Number(process.env.MYSQL_PORT || 3306),
    dialect: "mysql",
    logging: false,
  },
);

async function connectDatabase() {
  const bootstrapConnection = await mysql.createConnection({
    host: process.env.MYSQL_HOST || "127.0.0.1",
    port: Number(process.env.MYSQL_PORT || 3306),
    user: process.env.MYSQL_USER || "root",
    password: process.env.MYSQL_PASSWORD || "",
  });

  await bootstrapConnection.query(
    `CREATE DATABASE IF NOT EXISTS \`${process.env.MYSQL_DATABASE}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`
  );
  await bootstrapConnection.end();

  await sequelize.authenticate();
  console.log("MySQL Connection established");
}

async function syncDatabase() {
  await sequelize.sync();
  console.log("Database schema synced");
}

module.exports = {
  sequelize,
  connectDatabase,
  syncDatabase,
};
