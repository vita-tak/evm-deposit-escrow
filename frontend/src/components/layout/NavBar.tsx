'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { ConnectButton } from '@rainbow-me/rainbowkit';
import { Home, Building2, User, Scale } from 'lucide-react';

export function Navbar() {
  const pathname = usePathname();

  const isActive = (path: string) => {
    return pathname === path;
  };

  const navLinks = [
    { href: '/', label: 'Home', icon: Home },
    { href: '/landlord', label: 'Landlord', icon: Building2 },
    { href: '/tenant', label: 'Tenant', icon: User },
    { href: '/resolver', label: 'Resolver', icon: Scale },
  ];

  return (
    <nav className='border-b bg-white'>
      <div className='container mx-auto px-4'>
        <div className='flex h-16 items-center justify-between'>
          <Link href='/' className='text-xl font-bold'>
            Blip Rental Deposit Demo
          </Link>

          <div className='flex items-center gap-6'>
            {navLinks.map((link) => {
              const Icon = link.icon;
              return (
                <Link
                  key={link.href}
                  href={link.href}
                  className={`text-base font-medium transition-colors hover:text-primary flex items-center ${
                    isActive(link.href)
                      ? 'text-primary border-b-2 border-primary'
                      : 'text-gray-700'
                  }`}>
                  <Icon className='w-4 h-4 inline mr-1' />
                  {link.label}
                </Link>
              );
            })}

            <ConnectButton />
          </div>
        </div>
      </div>
    </nav>
  );
}
