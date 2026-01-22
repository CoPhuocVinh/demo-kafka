import { useEffect, useState } from 'react';
import { io, Socket } from 'socket.io-client';

const SOCKET_URL = '/';

export const useSocket = () => {
  const [socket, setSocket] = useState<Socket | null>(null);
  const [isConnected, setIsConnected] = useState(false);
  const [transport, setTransport] = useState('N/A');

  useEffect(() => {
    const newSocket = io(SOCKET_URL, {
      transports: ['websocket'],
      autoConnect: true,
    });

    newSocket.on('connect', () => {
      setIsConnected(true);
      setTransport(newSocket.io.engine.transport.name);
      
      newSocket.io.engine.on('upgrade', (transport) => {
        setTransport(transport.name);
      });
    });

    newSocket.on('disconnect', () => {
      setIsConnected(false);
      setTransport('N/A');
    });

    setSocket(newSocket);

    return () => {
      newSocket.disconnect();
    };
  }, []);

  return { socket, isConnected, transport };
};
