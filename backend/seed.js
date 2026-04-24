const dotenv = require("dotenv");
dotenv.config();

const bcrypt = require("bcryptjs");
const { sequelize, connectDatabase, syncDatabase } = require("./config/database");
const { User, Chat, Message, ChatUser } = require("./models");

async function clearDatabase() {
	await sequelize.transaction(async (transaction) => {
		await sequelize.query("SET FOREIGN_KEY_CHECKS = 0", { transaction });
		await Message.destroy({ where: {}, transaction });
		await ChatUser.destroy({ where: {}, transaction });
		await Chat.destroy({ where: {}, transaction });
		await User.destroy({ where: {}, transaction });
		await sequelize.query("SET FOREIGN_KEY_CHECKS = 1", { transaction });
	});
}

async function seed() {
	await connectDatabase();
	await syncDatabase();
	await clearDatabase();

	const demoPassword = await bcrypt.hash("password123", 8);

	const users = await User.bulkCreate(
		[
			{
				firstName: "Alice",
				lastName: "Johnson",
				email: "alice@example.com",
				password: demoPassword,
			},
			{
				firstName: "Bob",
				lastName: "Smith",
				email: "bob@example.com",
				password: demoPassword,
			},
			{
				firstName: "Charlie",
				lastName: "Brown",
				email: "charlie@example.com",
				password: demoPassword,
			},
		],
		{ returning: true }
	);

	const [alice, bob, charlie] = users;

	const directChat = await Chat.create({
		chatName: "Messenger",
		isGroupChat: false,
	});

	const groupChat = await Chat.create({
		chatName: "Project Team",
		isGroupChat: true,
		groupAdminId: alice._id,
	});

	await ChatUser.bulkCreate([
		{ chatId: directChat._id, userId: alice._id },
		{ chatId: directChat._id, userId: bob._id },
		{ chatId: groupChat._id, userId: alice._id },
		{ chatId: groupChat._id, userId: bob._id },
		{ chatId: groupChat._id, userId: charlie._id },
	]);

	const message1 = await Message.create({
		senderId: alice._id,
		chatId: directChat._id,
		message: "Hi Bob, this is a seeded direct chat.",
	});

	const message2 = await Message.create({
		senderId: bob._id,
		chatId: directChat._id,
		message: "Nice, the backend is ready for testing.",
	});

	const message3 = await Message.create({
		senderId: charlie._id,
		chatId: groupChat._id,
		message: "Hello team, this is a seeded group chat.",
	});

	await directChat.update({ latestMessageId: message2._id });
	await groupChat.update({ latestMessageId: message3._id });

	console.log("Dummy data inserted successfully.");
	console.log("Test logins:");
	console.log("alice@example.com / password123");
	console.log("bob@example.com / password123");
	console.log("charlie@example.com / password123");

	await sequelize.close();
}

seed().catch(async (error) => {
	console.error("Seed failed:", error.message);
	await sequelize.close();
	process.exit(1);
});