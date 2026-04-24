const User = require("./user");
const Chat = require("./chat");
const Message = require("./message");
const ChatUser = require("./chatUser");

User.belongsToMany(Chat, {
  through: ChatUser,
  as: "chats",
  foreignKey: "userId",
  otherKey: "chatId",
});

Chat.belongsToMany(User, {
  through: ChatUser,
  as: "users",
  foreignKey: "chatId",
  otherKey: "userId",
});

Chat.belongsTo(User, {
  as: "groupAdmin",
  foreignKey: "groupAdminId",
});

Chat.belongsTo(Message, {
  as: "latestMessage",
  foreignKey: "latestMessageId",
  constraints: false,
});

Message.belongsTo(User, {
  as: "sender",
  foreignKey: "senderId",
});

Message.belongsTo(Chat, {
  as: "chat",
  foreignKey: "chatId",
});

Chat.hasMany(Message, {
  as: "messages",
  foreignKey: "chatId",
});

module.exports = {
  User,
  Chat,
  Message,
  ChatUser,
};
