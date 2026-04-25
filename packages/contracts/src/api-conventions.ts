export const OFFLINE_SCHOOL_ID_FORMAT = "uuid" as const;

export const OFFLINE_SCHOOL_TIMESTAMP_FIELDS = [
  "createdAt",
  "updatedAt",
] as const;

export const OFFLINE_SCHOOL_REVISION_FIELD = "serverRevision" as const;

export const OFFLINE_SCHOOL_IDEMPOTENCY_HEADER = "x-idempotency-key" as const;
export const OFFLINE_SCHOOL_REQUEST_ID_HEADER = "x-request-id" as const;

export interface ApiErrorEnvelope {
  error: {
    code: string;
    statusCode: number;
    message: string;
    path: string;
    timestamp: string;
    requestId: string | null;
    details?: unknown;
  };
}
