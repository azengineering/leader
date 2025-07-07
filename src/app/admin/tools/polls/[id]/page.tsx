
'use client';

import { useState, useEffect } from 'react';
import { useRouter, useParams } from 'next/navigation';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import * as z from 'zod';
import { format } from 'date-fns';

import { getPollById, updatePoll, type Poll } from '@/data/polls';
import { indianStates } from '@/data/locations';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Form, FormControl, FormDescription, FormField, FormItem, FormLabel, FormMessage } from '@/components/ui/form';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { Switch } from '@/components/ui/switch';
import { Calendar } from '@/components/ui/calendar';
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover';
import { Checkbox } from '@/components/ui/checkbox';
import { Badge } from '@/components/ui/badge';
import { useToast } from '@/hooks/use-toast';
import { cn } from '@/lib/utils';
import { ChevronLeft, CalendarIcon, Loader2, Save, Users, Trash2, AlertTriangle } from 'lucide-react';
import { Skeleton } from '@/components/ui/skeleton';
import { Alert, AlertDescription } from '@/components/ui/alert';

const editPollSchema = z.object({
  title: z.string().min(1, { message: "Title is required." }),
  description: z.string().optional(),
  is_active: z.boolean().default(true),
  active_until: z.date().optional(),
  target_filters: z.object({
    states: z.array(z.string()).optional(),
    constituencies: z.array(z.string()).optional(),
    gender: z.array(z.string()).optional(),
    age_min: z.number().min(18).max(100).optional(),
    age_max: z.number().min(18).max(100).optional(),
  }).optional(),
});

type EditPollFormData = z.infer<typeof editPollSchema>;

