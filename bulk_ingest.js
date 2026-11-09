const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const fs = require('fs');
const path = require('path');

async function runIngestion() {
  const { pipeline } = await (Function('return import("@xenova/transformers")')());
  console.log('Loading embedding model for vector generation...');
  const embedder = await pipeline('feature-extraction', 'Xenova/all-MiniLM-L6-v2');

  const dataPath = path.join(__dirname, 'guides.json');
  if (!fs.existsSync(dataPath)) {
    console.error(`Error: Ingestion data file not found at ${dataPath}`);
    console.log('Please create a guides.json file in this format: [{"title": "Quest 3 setup", "content": "Steps to setup..."}]');
    return;
  }

  const rawData = fs.readFileSync(dataPath, 'utf8');
  const guides = JSON.parse(rawData);
  console.log(`Loaded ${guides.length} guides from JSON. Starting bulk vector generation...`);

  // Batch process to prevent out of memory
  const batchSize = 50;
  for (let i = 0; i < guides.length; i += batchSize) {
    const chunk = guides.slice(i, i + batchSize);
    console.log(`Processing batch ${i / batchSize + 1} (${i} to ${Math.min(i + batchSize, guides.length)})...`);

    for (const guide of chunk) {
      try {
        const output = await embedder(guide.content, { pooling: 'mean', normalize: true });
        const embedding = Array.from(output.data);

        await prisma.troubleshootingGuide.create({
          data: {
            title: guide.title,
            content: guide.content,
            embedding: embedding,
          }
        });
      } catch (err) {
        console.error(`Failed to ingest guide "${guide.title}": ${err.message}`);
      }
    }
  }

  console.log('Ingestion complete! All guides successfully stored in local vector database.');
}

runIngestion().then(() => prisma.$disconnect()).catch(e => { console.error(e); prisma.$disconnect(); });
