
'use client';

import { useEffect, useState } from 'react';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { PieChart, Pie, Cell, Tooltip, Legend, ResponsiveContainer } from 'recharts';
import { getPollResults, type PollResult } from '@/data/polls';
import { Loader2, X, Users, PieChart as PieChartIcon } from 'lucide-react';
import { ChartConfig, ChartContainer, ChartTooltipContent } from "@/components/ui/chart";

const GENDER_COLORS = { Male: '#3b82f6', Female: '#ec4899', Other: '#f97316', Unknown: '#6b7280' };
const OPTION_COLORS = ['#8884d8', '#82ca9d', '#ffc658', '#ff8042', '#0088FE', '#00C49F', '#FFBB28', '#FF8042'];

interface PollResultsProps {
  pollId: string;
  onClose: () => void;
}

export default function PollResults({ pollId, onClose }: PollResultsProps) {
  const [results, setResults] = useState<PollResult | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    if (pollId) {
      setIsLoading(true);
      const fetchResults = async () => {
        const data = await getPollResults(pollId);
        setResults(data);
        setIsLoading(false);
      };
      fetchResults();
    }
  }, [pollId]);

  if (isLoading) {
    return (
      <Card className="mt-6">
        <CardHeader><CardTitle>Loading Results...</CardTitle></CardHeader>
        <CardContent className="flex justify-center items-center h-64">
          <Loader2 className="h-12 w-12 animate-spin text-primary" />
        </CardContent>
      </Card>
    );
  }

  if (!results) {
    return (
      <Card className="mt-6">
        <CardHeader><CardTitle>Error</CardTitle></CardHeader>
        <CardContent><p>Could not load results for this poll.</p></CardContent>
      </Card>
    );
  }

  const genderChartConfig: ChartConfig = results.genderDistribution.reduce((acc, gender) => {
    acc[gender.name] = {
      label: gender.name,
      color: GENDER_COLORS[gender.name as keyof typeof GENDER_COLORS] || '#a8a29e',
    };
    return acc;
  }, {} as ChartConfig);
  

  return (
    <Card className="mt-6 animate-in fade-in-0" id="poll-results-section">
      <CardHeader className="flex flex-row justify-between items-start">
        <div>
          <CardTitle className="text-2xl font-headline">Results for: {results.pollTitle}</CardTitle>
          <CardDescription>A detailed analysis of user responses and demographics.</CardDescription>
        </div>
        <Button variant="ghost" size="icon" onClick={onClose}>
          <X className="h-5 w-5" />
          <span className="sr-only">Close results</span>
        </Button>
      </CardHeader>
      <CardContent className="space-y-8">
        {results.totalResponses > 0 ? (
          <>
            {/* Statistics Overview */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                <Card className="bg-gradient-to-br from-blue-50 to-blue-100 border-blue-200">
                    <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                        <CardTitle className="text-base font-medium">Total Responses</CardTitle>
                        <Users className="h-5 w-5 text-blue-600" />
                    </CardHeader>
                    <CardContent>
                        <div className="text-4xl font-bold text-blue-700">{results.totalResponses}</div>
                        <p className="text-xs text-blue-600">participants voted</p>
                    </CardContent>
                </Card>
                <Card className="bg-gradient-to-br from-green-50 to-green-100 border-green-200">
                    <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                        <CardTitle className="text-base font-medium">Questions</CardTitle>
                        <PieChartIcon className="h-5 w-5 text-green-600" />
                    </CardHeader>
                    <CardContent>
                        <div className="text-4xl font-bold text-green-700">{results.questions.length}</div>
                        <p className="text-xs text-green-600">total questions</p>
                    </CardContent>
                </Card>
                <Card className="bg-gradient-to-br from-purple-50 to-purple-100 border-purple-200">
                    <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                        <CardTitle className="text-base font-medium">Engagement Rate</CardTitle>
                        <PieChartIcon className="h-5 w-5 text-purple-600" />
                    </CardHeader>
                    <CardContent>
                        <div className="text-4xl font-bold text-purple-700">
                            {results.totalResponses > 0 ? '100%' : '0%'}
                        </div>
                        <p className="text-xs text-purple-600">completion rate</p>
                    </CardContent>
                </Card>
            </div>

            {/* Demographics Section */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                <Card className="bg-secondary/50">
                    <CardHeader>
                        <CardTitle className="text-lg font-medium flex items-center gap-2">
                            <PieChartIcon className="h-5 w-5" />
                            Gender Distribution
                        </CardTitle>
                    </CardHeader>
                    <CardContent>
                         <ChartContainer config={genderChartConfig} className="mx-auto aspect-square h-[200px]">
                            <ResponsiveContainer width="100%" height="100%">
                                <PieChart>
                                <Tooltip cursor={false} content={<ChartTooltipContent hideLabel />} />
                                <Pie data={results.genderDistribution} dataKey="value" nameKey="name" innerRadius={40} outerRadius={80}>
                                    {results.genderDistribution.map((entry) => (
                                        <Cell key={entry.name} fill={`var(--color-${entry.name})`} />
                                    ))}
                                </Pie>
                                <Legend />
                                </PieChart>
                            </ResponsiveContainer>
                        </ChartContainer>
                        <div className="mt-4 space-y-2">
                            {results.genderDistribution.map((item) => (
                                <div key={item.name} className="flex justify-between text-sm">
                                    <span>{item.name}</span>
                                    <span className="font-medium">{item.value} ({((item.value / results.totalResponses) * 100).toFixed(1)}%)</span>
                                </div>
                            ))}
                        </div>
                    </CardContent>
                </Card>
                
                <Card className="bg-secondary/50">
                    <CardHeader>
                        <CardTitle className="text-lg font-medium flex items-center gap-2">
                            <Users className="h-5 w-5" />
                            Response Summary
                        </CardTitle>
                    </CardHeader>
                    <CardContent>
                        <div className="space-y-4">
                            <div className="p-4 bg-background rounded-lg">
                                <h4 className="font-medium mb-2">Most Popular Answer</h4>
                                {results.questions.length > 0 && results.questions[0].answers.length > 0 && (
                                    <p className="text-sm text-muted-foreground">
                                        "{results.questions[0].answers.reduce((a, b) => a.value > b.value ? a : b).name}" 
                                        with {results.questions[0].answers.reduce((a, b) => a.value > b.value ? a : b).value} votes
                                    </p>
                                )}
                            </div>
                            <div className="p-4 bg-background rounded-lg">
                                <h4 className="font-medium mb-2">Participation Metrics</h4>
                                <div className="space-y-1 text-sm text-muted-foreground">
                                    <div className="flex justify-between">
                                        <span>Average responses per question:</span>
                                        <span className="font-medium">{results.totalResponses}</span>
                                    </div>
                                    <div className="flex justify-between">
                                        <span>Total unique participants:</span>
                                        <span className="font-medium">{results.totalResponses}</span>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </CardContent>
                </Card>
            </div>
            
            {/* Individual Question Results */}
            <div className="space-y-6">
                <h3 className="text-xl font-semibold">Question Results</h3>
                {results.questions.map((question, index) => {
                    const questionChartConfig = question.answers.reduce((acc, answer, i) => {
                        acc[answer.name] = { label: answer.name, color: OPTION_COLORS[i % OPTION_COLORS.length] };
                        return acc;
                    }, {} as ChartConfig);

                    const totalVotes = question.answers.reduce((sum, answer) => sum + answer.value, 0);
                    const winner = question.answers.reduce((a, b) => a.value > b.value ? a : b);

                    return (
                        <Card key={question.id} className="border-border/50">
                            <CardHeader>
                                <div className="flex justify-between items-start">
                                    <div>
                                        <CardTitle className="text-lg">Question {index + 1}</CardTitle>
                                        <p className="text-base mt-2 text-foreground">{question.text}</p>
                                    </div>
                                    <Badge variant="secondary" className="ml-4">
                                        {totalVotes} votes
                                    </Badge>
                                </div>
                            </CardHeader>
                            <CardContent>
                                <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                                    {/* Chart */}
                                    <div>
                                        <ChartContainer config={questionChartConfig} className="mx-auto aspect-square h-[300px]">
                                            <ResponsiveContainer width="100%" height="100%">
                                                <PieChart>
                                                <Tooltip cursor={false} content={<ChartTooltipContent indicator="dot" />} />
                                                <Pie 
                                                    data={question.answers} 
                                                    dataKey="value" 
                                                    nameKey="name" 
                                                    outerRadius={100}
                                                    innerRadius={40}
                                                    paddingAngle={2}
                                                >
                                                    {question.answers.map((entry, i) => (
                                                    <Cell 
                                                        key={entry.name} 
                                                        fill={`var(--color-${entry.name})`}
                                                        stroke={entry.name === winner.name ? "#000" : "none"}
                                                        strokeWidth={entry.name === winner.name ? 2 : 0}
                                                    />
                                                    ))}
                                                </Pie>
                                                <Legend />
                                                </PieChart>
                                            </ResponsiveContainer>
                                        </ChartContainer>
                                    </div>
                                    
                                    {/* Detailed Results */}
                                    <div className="space-y-4">
                                        <div className="bg-primary/5 p-4 rounded-lg border border-primary/20">
                                            <h4 className="font-semibold text-primary mb-2">📊 Winning Option</h4>
                                            <p className="text-lg font-medium">{winner.name}</p>
                                            <p className="text-sm text-muted-foreground">
                                                {winner.value} votes ({((winner.value / totalVotes) * 100).toFixed(1)}%)
                                            </p>
                                        </div>
                                        
                                        <div className="space-y-3">
                                            <h4 className="font-semibold">All Options</h4>
                                            {question.answers
                                                .sort((a, b) => b.value - a.value)
                                                .map((answer, i) => (
                                                <div key={answer.name} className="flex items-center justify-between p-3 bg-background rounded border">
                                                    <div className="flex items-center gap-3">
                                                        <div 
                                                            className="w-4 h-4 rounded-full"
                                                            style={{ backgroundColor: OPTION_COLORS[question.answers.findIndex(a => a.name === answer.name) % OPTION_COLORS.length] }}
                                                        />
                                                        <span className={`${i === 0 ? 'font-semibold' : ''}`}>
                                                            {answer.name}
                                                        </span>
                                                        {i === 0 && <Badge variant="secondary" className="text-xs">Winner</Badge>}
                                                    </div>
                                                    <div className="text-right">
                                                        <div className="font-medium">{answer.value}</div>
                                                        <div className="text-xs text-muted-foreground">
                                                            {((answer.value / totalVotes) * 100).toFixed(1)}%
                                                        </div>
                                                    </div>
                                                </div>
                                            ))}
                                        </div>
                                    </div>
                                </div>
                            </CardContent>
                        </Card>
                    )
                })}
            </div>
          </>
        ) : (
          <div className="text-center py-16">
            <p className="text-muted-foreground">There are no responses for this poll yet.</p>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