export default function EditPollPage() {
  const router = useRouter();
  const params = useParams();
  const { toast } = useToast();
  const [poll, setPoll] = useState<Poll | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [constituencyInput, setConstituencyInput] = useState('');

  const form = useForm<EditPollFormData>({
    resolver: zodResolver(editPollSchema),
    defaultValues: {
      title: '',
      description: '',
      is_active: true,
      target_filters: {
        states: [],
        constituencies: [],
        gender: [],
      },
    },
  });

  useEffect(() => {
    const fetchPoll = async () => {
      try {
        const pollId = params.id as string;
        const pollData = await getPollById(pollId);

        if (pollData) {
          setPoll(pollData);
          form.reset({
            title: pollData.title,
            description: pollData.description || '',
            is_active: pollData.is_active,
            active_until: pollData.active_until ? new Date(pollData.active_until) : undefined,
            target_filters: {
              states: pollData.target_filters?.states || [],
              constituencies: pollData.target_filters?.constituencies || [],
              gender: pollData.target_filters?.gender || [],
              age_min: pollData.target_filters?.age_min,
              age_max: pollData.target_filters?.age_max,
            },
          });
        }
      } catch (error) {
        console.error('Error fetching poll:', error);
        toast({
          variant: 'destructive',
          title: 'Error',
          description: 'Failed to load poll data.',
        });
      } finally {
        setIsLoading(false);
      }
    };

    fetchPoll();
  }, [params.id, form, toast]);

  const onSubmit = async (data: EditPollFormData) => {
    if (!poll) return;

    setIsSubmitting(true);
    try {
      await updatePoll(poll.id, {
        title: data.title,
        description: data.description,
        is_active: data.is_active,
        active_until: data.active_until?.toISOString(),
        target_filters: data.target_filters && (
          data.target_filters.states?.length || 
          data.target_filters.constituencies?.length || 
          data.target_filters.gender?.length ||
          data.target_filters.age_min ||
          data.target_filters.age_max
        ) ? data.target_filters : undefined,
      });

      toast({
        title: 'Success',
        description: 'Poll updated successfully.',
      });

      router.back();
    } catch (error) {
      console.error('Error updating poll:', error);
      toast({
        variant: 'destructive',
        title: 'Error',
        description: 'Failed to update poll.',
      });
    } finally {
      setIsSubmitting(false);
    }
  };

  if (isLoading) {
    return (
      <div className="space-y-6">
        <div className="flex items-center gap-4">
          <Skeleton className="h-10 w-10" />
          <Skeleton className="h-8 w-48" />
        </div>
        <Card>
          <CardHeader>
            <Skeleton className="h-6 w-32" />
            <Skeleton className="h-4 w-64" />
          </CardHeader>
          <CardContent className="space-y-4">
            <Skeleton className="h-10 w-full" />
            <Skeleton className="h-20 w-full" />
            <Skeleton className="h-6 w-24" />
            <Skeleton className="h-10 w-48" />
          </CardContent>
        </Card>
      </div>
    );
  }

  if (!poll) {
    return (
      <div className="text-center py-16">
        <h2 className="text-2xl font-bold">Poll not found</h2>
        <p className="text-muted-foreground mt-2">The poll you're looking for doesn't exist.</p>
        <Button onClick={() => router.back()} className="mt-4">
          <ChevronLeft className="mr-2 h-4 w-4" />
          Go Back
        </Button>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-4">
        <Button variant="outline" size="icon" onClick={() => router.back()}>
          <ChevronLeft className="h-4 w-4" />
        </Button>
        <div>
          <h1 className="text-3xl font-bold font-headline">Edit Poll</h1>
          <p className="text-muted-foreground">Update poll details and settings</p>
        </div>
      </div>

      {poll.is_active && (
        <Alert>
          <AlertTriangle className="h-4 w-4" />
          <AlertDescription>
            This poll is currently active. Questions and answer options cannot be modified while the poll is active. You can edit other settings and deactivate the poll if needed.
          </AlertDescription>
        </Alert>
      )}

      <Form {...form}>
        <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-6">
          <Card>
            <CardHeader>
              <CardTitle>Poll Details</CardTitle>
              <CardDescription>Basic information about the poll</CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <FormField
                control={form.control}
                name="title"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Title</FormLabel>
                    <FormControl>
                      <Input {...field} />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />

              <FormField
                control={form.control}
                name="description"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Description</FormLabel>
                    <FormControl>
                      <Textarea {...field} rows={3} />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />

              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <FormField
                  control={form.control}
                  name="is_active"
                  render={({ field }) => (
                    <FormItem className="flex flex-row items-center justify-between rounded-lg border p-4">
                      <div className="space-y-0.5">
                        <FormLabel className="text-base">Active Status</FormLabel>
                        <FormDescription>
                          Whether this poll is currently active and accepting votes
                        </FormDescription>
                      </div>
                      <FormControl>
                        <Switch
                          checked={field.value}
                          onCheckedChange={field.onChange}
                        />
                      </FormControl>
                    </FormItem>
                  )}
                />

                <FormField
                  control={form.control}
                  name="active_until"
                  render={({ field }) => (
                    <FormItem className="flex flex-col">
                      <FormLabel>End Date (Optional)</FormLabel>
                      <Popover>
                        <PopoverTrigger asChild>
                          <FormControl>
                            <Button
                              variant={"outline"}
                              className={cn(
                                "w-full pl-3 text-left font-normal",
                                !field.value && "text-muted-foreground"
                              )}
                            >
                              {field.value ? (
                                format(field.value, "PPP")
                              ) : (
                                <span>Pick a date</span>
                              )}
                              <CalendarIcon className="ml-auto h-4 w-4 opacity-50" />
                            </Button>
                          </FormControl>
                        </PopoverTrigger>
                        <PopoverContent className="w-auto p-0" align="start">
                          <Calendar
                            mode="single"
                            selected={field.value}
                            onSelect={field.onChange}
                            disabled={(date) =>
                              date < new Date() || date < new Date("1900-01-01")
                            }
                            initialFocus
                          />
                        </PopoverContent>
                      </Popover>
                      <FormDescription>
                        The date when this poll will stop accepting votes.
                      </FormDescription>
                      <FormMessage />
                    </FormItem>
                  )}
                />
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Users className="h-5 w-5" />
                Target Audience (Optional)
              </CardTitle>
              <CardDescription>
                Configure filters to target specific users. Leave empty to show to all users.
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              {/* Quick Actions */}
              <div className="flex gap-2">
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  onClick={() => {
                    form.setValue('target_filters.states', []);
                    form.setValue('target_filters.constituencies', []);
                    form.setValue('target_filters.gender', []);
                    form.setValue('target_filters.age_min', undefined);
                    form.setValue('target_filters.age_max', undefined);
                    setConstituencyInput('');
                  }}
                >
                  Clear All
                </Button>
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  onClick={() => form.setValue('target_filters.states', indianStates)}
                >
                  All States
                </Button>
              </div>

              {/* States Filter */}
              <div className="space-y-2">
                <div className="flex items-center justify-between">
                  <FormLabel>States ({form.watch('target_filters.states')?.length || 0}/{indianStates.length})</FormLabel>
                </div>
                <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-2 max-h-32 overflow-y-auto p-2 border rounded-lg bg-muted/20">
                  {indianStates.map((state) => (
                    <FormField
                      key={state}
                      control={form.control}
                      name="target_filters.states"
                      render={({ field }) => (
                        <FormItem className="flex flex-row items-start space-x-2 space-y-0">
                          <FormControl>
                            <Checkbox
                              checked={field.value?.includes(state)}
                              onCheckedChange={(checked) => {
                                const currentStates = field.value || [];
                                if (checked) {
                                  field.onChange([...currentStates, state]);
                                } else {
                                  field.onChange(currentStates.filter(s => s !== state));
                                }
                              }}
                            />
                          </FormControl>
                          <FormLabel className="text-xs font-normal cursor-pointer">
                            {state}
                          </FormLabel>
                        </FormItem>
                      )}
                    />
                  ))}
                </div>
              </div>

              {/* Constituencies Filter */}
              <div className="space-y-2">
                <div className="flex items-center justify-between">
                  <FormLabel>Constituencies ({form.watch('target_filters.constituencies')?.length || 0})</FormLabel>
                </div>
                
                <div className="flex gap-2">
                  <Input
                    placeholder="MP/MLA/Panchayat constituency name"
                    value={constituencyInput}
                    onChange={(e) => setConstituencyInput(e.target.value)}
                    onKeyDown={(e) => {
                      if (e.key === 'Enter') {
                        e.preventDefault();
                        const value = constituencyInput.trim();
                        if (value) {
                          const currentConstituencies = form.getValues('target_filters.constituencies') || [];
                          if (!currentConstituencies.includes(value)) {
                            form.setValue('target_filters.constituencies', [...currentConstituencies, value]);
                          }
                          setConstituencyInput('');
                        }
                      }
                    }}
                    className="flex-1"
                  />
                  <Button
                    type="button"
                    variant="outline"
                    onClick={() => {
                      const value = constituencyInput.trim();
                      if (value) {
                        const currentConstituencies = form.getValues('target_filters.constituencies') || [];
                        if (!currentConstituencies.includes(value)) {
                          form.setValue('target_filters.constituencies', [...currentConstituencies, value]);
                        }
                        setConstituencyInput('');
                      }
                    }}
                  >
                    Add
                  </Button>
                  <Button
                    type="button"
                    variant="outline"
                    onClick={() => {
                      form.setValue('target_filters.constituencies', []);
                      setConstituencyInput('');
                    }}
                    title="Clear all constituencies"
                  >
                    ✕
                  </Button>
                </div>

                {form.watch('target_filters.constituencies')?.length > 0 && (
                  <div className="flex flex-wrap gap-1">
                    {form.watch('target_filters.constituencies')?.map((constituency, index) => (
                      <Badge key={index} variant="secondary" className="flex items-center gap-1 text-xs">
                        {constituency}
                        <Button
                          type="button"
                          variant="ghost"
                          size="sm"
                          onClick={() => {
                            const currentConstituencies = form.getValues('target_filters.constituencies') || [];
                            const filteredConstituencies = currentConstituencies.filter((_, i) => i !== index);
                            form.setValue('target_filters.constituencies', filteredConstituencies);
                          }}
                          className="h-3 w-3 p-0 hover:bg-destructive hover:text-destructive-foreground"
                        >
                          <Trash2 className="h-2 w-2" />
                        </Button>
                      </Badge>
                    ))}
                  </div>
                )}
              </div>

              {/* Gender & Age in same row */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {/* Gender Filter */}
                <div className="space-y-2">
                  <FormLabel>Gender ({form.watch('target_filters.gender')?.length || 0})</FormLabel>
                  <div className="flex gap-2">
                    {['Male', 'Female', 'Other'].map((gender) => (
                      <FormField
                        key={gender}
                        control={form.control}
                        name="target_filters.gender"
                        render={({ field }) => (
                          <FormItem className="flex flex-row items-start space-x-2 space-y-0">
                            <FormControl>
                              <Checkbox
                                checked={field.value?.includes(gender)}
                                onCheckedChange={(checked) => {
                                  const currentGenders = field.value || [];
                                  if (checked) {
                                    field.onChange([...currentGenders, gender]);
                                  } else {
                                    field.onChange(currentGenders.filter(g => g !== gender));
                                  }
                                }}
                              />
                            </FormControl>
                            <FormLabel className="text-sm font-normal cursor-pointer">
                              {gender}
                            </FormLabel>
                          </FormItem>
                        )}
                      />
                    ))}
                  </div>
                </div>

                {/* Age Range Filter */}
                <div className="space-y-2">
                  <FormLabel>Age Range</FormLabel>
                  <div className="flex gap-2 items-center">
                    <FormField
                      control={form.control}
                      name="target_filters.age_min"
                      render={({ field }) => (
                        <FormItem className="flex-1">
                          <FormControl>
                            <Input
                              type="number"
                              min="18"
                              max="100"
                              placeholder="Min"
                              value={field.value || ''}
                              onChange={(e) => field.onChange(e.target.value ? parseInt(e.target.value) : undefined)}
                            />
                          </FormControl>
                        </FormItem>
                      )}
                    />
                    <span className="text-sm text-muted-foreground">to</span>
                    <FormField
                      control={form.control}
                      name="target_filters.age_max"
                      render={({ field }) => (
                        <FormItem className="flex-1">
                          <FormControl>
                            <Input
                              type="number"
                              min="18"
                              max="100"
                              placeholder="Max"
                              value={field.value || ''}
                              onChange={(e) => field.onChange(e.target.value ? parseInt(e.target.value) : undefined)}
                            />
                          </FormControl>
                        </FormItem>
                      )}
                    />
                  </div>
                </div>
              </div>

              {/* Target Summary */}
              <div className="bg-muted/30 rounded p-3 border">
                <div className="flex items-center gap-2 text-sm">
                  <strong>Target:</strong>
                  {(form.watch('target_filters.states')?.length || 0) === 0 && 
                   (form.watch('target_filters.constituencies')?.length || 0) === 0 && 
                   (form.watch('target_filters.gender')?.length || 0) === 0 &&
                   !form.watch('target_filters.age_min') &&
                   !form.watch('target_filters.age_max') ? (
                    <span className="text-muted-foreground">All users</span>
                  ) : (
                    <div className="flex flex-wrap gap-1">
                      {form.watch('target_filters.states')?.length > 0 && (
                        <Badge variant="outline" className="text-xs">
                          {form.watch('target_filters.states').length} states
                        </Badge>
                      )}
                      {form.watch('target_filters.constituencies')?.length > 0 && (
                        <Badge variant="outline" className="text-xs">
                          {form.watch('target_filters.constituencies').length} constituencies
                        </Badge>
                      )}
                      {form.watch('target_filters.gender')?.length > 0 && (
                        <Badge variant="outline" className="text-xs">
                          {form.watch('target_filters.gender').join(', ')}
                        </Badge>
                      )}
                      {(form.watch('target_filters.age_min') || form.watch('target_filters.age_max')) && (
                        <Badge variant="outline" className="text-xs">
                          Age {form.watch('target_filters.age_min') || '18'}-{form.watch('target_filters.age_max') || '100'}
                        </Badge>
                      )}
                    </div>
                  )}
                </div>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Questions & Options</CardTitle>
              <CardDescription>
                {poll.is_active 
                  ? "Questions and options cannot be modified while the poll is active. Deactivate the poll to make changes."
                  : "Current poll questions and their options"
                }
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-6">
                {poll.questions.map((question, questionIndex) => (
                  <div key={question.id} className={cn(
                    "border rounded-lg p-4",
                    poll.is_active && "bg-muted/50"
                  )}>
                    <h4 className="font-medium mb-3 flex items-center gap-2">
                      Question {questionIndex + 1}: {question.question_text}
                      {poll.is_active && <AlertTriangle className="h-4 w-4 text-amber-500" />}
                    </h4>
                    <div className="space-y-2">
                      {question.options.map((option) => (
                        <div key={option.id} className="text-sm text-muted-foreground">
                          • {option.option_text}
                        </div>
                      ))}
                    </div>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>

          <div className="flex justify-end space-x-4">
            <Button type="button" variant="outline" onClick={() => router.back()}>
              Cancel
            </Button>
            <Button type="submit" disabled={isSubmitting}>
              {isSubmitting ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : <Save className="mr-2 h-4 w-4" />}
              Update Poll
            </Button>
          </div>
        </form>
      </Form>
    </div>
  );
}
