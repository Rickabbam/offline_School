export declare const OFFLINE_SCHOOL_ID_FORMAT: "uuid";
export declare const OFFLINE_SCHOOL_TIMESTAMP_FIELDS: readonly ["createdAt", "updatedAt"];
export declare const OFFLINE_SCHOOL_REVISION_FIELD: "serverRevision";
export declare const OFFLINE_SCHOOL_IDEMPOTENCY_HEADER: "x-idempotency-key";
export declare const OFFLINE_SCHOOL_REQUEST_ID_HEADER: "x-request-id";
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
