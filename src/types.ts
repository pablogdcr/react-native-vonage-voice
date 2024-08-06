export interface EventBase {
  callId: string;
}

export interface EventWithCallId extends EventBase {
  caller: string;
}

export interface EventWithReason extends EventBase {
  reason: string;
}