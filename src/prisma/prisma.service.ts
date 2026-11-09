import { Injectable, OnModuleInit, OnModuleDestroy, Logger } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(PrismaService.name);

  async onModuleInit() {
    try {
      await this.$connect();
      this.logger.log('Database connected successfully to MongoDB Atlas.');
      await this.seedAdminUser();
    } catch (error: any) {
      this.logger.warn(`Neon database server offline/unreachable: ${error.message}. Running NestJS in Fallback/Mock Offline Mode.`);
    }
  }

  private async seedAdminUser() {
    try {
      const adminEmail = 'admin@admin.com';
      const existingAdmin = await this.user.findUnique({
        where: { email: adminEmail },
      });

      if (!existingAdmin) {
        const crypto = await import('crypto');
        const hashedPassword = crypto.createHmac('sha256', 'chronos-salt').update('admin').digest('hex');
        
        await this.user.create({
          data: {
            email: adminEmail,
            password: hashedPassword,
            name: 'Administrator',
            studentId: 'ADMIN001',
            role: 'ADMIN',
          },
        });
        this.logger.log('Admin account (admin@admin.com) successfully seeded in database.');
      }
    } catch (error: any) {
      this.logger.error(`Failed to seed admin user: ${error.message}`);
    }
  }

  async onModuleDestroy() {
    try {
      await this.$disconnect();
    } catch (error) {
      // Ignore disconnect errors
    }
  }
}
