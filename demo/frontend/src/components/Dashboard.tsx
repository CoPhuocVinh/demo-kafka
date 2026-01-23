import { useState, useEffect } from 'react';
import { useSocket } from '../hooks/useSocket';
import { ClusterStatus } from './ClusterStatus';
import { MessageStream } from './MessageStream';
import { ControlPanel } from './ControlPanel';
import { ClusterVisualizer } from './ClusterVisualizer';
import { Activity, Wifi, WifiOff, ExternalLink, LayoutDashboard, Network } from 'lucide-react';
import { config } from '../config';

export const Dashboard = () => {
  const { socket, isConnected } = useSocket();
  const [messages, setMessages] = useState<any[]>([]);
  const [metrics] = useState<any>({});
  const [clientCount, setClientCount] = useState(0);
  const [activeTab, setActiveTab] = useState<'overview' | 'visualizer'>('visualizer');
  const [isProducing, setIsProducing] = useState(false);

  useEffect(() => {
    if (!socket) return;

    // Listen for kafka messages
    socket.on('kafka-message', (data) => {
      setMessages((prev) => [...prev, data].slice(-50));
      setIsProducing(true);
      // Reset producing state after a short delay if no new messages come
      const timeout = setTimeout(() => setIsProducing(false), 5000);
      return () => clearTimeout(timeout);
    });

    socket.on('clients-update', (data) => {
      setClientCount(data.totalClients);
    });

    return () => {
      socket.off('kafka-message');
      socket.off('clients-update');
    };
  }, [socket]);

  return (
    <div className="min-h-screen bg-slate-950 p-6 font-sans text-slate-50 selection:bg-indigo-500/30 overflow-x-hidden">
      {/* Header */}
      <header className="max-w-7xl mx-auto mb-8">
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
          <div>
            <div className="flex items-center gap-3 mb-1">
               <div className="relative flex h-3 w-3">
                  <span className={`animate-ping absolute inline-flex h-full w-full rounded-full opacity-75 ${isConnected ? 'bg-cyan-400' : 'bg-red-400'}`}></span>
                  <span className={`relative inline-flex rounded-full h-3 w-3 ${isConnected ? 'bg-cyan-500' : 'bg-red-500'}`}></span>
               </div>
               <h1 className="text-4xl font-black bg-clip-text text-transparent bg-gradient-to-r from-cyan-400 via-indigo-500 to-purple-600 tracking-tighter filter drop-shadow-lg">
                KAFKA<span className="font-light text-slate-400">DEMO</span>
              </h1>
            </div>
            <p className="text-slate-400 text-sm pl-6 font-mono tracking-wide">REAL-TIME CLUSTER OBSERVABILITY BY APP TEAM - YOUNETMEDIA</p>
          </div>
          
          <div className="flex items-center gap-3">
             <div className="flex p-1 bg-slate-900 rounded-lg border border-slate-800">
                <button 
                  onClick={() => setActiveTab('visualizer')}
                  className={`px-4 py-2 rounded-md text-sm font-medium transition-all flex items-center gap-2 ${activeTab === 'visualizer' ? 'bg-indigo-600/20 text-indigo-400 shadow-inner' : 'text-slate-400 hover:text-slate-200'}`}
                >
                  <Network className="w-4 h-4" /> Visualizer
                </button>
                <button 
                  onClick={() => setActiveTab('overview')}
                  className={`px-4 py-2 rounded-md text-sm font-medium transition-all flex items-center gap-2 ${activeTab === 'overview' ? 'bg-indigo-600/20 text-indigo-400 shadow-inner' : 'text-slate-400 hover:text-slate-200'}`}
                >
                  <LayoutDashboard className="w-4 h-4" /> Dashboard
                </button>
             </div>
             
             <div className="h-10 w-px bg-slate-800 mx-2"></div>

             <div className="flex items-center gap-4 bg-slate-900/80 backdrop-blur border border-slate-800 px-4 py-2 rounded-xl shadow-xl">
                 <div className={`flex items-center gap-2 ${isConnected ? 'text-cyan-400' : 'text-red-400'}`}>
                    {isConnected ? <Wifi className="w-4 h-4" /> : <WifiOff className="w-4 h-4" />}
                 </div>
                 <div className="flex items-center gap-2 text-slate-400">
                    <Activity className="w-4 h-4" />
                    <span className="font-mono font-bold text-white">{clientCount}</span>
                 </div>
                 <div className="text-[10px] text-slate-500 border-l border-slate-700 pl-3 ml-1">
                    {socket?.id?.slice(0, 4)}... ({socket?.io.engine.transport.name})
                 </div>
             </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto space-y-6">
        
        {/* Top Section: Visualizer or Stats */}
        <section className={`transition-all duration-500 ${activeTab === 'visualizer' ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-4 absolute inset-0 -z-10'}`}>
           {activeTab === 'visualizer' && (
             <div className="mb-8">
             <div className="mb-8">
               <ClusterVisualizer isProducing={isProducing} latestMessage={messages.length > 0 ? messages[messages.length - 1] : null} />
             </div>
             </div>
           )}
        </section>

        {activeTab === 'overview' && (
           <section className="animate-in fade-in slide-in-from-bottom-4 duration-500">
              <ClusterStatus metrics={metrics} isProducing={isProducing} />
           </section>
        )}

        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8">
          {/* Left Column: Stream */}
          <div className="lg:col-span-8 space-y-4">
             <MessageStream messages={messages} isProducing={isProducing} />
          </div>
          
          {/* Right Column: Controls & Info */}
          <div className="lg:col-span-4 space-y-6">
            <ControlPanel />

            {/* Grafana Card */}
            <a 
               href={config.grafanaUrl} 
               target="_blank" 
               rel="noopener noreferrer"
               className="block group relative bg-gradient-to-br from-slate-900 to-indigo-950 rounded-2xl border border-indigo-500/20 p-6 overflow-hidden hover:border-indigo-500/50 transition-all duration-300 hover:shadow-[0_0_30px_-5px_theme(colors.indigo.500/0.3)]"
            >
               <div className="relative z-10 flex flex-col gap-4">
                 <div className="p-3 bg-indigo-500/10 rounded-xl w-fit group-hover:bg-indigo-500/20 transition-colors">
                    <Activity className="w-8 h-8 text-indigo-400" />
                 </div>
                 <div>
                    <h3 className="text-xl font-bold text-white mb-1">Deep Metrics</h3>
                    <p className="text-slate-400 text-sm">Analyze historical throughput and latency in Grafana.</p>
                 </div>
                 <div className="mt-2 flex items-center gap-2 text-sm font-medium text-indigo-300 group-hover:text-indigo-200">
                    Open Dashboards <ExternalLink className="w-4 h-4" />
                 </div>
               </div>
               
               {/* Decorative elements */}
               <div className="absolute right-0 top-0 h-32 w-32 bg-indigo-500/10 blur-[50px] rounded-full group-hover:bg-indigo-500/20 transition-all"></div>
            </a>
          </div>
        </div>
      </main>
    </div>
  );
};

