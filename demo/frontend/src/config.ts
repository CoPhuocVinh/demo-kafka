/**
 * Application Configuration
 * Uses dynamic hostname detection for deployment flexibility
 */

const getBaseHost = () => {
  if (typeof window !== 'undefined') {
    return window.location.hostname;
  }
  return 'localhost';
};

const getProtocol = () => {
  if (typeof window !== 'undefined') {
    return window.location.protocol;
  }
  return 'http:';
};

export const config = {
  // External service URLs (different ports)
  grafanaUrl: `${getProtocol()}//${getBaseHost()}:3001`,
  kafkaUiUrl: `${getProtocol()}//${getBaseHost()}:8081`,
  prometheusUrl: `${getProtocol()}//${getBaseHost()}:9090`,
  
  // API is proxied through nginx, so use relative URLs
  apiBaseUrl: '',
};

export default config;
