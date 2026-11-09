import { Controller, Post, Body, UploadedFiles, UseInterceptors, Logger } from '@nestjs/common';
import { FilesInterceptor } from '@nestjs/platform-express';
import { Module2ApiService } from './module2-api.service';
import * as multer from 'multer';
import * as path from 'path';

@Controller('inspection')
export class Module2ApiController {
  private readonly logger = new Logger(Module2ApiController.name);

  constructor(private readonly module2ApiService: Module2ApiService) {}

  @Post('photo')
  @UseInterceptors(FilesInterceptor('files', 10, {
    storage: multer.diskStorage({
      destination: './uploads/inspection',
      filename: (req, file, cb) => {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1e9);
        cb(null, file.fieldname + '-' + uniqueSuffix + path.extname(file.originalname));
      },
    }),
  }))
  async processPhoto(
    @UploadedFiles() files: Express.Multer.File[],
    @Body() body: {
      itemId: string;
      itemType: string;
      deviceModel: string;
      complaintText?: string;
    },
  ) {
    this.logger.log(`Received photo inspection request for ${body.itemId}`);
    
    // Split files into baseline and return (assuming half and half for simplicity)
    const mid = Math.floor(files.length / 2);
    const baselineFiles = files.slice(0, mid).map(f => f.path);
    const returnFiles = files.slice(mid).map(f => f.path);

    return this.module2ApiService.processPhotoInspection(
      body.itemId,
      body.itemType,
      baselineFiles,
      returnFiles,
      body.deviceModel,
      body.complaintText || '',
    );
  }

  @Post('text')
  async processText(
    @Body() body: {
      itemType: string;
      deviceModel: string;
      complaintText: string;
    },
  ) {
    this.logger.log(`Received text inspection request for ${body.deviceModel}`);
    return this.module2ApiService.processTextInspection(
      body.itemType,
      body.complaintText,
      body.deviceModel,
    );
  }

  @Post('video')
  @UseInterceptors(FilesInterceptor('file', 1, {
    storage: multer.diskStorage({
      destination: './uploads/videos',
      filename: (req, file, cb) => {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1e9);
        cb(null, 'lab-video-' + uniqueSuffix + path.extname(file.originalname));
      },
    }),
  }))
  async processVideo(
    @UploadedFiles() files: Express.Multer.File[],
    @Body() body: { itemId: string; startTime?: string; endTime?: string },
  ) {
    if (!files || files.length === 0) {
      throw new Error('No video file provided');
    }
    
    // Ensure uploads/videos directory exists
    const dir = './uploads/videos';
    const fs = require('fs');
    if (!fs.existsSync(dir)){
        fs.mkdirSync(dir, { recursive: true });
    }

    let maxSeconds: number | undefined;
    if (body.startTime && body.endTime) {
      try {
        const parseTime = (t: string) => {
          const [h, m] = t.split(':').map(Number);
          return h * 3600 + m * 60;
        };
        const startSec = parseTime(body.startTime);
        const endSec = parseTime(body.endTime);
        if (endSec > startSec) {
          maxSeconds = endSec - startSec;
        } else {
          // If crosses midnight (e.g., 22:00 to 02:00)
          maxSeconds = (24 * 3600 - startSec) + endSec;
        }
      } catch (e) {
        this.logger.warn(`Failed to parse startTime/endTime: ${e.message}`);
      }
    }

    const videoPath = path.resolve(files[0].path);
    this.logger.log(`Received video monitoring request for ${body.itemId} at ${videoPath} with maxSeconds=${maxSeconds}`);
    
    return this.module2ApiService.processVideoMonitoring(
      body.itemId || 'LAB_KIT_DEFAULT',
      videoPath,
      maxSeconds,
    );
  }
}
