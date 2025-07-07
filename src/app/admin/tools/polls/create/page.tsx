
'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { useForm, useFieldArray } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import * as z from 'zod';
import { format } from 'date-fns';

import { createPoll, type CreatePollData, type PollQuestionType } from '@/data/polls';
import { indianStates, districtsByState } from '@/data/locations';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Form, FormControl, FormDescription, FormField, FormItem, FormLabel, FormMessage } from '@/components/ui/form';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { Switch } from '@/components/ui/switch';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Calendar } from '@/components/ui/calendar';
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover';
import { useToast } from '@/hooks/use-toast';
import { cn } from '@/lib/utils';
import { ChevronLeft, CalendarIcon, Plus, Trash2, Loader2, Save, Users } from 'lucide-react';
import { Separator } from '@/components/ui/separator';
import { Checkbox } from '@/components/ui/checkbox';
import { Badge } from '@/components/ui/badge';

const questionSchema = z.object({
  question_text: z.string().min(1, 'Question text is required'),
  question_type: z.enum(['yes_no', 'multiple_choice']),
  options: z.array(z.string().min(1, 'Option text is required')).min(2, 'At least 2 options required'),
});

const pollSchema = z.object({
  title: z.string().min(1, 'Poll title is required'),
  description: z.string().optional(),
  is_active: z.boolean(),
  active_until: z.date().optional(),
  target_filters: z.object({
    states: z.array(z.string()).optional(),
    constituencies: z.array(z.string()).optional(),
    gender: z.array(z.string()).optional(),
    age_min: z.number().min(18).max(100).optional(),
    age_max: z.number().min(18).max(100).optional(),
  }).optional(),
  questions: z.array(questionSchema).min(1, 'At least one question is required'),
});

type PollFormData = z.infer<typeof pollSchema>;

