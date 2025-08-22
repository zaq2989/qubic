// SPDX-License-Identifier: MIT
import { Worker } from '@/api/client';

interface Props {
  workers: Worker[];
}

export default function WorkersList({ workers }: Props) {
  const formatTimestamp = (timestamp: string) => {
    return new Date(timestamp).toLocaleString();
  };

  const isWorkerActive = (lastSeen: string) => {
    const lastSeenTime = new Date(lastSeen).getTime();
    const now = new Date().getTime();
    return now - lastSeenTime < 60000; // Active if seen within last minute
  };

  return (
    <div className="bg-white shadow overflow-hidden rounded-lg">
      <div className="px-4 py-5 sm:px-6">
        <h3 className="text-lg leading-6 font-medium text-gray-900">Workers</h3>
      </div>
      <div className="overflow-x-auto">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Worker ID
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Status
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Types
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Active Jobs
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Completed
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Resources
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Last Seen
              </th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {workers.map((worker) => (
              <tr key={worker.id} className="hover:bg-gray-50">
                <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                  {worker.id}
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                    isWorkerActive(worker.last_seen)
                      ? 'text-green-600 bg-green-100'
                      : 'text-gray-600 bg-gray-100'
                  }`}>
                    {isWorkerActive(worker.last_seen) ? 'Active' : 'Inactive'}
                  </span>
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {worker.capabilities.job_types.map(type => (
                    <span 
                      key={type}
                      className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium mr-1 ${
                        type === 'ATTACK' 
                          ? 'text-orange-600 bg-orange-100' 
                          : 'text-purple-600 bg-purple-100'
                      }`}
                    >
                      {type}
                    </span>
                  ))}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {worker.status.active_jobs} / {worker.capabilities.max_concurrent_jobs}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {worker.status.completed_jobs}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  <div>CPU: {(worker.status.cpu_usage * 100).toFixed(0)}%</div>
                  <div>Mem: {(worker.status.memory_usage * 100).toFixed(0)}%</div>
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {formatTimestamp(worker.last_seen)}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}