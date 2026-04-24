const { DataTypes } = require("sequelize");
const { sequelize } = require("../config/database");

const ChatUser = sequelize.define(
  "ChatUser",
  {
    chatId: {
      type: DataTypes.UUID,
      allowNull: false,
      primaryKey: true,
    },
    userId: {
      type: DataTypes.UUID,
      allowNull: false,
      primaryKey: true,
    },
  },
  {
    tableName: "chat_users",
    timestamps: false,
  },
);

module.exports = ChatUser;
