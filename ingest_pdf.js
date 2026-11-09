const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const fs = require('fs');
const path = require('path');
const pdfParse = require('pdf-parse').default || require('pdf-parse');

async function ingestPdf() {
  const { pipeline } = await (Function('return import("@xenova/transformers")')());
  console.log('Loading embedding model...');
  const embedder = await pipeline('feature-extraction', 'Xenova/all-MiniLM-L6-v2');

  const pdfPath = 'c:/Users/Negza/Desktop/Project_Stage/Project_Stage/Agent/Guide-meta-livreV0.3L.pdf';
  if (!fs.existsSync(pdfPath)) {
    console.error(`Error: PDF file not found at ${pdfPath}`);
    return;
  }

  console.log(`Reading PDF from ${pdfPath}...`);
  const parser = new pdfParse.PDFParse({ url: pdfPath });
  await parser.load();
  const data = await parser.getText();
  console.log(`PDF read successfully! Total pages: ${data.total}`);

  const text = data.text;
  
  // Split text into overlapping chunks of ~700 characters
  const chunkSize = 700;
  const overlap = 150;
  const chunks = [];
  
  let i = 0;
  while (i < text.length) {
    const chunk = text.substring(i, i + chunkSize).trim();
    if (chunk.length > 20) {
      chunks.push(chunk);
    }
    i += (chunkSize - overlap);
  }

  console.log(`Split PDF text into ${chunks.length} semantic chunks. Starting bulk ingestion...`);

  let count = 0;
  for (let idx = 0; idx < chunks.length; idx++) {
    const chunk = chunks[idx];
    try {
      const title = `PDF: Guide Meta Quest 3 (Chunk ${idx + 1})`;
      const embedText = `${title}. ${chunk}`;
      
      const output = await embedder(embedText, { pooling: 'mean', normalize: true });
      const embedding = Array.from(output.data);

      await prisma.troubleshootingGuide.create({
        data: {
          title: title,
          content: chunk,
          embedding: embedding,
        }
      });
      count++;
      if (count % 10 === 0 || idx === chunks.length - 1) {
        console.log(`Ingested ${count}/${chunks.length} chunks...`);
      }
    } catch (err) {
      console.error(`Failed to ingest chunk ${idx + 1}: ${err.message}`);
    }
  }
  
  try {
    await parser.destroy();
  } catch (err) {}

  console.log(`Ingestion completed successfully! Ingested ${count} chunks into PostgreSQL database.`);
}

ingestPdf()
  .then(() => prisma.$disconnect())
  .catch(e => {
    console.error(e);
    prisma.$disconnect();
  });
