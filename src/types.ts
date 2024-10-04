export interface EventBase {
  callId: string;
  outbound?: boolean;
}

export interface EventWithCallId extends EventBase {
  caller: string;
}

export interface EventWithReason extends EventBase {
  reason: string;
}

export interface EventWithConnectionStatus extends EventBase {
  status: string;
  reason?: string;
}
