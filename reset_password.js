const { PrismaClient } = require('@prisma/client');
const crypto = require('crypto');
const prisma = new PrismaClient();

function hashPassword(password) {
  return crypto.createHmac('sha256', 'chronos-salt').update(password).digest('hex');
}

async function main() {
  const email = 'negzaoui@gmail.com';
  const newPassword = 'password123';
  const hashedPassword = hashPassword(newPassword);

  const updated = await prisma.user.update({
    where: { email },
    data: { password: hashedPassword }
  });

  console.log(`Password reset successfully for ${email}! Hashed: ${hashedPassword}`);
  await prisma.$disconnect();
}

main().catch(err => {
  console.error(err);
  prisma.$disconnect();
});
