// SPDX-License-Identifier: MIT
import { useEffect, useState } from 'react';
import { apiClient, RoundSummary, Job, Worker } from '@/api/client';
import RoundOverview from '@/components/RoundOverview';
import JobsList from '@/components/JobsList';
import WorkersList from '@/components/WorkersList';
import MetricsChart from '@/components/MetricsChart';

export default function Dashboard() {
  const [currentRound, setCurrentRound] = useState<RoundSummary | null>(null);
  const [jobs, setJobs] = useState<Job[]>([]);
  const [workers, setWorkers] = useState<Worker[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState<'overview' | 'jobs' | 'workers'>('overview');

  useEffect(() => {
    fetchData();
    const interval = setInterval(fetchData, 5000); // Refresh every 5 seconds
    return () => clearInterval(interval);
  }, []);

  const fetchData = async () => {
    try {
      // For PoC, assume round 1
      const [roundData, jobsData, workersData] = await Promise.all([
        apiClient.getRoundSummary(1),
        apiClient.listJobs('1'),
        apiClient.listWorkers(),
      ]);

      setCurrentRound(roundData);
      setJobs(jobsData);
      setWorkers(workersData);
      setError(null);
    } catch (err) {
      setError('Failed to fetch data');
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-100 flex items-center justify-center">
        <div className="text-lg">Loading...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="min-h-screen bg-gray-100 flex items-center justify-center">
        <div className="text-lg text-red-600">{error}</div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-100">
      <div className="py-6">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <h1 className="text-3xl font-bold text-gray-900">Qubic Wargame Grid Dashboard</h1>
        </div>
      </div>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Tab Navigation */}
        <div className="border-b border-gray-200">
          <nav className="-mb-px flex space-x-8">
            <button
              onClick={() => setActiveTab('overview')}
              className={`py-2 px-1 border-b-2 font-medium text-sm ${
                activeTab === 'overview'
                  ? 'border-indigo-500 text-indigo-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              }`}
            >
              Overview
            </button>
            <button
              onClick={() => setActiveTab('jobs')}
              className={`py-2 px-1 border-b-2 font-medium text-sm ${
                activeTab === 'jobs'
                  ? 'border-indigo-500 text-indigo-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              }`}
            >
              Jobs ({jobs.length})
            </button>
            <button
              onClick={() => setActiveTab('workers')}
              className={`py-2 px-1 border-b-2 font-medium text-sm ${
                activeTab === 'workers'
                  ? 'border-indigo-500 text-indigo-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              }`}
            >
              Workers ({workers.length})
            </button>
          </nav>
        </div>

        {/* Tab Content */}
        <div className="py-6">
          {activeTab === 'overview' && currentRound && (
            <div className="space-y-6">
              <RoundOverview round={currentRound} />
              <MetricsChart jobs={jobs} />
            </div>
          )}
          
          {activeTab === 'jobs' && (
            <JobsList jobs={jobs} />
          )}
          
          {activeTab === 'workers' && (
            <WorkersList workers={workers} />
          )}
        </div>
      </div>
    </div>
  );
}