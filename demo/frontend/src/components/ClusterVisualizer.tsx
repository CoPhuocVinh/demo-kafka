import { useMemo, useEffect, useState } from 'react';
import ReactFlow, {
  Node,
  Edge,
  Background,
  Controls,
  useNodesState,
  useEdgesState,
  ReactFlowProvider,
} from 'reactflow';
import 'reactflow/dist/style.css';
import { Zap, User, X, Search } from 'lucide-react';

const PartitionStrip = ({ data, pulsing }: any) => {
  const currentMax = data.latestOffset ?? 0;
  const start = Math.max(0, currentMax - 5);
  const offsets = Array.from({ length: 6 }, (_, i) => start + i);
  
  return (
    <div className={`
       rounded-xl border-2 transition-all duration-300 min-w-[280px] bg-slate-950/90
       ${pulsing 
         ? 'border-amber-500 shadow-[0_0_20px_rgba(245,158,11,0.3)] ring-1 ring-amber-500/50' 
         : 'border-slate-800 shadow-lg'
       }
    `}>
      <div className="px-3 py-2 border-b border-slate-800 flex items-center justify-between bg-slate-900/50 rounded-t-xl">
         <span className={`text-xs font-bold font-mono ${pulsing ? 'text-amber-400' : 'text-slate-400'}`}>
           {data.label}
         </span>
         {pulsing && <span className="flex h-1.5 w-1.5 rounded-full bg-amber-500 animate-ping"/>}
      </div>
      
      <div className="p-3">
         <div className="flex items-center gap-1 overflow-hidden">
            <span className="text-slate-600 font-mono text-xs mr-1">...</span>
            {offsets.map((off) => (
               <div key={off} className={`
                 h-8 flex-1 border rounded flex items-center justify-center font-mono text-xs transition-colors duration-300
                 ${pulsing && off === currentMax
                    ? 'bg-amber-500 text-slate-950 border-amber-400 font-bold scale-105'
                    : 'bg-slate-900 border-slate-700 text-slate-500'
                 }
               `}>
                 {off}
               </div>
            ))}
         </div>
      </div>
       
      <div className="absolute -left-1 top-1/2 w-2 h-2 rounded-full bg-slate-500/50" />
      <div className="absolute -right-1 top-1/2 w-2 h-2 rounded-full bg-slate-500/50" />
    </div>
  );
};

const SimpleNode = ({ data, icon: Icon, color, pulsing, onClick }: any) => (
  <div 
    onClick={onClick}
    className={`
    px-4 py-3 rounded-xl border-2 shadow-xl backdrop-blur-md transition-all duration-300 min-w-[140px] bg-slate-950/90 group cursor-pointer
    ${pulsing ? 'scale-105' : ''}
    hover:ring-2 hover:ring-white/20
  `}
  style={{ 
    borderColor: pulsing ? color : '#1e293b',
    boxShadow: pulsing ? `0 0 20px -5px ${color}40` : 'none'
  }}>
    <div className="flex flex-col items-center gap-2">
      <div className={`p-2 rounded-lg bg-slate-900/50 ${pulsing ? 'animate-bounce' : ''} group-hover:bg-slate-800 transition-colors`}>
        <Icon className="w-5 h-5" style={{ color }} />
      </div>
      <div className="font-bold text-slate-200 text-sm">{data.label}</div>
      {data.subLabel && <div className="text-[10px] text-slate-500">{data.subLabel}</div>}
    </div>
    <div className="absolute -right-1 top-1/2 w-2 h-2 rounded-full bg-slate-600" />
    <div className="absolute -left-1 top-1/2 w-2 h-2 rounded-full bg-slate-600" />
  </div>
);

const GroupNode = ({ data }: any) => (
  <div className="w-full h-full rounded-2xl border-2 border-dashed border-slate-700/50 bg-slate-900/20 p-4 pt-8 relative group">
     <div className="absolute -top-3 left-4 px-2 py-0.5 bg-slate-800 rounded border border-slate-700 text-[10px] text-slate-400 uppercase tracking-widest font-bold group-hover:text-slate-200 transition-colors">
       {data.label}
     </div>
  </div>
);

