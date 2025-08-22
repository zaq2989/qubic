# Wargame Dashboard

Web-based monitoring dashboard for the Qubic Cyber Wargame Grid.

## Features

- Real-time round overview
- Job status tracking
- Worker monitoring
- Performance metrics visualization
- Responsive design with Tailwind CSS

## Tech Stack

- Next.js 14
- React 18
- TypeScript
- Tailwind CSS
- Recharts for data visualization
- Axios for API calls

## Development

```bash
# Install dependencies
npm install

# Run development server
npm run dev

# Build for production
npm run build

# Start production server
npm start
```

## Environment Variables

Create `.env.local`:

```env
NEXT_PUBLIC_API_URL=http://localhost:8080/api
RELAY_API_URL=http://localhost:8080/api
```

## Pages

### Overview Tab
- Round statistics (total jobs, completion rate, success rates)
- Performance metrics chart
- Real-time updates every 5 seconds

### Jobs Tab
- List of all jobs with status
- Job type (ATTACK/DEFENSE)
- Worker assignment
- Timestamps and result links

### Workers Tab
- Active worker list
- Resource utilization
- Job capacity and completion counts
- Last seen timestamps

## API Integration

The dashboard connects to the relay service API endpoints:
- `/api/health` - System health check
- `/api/rounds/:id/summary` - Round statistics
- `/api/jobs` - Job listing
- `/api/workers` - Worker status

## Building for Production

```bash
npm run build
npm start
```

Or with Docker:

```bash
docker build -t wargame-dashboard .
docker run -p 3000:3000 wargame-dashboard
```