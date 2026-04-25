import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
} from "@nestjs/common";
import { Request, Response } from "express";
import {
  ApiErrorEnvelope,
  OFFLINE_SCHOOL_REQUEST_ID_HEADER,
} from "../../../../packages/contracts/src";

type HttpExceptionResponse =
  | string
  | {
      message?: string | string[];
      error?: string;
      code?: string;
      details?: unknown;
      [key: string]: unknown;
    };

@Catch()
export class ApiExceptionFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    const statusCode =
      exception instanceof HttpException
        ? exception.getStatus()
        : HttpStatus.INTERNAL_SERVER_ERROR;
    const payload = this.buildEnvelope(exception, request, statusCode);

    response.status(statusCode).json(payload);
  }

  private buildEnvelope(
    exception: unknown,
    request: Request,
    statusCode: number,
  ): ApiErrorEnvelope {
    const fallbackMessage =
      statusCode >= HttpStatus.INTERNAL_SERVER_ERROR
        ? "Internal server error."
        : "Request failed.";

    if (!(exception instanceof HttpException)) {
      return {
        error: {
          code: "INTERNAL_SERVER_ERROR",
          statusCode,
          message: fallbackMessage,
          path: request.url,
          timestamp: new Date().toISOString(),
          requestId: this.resolveRequestId(request),
        },
      };
    }

    const raw = exception.getResponse() as HttpExceptionResponse;
    if (typeof raw === "string") {
      return {
        error: {
          code: this.toErrorCode(exception.name),
          statusCode,
          message: raw,
          path: request.url,
          timestamp: new Date().toISOString(),
          requestId: this.resolveRequestId(request),
        },
      };
    }

    const message = Array.isArray(raw.message)
      ? raw.message.join("; ")
      : raw.message ?? exception.message ?? fallbackMessage;
    const details =
      Array.isArray(raw.message) || raw.details != null
        ? {
            ...(Array.isArray(raw.message)
                ? { validationErrors: raw.message }
                : {}),
            ...(raw.details != null ? { details: raw.details } : {}),
          }
        : undefined;

    return {
      error: {
        code: raw.code ?? this.toErrorCode(raw.error ?? exception.name),
        statusCode,
        message,
        path: request.url,
        timestamp: new Date().toISOString(),
        requestId: this.resolveRequestId(request),
        ...(details != null ? { details } : {}),
      },
    };
  }

  private resolveRequestId(request: Request): string | null {
    const headerValue = request.headers[OFFLINE_SCHOOL_REQUEST_ID_HEADER];
    if (Array.isArray(headerValue)) {
      return headerValue[0] ?? null;
    }
    return headerValue ?? null;
  }

  private toErrorCode(value?: string): string {
    const normalized = (value ?? "Request failed")
      .replace(/([a-z0-9])([A-Z])/g, "$1_$2")
      .replace(/[^a-zA-Z0-9]+/g, "_")
      .replace(/^_+|_+$/g, "")
      .toUpperCase();
    return normalized.length > 0 ? normalized : "REQUEST_FAILED";
  }
}
