import { Controller, Get, Post, Body, UseGuards, UseInterceptors, UploadedFile, UploadedFiles, Param, Req } from '@nestjs/common';
import { FileInterceptor, AnyFilesInterceptor } from '@nestjs/platform-express';
import { BookingsService } from './bookings.service';
import { CloudinaryService } from '../common/cloudinary/cloudinary.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import * as multer from 'multer';
import * as path from 'path';

@Controller('bookings')
@UseGuards(JwtAuthGuard)
export class BookingsController {
  constructor(
    private readonly bookingsService: BookingsService,
    private readonly cloudinaryService: CloudinaryService,
  ) {}

  @Get()
  async findAll() {
    return this.bookingsService.findAll();
  }

  @Get('my')
  async findMy(@Req() req: any) {
    return this.bookingsService.findByUser(req.user.id);
  }

  @Get(':id')
  async findOne(@Param('id') id: string) {
    return this.bookingsService.findOne(id);
  }

  @Post()
  @UseInterceptors(AnyFilesInterceptor())
  async create(
    @Req() req: any, 
    @Body() body: any,
    @UploadedFiles() files: Array<Express.Multer.File>
  ) {
    let frontPhotoUrl = '';
    let backPhotoUrl = '';
    
    if (files && files.length > 0) {
      console.log(`Received files in POST /bookings:`, files.map(f => f.fieldname));
      for (const file of files) {
        try {
          const url = await this.cloudinaryService.uploadImage(file);
          if (file.fieldname === 'frontPhoto') frontPhotoUrl = url;
          else if (file.fieldname === 'backPhoto') backPhotoUrl = url;
          // Fallback if frontend sends generic 'files'
          else if (!frontPhotoUrl) frontPhotoUrl = url;
          else if (!backPhotoUrl) backPhotoUrl = url;
        } catch (error) {
          console.error("Failed to upload baseline photo", error);
        }
      }
    }

    return this.bookingsService.createBooking(
      req.user.id,
      body.assetId,
      body.startTime,
      body.endTime,
      frontPhotoUrl,
      backPhotoUrl
    );
  }

  @Post(':id/request-return')
  async requestReturn(@Param('id') id: string) {
    return this.bookingsService.requestReturn(id);
  }

  @Post(':id/run-ai-scan')
  @UseInterceptors(AnyFilesInterceptor({
    storage: multer.diskStorage({
      destination: './uploads/inspection',
      filename: (req, file, cb) => {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1e9);
        cb(null, file.fieldname + '-' + uniqueSuffix + path.extname(file.originalname));
      },
    }),
  }))
  async runAiScan(
    @Param('id') id: string,
    @UploadedFiles() files: Array<Express.Multer.File>,
    @Body() body: any,
  ) {
    const returnFilesPaths = files.map(f => f.path);
    return this.bookingsService.runAiScan(id, returnFilesPaths, body.complaintText || '');
  }

  @Post(':id/return')
  @UseInterceptors(FileInterceptor('image'))
  async submitReturn(
    @Param('id') id: string,
    @UploadedFile() file: Express.Multer.File,
    @Body() body: any,
  ) {
    let scannedPhotoUrl = '';
    if (file) {
      try {
        scannedPhotoUrl = await this.cloudinaryService.uploadImage(file);
      } catch (error) {
        scannedPhotoUrl = 'https://res.cloudinary.com/dgjubz6pl/image/upload/v1721054580/chronos/fallback_return.png';
      }
    } else {
      scannedPhotoUrl = body.scannedPhotoUrl || '';
    }

    const cost = body.estimatedRepairCost ? parseFloat(body.estimatedRepairCost) : 0.0;

    return this.bookingsService.submitReturnInspection(id, scannedPhotoUrl, {
      damageCategory: body.damageCategory,
      damageSeverity: body.damageSeverity,
      aiDescription: body.aiDescription,
      estimatedRepairCost: cost,
      estimatedRepairTime: body.estimatedRepairTime,
      recommendedAction: body.recommendedAction,
      status: body.status,
      resolutionChoice: body.resolutionChoice, // PASS, PARTIAL, or TOTAL_LOSS
    });
  }

  @Post(':id/cancel')
  async cancelBooking(@Req() req: any, @Param('id') id: string) {
    return this.bookingsService.cancelBooking(req.user.id, id);
  }
}
