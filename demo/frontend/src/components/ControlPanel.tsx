import { useState, useEffect } from 'react';
import { Play, Square, Send, Terminal, Loader2 } from 'lucide-react';

export const ControlPanel = () => {
  const [isProducing, setIsProducing] = useState(false);
  const [customMessage, setCustomMessage] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [logs, setLogs] = useState<string[]>([]);

  const [weights, setWeights] = useState([1, 1, 1]);

  useEffect(() => {
    fetch('/demo/statistics')
      .then(res => res.json())
      .then(data => {
        setIsProducing(data.isProducing);
        if (data.partitionWeights) setWeights(data.partitionWeights);
      })
      .catch(err => console.error('Failed to fetch status:', err));
  }, []);

  const updateWeights = (index: number, value: number) => {
    const newWeights = [...weights];
    newWeights[index] = value;
    setWeights(newWeights);
    
    // Debounce or just send immediately? For demo, immediate is fine but maybe separate "Apply" button?
    // Let's use an apply effect or just update on change. 
    // Actually, sending on every slider change might spam. 
    // Let's rely on a "Update Config" button or simpler: just send it.
    
    fetch('/demo/config', {
       method: 'POST',
       headers: { 'Content-Type': 'application/json' },
       body: JSON.stringify({ partitionWeights: newWeights }),
    }).catch(() => addLog('Failed to update config'));
  };

  const addLog = (msg: string) => {
    setLogs(prev => [`[${new Date().toLocaleTimeString()}] ${msg}`, ...prev].slice(0, 5));
  };

  const handleStart = async () => {
    setIsLoading(true);
    try {
      await fetch('/demo/start', { method: 'POST' });
      setIsProducing(true);
      addLog('Started producer');
    } catch (error) {
      addLog('Failed to start producer');
    } finally {
      setIsLoading(false);
    }
  };

  const handleStop = async () => {
    setIsLoading(true);
    try {
      await fetch('/demo/stop', { method: 'POST' });
      setIsProducing(false);
      addLog('Stopped producer');
    } catch (error) {
      addLog('Failed to stop producer');
    } finally {
      setIsLoading(false);
    }
  };

  const handleSend = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!customMessage.trim()) return;

    try {
      await fetch('/demo/send', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ message: customMessage, type: 'manual' }),
      });
      addLog(`Sent: ${customMessage}`);
      setCustomMessage('');
    } catch (error) {
      addLog('Failed to send message');
    }
  };

  return (
    <div className="bg-slate-900/80 backdrop-blur-md rounded-2xl border border-slate-800 p-6 flex flex-col gap-6 shadow-xl relative overflow-hidden group">
      {/* Decorative Glow */}
      <div className="absolute top-0 right-0 w-32 h-32 bg-indigo-500/10 rounded-full blur-3xl -z-10 group-hover:bg-indigo-500/20 transition-all"></div>

      <div>
        <h3 className="text-sm font-bold text-slate-400 uppercase tracking-wider mb-4 flex items-center gap-2">
          <Terminal className="w-4 h-4 text-indigo-400" />
          Control Center
        </h3>
        
        <div className="flex gap-3 mb-6">
          {!isProducing ? (
            <button
              onClick={handleStart}
              disabled={isLoading}
              className="flex-1 flex items-center justify-center gap-2 bg-gradient-to-r from-emerald-600 to-emerald-500 hover:from-emerald-500 hover:to-emerald-400 text-white px-4 py-3 rounded-xl font-bold transition-all shadow-lg shadow-emerald-900/20 disabled:opacity-50 disabled:cursor-not-allowed transform active:scale-95"
            >
              {isLoading ? <Loader2 className="w-4 h-4 animate-spin" /> : <Play className="w-4 h-4 fill-current" />}
              Start Data Feed
            </button>
          ) : (
            <button
              onClick={handleStop}
              disabled={isLoading}
              className="flex-1 flex items-center justify-center gap-2 bg-gradient-to-r from-slate-700 to-slate-600 hover:from-red-600 hover:to-red-500 text-white px-4 py-3 rounded-xl font-bold transition-all shadow-lg shadow-red-900/20 disabled:opacity-50 disabled:cursor-not-allowed transform active:scale-95 group/stop"
            >
              {isLoading ? <Loader2 className="w-4 h-4 animate-spin" /> : <Square className="w-4 h-4 fill-current group-hover/stop:fill-white/90" />}
              Stop Data Feed
            </button>
          )}
        </div>

      </div>

      <div className="border-t border-slate-800/50 pt-4">
         <label className="text-[10px] font-bold text-slate-600 uppercase tracking-wider mb-3 block ml-1">
            Partition Distribution
         </label>
         <div className="space-y-3">
            {[0, 1, 2].map((i) => (
              <div key={i} className="flex items-center gap-3">
                 <span className="text-xs text-slate-400 font-mono w-4">P{i}</span>
                 <input 
                    type="range" 
                    min="0" 
                    max="10" 
                    step="1"
                    value={weights[i]}
                    onChange={(e) => updateWeights(i, parseInt(e.target.value))}
                    className="flex-1 h-1 bg-slate-800 rounded-lg appearance-none cursor-pointer [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:w-3 [&::-webkit-slider-thumb]:h-3 [&::-webkit-slider-thumb]:rounded-full [&::-webkit-slider-thumb]:bg-indigo-500 hover:[&::-webkit-slider-thumb]:bg-indigo-400 transition-all"
                 />
                 <span className="text-xs text-slate-300 font-bold w-4 text-right">{weights[i]}</span>
              </div>
            ))}
         </div>
         <p className="text-[10px] text-slate-600 mt-2 mb-2 italic text-center">
            Adjust ratio of messages per partition
         </p>
      </div>

      <div className="border-t border-slate-800/50 pt-4">
        <form onSubmit={handleSend} className="space-y-3">
          <label className="text-[10px] font-bold text-slate-600 uppercase tracking-wider block ml-1">
            Manual Event Injection
          </label>
          <div className="flex gap-2 relative">
            <input
              type="text"
              value={customMessage}
              onChange={(e) => setCustomMessage(e.target.value)}
              placeholder='{"id": 123, "status": "active"}'
              className="flex-1 bg-slate-950/50 border border-slate-700/50 rounded-xl px-4 py-2.5 text-sm text-slate-200 placeholder:text-slate-600 focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50 font-mono transition-all"
            />
            <button
              type="submit"
              disabled={!customMessage.trim()}
              className="bg-indigo-600 hover:bg-indigo-500 text-white p-2.5 rounded-xl transition-all shadow-lg shadow-indigo-900/20 disabled:opacity-50 disabled:cursor-not-allowed hover:scale-105 active:scale-95"
            >
              <Send className="w-4 h-4" />
            </button>
          </div>
        </form>
      </div>

      <div className="border-t border-slate-800/50 pt-4">
        <label className="text-[10px] font-bold text-slate-600 uppercase tracking-wider mb-2 block ml-1">
          Recent Activity
        </label>
        <div className="font-mono text-xs text-slate-400 space-y-2 bg-slate-950/30 p-2 rounded-lg border border-slate-800/30 min-h-[80px]">
          {logs.length === 0 ? (
            <span className="text-slate-700 italic flex items-center gap-2 justify-center h-full pt-4">
               Waiting for commands...
            </span>
          ) : (
            logs.map((log, i) => (
              <div key={i} className="truncate flex items-start gap-2">
                 <span className="text-indigo-500/50">›</span> {log}
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
};