// Popup Component
const SeekPopup = ({ consumer, currentOffset, maxOffset, onClose, onSeek }: any) => {
  const [offset, setOffset] = useState('');
  const lag = Math.max(0, (maxOffset || 0) - (currentOffset || 0));

  return (
    <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 z-50 bg-slate-900 border border-slate-700 rounded-xl shadow-2xl p-4 w-80 animate-in fade-in zoom-in duration-200">
      <div className="flex justify-between items-center mb-4">
        <h3 className="font-bold text-slate-200 flex items-center gap-2">
          <Search className="w-4 h-4 text-amber-500" />
          Seek Consumer Offset
        </h3>
        <button onClick={onClose} className="text-slate-500 hover:text-white transition-colors">
          <X className="w-4 h-4" />
        </button>
      </div>
      
      <div className="space-y-4">
        <div className="bg-slate-950 rounded-lg p-3 border border-slate-800 space-y-2">
          <div className="flex justify-between text-xs">
             <span className="text-slate-500">Consumer</span>
             <span className="text-amber-400 font-mono font-bold">{consumer.label}</span>
          </div>
          <div className="flex justify-between text-xs">
             <span className="text-slate-500">Current Offset</span>
             <span className="text-slate-200 font-mono">{currentOffset}</span>
          </div>
          <div className="flex justify-between text-xs">
             <span className="text-slate-500">Latest Offset (HW)</span>
             <span className="text-slate-200 font-mono">{maxOffset}</span>
          </div>
          {lag > 0 && (
             <div className="pt-1 border-t border-slate-800 flex justify-between text-xs items-center">
               <span className="text-slate-400">Status</span>
               <span className="text-emerald-400 flex items-center gap-1">
                 Catching up ({lag})
                 <span className="relative flex h-2 w-2">
                    <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
                    <span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-500"></span>
                 </span>
               </span>
             </div>
          )}
        </div>
        
        <div>
          <label className="text-[10px] text-slate-500 uppercase font-bold mb-1 block">Seek To Offset</label>
          <div className="flex gap-2">
            <input 
              type="number" 
              value={offset}
              onChange={(e) => setOffset(e.target.value)}
              className="flex-1 bg-slate-950 border border-slate-800 rounded px-3 py-2 text-sm text-white focus:outline-none focus:border-amber-500 transition-colors font-mono"
              placeholder="Offset..."
              autoFocus
            />
            <button 
              onClick={() => onSeek(consumer.label, '0')}
              className="px-3 py-2 bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs rounded border border-slate-700 transition-colors"
              title="Reset to 0"
            >
              Reset
            </button>
          </div>
        </div>
        
        <button 
          onClick={() => onSeek(consumer.label, offset)}
          disabled={!offset}
          className="w-full bg-amber-500 hover:bg-amber-400 text-slate-950 font-bold py-2 rounded text-sm transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
        >
          Seek
        </button>
      </div>
    </div>
  );
};

const initialNodes: Node[] = [
  // Producer
  { id: 'producer', position: { x: 0, y: 200 }, data: { label: 'Producer', subLabel: 'NestJS' }, type: 'simpleInput' },

  // Topic Group
  { id: 'group-topic', position: { x: 250, y: 0 }, data: { label: 'Topic: demo-events' }, style: { width: 320, height: 420 }, type: 'groupContainer', zIndex: -1 },
  
  // Partitions
  { id: 'p0', position: { x: 270, y: 50 }, data: { label: 'Partition 0', latestOffset: 5 }, type: 'partition' },
  { id: 'p1', position: { x: 270, y: 170 }, data: { label: 'Partition 1', latestOffset: 5 }, type: 'partition' },
  { id: 'p2', position: { x: 270, y: 290 }, data: { label: 'Partition 2', latestOffset: 5 }, type: 'partition' },

  // Consumer Group
  { id: 'group-consumers', position: { x: 700, y: 0 }, data: { label: 'Consumer Group' }, style: { width: 200, height: 420 }, type: 'groupContainer', zIndex: -1 },

  // Consumers
  { id: 'c1', position: { x: 730, y: 65 }, data: { label: 'Consumer 1', subLabel: 'Cyan' }, type: 'simpleOutput', style: { borderColor: '#22d3ee' } },
  { id: 'c2', position: { x: 730, y: 185 }, data: { label: 'Consumer 2', subLabel: 'Amber' }, type: 'simpleOutput', style: { borderColor: '#fbbf24' } },
  { id: 'c3', position: { x: 730, y: 305 }, data: { label: 'Consumer 3', subLabel: 'Pink' }, type: 'simpleOutput', style: { borderColor: '#f472b6' } },
];

