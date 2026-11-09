import { Controller, Get, Post, Body, UseGuards, UseInterceptors, UploadedFile, Param, Put, Delete } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { AssetsService } from './assets.service';
import { CloudinaryService } from '../common/cloudinary/cloudinary.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { Roles } from '../common/guards/roles.decorator';

@Controller('assets')
export class AssetsController {
  constructor(
    private readonly assetsService: AssetsService,
    private readonly cloudinaryService: CloudinaryService,
  ) {}

  @Get()
  async findAll() {
    return this.assetsService.findAll();
  }

  @Get(':id')
  async findOne(@Param('id') id: string) {
    return this.assetsService.findOne(id);
  }

  @Post()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN')
  @UseInterceptors(FileInterceptor('image'))
  async create(
    @Body() body: any,
    @UploadedFile() file: Express.Multer.File,
  ) {
    let imageUrl = '';
    if (file) {
      try {
        imageUrl = await this.cloudinaryService.uploadImage(file);
      } catch (error) {
        imageUrl = 'https://res.cloudinary.com/dgjubz6pl/image/upload/v1721054580/chronos/fallback_asset.png';
      }
    } else {
      imageUrl = body.imageUrl || '';
    }
    return this.assetsService.create({
      name: body.name,
      category: body.category,
      imageUrl,
      maxReservationDays: body.maxReservationDays ? parseInt(body.maxReservationDays, 10) : 3,
    });
  }

  @Put(':id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN')
  async update(
    @Param('id') id: string,
    @Body() body: any,
  ) {
    return this.assetsService.update(id, {
      name: body.name,
      category: body.category,
      maxReservationDays: body.maxReservationDays ? parseInt(body.maxReservationDays, 10) : undefined,
    });
  }

  @Delete(':id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN')
  async remove(@Param('id') id: string) {
    return this.assetsService.remove(id);
  }
}
