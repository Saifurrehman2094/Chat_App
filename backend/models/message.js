const { DataTypes } = require("sequelize");
const { sequelize } = require("../config/database");

const Message = sequelize.define(
  "Message",
  {
    _id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },
    senderId: {
      type: DataTypes.UUID,
      allowNull: false,
    },
    message: {
      type: DataTypes.TEXT,
      allowNull: false,
    },
    chatId: {
      type: DataTypes.UUID,
      allowNull: false,
    },
  },
  {
    tableName: "messages",
    timestamps: true,
  },
);

module.exports = Message;
