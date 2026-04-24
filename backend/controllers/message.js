const { Chat, Message, User } = require("../models");

const messageIncludes = [
  {
    model: User,
    as: "sender",
    attributes: { exclude: ["password"] },
  },
  {
    model: Chat,
    as: "chat",
    include: [
      {
        model: User,
        as: "users",
        attributes: { exclude: ["password"] },
        through: { attributes: [] },
      },
      {
        model: User,
        as: "groupAdmin",
        attributes: { exclude: ["password"] },
      },
    ],
  },
];

const createMessage = async (req, res) => {
  const { message, chatId } = req.body;
  if (message) {
    const newMessage = await Message.create({
      senderId: req.user._id,
      message,
      chatId,
    });

    await Chat.update(
      {
        latestMessageId: newMessage._id,
      },
      {
        where: { _id: chatId },
      },
    );

    const fullMessage = await Message.findByPk(newMessage._id, {
      include: messageIncludes,
    });

    return res.status(201).json({ data: fullMessage });
  } else {
    return res.status(400).json({ message: "Message not provide" });
  }
};

const allMessage = async (req, res) => {
  const chatId = req.params.chatId;
  const messages = await Message.findAll({
    where: { chatId },
    order: [["createdAt", "ASC"]],
    include: [
      {
        model: User,
        as: "sender",
        attributes: { exclude: ["password"] },
      },
      {
        model: Chat,
        as: "chat",
      },
    ],
  });
  return res.status(200).json({ data: messages });
};
const clearChat = async (req, res) => {
  const chatId = req.params.chatId;
  await Message.destroy({ where: { chatId } });
  await Chat.update({ latestMessageId: null }, { where: { _id: chatId } });
  return res.status(200).json({ message: "success" });
};

module.exports = { createMessage, allMessage, clearChat };
