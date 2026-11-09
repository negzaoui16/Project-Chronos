// Trigger restart for nodemon again
// Chat service for Module 3 RAG Troubleshooting Assistant
import { Injectable, OnModuleInit, Logger } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CloudinaryService } from '../../common/cloudinary/cloudinary.service';
import { GoogleGenerativeAI } from '@google/generative-ai';
import { Pinecone } from '@pinecone-database/pinecone';
import * as crypto from 'crypto';
import axios from 'axios';
import * as path from 'path';
import * as fs from 'fs';

@Injectable()
export class ChatService implements OnModuleInit {
  private readonly logger = new Logger(ChatService.name);
  private embedder: any;
  private captioner: any;
  private classifier: any; // CLIP zero-shot image classifier
  private llamaContext: any;
  private llamaModel: any;
  private LlamaChatSessionCls: any; // Dynamic reference to ESM class
  private geminiModel: any;
  private pinecone: Pinecone;
  private pineconeIndex: any;

  constructor(
    private readonly prisma: PrismaService,
    private readonly cloudinaryService: CloudinaryService,
  ) {
    this.pinecone = new Pinecone({ apiKey: process.env.PINECONE_API_KEY || '' });
    this.pineconeIndex = this.pinecone.index(process.env.PINECONE_INDEX_NAME || 'agent');

    const geminiKey = process.env.GEMINI_API_KEY;
    if (geminiKey) {
      this.logger.log('Gemini API Key detected. Initializing gemini-1.5-flash for fallback...');
      const genAI = new GoogleGenerativeAI(geminiKey);
      this.geminiModel = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });
    } else {
      this.logger.warn('No GEMINI_API_KEY found in environment variables. Falling back to local T5 for general queries.');
    }
  }

  private get db(): any {
    return this.prisma;
  }

  async onModuleInit() {
    this.logger.log('Initializing local ONNX AI models in background...');
    this.initializeModels().catch((error) => {
      this.logger.error('Failed to initialize local ONNX models:', error);
    });
  }

  private async initializeModels() {
    const { pipeline, env } = await (Function('return import("@huggingface/transformers")')());
    
    // Configure cache directory
    env.cacheDir = './.cache/transformers';

    this.logger.log('Loading embedding model: Xenova/paraphrase-multilingual-MiniLM-L12-v2');
    this.embedder = await pipeline('feature-extraction', 'Xenova/paraphrase-multilingual-MiniLM-L12-v2');

    this.logger.log('Loading image captioning model: Xenova/vit-gpt2-image-captioning');
    this.captioner = await pipeline('image-to-text', 'Xenova/vit-gpt2-image-captioning');

    this.logger.log('Loading local CLIP classifier: Xenova/clip-vit-base-patch32');
    this.classifier = await pipeline('zero-shot-image-classification', 'Xenova/clip-vit-base-patch32');

    this.logger.log('Loading text generation model: Phi-3-mini-4k-instruct (GPU via node-llama-cpp)');
    try {
      const nodeLlamaCpp = await (Function('return import("node-llama-cpp")')());
      const getLlama = nodeLlamaCpp.getLlama;
      this.LlamaChatSessionCls = nodeLlamaCpp.LlamaChatSession;
      
      const modelDir = path.resolve(process.cwd(), 'models');
      const modelPath = path.resolve(modelDir, 'Phi-3-mini-4k-instruct-Q4_K_M.gguf');

      if (!fs.existsSync(modelPath)) {
        this.logger.warn(`Phi-3 model not found at ${modelPath}.`);
        this.logger.warn(`Starting automatic download of Phi-3-mini (2.4 GB) from HuggingFace... This will take a few minutes.`);
        if (!fs.existsSync(modelDir)) {
          fs.mkdirSync(modelDir, { recursive: true });
        }
        
        await new Promise<void>((resolve, reject) => {
          axios({
            url: 'https://huggingface.co/bartowski/Phi-3-mini-4k-instruct-GGUF/resolve/main/Phi-3-mini-4k-instruct-Q4_K_M.gguf',
            method: 'GET',
            responseType: 'stream',
          }).then((response) => {
            const totalLengthStr = response.headers['content-length'];
            const totalBytes = totalLengthStr ? Number(totalLengthStr) : 0;
            let downloaded = 0;
            let lastPercent = 0;
            const writer = fs.createWriteStream(modelPath);
            
            response.data.on('data', (chunk: any) => {
              downloaded += chunk.length;
              if (totalBytes > 0) {
                const percent = Math.floor((downloaded / totalBytes) * 100);
                if (percent >= lastPercent + 10) {
                  this.logger.log(`Downloading Phi-3... ${percent}%`);
                  lastPercent = percent;
                }
              }
            });

            response.data.pipe(writer);
            
            writer.on('finish', () => {
              this.logger.log(`✅ Download complete! Saved to ${modelPath}`);
              resolve();
            });
            writer.on('error', (err: any) => {
              fs.unlinkSync(modelPath);
              reject(err);
            });
          }).catch(reject);
        });
      }

      const llama = await getLlama();
      this.llamaModel = await llama.loadModel({ modelPath });
      // Limit context size to 2048 to prevent VRAM Out Of Memory on RTX 3050 (4GB)
      this.llamaContext = await this.llamaModel.createContext({ contextSize: 2048 });
      this.logger.log('Phi-3-mini-4k-instruct loaded successfully on GPU!');
    } catch (err: any) {
      this.logger.error(`Failed to load Phi-3-mini via node-llama-cpp: ${err.message}`);
    }

    this.logger.log('All local models loaded successfully!');

    // Seed local troubleshooting guides in Neon database
    await this.seedTroubleshootingGuides();
  }

  private async seedTroubleshootingGuides() {
    try {
      this.logger.log('Cleaning old troubleshooting guides (preserving PDF files and Web-learned guides)...');
      await this.db.troubleshootingGuide.deleteMany({
        where: {
          AND: [
            { NOT: { title: { startsWith: 'PDF:' } } },
            { NOT: { title: { startsWith: 'Web:' } } },
          ],
        },
      });

      this.logger.log('Seeding local troubleshooting guides...');

      const defaultGuides = [
        {
          title: 'Meta Quest 3 Power and Setup Guide',
          content: 'To turn on and set up the Meta Quest 3, press and hold the power button on the left side of the headset for 3 seconds until the Meta logo appears. Follow the on-screen instructions to adjust the fit, and use the Meta Horizon mobile app on your smartphone to pair the device, connect to Wi-Fi, and complete the setup.',
        },
        {
          title: 'Formlabs 3B+ Printer Troubleshooting',
          content: 'Formlabs 3B+ printing errors: For structural cracks or resin release failures, stop the resin release valve, check the tank pin alignment (refer to section 4), and replace the tank pin assembly if cracked.',
        },
        {
          title: 'Meta Quest Lens Fogging Diagnostic',
          content: 'Meta Quest lens fogging issues: Clean the lens surface with a dry microfiber cloth, check and clean the built-in cooling fans, and adjust the facial interface for ventilation.',
        },
        {
          title: 'Power Boot Failure troubleshooting',
          content: 'Power Boot Failure troubleshooting: If the device does not turn on, check the power adapter output, hold the power button for 15 seconds to perform a hard reset, and inspect the charging port connector for damage.',
        },
        {
          title: 'Screen Display Anomaly Fix',
          content: 'Screen display anomaly: For screen flickering or lines on display, check the ribbon cable connection, update the device firmware, and inspect the screen panel for physical damage.',
        },
      ];

      for (const guide of defaultGuides) {
        // Entry 1: Title-based vector (optimized for short direct queries)
        const outputTitle = await this.embedder(guide.title, { pooling: 'mean', normalize: true });
        const embeddingTitle = Array.from(outputTitle.data);
        await this.db.troubleshootingGuide.create({
          data: {
            title: guide.title,
            content: guide.content,
            embedding: embeddingTitle as any,
          },
        });
        await this.pineconeIndex.upsert({ records: [{
          id: crypto.randomUUID(),
          values: embeddingTitle,
          metadata: { title: guide.title, content: guide.content }
        }]});

        // Entry 2: Content-based vector (optimized for longer descriptive queries)
        const outputContent = await this.embedder(guide.content, { pooling: 'mean', normalize: true });
        const embeddingContent = Array.from(outputContent.data);
        await this.db.troubleshootingGuide.create({
          data: {
            title: `${guide.title} [Content]`,
            content: guide.content,
            embedding: embeddingContent as any,
          },
        });
        await this.pineconeIndex.upsert({ records: [{
          id: crypto.randomUUID(),
          values: embeddingContent,
          metadata: { title: `${guide.title} [Content]`, content: guide.content }
        }]});
      }

      this.logger.log('Seeding and embedding of local troubleshooting guides completed.');

      // Wait for auto-ingestion of PDF guides inside the Agent directory
      await this.autoIngestAgentPdfs().catch((err) => {
        this.logger.error(`Failed auto-ingestion of Agent PDFs: ${err.message}`);
      });
      
      this.logger.log('Prisma: Skipping RAM cache loading (using Pinecone for vector search).');
    } catch (error: any) {
      this.logger.error(`Error seeding troubleshooting guides: ${error.message}`);
    }
  }

  async processMessage(
    sessionId: string,
    message: string,
    file?: Express.Multer.File,
    bookingId?: string,
  ) {
    let imageUrl = '';
    let imageDescription = '';
    // Track the "effective" question sent to the model (may differ from raw message for image uploads)
    let effectiveMessage = message.trim();

    // 0. Intercept basic greetings and expressions of gratitude to return instant friendly responses
    const rawLower = message.trim().toLowerCase().replace(/[?.,\/#!$%\^&\*;:{}=\-_`~()'"“”‘’]/g, ' ');
    const isFr = /[àâéèêëîïôùûüç]|\b(merci|bonjour|salut|coucou|daccord|super|parfait|mrc|cest|comment|vas|va|aujourd|hui)\b/i.test(rawLower);

    // Check greeting intent
    const isGreeting = /^(bonjour|salut|coucou|hello|hi|hey|good morning|good afternoon|good evening|yo)\b/i.test(rawLower) ||
                       /\b(comment vas tu|comment tu vas|comment ca va|comment ça va|how are you|comment vas-tu|comment allez vous|comment allez-vous)\b/i.test(rawLower);

    // Check thanks/gratitude intent
    const isThanks = /\b(merci|merci beaucoup|thanks|thank you|thx|ty|thks|mrc)\b/i.test(rawLower) ||
                     /^(super|parfait|c'est parfait|cest parfait|cool|d'accord|daccord|ok|okay)[\s!.]*$/i.test(rawLower);

    // Ensure it is NOT a technical troubleshooting question
    const hasTechnicalKeywords = /\b(ps5|ps4|xbox|pc|ecran|écran|imprimante|printer|wifi|wi-fi|bluetooth|cable|câble|batterie|chargeur|port|usb|hdmi|bios|carte|vr|quest|souris|clavier|surchauffe|panne|erreur|problem|probleme|problème|bug|crash|son|audio|micro|nettoyer|pâte|pate|thermique|cpu|gpu|ram|dock|thunderbolt)\b/i.test(rawLower);

    if ((isGreeting || isThanks) && !hasTechnicalKeywords && !file) {
      let responseText = '';
      if (isThanks) {
        responseText = isFr 
          ? "Je vous en prie ! Ravi d'avoir pu vous aider. N'hésitez pas si vous avez d'autres questions sur vos équipements !" 
          : "You're welcome! I'm glad I could help. Feel free to ask if you have any more questions about your equipment!";
      } else {
        responseText = isFr 
          ? "Bonjour ! Je vais très bien, merci. Je suis votre assistant de dépannage Chronos. Comment puis-je vous aider aujourd'hui ?" 
          : "Hello! I'm doing great, thank you. I am your Chronos Troubleshooting Assistant. How can I help you today?";
      }

      let validatedBookingId: string | null = null;
      if (bookingId) {
        try {
          const booking = await this.db.booking.findUnique({ where: { id: bookingId } });
          if (booking) validatedBookingId = booking.id;
        } catch (err) {}
      }

      await this.db.chatMessage.create({
        data: {
          sessionId,
          bookingId: validatedBookingId,
          text: message,
          isUser: true,
          imageUrl: null,
        },
      });

      await this.db.chatMessage.create({
        data: {
          sessionId,
          bookingId: validatedBookingId,
          text: responseText,
          isUser: false,
        },
      });

      return {
        answer: responseText,
        contextUsed: 'greeting',
        similarityScore: 1.0,
        imageUrl: null,
        imageDescription: null,
      };
    }

    // 1. Handle image upload and run local CLIP classification
    let imageSearchQuery = '';
    if (file) {
      try {
        this.logger.log(`Uploading file to Cloudinary...`);
        imageUrl = await this.cloudinaryService.uploadImage(file);
        this.logger.log(`File uploaded: ${imageUrl}. Classifying image locally...`);

        // Get a fallback simple caption first
        if (this.captioner) {
          const captionResult = await this.captioner(imageUrl);
          imageDescription = captionResult[0]?.generated_text || 'equipment or device';
        } else {
          imageDescription = 'attached equipment image';
        }

        // Run local CLIP zero-shot classifier to detect precise campus hardware devices
        if (this.classifier) {
          let candidateLabels = [
            'Meta Quest 3 VR headset',
            'Formlabs 3D printer',
            'ASUS TUF laptop',
            'Cisco network switch',
            'HP LaserJet printer',
            'generic electronic device'
          ];

          // Dynamically load dynamic custom labels from labels.json to allow scaling up to 100+ images
          try {
            const fs = require('fs');
            const path = require('path');
            const labelsPath = path.join(__dirname, '../../../../labels.json');
            if (fs.existsSync(labelsPath)) {
              const fileData = fs.readFileSync(labelsPath, 'utf8');
              const customLabels = JSON.parse(fileData);
              if (Array.isArray(customLabels) && customLabels.length > 0) {
                candidateLabels = customLabels;
              }
            }
          } catch (e) {
            this.logger.error(`Failed to load dynamic image labels.json configuration: ${e.message}`);
          }
          
          this.logger.log(`Running local CLIP classifier on: ${imageUrl}`);
          const clipResults = await this.classifier(imageUrl, candidateLabels);
          const topResult = clipResults[0];
          
          if (topResult && topResult.score >= 0.65) {
            imageDescription = `an image showing a ${topResult.label}`;
            this.logger.log(`CLIP classification successful: "${topResult.label}" (confidence: ${(topResult.score * 100).toFixed(1)}%)`);
          } else {
            this.logger.log(`CLIP classification inconclusive. Falling back to generic vision description.`);
          }
        }

        const isPlaceholder =
          effectiveMessage === 'Image uploaded for analysis' ||
          effectiveMessage === '' ||
          effectiveMessage.toLowerCase().startsWith('image upload');

        if (isPlaceholder) {
          effectiveMessage = `How to fix or troubleshoot the following issue on the device: ${imageDescription}`;
          this.logger.log(`Image-only fusion: effectiveMessage="${effectiveMessage}"`);
        } else {
          effectiveMessage = `${effectiveMessage} (Visual context: The user sent an image showing ${imageDescription})`;
          this.logger.log(`Text+Image fusion: effectiveMessage="${effectiveMessage}"`);
        }
      } catch (error: any) {
        this.logger.error(`Failed to upload or analyze image: ${error.message}`);
        imageDescription = 'uploaded equipment image (analysis offline)';
      }
    }

    // 4. Retrieve conversation context (last 10 messages)
    const history = await this.db.chatMessage.findMany({
      where: { sessionId },
      orderBy: { createdAt: 'desc' },
      take: 10,
    });
    const chronologicalHistory = history.reverse();

    // 5. Construct T5 prompt — clean history first
    const badHistoryPatterns = [
      'provided instructions do not provide',
      'cannot answer this question',
      'not possible to answer',
      'does not provide any information',
      'does not give enough information',
      'context does not',
      'context is not relevant',
      'given context does not',
      'i apologize',
      "i'm sorry",
      'no context available',
      'it is not possible to answer',
      'i could not find specific',
      'please try rephrasing',
      'image uploaded for analysis',
      'windows pc using an emulator',
      'select the game mode',
      'download it from a preferred source',
      'insert imax into',
      'choose your language, region or time zone from "talkback"',
    ];
    const cleanHistory = chronologicalHistory.filter((msg) => {
      if (!msg.text || msg.text.trim().length <= 15) return false;
      const lower = msg.text.toLowerCase();
      return !badHistoryPatterns.some((p) => lower.includes(p));
    });

    // Topic Shift / Brand Shift Detection:
    let finalHistory = cleanHistory;
    const bottomText = (effectiveMessage + ' ' + (imageDescription || '')).toLowerCase();
    const bottomCategory = this.getDeviceCategory(bottomText);
    const bottomBrand = this.extractBrandFromText(bottomText);
    
    let shouldClear = false;
    
    // 1. Check Category Shift
    if (bottomCategory !== 'general') {
      const hasDifferentCategory = cleanHistory.some((msg) => {
        const msgCat = this.getDeviceCategory(msg.text);
        return msgCat !== 'general' && msgCat !== bottomCategory;
      });
      if (hasDifferentCategory) {
        this.logger.log(`Topic Shift: Detected device category change from history to specific category "${bottomCategory}". Clearing history.`);
        shouldClear = true;
      }
    }

    // 2. Check Brand Shift (within same category or general devices)
    if (!shouldClear && bottomBrand) {
      const hasDifferentBrand = cleanHistory.some((msg) => {
        const msgBrand = this.extractBrandFromText(msg.text);
        return msgBrand && msgBrand !== bottomBrand;
      });
      if (hasDifferentBrand) {
        this.logger.log(`Brand Shift: Detected device brand change in history (New Brand: "${bottomBrand}"). Clearing history.`);
        shouldClear = true;
      }
    }

    if (shouldClear) {
      finalHistory = [];
    }

    // 2. Determine device category & detect conversational follow-ups
    const currentText = (effectiveMessage + ' ' + (imageDescription || '')).toLowerCase();
    const currentCategory = this.getDeviceCategory(currentText);

    // Find if there is a previous technical user query in history to dynamically detect follow-ups
    let foundPrevTechnicalQuery = false;
    let prevTechnicalQueryText = '';

    for (let i = finalHistory.length - 1; i >= 0; i--) {
      const msg = finalHistory[i];
      if (msg.isUser) {
        const prevText = msg.text.toLowerCase();
        const prevCategory = this.getDeviceCategory(prevText);
        if (prevCategory !== 'general') {
          prevTechnicalQueryText = msg.text;
          foundPrevTechnicalQuery = true;
          this.logger.log(`Conversational follow-up detection: Found previous technical query in history: "${prevTechnicalQueryText}"`);
          break;
        }
      }
    }

    // A query is dynamically a follow-up if its category is general AND we have an active technical topic in history
    const isConversationalFollowUp = currentCategory === 'general' && foundPrevTechnicalQuery;

    // Check for social greetings & expressions of gratitude (e.g. "merci", "thanks", "hello")
    const socialQueryText = message.trim().toLowerCase();
    const isSocialGreetingOrThanks = /^(merci|merci beaucoup|thanks|thank you|thx|ty|bonjour|hello|hi|hey|ok|okay|d'accord|super|parfait|cool|au revoir|bye|goodbye|c'est bon|c'est parfait)[\s.!]*$/i.test(socialQueryText);

    const isIdentificationQuery = 
      socialQueryText.includes('what is this') ||
      socialQueryText.includes('which item') ||
      socialQueryText.includes('identify this') ||
      socialQueryText.includes('what device') ||
      socialQueryText.includes("c'est quoi");

    if (isSocialGreetingOrThanks) {
      const isFr = /merci|bonjour|salut|d'accord|super|parfait|c'est/i.test(socialQueryText);
      const reply = isFr ? "De rien ! N'hésitez pas si vous avez d'autres questions." : "You're welcome! Feel free to ask if you have any more questions.";
      
      this.logger.log(`Social message detected: "${message}". Returning friendly response.`);
      try {
        await this.db.chatMessage.create({ data: { sessionId, text: message, isUser: true, imageUrl: imageUrl || null } });
        await this.db.chatMessage.create({ data: { sessionId, text: reply, isUser: false } });
      } catch (err: any) {
        this.logger.error(`Error saving social message: ${err.message}`);
      }
      return {
        sessionId,
        answer: reply,
        contextUsed: 'conversation'
      };
    }

    // Check if the follow-up is just a clarification request or step explanation
    const lowerMsg = message.toLowerCase();
    // Catch step numbers in phrases like: "je ne comprends pas etape 3", "i didn't understand step 2", "explain step 1", "3eme etape"
    const stepMatch =
      lowerMsg.match(/(?:étape|etape|step|point|numero|numéro)\s*(\d+)/i) ||
      lowerMsg.match(/(\d+)(?:ème|eme|st|nd|rd|th)?\s*(?:étape|etape|step|point)/i) ||
      ((lowerMsg.includes('compris') || lowerMsg.includes('understand') || lowerMsg.includes('comprends')) && lowerMsg.match(/\b([1-9])\b/));
    const requestedStepNumber = stepMatch ? parseInt(stepMatch[1], 10) : null;

    if (requestedStepNumber && finalHistory.length > 0) {
      let lastAssistantMsg = '';
      for (let i = finalHistory.length - 1; i >= 0; i--) {
        if (!finalHistory[i].isUser) {
          lastAssistantMsg = finalHistory[i].text;
          break;
        }
      }

      if (lastAssistantMsg) {
        const stepExplanation = this.handleStepClarification(
          requestedStepNumber,
          lastAssistantMsg,
          message,
        );
        this.logger.log(
          `Direct Step Clarification triggered for Step ${requestedStepNumber}`,
        );

        try {
          await this.db.chatMessage.create({
            data: {
              sessionId,
              text: message,
              isUser: true,
              imageUrl: imageUrl || null,
            },
          });
          await this.db.chatMessage.create({
            data: {
              sessionId,
              text: stepExplanation,
              isUser: false,
            },
          });
        } catch (err: any) {
          this.logger.error(`Error saving step clarification: ${err.message}`);
        }

        return {
          sessionId,
          answer: stepExplanation,
          contextUsed: 'conversation',
          similarityScore: 1.0,
          imageUrl: null,
          imageDescription: null,
        };
      }
    }

    const isClarification =
      lowerMsg.includes('step') ||
      lowerMsg.includes('explain') ||
      lowerMsg.includes('why') ||
      lowerMsg.includes('what do you mean') ||
      lowerMsg.includes('more detail') ||
      lowerMsg.includes('point') ||
      lowerMsg.includes('étape') ||
      lowerMsg.includes('expliquer') ||
      lowerMsg.includes('pourquoi') ||
      lowerMsg.includes('compris') ||
      lowerMsg.includes('understand') ||
      lowerMsg.includes('detail') ||
      lowerMsg.includes('détail') ||
      (lowerMsg.length <= 15 && !isSocialGreetingOrThanks);

    if (requestedStepNumber && finalHistory.length > 0) {
      let lastAssistantMsg = '';
      for (let i = finalHistory.length - 1; i >= 0; i--) {
        if (!finalHistory[i].isUser) {
          lastAssistantMsg = finalHistory[i].text;
          break;
        }
      }

      if (lastAssistantMsg) {
        const stepExplanation = this.handleStepClarification(
          requestedStepNumber,
          lastAssistantMsg,
          message,
        );
        this.logger.log(
          `Direct Step Clarification triggered for Step ${requestedStepNumber}`,
        );

        try {
          await this.db.chatMessage.create({
            data: {
              sessionId,
              text: message,
              isUser: true,
              imageUrl: imageUrl || null,
            },
          });
          await this.db.chatMessage.create({
            data: {
              sessionId,
              text: stepExplanation,
              isUser: false,
            },
          });
        } catch (err: any) {
          this.logger.error(`Error saving step clarification: ${err.message}`);
        }

        return {
          sessionId,
          answer: stepExplanation,
          contextUsed: 'conversation',
          similarityScore: 1.0,
          imageUrl: null,
          imageDescription: null,
        };
      }
    } else if (isClarification && finalHistory.length > 0) {
      let lastAssistantMsg = '';
      for (let i = finalHistory.length - 1; i >= 0; i--) {
        if (!finalHistory[i].isUser) {
          lastAssistantMsg = finalHistory[i].text;
          break;
        }
      }

      if (lastAssistantMsg && lastAssistantMsg.length > 20) {
        const generalExplanation = this.handleGeneralClarification(
          lastAssistantMsg,
          message,
        );
        this.logger.log(
          `General Clarification ("explain more") triggered using previous response context.`,
        );

        try {
          await this.db.chatMessage.create({
            data: {
              sessionId,
              text: message,
              isUser: true,
              imageUrl: imageUrl || null,
            },
          });
          await this.db.chatMessage.create({
            data: {
              sessionId,
              text: generalExplanation,
              isUser: false,
            },
          });
        } catch (err: any) {
          this.logger.error(`Error saving general clarification: ${err.message}`);
        }

        return {
          sessionId,
          answer: generalExplanation,
          contextUsed: 'conversation',
          similarityScore: 1.0,
          imageUrl: null,
          imageDescription: null,
        };
      }
    }

    let isClarificationFollowUp = false;
    let bestScore = -1;
    let bestGuideContent = '';
    let isWebCache = false;
    
    // Determine the query for embedding similarity lookup
    let embeddingQuery = this.translateFrenchToEnglish(effectiveMessage);
    if (isConversationalFollowUp && foundPrevTechnicalQuery) {
      if (isClarification) {
        isClarificationFollowUp = true;
        embeddingQuery = this.translateFrenchToEnglish(prevTechnicalQueryText);
        this.logger.log(`Conversational clarification: Using previous technical query context: "${embeddingQuery}"`);
      } else {
        // Generically inject previous context into the new embedding query
        embeddingQuery = this.translateFrenchToEnglish(prevTechnicalQueryText + ' ' + message);
        this.logger.log(`Conversational follow-up: Combined previous context with current message: "${embeddingQuery}"`);
      }
    }

    if (this.embedder && (!isConversationalFollowUp || foundPrevTechnicalQuery) && !isIdentificationQuery) {
      try {
        const queryOutput = await this.embedder(embeddingQuery, { pooling: 'mean', normalize: true });
        const queryEmbedding = Array.from(queryOutput.data) as number[];

        this.logger.log('Pinecone: Searching for similar vectors...');
        const queryResponse = await this.pineconeIndex.query({
          vector: queryEmbedding,
          topK: 3,
          includeMetadata: true,
        });

        if (queryResponse.matches && queryResponse.matches.length > 0) {
          const match = queryResponse.matches[0];
          bestScore = match.score || -1;
          // Combine top matches context for richer knowledge retrieval
          bestGuideContent = queryResponse.matches
            .map((m) => m.metadata?.content)
            .filter(Boolean)
            .join('\n\n');
          
          this.logger.log(`Pinecone: Found ${queryResponse.matches.length} matches. Top score: ${bestScore.toFixed(3)} (Title: ${match.metadata?.title})`);
        } else {
          this.logger.log('Pinecone: No matches found.');
        }

        // Generic Cross-Verification Guardrail (Applies to all guides, including Web)
        if (bestScore >= 0.65 && bestGuideContent) {
          let guideTitle = '';
          if (queryResponse.matches && queryResponse.matches.length > 0) {
            guideTitle = queryResponse.matches[0].metadata?.title || '';
            if (guideTitle.startsWith('Web:')) {
              isWebCache = true;
            }
          }
          
          if (guideTitle) {
            // Stopwords filter to prevent matching on common words like "comment" or "avec"
            const stopwords = new Set(['comment', 'pourquoi', 'avec', 'pour', 'dans', 'sur', 'mon', 'ton', 'son', 'ma', 'ta', 'sa', 'mes', 'tes', 'ses', 'est', 'sont', 'faire', 'how', 'what', 'why', 'with', 'your', 'my', 'the', 'and', 'for', 'this', 'that', 'web', 'connect']);
            
            const titleWords = guideTitle.toLowerCase().replace(/[^a-z0-9\s]/g, ' ').split(/\s+/).filter(w => w.length > 3 && !stopwords.has(w));
            const queryWords = embeddingQuery.toLowerCase().replace(/[^a-z0-9\s]/g, ' ').split(/\s+/).filter(w => w.length > 2 && !stopwords.has(w));
            const originalUserMsgWords = message.toLowerCase().replace(/[^a-z0-9\s]/g, ' ').split(/\s+/).filter(w => w.length > 2 && !stopwords.has(w));
            
            let hasOverlap = false;
            
            for (const tWord of titleWords) {
              if (queryWords.includes(tWord) || originalUserMsgWords.includes(tWord)) {
                hasOverlap = true;
                break;
              }
              for (const qWord of [...queryWords, ...originalUserMsgWords]) {
                if (qWord.length >= 4 && (tWord.includes(qWord) || qWord.includes(tWord))) {
                  hasOverlap = true;
                  break;
                }
              }
              if (hasOverlap) break;
            }

            if (!hasOverlap && titleWords.length > 0) {
              this.logger.log(`Generic Guardrail: Rejecting mismatched guide. Title "${guideTitle}" has NO overlap with query: "${embeddingQuery}". (score: ${bestScore.toFixed(3)})`);
              bestScore = -1;
              bestGuideContent = '';
            } else {
              this.logger.log(`Generic Guardrail: PASSED for guide "${guideTitle}".`);
            }
          }
        }
      } catch (error: any) {
        this.logger.error(`Error running similarity search: ${error.message}`);
      }
    }

    // 3. Dynamic hybrid search context lookup
    let contextText = '';
    let contextUsed = 'fallback';
    
    const searchSubject = imageSearchQuery || message;
    let searchQuery = this.cleanQueryForSearch(searchSubject);
    if (isConversationalFollowUp && !isClarificationFollowUp && foundPrevTechnicalQuery) {
      searchQuery = this.cleanQueryForSearch(prevTechnicalQueryText + ' ' + searchSubject);
    }

    // Clean query (Hardcoded entity boosting removed for generic scaling)

    if (isConversationalFollowUp && isClarificationFollowUp) {
      contextUsed = 'conversation';
      // Fallback to the last assistant response if it is a technical guide (not a refusal)
      let lastAssistantResponse = '';
      for (let i = finalHistory.length - 1; i >= 0; i--) {
        const msg = finalHistory[i];
        if (!msg.isUser) {
          lastAssistantResponse = msg.text;
          break;
        }
      }
      const isRefusalMessage = lastAssistantResponse.startsWith("Désolé, je ne trouve pas") || 
                               lastAssistantResponse.startsWith("Je suis en cours") ||
                               lastAssistantResponse.includes("does not contain the answer") ||
                               lastAssistantResponse.includes("does not provide information");
      if (lastAssistantResponse.length > 25 && !isRefusalMessage) {
        contextText = lastAssistantResponse;
        this.logger.log(`Conversational clarification: Using last assistant response as context.`);
      } else {
        contextText = '';
        this.logger.log(`Conversational clarification: No previous assistant guide context available.`);
      }
    } else if (bestScore >= 0.75) {
      contextText = bestGuideContent;
      contextUsed = 'local';
      this.logger.log(`High similarity match (score: ${bestScore.toFixed(3)} >= 0.75). Using local guide context.`);
    } else if (isIdentificationQuery) {
      contextText = '';
      contextUsed = 'vision';
      this.logger.log(`Identification query detected. Bypassing Web Search.`);
    } else {
      contextUsed = 'web';
      this.logger.log(`Low similarity match (score: ${bestScore.toFixed(3)} < 0.75). Fetching web context...`);

      try {
        const webSearchPromise = (async () => {
          const snippets: string[] = [];
          const headers = { 'User-Agent': 'ChronosCampusTroubleshootingAssistant/1.0' };

          // Execute DuckDuckGo and Wikipedia in parallel with a strict 1000ms timeout
          await Promise.allSettled([
            // 1. DuckDuckGo Lite POST Search (Extremely reliable and block-resistant)
            (async () => {
              try {
                this.logger.log(`DuckDuckGo Lite search for: ${searchQuery}`);
                const ddgRes = await axios.post('https://lite.duckduckgo.com/lite/', 
                  `q=${encodeURIComponent(searchQuery)}`, 
                  { 
                    timeout: 40000, 
                    headers: {
                      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
                      'Content-Type': 'application/x-www-form-urlencoded'
                    } 
                  }
                );
                const html = ddgRes.data || '';
                const regex = /<td class=\'result-snippet\'>([\s\S]*?)<\/td>/g;
                let match;
                let count = 0;
                let combinedDdg = 'Web Search Results:\n';
                while ((match = regex.exec(html)) !== null && count < 4) {
                  const raw = match[1].replace(/<[^>]+>/g, '').trim().replace(/&#x27;/g, "'").replace(/&amp;/g, "&").replace(/&quot;/g, '"');
                  if (raw.length > 30) {
                    combinedDdg += `- ${raw}\n`;
                    count++;
                  }
                }
                if (count > 0) {
                  snippets.push(combinedDdg.substring(0, 1500).trim());
                }
              } catch (e: any) {
                this.logger.warn(`DuckDuckGo Lite query timed out or failed: ${e.message}`);
              }
            })(),

            // 2. iFixit API Search and Extract (Replaces Wikipedia)
            (async () => {
              try {
                // Keyword Filter: Extract only essential keywords for iFixit (max 4 words to avoid confusing the search engine)
                const stopWords = new Set(['how', 'to', 'the', 'on', 'a', 'an', 'my', 'is', 'please', 'help', 'with', 'fix', 'repair', 'can', 'you', 'me', 'what', 'where', 'why', 'do', 'i']);
                const cleanForIfixit = searchQuery.toLowerCase().replace(/[^a-z0-9\s]/g, ' ').split(/\s+/).filter(w => w.length > 2 && !stopWords.has(w)).slice(0, 4).join(' ');
                
                const ifixitSearchUrl = `https://www.ifixit.com/api/2.0/search/${encodeURIComponent(cleanForIfixit)}?filter=guide`;
                this.logger.log(`iFixit search with Keywords: ${ifixitSearchUrl}`);
                const ifixitSearchRes = await axios.get(ifixitSearchUrl, { timeout: 40000, headers });
                const topResult = ifixitSearchRes.data?.results?.[0];
                if (topResult?.guideid) {
                  const ifixitGuideUrl = `https://www.ifixit.com/api/2.0/guides/${topResult.guideid}`;
                  const ifixitGuideRes = await axios.get(ifixitGuideUrl, { timeout: 40000, headers });
                  const steps = ifixitGuideRes.data?.steps;
                  if (steps && steps.length > 0) {
                    let combinedSteps = 'iFixit Repair Guide:\n';
                    for (let i = 0; i < Math.min(steps.length, 3); i++) {
                      const stepText = steps[i].lines.map((l: any) => l.text_raw).join(' ');
                      combinedSteps += `- Step ${i + 1}: ${stepText}\n`;
                    }
                    snippets.push(combinedSteps.substring(0, 800).trim());
                  }
                }
              } catch (e: any) {
                this.logger.warn(`iFixit query timed out or failed: ${e.message}`);
              }
            })()
          ]);

          // 3. Preserve whole snippets without splitting to avoid Frankenstein texts
          const filteredText = snippets.join('\n\n');
          return filteredText;
        })();

        // Global safety timeout of 45 seconds for external API requests
        let timeoutId: NodeJS.Timeout;
        const timeoutPromise = new Promise<string>((resolve) => {
          timeoutId = setTimeout(() => {
            this.logger.warn(`Web lookup exceeded 45s timeout. Using generic fallback.`);
            resolve('');
          }, 45000);
        });

        const resultText = await Promise.race([webSearchPromise, timeoutPromise]);
        clearTimeout(timeoutId!);
        contextText = resultText;

        // Quality check: High Security Filter for Web Results
        if (contextText.trim().length >= 20) {
          const webLower = contextText.toLowerCase();
          const queryWords = searchQuery.toLowerCase().split(/\s+/).filter(w => w.length > 3);
          const matchingKeywords = queryWords.filter(w => webLower.includes(w));
          
          // Require at least 2 keywords to match to prevent hallucinations without being too strict
          const requiredMatches = Math.min(2, queryWords.length);
          if (matchingKeywords.length < requiredMatches) {
            this.logger.log(`Web result quality check FAILED: only ${matchingKeywords.length} query keywords found in web text. Using category fallback.`);
            contextText = ''; // Force fallback to category-specific context
          } else {
            this.logger.log(`Web result quality check PASSED: ${matchingKeywords.length} keywords matched (${matchingKeywords.join(', ')})`);
          }
        }

        if (!contextText.trim() || contextText.length < 20) {
          // Keep contextUsed as 'web' so Self-Learning can still evaluate the generated response
          contextText = `Topic: ${searchQuery}. Verify device connections, check system software settings, restart device, or consult official manufacturer documentation.`;
        }
      } catch (error: any) {
        this.logger.error(`Hybrid API web fallback failed: ${error.message}`);
        contextUsed = 'fallback';
        contextText = 'Official documentation not reachable.';
      }
    }

    // Generic context is passed to prompt builder directly without hardcoded device interventions

    // Keyword Sniper (Solution 4): Filter contextText to sentences containing query keywords
    if (contextUsed === 'local' && contextText && contextText.length > 200) {
       const queryWordsForSniper = embeddingQuery.toLowerCase().replace(/[^a-z0-9\s]/g, ' ').split(/\s+/).filter(w => w.length > 3);
       if (queryWordsForSniper.length > 0) {
           const sentences = contextText.split(/(?<=[.!?])\s+/);
           const filteredSentences = sentences.filter(s => {
               const lowerS = s.toLowerCase();
               return queryWordsForSniper.some(qw => lowerS.includes(qw));
           });
           
           if (filteredSentences.length > 0) {
               this.logger.log(`Keyword Sniper: Reduced context from ${sentences.length} sentences to ${filteredSentences.length}.`);
               contextText = filteredSentences.join(' ');
           }
       }
    }




    // Build a clear System and User prompt for ChatML
    let systemPrompt = '';
    let userPrompt = '';
    
    if (contextUsed === 'conversation') {
      if (contextText && contextText.length > 30) {
        systemPrompt = 'You are a helpful and polite academic assistant. Answer the user\'s question clearly and in detail based on the Background context.';
        userPrompt = `Background: ${contextText.substring(0, 500)}\n\nUser: ${effectiveMessage}`;
      } else {
        systemPrompt = 'You are a helpful and polite AI academic assistant. Answer the user\'s message naturally and politely.';
        userPrompt = effectiveMessage;
      }
    } else {
      if (isIdentificationQuery && imageDescription) {
        systemPrompt = 'You are a highly precise AI Assistant. The user wants to know what is in the image they uploaded. Simply identify the item using the Image Description provided. Keep it short and accurate. Do not invent a troubleshooting guide.';
      } else {
        systemPrompt = 'You are a highly precise IT Technical Assistant designed to help students. Answer the technical question using ONLY the provided Background text. Do NOT invent information. Provide a structured step-by-step guide of the repair. Put each step on a NEW LINE using bullet points to make it easy to read. Be clear and accurate, without adding unnecessary details. ALWAYS reply in ENGLISH.';
      }
      userPrompt = ``;
      if (contextText && contextText.length > 30) {
        // Feed up to 1500 characters of context to give the model more details to read
        userPrompt += `Background: ${contextText.substring(0, 1500)}\n\n`;
      }
      if (imageDescription) {
        userPrompt += `Image shows: ${imageDescription}\n\n`;
      }
      userPrompt += `Question: ${effectiveMessage}`;
    }

    // 6. Generate answer (Phi-3 is smart enough to handle long tutorials directly!)
    let responseText = await this.generateText(systemPrompt, userPrompt);

    // Launch secondary background task for self-learning vocabulary (Fire-and-forget)
    this.extractAndLearnDevice(effectiveMessage).catch(e => this.logger.error(`Self-learning LLM error: ${e.message}`));

    // Direct Match Fallback (Solution 3)
    if (responseText === '[REFUSAL]') {
       this.logger.log(`Local model refused or failed. Applying Direct Match Fallback.`);
       if (contextText && contextText.length > 20) {
           responseText = `💡 **Extracted Information:**\n\n${contextText}`;
       } else {
           const isFrenchPrompt = /[àâéèêëîïôùûüç]|\b(comment|pourquoi|est|les|des|un|une|avec|dans|sur|pour|casque|ecran|ordinateur|imprimante)\b/i.test(effectiveMessage);
           responseText = isFrenchPrompt 
             ? "- Effectuez une vérification visuelle des câbles d'alimentation et des connexions réseau.\n- Redémarrez l'appareil en maintenant le bouton d'alimentation enfoncé pendant 10 à 15 secondes."
             : "- Perform a physical inspection of power connections, status LEDs, and cables.\n- Restart the device by holding down the power button for 10 to 15 seconds to trigger a hard reset.";
       }
    }

    // Self-Learning: if the AI successfully generated a helpful guide (not a refusal or generic fallback), save it to the DB
    const genericPhrases = [
      "Perform a physical inspection",
      "Check power adapter output",
      "Verify device connections",
      "verify device connections",
      "consult official manufacturer documentation",
      "Effectuez une vérification visuelle",
      "vérification visuelle des câbles"
    ];
    const isHardRefusal = responseText.startsWith("Désolé, je ne trouve pas") || 
                           responseText.startsWith("Je suis en cours");
    
    // Check if response contains generic phrases
    const hasGenericPhrase = genericPhrases.some(phrase => responseText.includes(phrase));
    
    // Smart check: if response has generic phrases BUT also contains query-specific keywords, allow it
    let isDefaultRefusal = isHardRefusal;
    if (hasGenericPhrase && !isHardRefusal) {
      const queryKeywords = searchQuery.toLowerCase().split(/\s+/).filter(w => w.length > 3);
      const responseLower = responseText.toLowerCase();
      const matchedQueryWords = queryKeywords.filter(w => responseLower.includes(w));
      if (matchedQueryWords.length >= 2) {
        // Response contains query-specific terms — it's a valid technical answer, not pure generic
        this.logger.log(`Self-Learning: Response contains generic phrases BUT also has ${matchedQueryWords.length} query keywords (${matchedQueryWords.join(', ')}). Allowing save.`);
        isDefaultRefusal = false;
      } else {
        this.logger.log(`Self-Learning: Response is purely generic (only ${matchedQueryWords.length} query keywords). Blocking save.`);
        isDefaultRefusal = true;
      }
    }
    if (contextUsed === 'web' && !isDefaultRefusal && responseText.length > 25 && this.embedder) {
      try {
        const learnedTitle = searchQuery;
        const dbTitle = `Web: ${learnedTitle.substring(0, 80)}`;
        
        this.logger.log(`Self-Learning: Saving generated response as a guide for "${dbTitle}"...`);
        // Calculate query embedding for direct vector lookup next time
        const output = await this.embedder(learnedTitle, { pooling: 'mean', normalize: true });
        const embedding = Array.from(output.data);
        
        await this.db.troubleshootingGuide.create({
          data: {
            title: dbTitle,
            content: responseText, // save the structured bullet-point response
            embedding: embedding as any,
          },
        });
        await this.pineconeIndex.upsert({ records: [{
          id: crypto.randomUUID(),
          values: embedding,
          metadata: { title: dbTitle, content: responseText }
        }]});
        this.logger.log(`Self-Learning complete!`);
      } catch (e: any) {
        this.logger.error(`Self-learning post-save failed: ${e.message}`);
      }
    }

    // 7. Save user message and AI response to the database
    // Validate bookingId relation exists (if provided)
    let validatedBookingId: string | null = null;
    if (bookingId) {
      try {
        const booking = await this.db.booking.findUnique({ where: { id: bookingId } });
        if (booking) {
          validatedBookingId = booking.id;
        }
      } catch (err) {
        // Ignore invalid UUID or booking not found
      }
    }

    await this.db.chatMessage.create({
      data: {
        sessionId,
        bookingId: validatedBookingId,
        text: message,
        isUser: true,
        imageUrl: imageUrl || null,
      },
    });

    await this.db.chatMessage.create({
      data: {
        sessionId,
        bookingId: validatedBookingId,
        text: responseText,
        isUser: false,
      },
    });

    return {
      answer: responseText,
      contextUsed,
      similarityScore: bestScore,
      imageUrl: imageUrl || null,
      imageDescription: imageDescription || null,
    };
  }

  private async generateText(systemPrompt: string, userPrompt: string): Promise<string> {
    if (this.geminiModel) {
      try {
        const geminiResult = await this.geminiModel.generateContent(systemPrompt + '\n\n' + userPrompt);
        const text = geminiResult.response?.text();
        if (text && text.trim().length > 20) {
          return text.trim();
        }
      } catch (err: any) {
        this.logger.error(`Gemini model generation error: ${err.message}. Falling back to local T5 model.`);
      }
    }

    if (!this.llamaContext) {
      return 'Je suis en cours d\'initialisation de mes modèles IA locaux (GPU). Veuillez patienter quelques secondes et réessayer !';
    }
    try {
      let sequence;
      let raw = '';
      try {
        sequence = this.llamaContext.getSequence();
        const session = new this.LlamaChatSessionCls({
          contextSequence: sequence,
          systemPrompt: systemPrompt
        });
        
        raw = await session.prompt(userPrompt, {
          maxTokens: 500, // Medium length to prevent hallucination of extra details
          temperature: 0.2
        });
      } finally {
        if (sequence) {
          sequence.dispose();
        }
      }
      
      // 1. Remove Chinese characters and Chinese punctuation
      raw = raw.replace(/[\u4e00-\u9fa5。、，！？；：]/g, '');
      
      // 2. Normalize spaces
      raw = raw.replace(/[ \t]+/g, ' ').trim();
      
      // 3. Remove hallucinated fake support numbers or signatures
      raw = raw.replace(/Best regards.*/gi, '');
      raw = raw.replace(/\+9078.*/g, '');
      raw = raw.replace(/\[Your Name\].*/gi, '');
      
      // 4. Clean up incomplete sentences at the very end caused by token limits
      raw = raw.replace(/[-,\(\s]+$/g, ''); // strip trailing commas, open parenthesis, spaces
      if (raw.length > 0 && !raw.endsWith('.') && !raw.endsWith('!') && !raw.endsWith('?')) {
         const lastPunctuation = Math.max(raw.lastIndexOf('.'), raw.lastIndexOf('!'), raw.lastIndexOf('?'));
         if (lastPunctuation > 0) {
            raw = raw.substring(0, lastPunctuation + 1);
         } else {
            raw = raw + '.';
         }
      }
      
      raw = raw.trim();
      raw = raw.trim();
      
      // 2. Identify refusal patterns
      const lowerRaw = raw.toLowerCase();
      const refusalPatterns = [
        'provided instructions do not provide',
        'cannot answer this question',
        'not possible to answer',
        'does not provide any information',
        'does not give enough information',
        'context does not',
        'context is not relevant',
        'given context does not',
        'provided context is not',
        'not provide enough information',
        'cannot be answered',
        'no information provided',
        'i do not have this information',
        'instructions do not seem',
        'please provide clear and concise',
        'related to any specific',
        'i\'m sorry, but',
        'i am sorry, but',
        'cannot provide a lengthy',
        'provided instructions do not seem',
        'is only about',
        'does not address any',
        'unclear what the user',
        'should be provided',
        'cannot provide a response',
        'not related to the',
        'cannot provide a concise',
        'is not related',
        'the answer should be',
        'unclear what the user is asking',
        'cannot provide a concise response',
        'cannot provide a response to the question',
        'not specified in',
        'is not specified',
        'not mentioned in',
        'not in the provided background',
        'not in the given background',
        'background does not',
      ];
      let isRefusal = refusalPatterns.some((p) => lowerRaw.includes(p));

      // 3. Anti-Hallucination: Check for unauthorized brands.
      // If a brand is mentioned but was NOT in the prompt, filter out the sentence containing it (instant, 0ms CPU cost!)
      const brands = ['apple', 'ray-ban', 'wii', 'dell', 'logitech', 'hp', 'cisco', 'asus', 'formlabs', 'oculus', 'playstation', 'xbox'];
      const promptLower = userPrompt.toLowerCase();
      
      if (raw.length > 10 && !isRefusal) {
        const sentences = raw.split(/[.!?]+/).map(s => s.trim()).filter(s => s.length > 2);
        const cleanSentences = sentences.filter(sentence => {
          const lowerSentence = sentence.toLowerCase();
          for (const brand of brands) {
            // If the sentence mentions an unauthorized brand not present in the prompt, reject this sentence
            if (lowerSentence.includes(brand) && !promptLower.includes(brand)) {
              this.logger.warn(`Anti-Hallucination: Filtered out sentence mentioning unauthorized brand "${brand}": "${sentence}"`);
              return false;
            }
          }
          return true;
        });

        raw = cleanSentences.join('. ').trim();
        if (raw.length > 0 && !raw.endsWith('.')) {
          raw += '.';
        }
      }

      // 4. Fallback Troubleshooting Steps if raw text is empty, too short, or a refusal
      if (isRefusal || raw.length < 15) {
        return '[REFUSAL]';
      }
      
      // 5. Improve readability: Force line breaks before steps if the model compressed them into one line
      // Aggressive Step formatter: Catches "- Step 2:", "Step 2:", ". Step 2", etc.
      raw = raw.replace(/[-–—]*\s*Step\s+(\d+)[\s:]*/gi, '\n\n- Step $1: ');
      // Standard bullet point formatter: Catches ". - " or "; - "
      raw = raw.replace(/([.:;])\s*[-–—]\s+/g, '$1\n\n- '); 
      raw = raw.replace(/\s+(\d+)\.\s/g, '\n\n$1. ');
      raw = raw.replace(/\n{3,}/g, '\n\n'); // Max 2 line breaks
      
      // 6. Force the beautiful UI formatting
      if (!raw.includes('💡') && !raw.includes('Solution:')) {
         raw = `💡 **Solution:**\n\n- ` + raw.replace(/^\s*-\s*/, '');
      }

      return this.formatAsBulletPoints(raw);
    } catch (error: any) {
      this.logger.error(`Error generating text: ${error.message}`);
      return 'Une erreur est survenue lors de la génération de la réponse. Veuillez réessayer.';
    }
  }

  private handleStepClarification(stepNumber: number, lastResponse: string, userQuery: string): string {
    const rawLines = lastResponse.split('\n').map((l) => l.trim()).filter((l) => l.length > 5);
    const bullets = rawLines.filter((l) => l.startsWith('-') || l.startsWith('*') || /^\d+[\.\)]/.test(l));

    let targetStepText = '';
    if (bullets.length >= stepNumber && stepNumber > 0) {
      targetStepText = bullets[stepNumber - 1].replace(/^[-*\d\.\)\s]+/, '').trim();
    } else if (rawLines.length >= stepNumber && stepNumber > 0) {
      targetStepText = rawLines[stepNumber - 1].replace(/^[-*\d\.\)\s]+/, '').trim();
    }

    const isFr = /[àâéèêëîïôùûüç]|\b(etape|étape|expliquer|explique|pourquoi)\b/i.test(userQuery + ' ' + targetStepText);

    if (targetStepText) {
      if (isFr) {
        return (
          `Voici l'explication détaillée pour l'Étape ${stepNumber} ("${targetStepText}") :\n\n` +
          `- Inspectez attentivement l'état matériel et les câbles du composant concerné par cette étape.\n` +
          `- Observez la couleur des voyants LED de diagnostic (rouge = matériel, orange = alim, clignotant = données).\n` +
          `- Pour les problèmes d'affichage ou d'écran bleu, vérifiez le gestionnaire de périphériques et réinitialisez le pilote vidéo avec Win + Ctrl + Shift + B.`
        );
      } else {
        return (
          `Here is the detailed explanation for Step ${stepNumber} ("${targetStepText}"):\n\n` +
          `- Inspect the hardware connections and cables associated with this step.\n` +
          `- Check the diagnostic status LEDs or error messages displayed on your screen.\n` +
          `- For graphics or display glitches, restart the video driver shortcut (Win + Ctrl + Shift + B) or inspect Device Manager.`
        );
      }
    }

    if (isFr) {
      return `Voici plus de détails sur l'Étape ${stepNumber} :\n\n- Effectuez un contrôle approfondi des connexions et de la configuration du composant.\n- Vérifiez les voyants d'état et réinitialisez le périphérique si nécessaire.`;
    } else {
      return `Here are more details regarding Step ${stepNumber}:\n\n- Perform a thorough check of component connections and settings.\n- Inspect diagnostic status LEDs and restart the hardware if needed.`;
    }
  }

  private handleGeneralClarification(lastResponse: string, userQuery: string): string {
    const isFr =
      /[àâéèêëîïôùûüç]|\b(comment|pourquoi|compris|expliquer|détails|plus|daccord|salut|effectuez|vérification|redémarrez|voyants|écran)\b/i.test(
        userQuery + ' ' + lastResponse,
      );
    const cleanLast = lastResponse.replace(/^[-*\d\.\)\s]+/, '').trim();
    const lowerContext = (lastResponse + ' ' + userQuery).toLowerCase();

    let step1 = cleanLast;
    let step2 = '';
    let step3 = '';

    if (
      lowerContext.includes('camera') ||
      lowerContext.includes('sony') ||
      lowerContext.includes('photo') ||
      lowerContext.includes('picture')
    ) {
      step1 = isFr
        ? "Appuyez sur le bouton de lecture (icône ▶) situé à l'arrière de l'appareil photo Sony près de l'écran LCD."
        : 'Locate and press the Playback button (▶ icon) on the back of the Sony camera near the LCD screen.';
      step2 = isFr
        ? 'Utilisez la molette de contrôle ou les touches fléchées pour naviguer parmi les photos enregistrées sur la carte SD.'
        : 'Use the control wheel or directional arrow buttons to navigate through photos saved on the SD card.';
      step3 = isFr
        ? "Appuyez sur le bouton central ou la molette pour zoomer sur une photo et afficher les détails d'image."
        : 'Press the center button or zoom lever to enlarge photos and view image details.';
    } else if (
      lowerContext.includes('quest') ||
      lowerContext.includes('vr') ||
      lowerContext.includes('oculus')
    ) {
      step1 = isFr
        ? "Maintenez le bouton d'alimentation situé sur le côté gauche du casque Meta Quest pendant 3 secondes."
        : 'Press and hold the power button on the left side of the Meta Quest headset for 3 seconds.';
      step2 = isFr
        ? "Ajustez les sangles de tête et les lentilles jusqu'à obtenir une image claire sans flou."
        : 'Adjust head straps and facial interface until the display is clear and comfortable.';
      step3 = isFr
        ? "Associez le casque au Wi-Fi via l'application mobile Meta Horizon et configurez l'espace Guardian."
        : 'Pair device with Wi-Fi via Meta Horizon mobile app and complete Guardian boundary setup.';
    } else if (
      lowerContext.includes('formlabs') ||
      lowerContext.includes('resin') ||
      lowerContext.includes('3b')
    ) {
      step1 = isFr
        ? "Inspectez le bac à résine et le plateau d'impression pour vérifier l'alignement des broches."
        : 'Inspect resin tank alignment and clean the print build platform.';
      step2 = isFr
        ? "Vérifiez que la soupape de décharge de résine n'est pas bloquée et nettoyez avec de l'IPA."
        : 'Ensure resin tank valve is unobstructed and clean optical window with IPA wipes.';
      step3 = isFr
        ? 'Lancez le logiciel PreForm pour calibrer les paramètres de hauteur de couche.'
        : 'Launch PreForm software to calibrate layer height settings and send print job.';
    } else if (
      lowerContext.includes('printer') ||
      lowerContext.includes('imprimante') ||
      lowerContext.includes('spooler') ||
      lowerContext.includes('hp') ||
      lowerContext.includes('laserjet')
    ) {
      step1 = isFr
        ? "Ouvrez le menu Démarrer > Paramètres > Périphériques > Imprimantes et scanners, puis cliquez sur 'Ajouter une imprimante'."
        : "Open Start Menu > Settings > Bluetooth & Devices > Printers & Scanners, then click 'Add Device'.";
      step2 = isFr
        ? "Connectez l'imprimante via un câble USB direct ou choisissez-la sur le même réseau Wi-Fi local que votre PC."
        : "Connect the printer via a direct USB cable or select it from the list on the same local Wi-Fi network.";
      step3 = isFr
        ? "Laissez Windows installer automatiquement le pilote requis et imprimez une page de test pour valider la connexion."
        : "Allow Windows to automatically install the driver and print a test page to confirm connectivity.";
    } else if (
      lowerContext.includes('cisco') ||
      lowerContext.includes('switch') ||
      lowerContext.includes('router') ||
      lowerContext.includes('rj45')
    ) {
      step1 = isFr
        ? "Vérifiez le câble d'alimentation et branchez les câbles réseau RJ45 aux ports gigabit."
        : 'Check power cable connection and insert RJ45 network cables into gigabit ports.';
      step2 = isFr
        ? 'Observez les voyants LED de port (vert fixe = connexion 1Gbps, vert clignotant = trafic actif).'
        : 'Check port LED status lights (solid green = 1Gbps link, flashing green = active data traffic).';
      step3 = isFr
        ? "Accédez à la console CLI Cisco pour vérifier la table d'adresses MAC et la configuration VLAN."
        : 'Access Cisco CLI console to clear MAC address table and verify VLAN configuration.';
    } else {
      step2 = isFr
        ? "Examinez les voyants LED de diagnostic, l'écran et les câbles pour vérifier l'absence d'erreurs."
        : 'Check diagnostic status LEDs, display screen, and cable connections for error indicators.';
      step3 = isFr
        ? 'Redémarrez le périphérique et vérifiez la configuration dans le menu des paramètres du logiciel.'
        : 'Restart device and verify configuration in the system settings menu.';
    }

    if (isFr) {
      return (
        `Voici l'explication détaillée étape par étape :\n\n` +
        `- Étape 1 : ${step1}\n` +
        `- Étape 2 : ${step2}\n` +
        `- Étape 3 : ${step3}\n\n` +
        `💡 Conseil : N'hésitez pas à me demander des précisions sur l'Étape 1, 2 ou 3 !`
      );
    } else {
      return (
        `Here is a step-by-step detailed breakdown:\n\n` +
        `- Step 1: ${step1}\n` +
        `- Step 2: ${step2}\n` +
        `- Step 3: ${step3}\n\n` +
        `💡 Tip: Feel free to ask for extra details on Step 1, Step 2, or Step 3!`
      );
    }
  }

  private formatAsBulletPoints(text: string): string {
    if (text.includes('- ') || text.includes('* ') || text.includes('\n-')) {
      return text;
    }

    const stepRegex = /(?:\d+[\.\)]\s+|Step\s+\d+:\s+)/gi;
    if (stepRegex.test(text)) {
      const parts = text.split(stepRegex).map(p => p.trim()).filter(p => p.length > 5);
      if (parts.length > 1) {
        let intro = '';
        let listStartIndex = 0;
        if (!text.trim().match(/^\d+[\.\)]/)) {
          intro = parts[0] + '\n\n';
          listStartIndex = 1;
        }
        const bullets = parts.slice(listStartIndex).map(p => `- ${p.charAt(0).toUpperCase() + p.slice(1)}`).join('\n');
        return intro + bullets;
      }
    }

    const sentences = text.split(/[.!?]+/).map(s => s.trim()).filter(s => s.length > 12);
    if (sentences.length > 1) {
      return sentences.map(s => `- ${s.charAt(0).toUpperCase() + s.slice(1)}.`).join('\n');
    }

    return text;
  }

  async getHistory(sessionId: string) {
    const history = await this.db.chatMessage.findMany({
      where: { sessionId },
      orderBy: { createdAt: 'asc' },
    });
    return history.map((msg) => ({
      id: msg.id,
      text: msg.text,
      isUser: msg.isUser,
      imageUrl: msg.imageUrl,
      createdAt: msg.createdAt,
    }));
  }

  private cleanQueryForSearch(msg: string): string {
    const translatedMsg = this.translateFrenchToEnglish(msg);
    let clean = translatedMsg.toLowerCase().trim();
    
    const prefixes = [
      'how do i', 'how to', 'how can i', 'where is', 'what is', 
      'how do you', 'can you show me how to', 'please help me with',
      'how can we', 'tell me how to', 'is there a way to',
      'explique en detail comment use', 'explique en detail comment utiliser',
      'comment utiliser', 'comment faire pour', 'explique comment', 'explique',
      'comment on utilise', 'comment configurer', 'comment installer', 'i get', 'i am getting',
      'im getting', 'i have a'
    ];
    
    for (const prefix of prefixes) {
      if (clean.startsWith(prefix)) {
        clean = clean.substring(prefix.length).trim();
      }
    }
    
    clean = clean.replace(/[?.,\/#!$%\^&\*;:{}=\-_`~()'"“”‘’]/g, '').trim();
    return clean || msg;
  }

  private getDeviceCategory(text: string): string {
    const t = text.toLowerCase();
    if (t.includes('quest') || t.includes('vr') || t.includes('lens')) return 'quest';
    if (t.includes('formlabs') || t.includes('resin') || t.includes('3b')) return 'formlabs';
    if (t.includes('asus') || t.includes('tuf') || t.includes('bsod') || t.includes('blue screen') || t.includes('crash')) return 'asus';
    if (t.includes('cisco') || t.includes('switch')) return 'cisco';
    if (t.includes('hp') || t.includes('laserjet') || t.includes('paper')) return 'hp';
    return 'general';
  }

  private extractBrandFromText(text: string): string {
    const lq = text.toLowerCase();
    const brands = ['quest', 'oculus', 'formlabs', 'asus', 'tuf', 'cisco', 'hp', 'samsung', 'dell', 'lenovo', 'apple', 'macbook', 'acer'];
    for (const b of brands) {
      if (lq.includes(b)) {
        if (b === 'oculus' || b === 'quest') return 'meta';
        if (b === 'tuf' || b === 'asus') return 'asus';
        if (b === 'macbook' || b === 'apple') return 'apple';
        return b;
      }
    }
    return '';
  }

  private cosineSimilarity(a: number[], b: number[]): number {
    if (a.length !== b.length) return 0;
    let dotProduct = 0;
    for (let i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
    }
    return dotProduct;
  }

  async getSessionsForUser(userId: string) {
    try {
      const isValidObjectId = typeof userId === 'string' && /^[0-9a-fA-F]{24}$/.test(userId);
      let bookings: any[] = [];
      if (isValidObjectId) {
        try {
          bookings = await this.db.booking.findMany({
            where: { userId },
            include: { asset: true },
          });
        } catch (bErr: any) {
          this.logger.warn(`Could not query bookings for userId "${userId}": ${bErr.message}`);
        }
      } else {
        this.logger.warn(`getSessionsForUser received non-ObjectId userId "${userId}". Skipping booking query.`);
      }

      const bookingIds = bookings.map((b) => b.id);
      const generalSessionId = `${userId}_general`;

      const knownOldUuids: Record<string, string> = {
        'negzaoui@gmail.com': '88d65126-a932-467b-9309-1745285bfe0a',
        'negzaouioussama65@gmail.com': '79447337-6a1f-4bc4-b58a-01f3600a0da2',
        'admin@admin.com': 'd47ff935-89e3-4821-9949-0a0c0fdf8881',
      };

      let prefixesToMatch: string[] = [`${userId}_`];
      let userObj = null;
      if (isValidObjectId) {
        userObj = await this.db.user.findUnique({ where: { id: userId } });
      } else {
        userObj = await this.db.user.findFirst({
          where: { OR: [{ email: userId }, { studentId: userId }] },
        });
      }

      if (userObj) {
        const oldUuid = knownOldUuids[userObj.email.toLowerCase()];
        if (oldUuid) {
          prefixesToMatch.push(`${oldUuid}_`);
        }
        if (userObj.studentId) {
          prefixesToMatch.push(`${userObj.studentId}_`);
        }
      }

      const orConditions = prefixesToMatch.map((prefix) => ({
        sessionId: { startsWith: prefix },
      }));

      // Fetch all unique session IDs from ChatMessage database that belong to this user
      const userChatMessages = await this.db.chatMessage.findMany({
        where: {
          OR: orConditions,
        },
        select: {
          sessionId: true,
        },
        distinct: ['sessionId'],
      });

      const dbUserSessionIds = userChatMessages.map((m) => m.sessionId);

      // Merge all sessions (general, custom chats, and booking chats) without duplicates
      const allSessionIds = Array.from(new Set([
        generalSessionId,
        ...dbUserSessionIds,
        ...bookingIds,
      ]));

      // Fetch all messages for these sessions ordered by createdAt desc in a single query
      const allMessages = await this.db.chatMessage.findMany({
        where: {
          sessionId: { in: allSessionIds },
        },
        orderBy: { createdAt: 'desc' },
      });

      // Map the latest message per session ID in memory
      const latestMessageMap = new Map<string, typeof allMessages[0]>();
      for (const msg of allMessages) {
        if (!latestMessageMap.has(msg.sessionId)) {
          latestMessageMap.set(msg.sessionId, msg);
        }
      }

      const sessionsList = [];

      for (const sessionId of allSessionIds) {
        const latestMessage = latestMessageMap.get(sessionId);

        if (latestMessage) {
          let title = 'General Troubleshooting';
          let status = 'General';

          if (sessionId !== generalSessionId && !sessionId.startsWith(`${userId}_`)) {
            // It is a booking session
            const booking = bookings.find((b) => b.id === sessionId);
            title = booking ? `Troubleshoot: ${booking.asset.name}` : 'Equipment Troubleshooting';
            status = booking ? booking.status.toString() : 'Active';
          } else if (sessionId.startsWith(`${userId}_`) && sessionId !== generalSessionId) {
            // It is a custom new conversation (timestamped)
            title = `Conversation (${sessionId.substring(sessionId.indexOf('_') + 1)})`;
            status = 'General';
            
            // Format timestamp into human readable title if possible
            const parts = sessionId.split('_');
            if (parts.length > 1 && !isNaN(Number(parts[1]))) {
              const dateObj = new Date(Number(parts[1]));
              title = `New Chat - ${dateObj.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}`;
            }
          }

          sessionsList.push({
            id: sessionId,
            title,
            lastMessage: latestMessage.text,
            date: this.formatRelativeDate(latestMessage.createdAt),
            status,
            rawDate: latestMessage.createdAt.toISOString(),
          });
        }
      }

      // Sort sessionsList by rawDate descending (newest first)
      sessionsList.sort((a, b) => {
        return new Date(b.rawDate).getTime() - new Date(a.rawDate).getTime();
      });

      return sessionsList;
    } catch (error: any) {
      this.logger.error(`Failed to get chat sessions for user ${userId}: ${error.message}`);
      return [];
    }
  }

  async deleteSession(sessionId: string) {
    try {
      this.logger.log(`Deleting all messages for session: ${sessionId}`);
      const result = await this.db.chatMessage.deleteMany({
        where: { sessionId },
      });
      return { success: true, deletedCount: result.count };
    } catch (error: any) {
      this.logger.error(`Failed to delete session ${sessionId}: ${error.message}`);
      return { success: false, error: error.message };
    }
  }

  private formatRelativeDate(date: Date): string {
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));

    if (diffDays === 0) return 'Today';
    if (diffDays === 1) return 'Yesterday';
    if (diffDays < 7) return `${diffDays} days ago`;
    return date.toLocaleDateString();
  }

  async processPdf(file: Express.Multer.File) {
    const fs = require('fs');
    const path = require('path');
    const pdfParse = require('pdf-parse').default || require('pdf-parse');

    const tempDir = path.join(__dirname, 'temp_pdf');
    if (!fs.existsSync(tempDir)) {
      fs.mkdirSync(tempDir, { recursive: true });
    }
    const tempFilePath = path.join(tempDir, `${Date.now()}_${file.originalname}`);

    try {
      this.logger.log(`Writing temporary PDF file to: ${tempFilePath}`);
      fs.writeFileSync(tempFilePath, file.buffer);

      const parser = new pdfParse.PDFParse({ url: tempFilePath });
      await parser.load();
      const data = await parser.getText();
      const text = data.text;

      this.logger.log(`PDF read successfully. Total pages: ${data.total}. Extracting chunks...`);

      // Split text into overlapping chunks of ~700 characters
      const chunkSize = 700;
      const overlap = 150;
      const chunks: string[] = [];

      let i = 0;
      while (i < text.length) {
        const chunk = text.substring(i, i + chunkSize).trim();
        if (chunk.length > 20) {
          chunks.push(chunk);
        }
        i += (chunkSize - overlap);
      }

      this.logger.log(`Generated ${chunks.length} chunks. Starting vectorization and DB ingestion...`);

      let count = 0;
      for (let idx = 0; idx < chunks.length; idx++) {
        const chunk = chunks[idx];
        try {
          const title = `PDF: ${file.originalname} (Chunk ${idx + 1})`;
          const embedText = `${title}. ${chunk}`;

          const output = await this.embedder(embedText, { pooling: 'mean', normalize: true });
          const embedding = Array.from(output.data);

          await this.db.troubleshootingGuide.create({
            data: {
              title: title,
              content: chunk,
              embedding: embedding as any,
            }
          });
          await this.pineconeIndex.upsert({ records: [{
            id: crypto.randomUUID(),
            values: embedding,
            metadata: { title: title, content: chunk }
          }]});
          count++;
        } catch (err: any) {
          this.logger.error(`Failed to ingest PDF chunk ${idx + 1}: ${err.message}`);
        }
      }

      try {
        await parser.destroy();
      } catch (err) {}

      return {
        success: true,
        message: `Le document "${file.originalname}" a été importé avec succès (${data.total} pages). Il a été découpé et stocké sous forme de ${count} vecteurs dans PostgreSQL.`,
        chunksCount: count,
      };
    } catch (error: any) {
      this.logger.error(`PDF ingestion failed: ${error.message}`);
      return {
        success: false,
        message: `L'importation du PDF a échoué: ${error.message}`,
      };
    } finally {
      // Always cleanup the temp file
      try {
        if (fs.existsSync(tempFilePath)) {
          fs.unlinkSync(tempFilePath);
        }
      } catch (err) {}
    }
  }

  private async autoIngestAgentPdfs() {
    const fs = require('fs');
    const path = require('path');
    const pdfParse = require('pdf-parse').default || require('pdf-parse');

    const agentDir = 'c:/Users/Negza/Desktop/Project_Stage/Project_Stage/Agent';
    if (!fs.existsSync(agentDir)) {
      this.logger.warn(`Agent directory not found at: ${agentDir}`);
      return;
    }

    try {
      const files = fs.readdirSync(agentDir);
      const pdfFiles = files.filter((f: string) => f.toLowerCase().endsWith('.pdf'));
      this.logger.log(`Found ${pdfFiles.length} PDF files in Agent directory. Checking for ingestion...`);

      for (const filename of pdfFiles) {
        const titlePrefix = `PDF: ${filename}`;

        // SOLUTION 1: FAST SKIP
        // If Chunk 1 exists, we assume the PDF is already ingested and skip parsing entirely!
        const firstChunkExists = await this.db.troubleshootingGuide.findFirst({
          where: { title: `${titlePrefix} (Chunk 1)` }
        });

        if (firstChunkExists) {
          this.logger.log(`PDF "${filename}" already in database. Fast skipping...`);
          continue;
        }

        const pdfPath = path.join(agentDir, filename);
        this.logger.log(`Checking/Ingesting PDF guide: ${filename}...`);

        try {
          const parser = new pdfParse.PDFParse({ url: pdfPath });
          await parser.load();
          const data = await parser.getText();
          const text = data.text;

          // Split text into overlapping chunks of ~700 characters
          const chunkSize = 700;
          const overlap = 150;
          const chunks: string[] = [];

          let i = 0;
          while (i < text.length) {
            const chunk = text.substring(i, i + chunkSize).trim();
            if (chunk.length > 20) {
              chunks.push(chunk);
            }
            i += (chunkSize - overlap);
          }

          let count = 0;
          let skipped = 0;
          for (let idx = 0; idx < chunks.length; idx++) {
            const chunk = chunks[idx];
            const title = `${titlePrefix} (Chunk ${idx + 1})`;

            // Check if this specific chunk is already in MongoDB (Resume capability)
            const chunkExists = await this.db.troubleshootingGuide.findFirst({
              where: { title: title }
            });

            if (chunkExists) {
              skipped++;
              continue; // Skip already ingested chunk
            }

            const embedText = `${title}. ${chunk}`;
            const output = await this.embedder(embedText, { pooling: 'mean', normalize: true });
            const embedding = Array.from(output.data);

            await this.db.troubleshootingGuide.create({
              data: {
                title: title,
                content: chunk,
                embedding: embedding as any,
              }
            });
            const hashId = crypto.createHash('md5').update(title).digest('hex');
            await this.pineconeIndex.upsert({ records: [{
              id: hashId,
              values: embedding,
              metadata: { title: title, content: chunk }
            }]});
            count++;
            // Yield execution to NestJS event loop to handle user chat requests instantly
            await new Promise((resolve) => setTimeout(resolve, 50));
          }

          try {
            await parser.destroy();
          } catch (err) {}

          if (count > 0) {
            this.logger.log(`Ingestion of "${filename}" completed: saved ${count} new chunks (skipped ${skipped} existing).`);
          } else if (skipped > 0 && count === 0) {
            this.logger.log(`PDF "${filename}" is already 100% ingested (skipped ${skipped} chunks).`);
          }
        } catch (err: any) {
          this.logger.error(`Failed to automatically ingest PDF file "${filename}": ${err.message}`);
        }
      }
      this.logger.log('Auto-ingestion check of Agent PDF directory completed.');
    } catch (error: any) {
      this.logger.error(`Error scanning Agent PDF directory: ${error.message}`);
    }
  }

  private translateFrenchToEnglish(text: string): string {
    if (!text) return '';
    return text; // bypassed for multilingual model
    let t = text.toLowerCase();
    
    // Replace common French device names and brands
    t = t.replace(/\bordinateur\b/g, 'computer');
    t = t.replace(/\bportable\b/g, 'laptop');
    t = t.replace(/\bécran\b/g, 'screen');
    t = t.replace(/\bimprimante\b/g, 'printer');
    t = t.replace(/\bcasque\b/g, 'headset');
    t = t.replace(/\blentilles?\b/g, 'lenses');
    t = t.replace(/\bclavier\b/g, 'keyboard');
    t = t.replace(/\bsouris\b/g, 'mouse');
    t = t.replace(/\bcâble\b/g, 'cable');
    t = t.replace(/\bréseau\b/g, 'network');
    t = t.replace(/\bconnexion\b/g, 'connection');
    t = t.replace(/\bvoyant\b/g, 'led');
    
    // Replace common French problems and questions
    t = t.replace(/\bpas reconnu\b/g, 'not recognized');
    t = t.replace(/\bnon reconnu\b/g, 'not recognized');
    t = t.replace(/\bclignote\b/g, 'flickering');
    t = t.replace(/\bclignotent\b/g, 'flickering');
    t = t.replace(/\bécran bleu\b/g, 'blue screen');
    t = t.replace(/\bne s'allume pas\b/g, 'wont turn on');
    t = t.replace(/\bne marche pas\b/g, 'does not work');
    t = t.replace(/\bcomment faire\b/g, 'how to');
    t = t.replace(/\bque faire\b/g, 'what to do');
    t = t.replace(/\bhors ligne\b/g, 'offline');
    t = t.replace(/\bbourrage\b/g, 'jam');
    t = t.replace(/\bpapier\b/g, 'paper');
    t = t.replace(/\bnettoyer\b/g, 'clean');
    t = t.replace(/\bbuée\b/g, 'foggy');
    
    return t;
  }

  private async extractAndLearnDevice(userMessage: string) {
    try {
      const extractionPrompt = 'You are a precise data extraction AI. Extract the specific electronic device brand and model from the User Text. Output ONLY the brand and model (e.g., "HP Smart Tank 515", "iPhone 15"). If no specific device is mentioned, output exactly "NONE". Do not write any sentences. Keep it under 50 characters.';
      const extractionUserPrompt = `User Text: "${userMessage}"\n\nDevice Name:`;
      
      let newDevice = await this.generateText(extractionPrompt, extractionUserPrompt);
      // Clean up the string to remove common hallucinations
      newDevice = newDevice.replace(/[^a-zA-Z0-9 -]/g, '').trim();
      newDevice = newDevice.replace(/Solution-?\s*/i, '').trim();
      
      const isInvalid = !newDevice || 
                        newDevice.toUpperCase() === 'NONE' || 
                        newDevice.toUpperCase().includes('REFUSAL') || 
                        newDevice.length >= 50 || 
                        newDevice.length <= 3;
                        
      if (!isInvalid) {
        const fs = require('fs');
        const path = require('path');
        const labelsPath = path.join(__dirname, '../../../../labels.json');
        if (fs.existsSync(labelsPath)) {
          const labelsData = fs.readFileSync(labelsPath, 'utf8');
          let labels = JSON.parse(labelsData);
          const exists = labels.some((l: string) => l.toLowerCase().includes(newDevice.toLowerCase()));
          if (!exists) {
            labels.push(newDevice);
            fs.writeFileSync(labelsPath, JSON.stringify(labels, null, 2), 'utf8');
            this.logger.log(`Auto-Learning (Call 2): Added new device "${newDevice}" to labels.json`);
          }
        }
      }
    } catch (e: any) {
       this.logger.error(`Auto-Learning Extraction Error: ${e.message}`);
    }
  }
}
