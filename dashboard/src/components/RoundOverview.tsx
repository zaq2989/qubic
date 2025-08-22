// SPDX-License-Identifier: MIT
import { RoundSummary } from '@/api/client';

interface Props {
  round: RoundSummary;
}

export default function RoundOverview({ round }: Props) {
  const completionRate = round.total_jobs > 0 
    ? (round.completed_jobs / round.total_jobs * 100).toFixed(1)
    : 0;

  const attackSuccessRate = round.completed_jobs > 0
    ? (round.attack_success_count / round.completed_jobs * 100).toFixed(1)
    : 0;

  const defenseSuccessRate = round.completed_jobs > 0
    ? (round.defense_success_count / round.completed_jobs * 100).toFixed(1)
    : 0;

  return (
    <div className="bg-white overflow-hidden shadow rounded-lg">
      <div className="px-4 py-5 sm:p-6">
        <h2 className="text-lg font-medium text-gray-900 mb-4">Round {round.round_id} Overview</h2>
        
        <div className="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4">
          <div className="bg-gray-50 px-4 py-5 rounded-lg">
            <dt className="text-sm font-medium text-gray-500">Total Jobs</dt>
            <dd className="mt-1 text-3xl font-semibold text-gray-900">{round.total_jobs}</dd>
          </div>
          
          <div className="bg-green-50 px-4 py-5 rounded-lg">
            <dt className="text-sm font-medium text-gray-500">Completed</dt>
            <dd className="mt-1 text-3xl font-semibold text-green-600">
              {round.completed_jobs}
              <span className="text-sm text-gray-500 ml-2">({completionRate}%)</span>
            </dd>
          </div>
          
          <div className="bg-red-50 px-4 py-5 rounded-lg">
            <dt className="text-sm font-medium text-gray-500">Failed</dt>
            <dd className="mt-1 text-3xl font-semibold text-red-600">{round.failed_jobs}</dd>
          </div>
          
          <div className="bg-blue-50 px-4 py-5 rounded-lg">
            <dt className="text-sm font-medium text-gray-500">In Progress</dt>
            <dd className="mt-1 text-3xl font-semibold text-blue-600">
              {round.total_jobs - round.completed_jobs - round.failed_jobs}
            </dd>
          </div>
        </div>

        <div className="mt-6 grid grid-cols-1 gap-5 sm:grid-cols-2">
          <div className="bg-indigo-50 px-4 py-5 rounded-lg">
            <dt className="text-sm font-medium text-gray-500">Attack Success Rate</dt>
            <dd className="mt-1 text-2xl font-semibold text-indigo-600">
              {attackSuccessRate}%
              <span className="text-sm text-gray-500 ml-2">
                ({round.attack_success_count} successful)
              </span>
            </dd>
          </div>
          
          <div className="bg-purple-50 px-4 py-5 rounded-lg">
            <dt className="text-sm font-medium text-gray-500">Defense Detection Rate</dt>
            <dd className="mt-1 text-2xl font-semibold text-purple-600">
              {defenseSuccessRate}%
              <span className="text-sm text-gray-500 ml-2">
                ({round.defense_success_count} detected)
              </span>
            </dd>
          </div>
        </div>
      </div>
    </div>
  );
}