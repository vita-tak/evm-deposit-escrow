import { Controller, Get, Param } from '@nestjs/common';
import { UsersService } from './users.service';

@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get(':address')
  async getUser(@Param('address') address: string) {
    return this.usersService.findByAddress(address);
  }

  @Get(':address/deposits')
  async getUserDeposits(@Param('address') address: string) {
    return this.usersService.getUserDeposits(address);
  }
}
