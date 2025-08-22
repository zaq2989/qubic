// SPDX-License-Identifier: MIT
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';
import { Job } from '@/api/client';

interface Props {
  jobs: Job[];
}

export default function MetricsChart({ jobs }: Props) {
  // Group jobs by time window (5 minute buckets)
  const getChartData = () => {
    const completedJobs = jobs.filter(job => job.status === 'COMPLETED' && job.completed_at);
    
    if (completedJobs.length === 0) {
      return [];
    }

    // Sort by completion time
    completedJobs.sort((a, b) => (a.completed_at || 0) - (b.completed_at || 0));

    // Create time buckets
    const buckets = new Map<string, { time: string, attacks: number, defenses: number, attackSuccess: number, defenseSuccess: number }>();
    
    completedJobs.forEach(job => {
      const timestamp = new Date((job.completed_at || 0) * 1000);
      const bucketTime = new Date(Math.floor(timestamp.getTime() / (5 * 60 * 1000)) * (5 * 60 * 1000));
      const bucketKey = bucketTime.toLocaleTimeString();

      if (!buckets.has(bucketKey)) {
        buckets.set(bucketKey, {
          time: bucketKey,
          attacks: 0,
          defenses: 0,
          attackSuccess: 0,
          defenseSuccess: 0,
        });
      }

      const bucket = buckets.get(bucketKey)!;
      
      if (job.spec.job_type === 'ATTACK') {
        bucket.attacks++;
        // Simplified success detection for PoC
        if (job.result && job.result.hash.startsWith('1')) {
          bucket.attackSuccess++;
        }
      } else {
        bucket.defenses++;
        if (job.result && job.result.hash.startsWith('1')) {
          bucket.defenseSuccess++;
        }
      }
    });

    return Array.from(buckets.values()).map(bucket => ({
      ...bucket,
      attackSuccessRate: bucket.attacks > 0 ? (bucket.attackSuccess / bucket.attacks * 100) : 0,
      defenseSuccessRate: bucket.defenses > 0 ? (bucket.defenseSuccess / bucket.defenses * 100) : 0,
    }));
  };

  const data = getChartData();

  if (data.length === 0) {
    return (
      <div className="bg-white p-6 rounded-lg shadow">
        <h3 className="text-lg font-medium text-gray-900 mb-4">Performance Metrics</h3>
        <div className="text-gray-500 text-center py-8">
          No completed jobs yet. Metrics will appear once jobs are completed.
        </div>
      </div>
    );
  }

  return (
    <div className="bg-white p-6 rounded-lg shadow">
      <h3 className="text-lg font-medium text-gray-900 mb-4">Performance Metrics</h3>
      <div className="h-80">
        <ResponsiveContainer width="100%" height="100%">
          <LineChart data={data} margin={{ top: 5, right: 30, left: 20, bottom: 5 }}>
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis dataKey="time" />
            <YAxis />
            <Tooltip />
            <Legend />
            <Line 
              type="monotone" 
              dataKey="attackSuccessRate" 
              stroke="#f97316" 
              name="Attack Success Rate (%)"
              strokeWidth={2}
            />
            <Line 
              type="monotone" 
              dataKey="defenseSuccessRate" 
              stroke="#a855f7" 
              name="Defense Detection Rate (%)"
              strokeWidth={2}
            />
            <Line 
              type="monotone" 
              dataKey="attacks" 
              stroke="#fb923c" 
              name="Attack Jobs"
              strokeDasharray="5 5"
            />
            <Line 
              type="monotone" 
              dataKey="defenses" 
              stroke="#c084fc" 
              name="Defense Jobs"
              strokeDasharray="5 5"
            />
          </LineChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}