const { Op } = require("sequelize");
const { User } = require("../models");

const getAuthUser = async (req, res) => {
  if (!req.user) {
    return res.status(404).json({ message: `User Not Found` });
  }
  res.status(200).json({
    data: req.user,
  });
};

const getAllUsers = async (req, res) => {
  const allUsers = await User.findAll({
    where: {
      _id: {
        [Op.ne]: req.user._id,
      },
    },
    attributes: { exclude: ["password"] },
    order: [["createdAt", "DESC"]],
  });
  res.status(200).send({ data: allUsers });
};

module.exports = { getAuthUser, getAllUsers };
