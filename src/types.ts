export enum CallStatus {
  RINGING = 'ringing',
  ANSWERED = 'answered',
  RECONNECTING = 'reconnecting',
  COMPLETED = 'completed',
}

export interface CallEvent {
  id: string;
  status: CallStatus;
  isOutbound: boolean;
  phoneNumber: string;
  startedAt?: number;
}

export interface AudioRouteChangeEvent {
  device: AudioDevice;
}

export interface MuteChangedEvent {
  muted: boolean;
}

export interface AudioDevice {
  name: string;
  id: string;
  type: string;
}
