const { Op } = require("sequelize");
const { Chat, ChatUser, Message, User } = require("../models");

const chatInclude = [
  {
    model: User,
    as: "users",
    attributes: { exclude: ["password"] },
    through: { attributes: [] },
  },
  {
    model: Message,
    as: "latestMessage",
    include: [
      {
        model: User,
        as: "sender",
        attributes: { exclude: ["password"] },
      },
    ],
  },
  {
    model: User,
    as: "groupAdmin",
    attributes: { exclude: ["password"] },
  },
];

const getChatIdsByUser = async (userId) => {
  const memberships = await ChatUser.findAll({
    where: { userId },
    attributes: ["chatId"],
    raw: true,
  });
  return memberships.map((item) => item.chatId);
};

const postChat = async (req, res) => {
  const { userId } = req.body;
  if (!userId) {
    return res.status(200).json({ message: "userId not provide" });
  }

  const chatIds = await getChatIdsByUser(req.user._id);
  const existingChatCandidates = await Chat.findAll({
    where: {
      _id: { [Op.in]: chatIds },
      isGroupChat: false,
    },
    include: chatInclude,
  });

  const existingChat = existingChatCandidates.find((chat) => {
    const ids = chat.users.map((user) => user._id);
    return (
      ids.length === 2 && ids.includes(req.user._id) && ids.includes(userId)
    );
  });

  if (!existingChat) {
    const chatName = "Messenger";
    const isGroupChat = false;
    const chat = await Chat.create({
      chatName,
      isGroupChat,
    });
    await ChatUser.bulkCreate(
      [
        { chatId: chat._id, userId: req.user._id },
        { chatId: chat._id, userId },
      ],
      { ignoreDuplicates: true },
    );

    const chatAll = await Chat.findByPk(chat._id, {
      include: chatInclude,
    });
    return res.status(200).json({ data: chatAll });
  } else {
    return res.status(200).json({ data: existingChat });
  }
};
const getChat = async (req, res) => {
  const chatIds = await getChatIdsByUser(req.user._id);
  if (chatIds.length === 0) {
    return res.status(200).json({ data: [] });
  }

  const chat = await Chat.findAll({
    where: { _id: { [Op.in]: chatIds } },
    order: [["updatedAt", "DESC"]],
    include: chatInclude,
  });

  return res.status(200).json({ data: chat });
};
const createGroup = async (req, res) => {
  if (!req.body.users || !req.body.name) {
    return res.status(200).json({ message: "users and name not provide" });
  }
  const users = [...new Set(req.body.users)];
  if (users.length < 2) {
    return res.status(200).json({ message: "min 2 users required for group" });
  }
  if (!users.includes(req.user._id)) {
    users.push(req.user._id);
  }

  const groupChat = await Chat.create({
    chatName: req.body.name,
    isGroupChat: true,
    groupAdminId: req.user._id,
  });

  await ChatUser.bulkCreate(
    users.map((id) => ({ chatId: groupChat._id, userId: id })),
    { ignoreDuplicates: true },
  );

  const groups = await Chat.findByPk(groupChat._id, {
    include: chatInclude,
  });

  res.status(200).json({ data: groups });
};
const deleteGroup = async (req, res) => {
  const chatId = req.params.chatId;
  await Message.destroy({ where: { chatId } });
  await ChatUser.destroy({ where: { chatId } });
  await Chat.destroy({ where: { _id: chatId } });
  return res.status(200).json({ message: "success" });
};
const renameGroup = async (req, res) => {
  const { name, chatId } = req.body;
  if (!name || !chatId) {
    return res.status(200).json({ message: "name and chatId not provide" });
  }

  const chatExists = await Chat.findByPk(chatId);
  if (!chatExists) {
    return res.status(200).json({ message: "chat not found" });
  }

  await chatExists.update({ chatName: name });
  const chat = await Chat.findByPk(chatId, {
    include: chatInclude,
  });

  if (!chat) {
    return res.status(200).json({ message: "chat not found" });
  } else {
    return res.status(200).json({ data: chat });
  }
};
const removeFromGroup = async (req, res) => {
  const { chatId, userId } = req.body;
  if (!chatId || !userId) {
    return res.status(200).json({ message: "chatId and userId not provide" });
  }
  await ChatUser.destroy({ where: { chatId, userId } });
  const chat = await Chat.findByPk(chatId, {
    include: chatInclude,
  });
  if (!chat) {
    return res.status(200).json({ message: "chat not found" });
  } else {
    return res.status(200).json({ data: chat });
  }
};
const addToGroup = async (req, res) => {
  const { chatId, userId } = req.body;
  if (!chatId || !userId) {
    return res.status(200).json({ message: "chatId and userId not provide" });
  }
  await ChatUser.findOrCreate({ where: { chatId, userId } });
  const chat = await Chat.findByPk(chatId, {
    include: chatInclude,
  });
  if (!chat) {
    return res.status(200).json({ message: "chat not found" });
  } else {
    return res.status(200).json({ data: chat });
  }
};

module.exports = {
  postChat,
  getChat,
  createGroup,
  deleteGroup,
  renameGroup,
  removeFromGroup,
  addToGroup,
};
