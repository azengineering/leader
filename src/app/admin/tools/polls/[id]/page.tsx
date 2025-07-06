
'use client';

import { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { useForm, useFieldArray, useFormContext } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import * as z from 'zod';
import { format } from 'date-fns';
import { cn } from '@/lib/utils';
import { getPollForEdit, upsertPoll, type Poll, type PollQuestion, type PollOption } from '@/data/polls';
import { useToast } from '@/hooks/use-toast';
import {
  Form, FormControl, FormDescription, FormField, FormItem, FormLabel, FormMessage,
} from '@/components/ui/form';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Textarea } from '@/components/ui/textarea';
import { Card, CardContent, CardHeader, CardTitle, CardDescription, CardFooter } from '@/components/ui/card';
import { Switch } from '@/components/ui/switch';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover';
import { Calendar } from '@/components/ui/calendar';
import { Label } from '@/components/ui/label';
import { PlusCircle, Trash2, ChevronLeft, Loader2, Save, CalendarIcon } from 'lucide-react';

const optionSchema = z.object({
  id: z.string().optional(),
  option_text: z.string().min(1, 'Option text cannot be empty.'),
});

const questionSchema = z.object({
  id: z.string().optional(),
  question_text: z.string().min(1, 'Question text cannot be empty.'),
  question_type: z.enum(['yes_no', 'multiple_choice']),
  options: z.array(optionSchema),
}).refine(data => {
    if (data.question_type === 'multiple_choice') {
        return data.options.length >= 2;
    }
    return true;
}, {
    message: 'Multiple choice questions must have at least 2 options.',
    path: ['options'],
});

const pollFormSchema = z.object({
  title: z.string().min(3, 'Title must be at least 3 characters.'),
  description: z.string().optional(),
  is_active: z.boolean(),
  active_until: z.date().optional(),
  questions: z.array(questionSchema).min(1, 'A poll must have at least one question.'),
});

type PollFormData = z.infer<typeof pollFormSchema>;


