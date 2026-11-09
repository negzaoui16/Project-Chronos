import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';

@Injectable()
export class MailService {
  private transporter: nodemailer.Transporter;
  private readonly logger = new Logger(MailService.name);

  constructor(private readonly configService: ConfigService) {
    this.transporter = nodemailer.createTransport({
      host: this.configService.get<string>('SMTP_HOST') || 'smtp.gmail.com',
      port: this.configService.get<number>('SMTP_PORT') || 587,
      secure: false, // TLS
      auth: {
        user: this.configService.get<string>('SMTP_USER') || 'negzaouioussama15@gmail.com',
        pass: this.configService.get<string>('SMTP_PASSWORD') || 'mycaykubwfewclql',
      },
    });
  }

  async sendResetCode(email: string, code: string): Promise<void> {
    const mailOptions = {
      from: '"Chronos Security" <' + (this.configService.get<string>('SMTP_USER') || 'negzaouioussama15@gmail.com') + '>',
      to: email,
      subject: 'Chronos Verification Code - Reset Password',
      html: `
        <div style="font-family: Arial, sans-serif; padding: 20px; max-width: 600px; margin: 0 auto; border: 1px solid #e2e8f0; border-radius: 12px; background-color: #ffffff;">
          <h2 style="color: #8083FF; margin-bottom: 16px; font-weight: 700; letter-spacing: -0.5px;">CHRONOS OS</h2>
          <p style="color: #334155; font-size: 15px; line-height: 24px;">A request has been made to recover your academic workstation password. Use the following security authorization code:</p>
          <div style="background-color: #f8fafc; padding: 18px; border-radius: 8px; text-align: center; font-size: 28px; font-weight: 700; letter-spacing: 4px; color: #0b1326; margin: 24px 0; border: 1px dashed #cbd5e1;">
            ${code}
          </div>
          <p style="color: #64748b; font-size: 13px; line-height: 20px;">This code is valid for 15 minutes. If you did not request this recovery, please change your credentials immediately.</p>
        </div>
      `,
    };

    try {
      await this.transporter.sendMail(mailOptions);
      this.logger.log(`Password reset email successfully sent to ${email}`);
    } catch (error: any) {
      this.logger.error(`Failed to send password reset email to ${email}: ${error.message}`);
      throw error;
    }
  }
}
