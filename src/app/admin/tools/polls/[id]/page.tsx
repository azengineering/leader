'use client';

import { useState, useEffect } from 'react';
import { useRouter, useParams } from 'next/navigation';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import * as z from 'zod';
import { format } from 'date-fns';

import { getPollById, updatePoll, type Poll } from '@/data/polls';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Form, FormControl, FormDescription, FormField, FormItem, FormLabel, FormMessage } from '@/components/ui/form';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { Switch } from '@/components/ui/switch';
import { Calendar } from '@/components/ui/calendar';
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover';
import { useToast } from '@/hooks/use-toast';
import { cn } from '@/lib/utils';
import { ChevronLeft, CalendarIcon, Loader2, Save } from 'lucide-react';
import { Skeleton } from '@/components/ui/skeleton';

const editPollSchema = z.object({
  title: z.string().min(1, { message: "Title is required." }),
  description: z.string().min(1, { message: "Description is required." }),
  isActive: z.boolean().default(true),
  endDate: z.date({
    required_error: "End date is required.",
  }),
  questions: z.array(z.object({
    id: z.string(),
    questionText: z.string().min(1, { message: "Question text is required." }),
    options: z.array(z.object({
      id: z.string(),
      optionText: z.string().min(1, { message: "Option text is required." }),
    })).min(2, { message: "At least 2 options are required." }),
  })).min(1, { message: "At least 1 question is required." }),
});

type EditPollFormData = z.infer<typeof editPollSchema>;

export default function EditPollPage() {
  const router = useRouter();
  const params = useParams();
  const { toast } = useToast();
  const [poll, setPoll] = useState<Poll | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const form = useForm<EditPollFormData>({
    resolver: zodResolver(editPollSchema),
    defaultValues: {
      title: '',
      description: '',
      isActive: true,
      endDate: new Date(),
      questions: [],
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
            description: pollData.description,
            isActive: pollData.is_active,
            endDate: pollData.active_until ? new Date(pollData.active_until) : new Date(),
            questions: pollData.questions.map(q => ({
              id: q.id,
              questionText: q.question_text,
              options: q.options.map(o => ({
                id: o.id,
                optionText: o.option_text,
              })),
            })),
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
        is_active: data.isActive,
        active_until: data.endDate.toISOString(),
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

              <FormField
                control={form.control}
                name="isActive"
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
                name="endDate"
                render={({ field }) => (
                  <FormItem className="flex flex-col">
                    <FormLabel>End Date</FormLabel>
                    <Popover>
                      <PopoverTrigger asChild>
                        <FormControl>
                          <Button
                            variant={"outline"}
                            className={cn(
                              "w-[240px] pl-3 text-left font-normal",
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
            </CardContent>
          </Card>

          {poll && (
            <Card>
              <CardHeader>
                <CardTitle>Questions & Options</CardTitle>
                <CardDescription>Current poll questions and their options</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="space-y-6">
                  {poll.questions.map((question, questionIndex) => (
                    <div key={question.id} className="border rounded-lg p-4">
                      <h4 className="font-medium mb-3">
                        Question {questionIndex + 1}: {question.questionText}
                      </h4>
                      <div className="space-y-2">
                        {question.options.map((option) => (
                          <div key={option.id} className="text-sm text-muted-foreground">
                            • {option.optionText}
                          </div>
                        ))}
                      </div>
                    </div>
                  ))}
                </div>
              </CardContent>
            </Card>
          )}

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