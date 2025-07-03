
'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';
import { UserCheck, LogOut, LayoutDashboard, Scale, Users, Menu, Wrench, Bell, User, Clock } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';
import { Sheet, SheetContent, SheetTrigger, SheetClose, SheetTitle } from '@/components/ui/sheet';
import { Badge } from '@/components/ui/badge';
import { Separator } from '@/components/ui/separator';
import { checkAdminAuth, adminLogout, type AdminSession } from '@/lib/adminAuth';
import { useToast } from '@/hooks/use-toast';

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const { toast } = useToast();
  
  const [isClient, setIsClient] = useState(false);
  const [adminSession, setAdminSession] = useState<AdminSession | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [sessionTimeRemaining, setSessionTimeRemaining] = useState<string>('');

  useEffect(() => {
    setIsClient(true);
  }, []);

  // Check authentication and manage session
  useEffect(() => {
    if (!isClient) return;

    const checkAuth = async () => {
      try {
        const session = await checkAdminAuth();
        
        if (!session && pathname !== '/admin/login') {
          router.push('/admin/login');
          return;
        }
        
        setAdminSession(session);
      } catch (error) {
        console.error('Auth check error:', error);
        if (pathname !== '/admin/login') {
          router.push('/admin/login');
        }
      } finally {
        setIsLoading(false);
      }
    };

    checkAuth();
  }, [isClient, pathname, router]);

  // Update session time remaining
  useEffect(() => {
    if (!adminSession) return;

    const updateTimer = () => {
      const remaining = adminSession.expiresAt - Date.now();
      if (remaining <= 0) {
        handleLogout();
        return;
      }

      const hours = Math.floor(remaining / (1000 * 60 * 60));
      const minutes = Math.floor((remaining % (1000 * 60 * 60)) / (1000 * 60));
      setSessionTimeRemaining(`${hours}h ${minutes}m`);

      // Warn when session is about to expire
      if (remaining <= 15 * 60 * 1000 && remaining > 14 * 60 * 1000) { // 15 minutes
        toast({
          title: 'Session Expiring Soon',
          description: 'Your admin session will expire in 15 minutes.',
          variant: 'default',
        });
      }
    };

    updateTimer();
    const interval = setInterval(updateTimer, 60000); // Update every minute

    return () => clearInterval(interval);
  }, [adminSession, toast]);

  const handleLogout = async () => {
    try {
      await adminLogout();
      toast({
        title: 'Logged Out',
        description: 'You have been successfully logged out.',
      });
    } catch (error) {
      console.error('Logout error:', error);
    } finally {
      router.push('/admin/login');
    }
  };

  const navItems = [
    { href: '/admin', label: 'Dashboard', icon: LayoutDashboard },
    { href: '/admin/users', label: 'Users', icon: Users },
    { href: '/admin/leaders', label: 'Leaders', icon: UserCheck },
    { href: '/admin/ratings', label: 'Ratings', icon: Bell },
    { href: '/admin/tools', label: 'Admin Tools', icon: Wrench },
  ];

  // Don't render anything while checking authentication
  if (!isClient || isLoading) {
    return null;
  }

  // Allow login page to render without authentication
  if (pathname === '/admin/login') {
    return <>{children}</>;
  }

  // Redirect to login if not authenticated
  if (!adminSession) {
    return null;
  }

  const NavLinks = () => (
    <>
      {navItems.map(item => (
        <Link
          key={item.href}
          href={item.href}
          className={cn(
            "flex items-center gap-3 rounded-lg px-3 py-2 text-muted-foreground transition-all hover:text-primary",
            pathname.startsWith(item.href) && (item.href !== '/admin' || pathname === item.href) ? "bg-secondary text-primary" : ""
          )}
        >
          <item.icon className="h-4 w-4" />
          {item.label}
        </Link>
      ))}
    </>
  );

  const UserInfo = () => (
    <div className="space-y-3">
      <div className="flex items-center gap-3">
        <div className="flex items-center justify-center w-8 h-8 rounded-full bg-primary/10">
          <User className="h-4 w-4 text-primary" />
        </div>
        <div className="flex-1 min-w-0">
          <p className="text-sm font-medium truncate">{adminSession.user.name}</p>
          <p className="text-xs text-muted-foreground truncate">{adminSession.user.email}</p>
        </div>
        <Badge variant={adminSession.user.role === 'super_admin' ? 'default' : 'secondary'} className="text-xs">
          {adminSession.user.role === 'super_admin' ? 'Super Admin' : 'Admin'}
        </Badge>
      </div>
      
      <div className="flex items-center gap-2 text-xs text-muted-foreground">
        <Clock className="h-3 w-3" />
        <span>Session expires in {sessionTimeRemaining}</span>
      </div>
      
      <Separator />
      
      <Button
        onClick={handleLogout}
        variant="ghost"
        className="w-full justify-start text-muted-foreground hover:text-red-600 hover:bg-red-50"
      >
        <LogOut className="h-4 w-4 mr-2" />
        Sign Out
      </Button>
    </div>
  );

  return (
    <div className="grid min-h-screen w-full grid-cols-1 lg:grid-cols-[280px_1fr]">
      {/* Desktop Sidebar */}
      <div className="hidden border-r bg-background lg:block">
        <div className="flex h-full max-h-screen flex-col gap-2">
          {/* Header */}
          <div className="flex h-14 items-center border-b px-4 lg:h-[60px] lg:px-6">
            <Link href="/" className="flex items-center gap-2 font-semibold">
              <Scale className="h-6 w-6 text-primary" />
              <span>PolitiRate Admin</span>
            </Link>
          </div>
          
          {/* Navigation */}
          <div className="flex-1 overflow-auto">
            <nav className="grid items-start px-2 text-sm font-medium lg:px-4 gap-1">
              <NavLinks />
            </nav>
          </div>
          
          {/* User Info */}
          <div className="border-t p-4">
            <UserInfo />
          </div>
        </div>
      </div>

      {/* Main Content */}
      <div className="flex flex-col flex-1">
        {/* Mobile Header */}
        <header className="flex h-14 items-center gap-4 border-b bg-background px-4 lg:hidden">
          <Sheet>
            <SheetTrigger asChild>
              <Button size="icon" variant="outline">
                <Menu className="h-5 w-5" />
                <span className="sr-only">Toggle Menu</span>
              </Button>
            </SheetTrigger>
            <SheetContent side="left" className="flex flex-col">
              <SheetTitle className="sr-only">Admin Menu</SheetTitle>
              
              {/* Mobile Header */}
              <div className="flex items-center gap-2 font-semibold mb-4">
                <Scale className="h-6 w-6 text-primary" />
                <span>PolitiRate Admin</span>
              </div>
              
              {/* Mobile Navigation */}
              <nav className="grid gap-2 text-base font-medium flex-1">
                {navItems.map(item => (
                  <SheetClose asChild key={item.href}>
                    <Link
                      href={item.href}
                      className={cn(
                        "flex items-center gap-3 rounded-lg px-3 py-2 text-muted-foreground transition-all hover:text-primary",
                        pathname.startsWith(item.href) && (item.href !== '/admin' || pathname === item.href) ? "bg-secondary text-primary" : ""
                      )}
                    >
                      <item.icon className="h-4 w-4" />
                      {item.label}
                    </Link>
                  </SheetClose>
                ))}
              </nav>
              
              {/* Mobile User Info */}
              <div className="border-t pt-4">
                <UserInfo />
              </div>
            </SheetContent>
          </Sheet>
          
          <div className="flex-1" />
          
          {/* Mobile user badge */}
          <Badge variant={adminSession.user.role === 'super_admin' ? 'default' : 'secondary'}>
            {adminSession.user.role === 'super_admin' ? 'Super Admin' : 'Admin'}
          </Badge>
        </header>

        {/* Page Content */}
        <main className="flex-1 overflow-auto p-4 lg:p-6">
          {children}
        </main>
      </div>
    </div>
  );
}