const initialEdges: Edge[] = [
  // Producer -> Partitions
  { id: 'e-prod-p0', source: 'producer', target: 'p0', animated: false, style: { stroke: '#475569', strokeWidth: 1 } },
  { id: 'e-prod-p1', source: 'producer', target: 'p1', animated: false, style: { stroke: '#475569', strokeWidth: 1 } },
  { id: 'e-prod-p2', source: 'producer', target: 'p2', animated: false, style: { stroke: '#475569', strokeWidth: 1 } },

  // Partitions -> Consumers
  { id: 'e-p0-c1', source: 'p0', target: 'c1', animated: true, style: { stroke: '#22d3ee', opacity: 0.3 } },
  { id: 'e-p1-c2', source: 'p1', target: 'c2', animated: true, style: { stroke: '#fbbf24', opacity: 0.3 } },
  { id: 'e-p2-c3', source: 'p2', target: 'c3', animated: true, style: { stroke: '#f472b6', opacity: 0.3 } },
];

const VisualizerContent = ({ isProducing, latestMessage }: any) => {
  const [nodes, setNodes, onNodesChange] = useNodesState(initialNodes);
  const [edges, setEdges, onEdgesChange] = useEdgesState(initialEdges);
  
  // Track MAX offset seen for each partition (High Watermark)
  const [partitionHighWatermarks, setPartitionHighWatermarks] = useState<Record<number, number>>({ 0: 5, 1: 5, 2: 5 });
  // Track CURRENT offset for each consumer
  const [consumerOffsets, setConsumerOffsets] = useState<Record<string, number>>({});

  const [seekTarget, setSeekTarget] = useState<any>(null);

  const onSeek = async (consumerId: string, offset: string) => {
     try {
       await fetch('http://localhost:3000/demo/seek', {
         method: 'POST',
         headers: { 'Content-Type': 'application/json' },
         body: JSON.stringify({ consumerId: consumerId.replace(' ', '-'), offset }),
       });
       setSeekTarget(null);
     } catch (e) {
       console.error('Seek failed', e);
     }
  };

  useEffect(() => {
    if (!latestMessage) return;

    const partitionIdStr = `p${latestMessage.partition}`;
    const newOffset = Number(latestMessage.offset);
    
    // Update High Watermark (strictly increasing)
    setPartitionHighWatermarks(prev => ({
       ...prev,
       [latestMessage.partition]: Math.max(prev[latestMessage.partition] || 0, newOffset)
    }));

    // Update Consumer Offset
    if (latestMessage.consumerId) {
        let nodeId = 'c1';
        if (latestMessage.consumerId === 'Consumer-2') nodeId = 'c2';
        if (latestMessage.consumerId === 'Consumer-3') nodeId = 'c3';
        
        setConsumerOffsets(prev => ({
            ...prev,
            [nodeId]: newOffset
        }));
    }

    setEdges((eds) => eds.map(e => {
        if (e.source === 'producer') {
           return e.target === partitionIdStr 
             ? { ...e, animated: true, style: { ...e.style, stroke: '#f59e0b', strokeWidth: 2, opacity: 1 } }
             : { ...e, animated: false, style: { ...e.style, stroke: '#475569', strokeWidth: 1, opacity: 0.5 } };
        }
        if (e.source === partitionIdStr) {
             return { ...e, style: { ...e.style, strokeWidth: 2, opacity: 1 }, animated: true };
        }
        return e;
    }));

    const timer = setTimeout(() => {
       setEdges((eds) => eds.map(e => {
          if (e.source === 'producer') {
             return { ...e, animated: false, style: { ...e.style, stroke: '#475569', strokeWidth: 1, opacity: 0.5 } };
          }
          if (e.source.startsWith('p')) {
             return { ...e, style: { ...e.style, strokeWidth: 1, opacity: 0.3 } };
          }
          return e;
       }));
    }, 300);

    return () => clearTimeout(timer);
  }, [latestMessage, setEdges]);

  useEffect(() => {
    setNodes((nds) => nds.map((node) => {
       if (node.type === 'partition') {
          const pIndex = parseInt(node.id.replace('p', ''));
          // Show High Watermark on the partition strip
          const currentOffset = partitionHighWatermarks[pIndex] ?? 5;
          return {
             ...node,
             data: { ...node.data, latestOffset: currentOffset }
          };
       }
       return node;
    }));
  }, [partitionHighWatermarks, setNodes]);

  const nodeTypes = useMemo(() => ({
    simpleInput: (props: any) => <SimpleNode {...props} icon={Zap} color="#6366f1" pulsing={isProducing} />,
    simpleOutput: (props: any) => {
       const pId = `p${latestMessage?.partition}`;
       const myId = props.id;
       const isMyPartition = (pId === 'p0' && myId === 'c1') || (pId === 'p1' && myId === 'c2') || (pId === 'p2' && myId === 'c3');
       const color = myId === 'c1' ? '#22d3ee' : myId === 'c2' ? '#fbbf24' : '#f472b6';
       
       return (
         <SimpleNode 
           {...props} 
           icon={User} 
           color={color} 
           pulsing={isMyPartition} 
           onClick={() => setSeekTarget({ id: myId, label: props.data.label })}
         />
       );
    },
    partition: (props: any) => {
       const isActive = latestMessage && props.id === `p${latestMessage.partition}`;
       return <PartitionStrip {...props} pulsing={isActive} />;
    },
    groupContainer: GroupNode,
  }), [isProducing, latestMessage]);

  // Helper to get offsets for popup
  const getStatsForPopup = (target: any) => {
      if (!target) return { current: 0, max: 0 };
      let pIndex = 0;
      if (target.id === 'c2') pIndex = 1;
      if (target.id === 'c3') pIndex = 2;
      
      return {
          current: consumerOffsets[target.id] ?? 0,
          max: partitionHighWatermarks[pIndex] ?? 0
      };
  };

  return (
    <div className="h-[500px] w-full rounded-2xl overflow-hidden border border-slate-800 bg-slate-950 shadow-2xl relative">
       <div className="absolute inset-0 bg-[linear-gradient(to_right,#1e293b_1px,transparent_1px),linear-gradient(to_bottom,#1e293b_1px,transparent_1px)] bg-[size:24px_24px] [mask-image:radial-gradient(ellipse_60%_50%_at_50%_50%,#000_70%,transparent_100%)] opacity-20 pointer-events-none" />

      <ReactFlow
        nodes={nodes}
        edges={edges}
        nodeTypes={nodeTypes}
        onNodesChange={onNodesChange}
        onEdgesChange={onEdgesChange}
        fitView
        className="bg-transparent"
        minZoom={0.5}
        maxZoom={1.5}
      >
        <Background color="#334155" gap={24} size={1} className="opacity-0" />
        <Controls className="bg-slate-800 border-slate-700 fill-slate-400" showInteractive={false} />
      </ReactFlow>

      {seekTarget && (
        <>
          <div className="absolute inset-0 bg-slate-950/60 backdrop-blur-sm z-40 transition-all" onClick={() => setSeekTarget(null)} />
          <SeekPopup 
             consumer={seekTarget} 
             currentOffset={getStatsForPopup(seekTarget).current}
             maxOffset={getStatsForPopup(seekTarget).max}
             onClose={() => setSeekTarget(null)} 
             onSeek={onSeek} 
          />
        </>
      )}
    </div>
  );
};

export const ClusterVisualizer = (props: any) => (
  <ReactFlowProvider>
    <VisualizerContent {...props} />
  </ReactFlowProvider>
);
