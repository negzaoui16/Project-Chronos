// Chat controller for Module 3 RAG Troubleshooting Assistant
import { Controller, Post, Get, Delete, Body, Param, UseInterceptors, UploadedFile } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ChatService } from '../chat/chat.service';

@Controller('chat')
export class ChatController {
  constructor(private readonly chatService: ChatService) {}

  @Post('message')
  @UseInterceptors(FileInterceptor('image'))
  async sendMessage(
    @UploadedFile() file: Express.Multer.File,
    @Body() body: { sessionId: string; message: string; bookingId?: string },
  ) {
    try {
      return await this.chatService.processMessage(
        body.sessionId,
        body.message,
        file,
        body.bookingId,
      );
    } catch (error: any) {
      return {
        answer: "Oups ! Je rencontre temporairement des difficultés de connexion réseau ou serveur. Veuillez vérifier votre connexion et réessayer.",
        contextUsed: 'error',
        similarityScore: 0,
        imageUrl: null,
        imageDescription: null,
      };
    }
  }

  @Post('upload-pdf')
  @UseInterceptors(FileInterceptor('file'))
  async uploadPdf(
    @UploadedFile() file: Express.Multer.File,
  ) {
    return this.chatService.processPdf(file);
  }

  @Get('history/:sessionId')
  async getHistory(@Param('sessionId') sessionId: string) {
    return this.chatService.getHistory(sessionId);
  }

  @Get('sessions/:userId')
  async getSessions(@Param('userId') userId: string) {
    return this.chatService.getSessionsForUser(userId);
  }

  @Delete('session/:sessionId')
  async deleteSession(@Param('sessionId') sessionId: string) {
    return this.chatService.deleteSession(sessionId);
  }
}
