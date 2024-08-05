export interface EventBase {
  callId: string;
}

export interface EventReceivedInvite extends EventBase {
  caller: string;
}

export interface EventReceivedHangup extends EventBase {
  callQuality: number;
  reason: string;
}

export interface EventReceivedCancel extends EventBase {
  reason: string;
}
