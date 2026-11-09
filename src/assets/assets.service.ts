import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AssetStatus } from '@prisma/client';

@Injectable()
export class AssetsService {
  constructor(private readonly prisma: PrismaService) {}

  async findAll() {
    return this.prisma.asset.findMany({
      orderBy: { createdAt: 'desc' },
    });
  }

  async findOne(id: string) {
    const asset = await this.prisma.asset.findUnique({
      where: { id },
    });
    if (!asset) {
      throw new NotFoundException(`Asset with ID ${id} not found`);
    }
    return asset;
  }

  async create(data: { name: string; description?: string; category: string; imageUrl: string; maxReservationDays?: number }) {
    return this.prisma.asset.create({
      data: {
        name: data.name,
        description: data.description,
        category: data.category,
        imageUrl: data.imageUrl,
        maxReservationDays: data.maxReservationDays ?? 3,
        status: AssetStatus.AVAILABLE,
      },
    });
  }

  async updateStatus(id: string, status: AssetStatus) {
    const asset = await this.findOne(id);
    return this.prisma.asset.update({
      where: { id: asset.id },
      data: { status },
    });
  }
  async update(id: string, data: { name?: string; category?: string; maxReservationDays?: number }) {
    const asset = await this.findOne(id);
    if (asset.status === AssetStatus.RESERVED) {
      throw new BadRequestException('Cannot modify an asset that is currently reserved');
    }
    return this.prisma.asset.update({
      where: { id },
      data,
    });
  }

  async remove(id: string) {
    const asset = await this.findOne(id);
    if (asset.status === AssetStatus.RESERVED) {
      throw new BadRequestException('Cannot delete an asset that is currently reserved');
    }
    return this.prisma.asset.delete({
      where: { id },
    });
  }
}