function OptionsArray({ qIndex }: { qIndex: number }) {
  const { control } = useFormContext<PollFormData>();
  const { fields, append, remove } = useFieldArray({
    control,
    name: `questions.${qIndex}.options`,
  });

  return (
    <div className="space-y-2 pl-4 border-l-2">
      <Label>Options</Label>
      {fields.map((option, oIndex) => (
        <div key={option.id} className="flex items-center gap-2">
            <FormField
              control={control}
              name={`questions.${qIndex}.options.${oIndex}.option_text`}
              render={({ field }) => (
                <FormItem className="flex-grow">
                  <FormControl>
                    <Input {...field} placeholder={`Option ${oIndex + 1}`} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            <Button type="button" variant="ghost" size="icon" onClick={() => remove(oIndex)} disabled={fields.length <= 2}>
                <Trash2 className="h-4 w-4" />
            </Button>
        </div>
      ))}
      <Button type="button" size="sm" variant="ghost" onClick={() => append({ option_text: '' })}>
        <PlusCircle className="mr-2 h-4 w-4"/>Add Option
      </Button>
    </div>
  );
}


export default function PollEditorPage() {
  const router = useRouter();
  const params = useParams();
  const { toast } = useToast();

  const pollId = Array.isArray(params.id) ? params.id[0] : params.id;
  const isEditMode = pollId !== 'create';

  const [isLoading, setIsLoading] = useState(isEditMode);
  const [isSaving, setIsSaving] = useState(false);

  const form = useForm<PollFormData>({
    resolver: zodResolver(pollFormSchema),
    defaultValues: {
      title: '',
      description: '',
      is_active: false,
      active_until: undefined,
      questions: [],
    },
  });

  const { fields, append, remove } = useFieldArray({
    control: form.control,
    name: 'questions',
  });

  useEffect(() => {
    if (isEditMode) {
      const fetchPoll = async () => {
        const pollData = await getPollForEdit(pollId);
        if (pollData) {
          form.reset({
            ...pollData,
            description: pollData.description || '',
            active_until: pollData.active_until ? new Date(pollData.active_until) : undefined,
          });
        } else {
          toast({ variant: 'destructive', title: 'Poll not found' });
          router.push('/admin/tools/polls');
        }
        setIsLoading(false);
      };
      fetchPoll();
    }
  }, [isEditMode, pollId, form, router, toast]);

  const addQuestion = () => {
    append({
      question_text: '',
      question_type: 'multiple_choice',
      options: [{ option_text: '' }, { option_text: '' }],
    });
  };

  const onSubmit = async (data: PollFormData) => {
    setIsSaving(true);
    try {
        const pollPayload: Omit<Poll, 'created_at'> = {
            id: isEditMode ? pollId : '',
            title: data.title,
            description: data.description || null,
            is_active: data.is_active,
            active_until: data.active_until ? data.active_until.toISOString() : null,
            questions: data.questions.map((q, qIndex) => ({
                id: q.id || '',
                poll_id: isEditMode ? pollId : '',
                question_text: q.question_text,
                question_type: q.question_type,
                question_order: qIndex,
                options: q.question_type === 'yes_no' 
                    ? [
                        { id: '', question_id: '', option_text: 'Yes', option_order: 0 },
                        { id: '', question_id: '', option_text: 'No', option_order: 1 },
                      ]
                    : q.options.map((o, oIndex) => ({
                        id: o.id || '',
                        question_id: q.id || '',
                        option_text: o.option_text,
                        option_order: oIndex,
                    })),
            })),
        };
      
      await upsertPoll(pollPayload);
      toast({ title: isEditMode ? 'Poll Updated' : 'Poll Created', description: 'Your poll has been saved successfully.' });
      router.push('/admin/tools/polls');
    } catch (error) {
        console.error(error);
        toast({ variant: 'destructive', title: 'Save Failed', description: 'An error occurred while saving the poll.' });
    } finally {
        setIsSaving(false);
    }
  };

  if (isLoading) {
    return <div>Loading...</div>;
  }

  return (
    <div className="space-y-6">
        <div className="flex justify-between items-center">
            <h1 className="text-3xl font-bold font-headline">{isEditMode ? 'Edit Poll' : 'Create New Poll'}</h1>
            <Button variant="outline" onClick={() => router.push('/admin/tools/polls')}>
                <ChevronLeft className="mr-2 h-4 w-4" />
                Back to Polls
            </Button>
        </div>
      <Form {...form}>
        <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-8">
          <Card>
            <CardHeader>
              <CardTitle>Poll Details</CardTitle>
              <CardDescription>Set the main title, description, and status for this poll.</CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
                <FormField control={form.control} name="title" render={({ field }) => (<FormItem><FormLabel>Title</FormLabel><FormControl><Input {...field} placeholder="e.g., Public Opinion on New Highway Project" /></FormControl><FormMessage /></FormItem>)} />
                <FormField control={form.control} name="description" render={({ field }) => (<FormItem><FormLabel>Description (Optional)</FormLabel><FormControl><Textarea {...field} placeholder="Provide some context or details about this poll..." /></FormControl><FormMessage /></FormItem>)} />
                <div className="flex items-start gap-8">
                    <FormField control={form.control} name="is_active" render={({ field }) => (<FormItem className="flex flex-row items-center justify-between rounded-lg border p-3"><div className="space-y-0.5 mr-4"><FormLabel>Activate Poll</FormLabel><FormDescription>Make this poll visible to users.</FormDescription></div><FormControl><Switch checked={field.value} onCheckedChange={field.onChange} /></FormControl></FormItem>)}/>
                    <FormField control={form.control} name="active_until" render={({ field }) => (
                    <FormItem className="flex flex-col"><FormLabel>Active Until (Optional)</FormLabel>
                        <Popover><PopoverTrigger asChild><FormControl>
                            <Button variant="outline" className={cn('w-[240px] pl-3 text-left font-normal',!field.value && 'text-muted-foreground')}>
                                {field.value ? format(field.value, 'PPP') : <span>Pick a date</span>}
                                <CalendarIcon className="ml-auto h-4 w-4 opacity-50" />
                            </Button>
                        </FormControl></PopoverTrigger>
                        <PopoverContent className="w-auto p-0" align="start"><Calendar mode="single" selected={field.value} onSelect={field.onChange} initialFocus/></PopoverContent>
                        </Popover><FormMessage/>
                    </FormItem>)}/>
                </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
                <CardTitle>Questions</CardTitle>
                <CardDescription>Add the questions for your poll.</CardDescription>
            </CardHeader>
            <CardContent className="space-y-6">
                {fields.map((question, qIndex) => (
                    <div key={question.id} className="p-4 border rounded-lg space-y-4 bg-secondary/50">
                        <div className="flex justify-between items-center">
                            <Label className="text-base font-semibold">Question {qIndex + 1}</Label>
                            <Button type="button" variant="ghost" size="icon" onClick={() => remove(qIndex)}><Trash2 className="h-4 w-4 text-destructive" /></Button>
                        </div>
                        <FormField control={form.control} name={`questions.${qIndex}.question_text`} render={({ field }) => (<FormItem><FormLabel>Question Text</FormLabel><FormControl><Input {...field} placeholder="Enter the question..." /></FormControl><FormMessage /></FormItem>)}/>
                        <FormField
                          control={form.control}
                          name={`questions.${qIndex}.question_type`}
                          render={({ field }) => (
                              <FormItem><FormLabel>Question Type</FormLabel>
                                  <Select
                                      onValueChange={(value) => {
                                          field.onChange(value);
                                          // When switching to yes/no, clear the options array to prevent validation errors on stale data
                                          if (value === 'yes_no') {
                                              form.setValue(`questions.${qIndex}.options`, []);
                                          }
                                      }}
                                      defaultValue={field.value}
                                  >
                                      <FormControl><SelectTrigger><SelectValue /></SelectTrigger></FormControl>
                                      <SelectContent>
                                          <SelectItem value="multiple_choice">Multiple Choice</SelectItem>
                                          <SelectItem value="yes_no">Yes / No</SelectItem>
                                      </SelectContent>
                                  </Select>
                              <FormMessage /></FormItem>
                          )}
                        />
                        {form.watch(`questions.${qIndex}.question_type`) === 'multiple_choice' && (
                           <OptionsArray qIndex={qIndex} />
                        )}
                        <FormMessage>{form.formState.errors.questions?.[qIndex]?.options?.message}</FormMessage>
                    </div>
                ))}
                <Button type="button" variant="outline" onClick={addQuestion}><PlusCircle className="mr-2 h-4 w-4" />Add Question</Button>
                <FormMessage>{form.formState.errors.questions?.root?.message || form.formState.errors.questions?.message}</FormMessage>
            </CardContent>
             <CardFooter className="flex justify-end">
                <Button type="submit" disabled={isSaving}>
                    {isSaving ? <Loader2 className="animate-spin mr-2" /> : <Save className="mr-2" />}
                    {isEditMode ? 'Save Changes' : 'Create Poll'}
                </Button>
            </CardFooter>
          </Card>
        </form>
      </Form>
    </div>
  );
}
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
  title: z.string().min(1, 'Poll title is required'),
  description: z.string().optional(),
  is_active: z.boolean(),
  active_until: z.date().optional(),
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
      is_active: true,
    },
  });

  useEffect(() => {
    const fetchPoll = async () => {
      if (!params.id || typeof params.id !== 'string') {
        toast({ variant: 'destructive', title: 'Error', description: 'Invalid poll ID' });
        router.push('/admin/tools/polls');
        return;
      }

      try {
        const pollData = await getPollById(params.id);
        if (!pollData) {
          toast({ variant: 'destructive', title: 'Error', description: 'Poll not found' });
          router.push('/admin/tools/polls');
          return;
        }

        setPoll(pollData);
        form.reset({
          title: pollData.title,
          description: pollData.description || '',
          is_active: pollData.is_active,
          active_until: pollData.active_until ? new Date(pollData.active_until) : undefined,
        });
      } catch (error) {
        toast({
          variant: 'destructive',
          title: 'Error',
          description: error instanceof Error ? error.message : 'Failed to fetch poll',
        });
        router.push('/admin/tools/polls');
      } finally {
        setIsLoading(false);
      }
    };

    fetchPoll();
  }, [params.id, form, router, toast]);

  const onSubmit = async (data: EditPollFormData) => {
    if (!poll) return;

    setIsSubmitting(true);
    try {
      await updatePoll(poll.id, {
        title: data.title,
        description: data.description,
        is_active: data.is_active,
        active_until: data.active_until?.toISOString(),
      });

      toast({ title: 'Poll Updated', description: 'The poll has been updated successfully.' });
      router.push('/admin/tools/polls');
    } catch (error) {
      toast({
        variant: 'destructive',
        title: 'Error',
        description: error instanceof Error ? error.message : 'Failed to update poll',
      });
    } finally {
      setIsSubmitting(false);
    }
  };

  if (isLoading) {
    return (
      <div className="space-y-6">
        <div className="flex justify-between items-center">
          <Skeleton className="h-8 w-64" />
          <Skeleton className="h-10 w-20" />
        </div>
        <Card>
          <CardHeader>
            <Skeleton className="h-6 w-32" />
            <Skeleton className="h-4 w-48" />
          </CardHeader>
          <CardContent className="space-y-6">
            <Skeleton className="h-10 w-full" />
            <Skeleton className="h-24 w-full" />
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <Skeleton className="h-16 w-full" />
              <Skeleton className="h-16 w-full" />
            </div>
          </CardContent>
        </Card>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h1 className="text-3xl font-bold font-headline">Edit Poll</h1>
        <Button variant="outline" onClick={() => router.back()}>
          <ChevronLeft className="mr-2 h-4 w-4" />
          Back
        </Button>
      </div>

      <Form {...form}>
        <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-6">
          <Card>
            <CardHeader>
              <CardTitle>Poll Details</CardTitle>
              <CardDescription>Update the basic settings for your poll.</CardDescription>
            </CardHeader>
            <CardContent className="space-y-6">
              <FormField
                control={form.control}
                name="title"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Poll Title</FormLabel>
                    <FormControl>
                      <Input {...field} placeholder="Enter poll title..." />
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
                    <FormLabel>Description (Optional)</FormLabel>
                    <FormControl>
                      <Textarea {...field} placeholder="Enter poll description..." rows={3} />
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
                        <FormLabel className="text-base">Active Poll</FormLabel>
                        <FormDescription>Make this poll available for voting</FormDescription>
                      </div>
                      <FormControl>
                        <Switch checked={field.value} onCheckedChange={field.onChange} />
                      </FormControl>
                    </FormItem>
                  )}
                />

                <FormField
                  control={form.control}
                  name="active_until"
                  render={({ field }) => (
                    <FormItem className="flex flex-col">
                      <FormLabel>Active Until (Optional)</FormLabel>
                      <Popover>
                        <PopoverTrigger asChild>
                          <FormControl>
                            <Button
                              variant="outline"
                              className={cn(
                                'w-full pl-3 text-left font-normal',
                                !field.value && 'text-muted-foreground'
                              )}
                            >
                              {field.value ? format(field.value, 'PPP') : <span>Pick a date</span>}
                              <CalendarIcon className="ml-auto h-4 w-4 opacity-50" />
                            </Button>
                          </FormControl>
                        </PopoverTrigger>
                        <PopoverContent className="w-auto p-0" align="start">
                          <Calendar
                            mode="single"
                            selected={field.value}
                            onSelect={field.onChange}
                            disabled={(date) => date < new Date()}
                            initialFocus
                          />
                        </PopoverContent>
                      </Popover>
                      <FormDescription>Leave empty for no expiration date</FormDescription>
                      <FormMessage />
                    </FormItem>
                  )}
                />
              </div>
            </CardContent>
          </Card>

          {poll && (
            <Card>
              <CardHeader>
                <CardTitle>Poll Questions</CardTitle>
                <CardDescription>Questions cannot be modified after poll creation to maintain data integrity.</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="space-y-4">
                  {poll.questions.map((question, index) => (
                    <div key={question.id} className="p-4 border rounded-lg bg-muted/50">
                      <h4 className="font-medium mb-2">Question {index + 1}: {question.question_text}</h4>
                      <div className="space-y-1">
                        {question.options.map((option, optionIndex) => (
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
