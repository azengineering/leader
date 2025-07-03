
'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { Card, CardContent, CardDescription, CardHeader, CardTitle, CardFooter } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Label } from '@/components/ui/label';
import { Shield, X, Home, Loader2, Eye, EyeOff, AlertCircle, CheckCircle2 } from 'lucide-react';
import { useToast } from '@/hooks/use-toast';
import Link from 'next/link';
import { authenticateAdmin, checkAdminAuth } from '@/lib/adminAuth';
import { Alert, AlertDescription } from '@/components/ui/alert';

interface LoginAttempt {
  count: number;
  lastAttempt: number;
  blockedUntil?: number;
}

const MAX_LOGIN_ATTEMPTS = 5;
const LOCKOUT_DURATION = 15 * 60 * 1000; // 15 minutes

export default function AdminLoginPage() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [isCheckingAuth, setIsCheckingAuth] = useState(true);
  const [loginAttempts, setLoginAttempts] = useState<LoginAttempt>({ count: 0, lastAttempt: 0 });
  const [errorMessage, setErrorMessage] = useState('');
  const [isBlocked, setIsBlocked] = useState(false);
  const [blockTimeRemaining, setBlockTimeRemaining] = useState(0);
  
  const router = useRouter();
  const { toast } = useToast();

  // Check if already authenticated
  useEffect(() => {
    const checkAuth = async () => {
      const session = await checkAdminAuth();
      if (session) {
        router.replace('/admin');
        return;
      }
      setIsCheckingAuth(false);
    };
    
    checkAuth();
  }, [router]);

  // Load login attempts from localStorage
  useEffect(() => {
    if (typeof window !== 'undefined') {
      const stored = localStorage.getItem('admin_login_attempts');
      if (stored) {
        try {
          const attempts: LoginAttempt = JSON.parse(stored);
          setLoginAttempts(attempts);
          
          // Check if still blocked
          if (attempts.blockedUntil && Date.now() < attempts.blockedUntil) {
            setIsBlocked(true);
            setBlockTimeRemaining(Math.ceil((attempts.blockedUntil - Date.now()) / 1000));
          }
        } catch {
          localStorage.removeItem('admin_login_attempts');
        }
      }
    }
  }, []);

  // Update block countdown
  useEffect(() => {
    if (!isBlocked || blockTimeRemaining <= 0) return;
    
    const timer = setInterval(() => {
      setBlockTimeRemaining(prev => {
        if (prev <= 1) {
          setIsBlocked(false);
          setLoginAttempts({ count: 0, lastAttempt: 0 });
          localStorage.removeItem('admin_login_attempts');
          return 0;
        }
        return prev - 1;
      });
    }, 1000);
    
    return () => clearInterval(timer);
  }, [isBlocked, blockTimeRemaining]);

  const updateLoginAttempts = (success: boolean) => {
    if (success) {
      setLoginAttempts({ count: 0, lastAttempt: 0 });
      localStorage.removeItem('admin_login_attempts');
      return;
    }

    const now = Date.now();
    const newCount = loginAttempts.count + 1;
    
    if (newCount >= MAX_LOGIN_ATTEMPTS) {
      const blockedUntil = now + LOCKOUT_DURATION;
      const newAttempts = { count: newCount, lastAttempt: now, blockedUntil };
      
      setLoginAttempts(newAttempts);
      setIsBlocked(true);
      setBlockTimeRemaining(Math.ceil(LOCKOUT_DURATION / 1000));
      
      localStorage.setItem('admin_login_attempts', JSON.stringify(newAttempts));
      
      toast({
        variant: 'destructive',
        title: 'Account Temporarily Locked',
        description: `Too many failed attempts. Try again in ${Math.ceil(LOCKOUT_DURATION / 60000)} minutes.`,
      });
    } else {
      const newAttempts = { count: newCount, lastAttempt: now };
      setLoginAttempts(newAttempts);
      localStorage.setItem('admin_login_attempts', JSON.stringify(newAttempts));
    }
  };

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (isBlocked) {
      toast({
        variant: 'destructive',
        title: 'Account Locked',
        description: `Please wait ${Math.ceil(blockTimeRemaining / 60)} more minutes before trying again.`,
      });
      return;
    }

    setIsLoading(true);
    setErrorMessage('');

    try {
      const session = await authenticateAdmin(email, password);
      
      if (session) {
        updateLoginAttempts(true);
        
        toast({
          title: 'Login Successful',
          description: `Welcome back, ${session.user.name}!`,
          action: (
            <div className="flex items-center gap-2">
              <CheckCircle2 className="h-4 w-4 text-green-600" />
              <span className="text-sm font-medium">Admin Panel</span>
            </div>
          ),
        });
        
        router.push('/admin');
      }
    } catch (error: any) {
      updateLoginAttempts(false);
      
      let message = 'Login failed. Please check your credentials.';
      
      if (error.message.includes('Invalid credentials')) {
        message = 'Invalid email or password.';
      } else if (error.message.includes('Access denied')) {
        message = 'Access denied. Admin privileges required.';
      } else if (error.message.includes('Unable to verify')) {
        message = 'Unable to verify admin status. Please try again.';
      }
      
      setErrorMessage(message);
      
      toast({
        variant: 'destructive',
        title: 'Login Failed',
        description: message,
      });
    } finally {
      setIsLoading(false);
    }
  };

  const formatTime = (seconds: number) => {
    const minutes = Math.floor(seconds / 60);
    const remainingSeconds = seconds % 60;
    return `${minutes}:${remainingSeconds.toString().padStart(2, '0')}`;
  };

  if (isCheckingAuth) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-secondary">
        <div className="flex items-center gap-3">
          <Loader2 className="h-6 w-6 animate-spin text-primary" />
          <span className="text-lg font-medium">Checking authentication...</span>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-secondary p-4">
      <Card className="w-full max-w-md shadow-xl rounded-xl relative">
        <Button 
          variant="ghost" 
          size="icon" 
          className="absolute top-4 right-4 text-muted-foreground hover:text-foreground" 
          onClick={() => router.push('/')}
        >
          <X className="h-5 w-5" />
          <span className="sr-only">Close</span>
        </Button>
        
        <CardHeader className="text-center p-8">
          <div className="mx-auto bg-primary/10 p-4 rounded-full w-fit mb-4">
            <Shield className="w-10 h-10 text-primary" />
          </div>
          <CardTitle className="text-3xl font-headline">Admin Panel</CardTitle>
          <CardDescription className="pt-1">
            Sign in with your admin credentials
          </CardDescription>
        </CardHeader>
        
        <CardContent className="px-8 pb-8">
          {/* Security Alerts */}
          {isBlocked && (
            <Alert className="mb-6 border-red-200 bg-red-50">
              <AlertCircle className="h-4 w-4 text-red-600" />
              <AlertDescription className="text-red-800">
                Account temporarily locked due to multiple failed attempts.
                <br />
                <span className="font-semibold">Time remaining: {formatTime(blockTimeRemaining)}</span>
              </AlertDescription>
            </Alert>
          )}
          
          {loginAttempts.count > 0 && loginAttempts.count < MAX_LOGIN_ATTEMPTS && !isBlocked && (
            <Alert className="mb-6 border-yellow-200 bg-yellow-50">
              <AlertCircle className="h-4 w-4 text-yellow-600" />
              <AlertDescription className="text-yellow-800">
                {loginAttempts.count} of {MAX_LOGIN_ATTEMPTS} login attempts used.
                {MAX_LOGIN_ATTEMPTS - loginAttempts.count} attempts remaining.
              </AlertDescription>
            </Alert>
          )}

          {errorMessage && (
            <Alert className="mb-6 border-red-200 bg-red-50">
              <AlertCircle className="h-4 w-4 text-red-600" />
              <AlertDescription className="text-red-800">
                {errorMessage}
              </AlertDescription>
            </Alert>
          )}
          
          <form onSubmit={handleLogin} className="space-y-6">
            <div className="space-y-2">
              <Label htmlFor="email">Email Address</Label>
              <Input
                id="email"
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="admin@example.com"
                className="h-12"
                disabled={isBlocked || isLoading}
                required
                autoComplete="email"
              />
            </div>
            
            <div className="space-y-2">
              <Label htmlFor="password">Password</Label>
              <div className="relative">
                <Input
                  id="password"
                  type={showPassword ? "text" : "password"}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="Enter your password"
                  className="h-12 pr-12"
                  disabled={isBlocked || isLoading}
                  required
                  autoComplete="current-password"
                />
                <Button
                  type="button"
                  variant="ghost"
                  size="icon"
                  className="absolute right-2 top-1/2 -translate-y-1/2 h-8 w-8"
                  onClick={() => setShowPassword(!showPassword)}
                  disabled={isBlocked || isLoading}
                >
                  {showPassword ? (
                    <EyeOff className="h-4 w-4" />
                  ) : (
                    <Eye className="h-4 w-4" />
                  )}
                  <span className="sr-only">
                    {showPassword ? 'Hide password' : 'Show password'}
                  </span>
                </Button>
              </div>
            </div>
            
            <Button 
              type="submit" 
              size="lg" 
              className="w-full text-base"
              disabled={isLoading || isBlocked || !email || !password}
            >
              {isLoading ? (
                <>
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                  Authenticating...
                </>
              ) : isBlocked ? (
                `Locked (${formatTime(blockTimeRemaining)})`
              ) : (
                'Sign In'
              )}
            </Button>
          </form>
        </CardContent>
        
        <CardFooter className="flex justify-center p-6 bg-secondary/30 rounded-b-xl border-t">
          <Link href="/" className="text-sm text-primary hover:underline font-medium flex items-center gap-2">
            <Home className="h-4 w-4" />
            Return to main site
          </Link>
        </CardFooter>
      </Card>
    </div>
  );
}
