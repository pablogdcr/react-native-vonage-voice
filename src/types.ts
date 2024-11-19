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
  startedAt: number;
}
