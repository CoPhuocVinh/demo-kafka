import { Activity, ChevronDown, ChevronUp, Layers, MessageSquare, PauseCircle, PlayCircle, Users, WifiOff } from 'lucide-react';
import { useEffect, useRef, useState } from 'react';

export interface Message {
  topic: string;
  partition: number;
  offset: string;
  value: any;
  timestamp: string;
  key?: string;
  consumerId?: string;
  id?: string;
}

interface MessageStreamProps {
  messages: Message[];
  isProducing: boolean;
}

export const MessageStream = ({ messages, isProducing }: MessageStreamProps) => {
  const [isExpanded, setIsExpanded] = useState(true);
  const [isPaused, setIsPaused] = useState(false);
  const [displayMessages, setDisplayMessages] = useState<Message[]>([]);
  
  // Update display messages only when not paused
  useEffect(() => {
    if (!isPaused) {
      setDisplayMessages(messages);
    }
  }, [messages, isPaused]);

  return (
    <div className={`bg-slate-900/80 backdrop-blur-md rounded-2xl border border-slate-800 shadow-xl overflow-hidden transition-all duration-300 ${isExpanded ? 'h-[600px]' : 'h-[72px]'}`}>
      
      {/* Header */}
      <div 
        className="p-4 border-b border-slate-800 flex items-center justify-between cursor-pointer hover:bg-slate-800/50 transition-colors group"
        onClick={() => setIsExpanded(!isExpanded)}
      >
        <div className="flex items-center gap-3">
          <div className="p-2 bg-indigo-500/10 rounded-lg group-hover:bg-indigo-500/20 transition-colors">
            <MessageSquare className="w-5 h-5 text-indigo-400" />
          </div>
          <div>
            <h3 className="font-bold text-slate-200">Live Message Stream</h3>
            <div className="flex items-center gap-2 mt-0.5">
              {!isProducing ? (
                 <div className="flex items-center gap-1.5">
                   <WifiOff className="w-3 h-3 text-slate-500" />
                   <span className="text-[10px] font-bold text-slate-500 uppercase tracking-wider">Offline</span>
                 </div>
              ) : isPaused ? (
                 <div className="flex items-center gap-1.5">
                   <PauseCircle className="w-3 h-3 text-amber-500" />
                   <span className="text-[10px] font-bold text-amber-500 uppercase tracking-wider">Paused</span>
                 </div>
              ) : (
                 <div className="flex items-center gap-1.5">
                   <span className="relative flex h-2 w-2">
                     <span className="animate-ping absolute inline-flex h-full w-full rounded-full opacity-75 bg-emerald-400"></span>
                     <span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-500"></span>
                   </span>
                   <span className="text-[10px] font-bold text-emerald-400 uppercase tracking-wider">Live</span>
                 </div>
              )}
            </div>
          </div>
        </div>

        <div className="flex items-center gap-3">
          <button
               onClick={(e) => { e.stopPropagation(); setIsPaused(!isPaused); }}
               className={`p-1.5 rounded-lg transition-all ${isPaused ? 'bg-yellow-500/10 text-yellow-500 hover:bg-yellow-500/20' : 'bg-slate-800 text-slate-400 hover:text-slate-200'}`}
               title={isPaused ? "Resume Stream" : "Pause Stream"}
             >
               {isPaused ? <PlayCircle className="w-4 h-4" /> : <PauseCircle className="w-4 h-4" />}
             </button>
        </div>

        <div className="flex items-center gap-3">
          <span className="px-2.5 py-0.5 rounded-full text-xs font-medium bg-indigo-500/10 text-indigo-400 border border-indigo-500/20 shadow-sm shadow-indigo-500/10 hidden sm:inline-block">
            Last {displayMessages.length} messages
          </span>
          <button className="text-slate-400 hover:text-white transition-colors">
            {isExpanded ? <ChevronUp className="w-5 h-5" /> : <ChevronDown className="w-5 h-5" />}
          </button>
        </div>
      </div>

      <div className={`grid grid-cols-1 md:grid-cols-3 divide-y md:divide-y-0 md:divide-x divide-slate-800 h-[528px] ${!isExpanded && 'hidden'}`}>
         <LogColumn title="Consumer-1" color="text-cyan-400" messages={displayMessages.filter(m => m.consumerId === 'Consumer-1')} />
         <LogColumn title="Consumer-2" color="text-amber-400" messages={displayMessages.filter(m => m.consumerId === 'Consumer-2')} />
         <LogColumn title="Consumer-3" color="text-pink-400" messages={displayMessages.filter(m => m.consumerId === 'Consumer-3')} />
      </div>
    </div>
  );
};

const LogColumn = ({ title, color, messages }: { title: string, color: string, messages: Message[] }) => {
  const scrollRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  }, [messages]);

  return (
    <div className="flex flex-col h-full overflow-hidden">
      <div className="p-3 border-b border-slate-800/50 bg-slate-900/50 flex items-center justify-between sticky top-0 backdrop-blur z-10">
         <div className="flex items-center gap-2">
            <Users className={`w-4 h-4 ${color}`} />
            <span className={`text-sm font-bold ${color}`}>{title}</span>
         </div>
         <span className="text-[10px] bg-slate-800 px-1.5 py-0.5 rounded text-slate-400 font-mono">
            {messages.length} events
         </span>
      </div>
      
      <div className="flex-1 overflow-y-auto p-2 space-y-2 custom-scrollbar" ref={scrollRef}>
          {messages.length === 0 ? (
            <div className="h-full flex flex-col items-center justify-center text-slate-700 space-y-2 opacity-50">
               <Activity className="w-8 h-8 animate-pulse" />
               <span className="text-xs">Waiting...</span>
            </div>
          ) : (
            messages.map((msg, idx) => (
               <LogItem key={msg.id || idx} msg={msg} idx={idx} />
            ))
          )}
      </div>
    </div>
  );
}

const LogItem = ({ msg, idx }: { msg: Message, idx: number }) => {
    let parsedValue = msg.value;
    try {
      if (typeof msg.value === 'string') parsedValue = JSON.parse(msg.value);
      else if (msg.value && msg.value.type === 'manual' && msg.value.message) {
         try { parsedValue = JSON.parse(msg.value.message); } catch {}
      }
    } catch {}

    return (
      <div 
        className="bg-slate-950/30 rounded border border-slate-800/50 p-2 text-[10px] font-mono hover:bg-slate-800/30 transition-colors animate-in fade-in slide-in-from-bottom-2 duration-300 fill-mode-backwards"
        style={{ animationDelay: `${idx * 50}ms` }}
      >
         <div className="flex items-center justify-between mb-1 text-slate-500">
            <div className="flex items-center gap-1.5">
               <Layers className="w-3 h-3" />
               <span>P:{msg.partition} | O:{msg.offset}</span>
            </div>
            <span className="text-[9px]">{new Date(Number(msg.timestamp)).toLocaleTimeString()}</span>
         </div>
         <div className="text-slate-300 break-all leading-tight">
             {JSON.stringify(parsedValue).slice(0, 100)}{JSON.stringify(parsedValue).length > 100 ? '...' : ''}
         </div>
      </div>
    );
}