export default function CreatePollPage() {
  const router = useRouter();
  const { toast } = useToast();
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [constituencyInput, setConstituencyInput] = useState('');

  const form = useForm<PollFormData>({
    resolver: zodResolver(pollSchema),
    defaultValues: {
      title: '',
      description: '',
      is_active: true,
      target_filters: {
        states: [],
        constituencies: [],
        gender: [],
      },
      questions: [
        {
          question_text: '',
          question_type: 'multiple_choice',
          options: ['', ''],
        },
      ],
    },
  });

  const { fields: questions, append: addQuestion, remove: removeQuestion } = useFieldArray({
    control: form.control,
    name: 'questions',
  });

  const addOption = (questionIndex: number) => {
    const currentOptions = form.getValues(`questions.${questionIndex}.options`);
    form.setValue(`questions.${questionIndex}.options`, [...currentOptions, '']);
  };

  const removeOption = (questionIndex: number, optionIndex: number) => {
    const currentOptions = form.getValues(`questions.${questionIndex}.options`);
    if (currentOptions.length > 2) {
      const newOptions = currentOptions.filter((_, index) => index !== optionIndex);
      form.setValue(`questions.${questionIndex}.options`, newOptions);
    }
  };

  const onQuestionTypeChange = (questionIndex: number, type: PollQuestionType) => {
    if (type === 'yes_no') {
      form.setValue(`questions.${questionIndex}.options`, ['Yes', 'No']);
    } else {
      form.setValue(`questions.${questionIndex}.options`, ['', '']);
    }
  };

  const onSubmit = async (data: PollFormData) => {
    setIsSubmitting(true);
    try {
      const pollData: CreatePollData = {
        title: data.title,
        description: data.description || undefined,
        is_active: data.is_active,
        active_until: data.active_until?.toISOString(),
        target_filters: data.target_filters && (
          data.target_filters.states?.length || 
          data.target_filters.constituencies?.length || 
          data.target_filters.gender?.length ||
          data.target_filters.age_min ||
          data.target_filters.age_max
        ) ? data.target_filters : undefined,
        questions: data.questions.map(q => ({
          question_text: q.question_text,
          question_type: q.question_type,
          options: q.options.filter(option => option.trim() !== ''),
        })),
      };

      await createPoll(pollData);
      toast({ title: 'Poll Created', description: 'The poll has been created successfully.' });
      router.push('/admin/tools/polls');
    } catch (error) {
      toast({
        variant: 'destructive',
        title: 'Error',
        description: error instanceof Error ? error.message : 'Failed to create poll',
      });
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h1 className="text-3xl font-bold font-headline">Create New Poll</h1>
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
              <CardDescription>Configure the basic settings for your poll.</CardDescription>
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
                        <FormDescription>Make this poll available for voting immediately</FormDescription>
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
                    <Plus className="h-4 w-4" />
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

              {/* Compact Summary */}
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
            <CardHeader className="flex flex-row items-center justify-between">
              <div>
                <CardTitle>Poll Questions</CardTitle>
                <CardDescription>Create questions and options for your poll.</CardDescription>
              </div>
              <Button
                type="button"
                variant="outline"
                onClick={() =>
                  addQuestion({
                    question_text: '',
                    question_type: 'multiple_choice',
                    options: ['', ''],
                  })
                }
              >
                <Plus className="mr-2 h-4 w-4" />
                Add Question
              </Button>
            </CardHeader>
            <CardContent className="space-y-6">
              {questions.map((question, questionIndex) => (
                <div key={question.id} className="space-y-4 p-4 border rounded-lg">
                  <div className="flex items-center justify-between">
                    <h4 className="text-lg font-medium">Question {questionIndex + 1}</h4>
                    {questions.length > 1 && (
                      <Button
                        type="button"
                        variant="ghost"
                        size="icon"
                        onClick={() => removeQuestion(questionIndex)}
                        className="text-destructive hover:text-destructive"
                      >
                        <Trash2 className="h-4 w-4" />
                      </Button>
                    )}
                  </div>

                  <FormField
                    control={form.control}
                    name={`questions.${questionIndex}.question_text`}
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel>Question Text</FormLabel>
                        <FormControl>
                          <Input {...field} placeholder="Enter your question..." />
                        </FormControl>
                        <FormMessage />
                      </FormItem>
                    )}
                  />

                  <FormField
                    control={form.control}
                    name={`questions.${questionIndex}.question_type`}
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel>Question Type</FormLabel>
                        <Select
                          value={field.value}
                          onValueChange={(value) => {
                            field.onChange(value);
                            onQuestionTypeChange(questionIndex, value as PollQuestionType);
                          }}
                        >
                          <FormControl>
                            <SelectTrigger>
                              <SelectValue />
                            </SelectTrigger>
                          </FormControl>
                          <SelectContent>
                            <SelectItem value="multiple_choice">Multiple Choice</SelectItem>
                            <SelectItem value="yes_no">Yes/No</SelectItem>
                          </SelectContent>
                        </Select>
                        <FormMessage />
                      </FormItem>
                    )}
                  />

                  <div className="space-y-2">
                    <div className="flex items-center justify-between">
                      <FormLabel>Options</FormLabel>
                      {form.watch(`questions.${questionIndex}.question_type`) === 'multiple_choice' && (
                        <Button
                          type="button"
                          variant="outline"
                          size="sm"
                          onClick={() => addOption(questionIndex)}
                        >
                          <Plus className="mr-1 h-3 w-3" />
                          Add Option
                        </Button>
                      )}
                    </div>
                    {form.watch(`questions.${questionIndex}.options`)?.map((_, optionIndex) => (
                      <FormField
                        key={optionIndex}
                        control={form.control}
                        name={`questions.${questionIndex}.options.${optionIndex}`}
                        render={({ field }) => (
                          <FormItem>
                            <div className="flex items-center space-x-2">
                              <FormControl>
                                <Input
                                  {...field}
                                  placeholder={`Option ${optionIndex + 1}`}
                                  disabled={form.watch(`questions.${questionIndex}.question_type`) === 'yes_no'}
                                />
                              </FormControl>
                              {form.watch(`questions.${questionIndex}.question_type`) === 'multiple_choice' &&
                                form.watch(`questions.${questionIndex}.options`).length > 2 && (
                                  <Button
                                    type="button"
                                    variant="ghost"
                                    size="icon"
                                    onClick={() => removeOption(questionIndex, optionIndex)}
                                    className="text-destructive hover:text-destructive"
                                  >
                                    <Trash2 className="h-3 w-3" />
                                  </Button>
                                )}
                            </div>
                            <FormMessage />
                          </FormItem>
                        )}
                      />
                    ))}
                  </div>
                </div>
              ))}
            </CardContent>
          </Card>

          <div className="flex justify-end space-x-4">
            <Button type="button" variant="outline" onClick={() => router.back()}>
              Cancel
            </Button>
            <Button type="submit" disabled={isSubmitting}>
              {isSubmitting ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : <Save className="mr-2 h-4 w-4" />}
              Create Poll
            </Button>
          </div>
        </form>
      </Form>
    </div>
  );
}
