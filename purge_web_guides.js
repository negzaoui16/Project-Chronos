const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  // Delete all web-scraped guides (titles starting with 'Web:')
  // These may contain polluted content from image queries
  const result = await prisma.troubleshootingGuide.deleteMany({
    where: {
      title: { startsWith: 'Web:' }
    }
  });
  console.log(`Deleted ${result.count} web-scraped/polluted guides from KB.`);

  // Show remaining guides
  const remaining = await prisma.troubleshootingGuide.findMany({
    select: { id: true, title: true }
  });
  console.log(`Remaining guides (${remaining.length}):`);
  remaining.forEach(g => console.log(`  - ${g.title}`));
}

main().then(() => prisma.$disconnect()).catch(e => { console.error(e); prisma.$disconnect(); });
