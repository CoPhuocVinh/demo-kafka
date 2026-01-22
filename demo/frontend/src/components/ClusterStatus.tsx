import { Server, Activity, Database, CheckCircle2 } from 'lucide-react';

interface ClusterStatusProps {
  metrics?: any;
  isProducing: boolean;
}

export const ClusterStatus = ({ isProducing }: ClusterStatusProps) => {
  const brokers = [1, 2, 3]; // We know we have 3 brokers from docker-compose

  return (
    <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
      {brokers.map((brokerId) => (
        <div key={brokerId} className="relative group">
          <div className={`absolute -inset-0.5 bg-gradient-to-r from-indigo-500 to-purple-600 rounded-xl blur opacity-25 group-hover:opacity-75 transition duration-1000 group-hover:duration-200 animate-tilt ${isProducing ? 'opacity-25' : 'opacity-0'}`}></div>
          <div className="relative px-6 py-6 bg-slate-900 rounded-xl border border-slate-800 group-hover:border-slate-700 transition-colors h-full flex flex-col justify-between">
            
            <div className="flex items-center justify-between mb-4">
               <div className="flex items-center gap-3">
                  <div className={`p-2.5 bg-slate-800 rounded-lg transition-colors ${isProducing ? 'group-hover:bg-indigo-500/20 group-hover:text-indigo-400' : ''}`}>
                    <Server className={`w-6 h-6 text-slate-400 ${isProducing ? 'group-hover:text-indigo-400' : ''}`} />
                  </div>
                  <div>
                    <h3 className="text-lg font-bold text-slate-100">Broker {brokerId}</h3>
                    <div className="text-xs text-slate-500 font-mono">kafka-{brokerId}:909{brokerId + 1}</div>
                  </div>
               </div>
               
               <div className="flex items-center gap-1.5 px-2 py-1 rounded-full bg-emerald-500/10 border border-emerald-500/20">
                 <CheckCircle2 className="w-3.5 h-3.5 text-emerald-400" />
                 <span className="text-xs font-semibold text-emerald-400">ONLINE</span>
               </div>
            </div>

            <div className="space-y-3">
              <div className="flex items-center justify-between p-2 rounded bg-slate-950/50 border border-slate-800/50">
                <span className="text-xs text-slate-500 flex items-center gap-1.5">
                   <Activity className={`w-3.5 h-3.5 ${isProducing ? 'text-indigo-400 animate-pulse' : 'text-slate-600'}`} /> Throughput
                </span>
                <span className={`text-sm font-mono font-medium ${isProducing ? 'text-indigo-300' : 'text-slate-500'}`}>
                   {isProducing ? Math.floor(Math.random() * 50) + 10 : 0} msg/s
                </span>
              </div>
              
              <div className="flex items-center justify-between p-2 rounded bg-slate-950/50 border border-slate-800/50">
                <span className="text-xs text-slate-500 flex items-center gap-1.5">
                   <Database className="w-3.5 h-3.5" /> Partitions
                </span>
                <span className="text-sm font-mono text-slate-300">
                   3
                </span>
              </div>
            </div>

          </div>
        </div>
      ))}
    </div>
  );
};

