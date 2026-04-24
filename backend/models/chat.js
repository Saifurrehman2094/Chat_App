const { DataTypes } = require("sequelize");
const { sequelize } = require("../config/database");

const Chat = sequelize.define(
  "Chat",
  {
    _id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },
    chatName: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    isGroupChat: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
    },
    latestMessageId: {
      type: DataTypes.UUID,
      allowNull: true,
    },
    groupAdminId: {
      type: DataTypes.UUID,
      allowNull: true,
    },
  },
  {
    tableName: "chats",
    timestamps: true,
  },
);

module.exports = Chat;
