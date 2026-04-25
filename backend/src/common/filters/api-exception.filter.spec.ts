import {
  ArgumentsHost,
  BadRequestException,
  ConflictException,
  HttpStatus,
} from "@nestjs/common";
import { Request, Response } from "express";
import { ApiExceptionFilter } from "./api-exception.filter";

describe("ApiExceptionFilter", () => {
  const filter = new ApiExceptionFilter();

  function createHost(url = "/students", requestId?: string): {
    host: ArgumentsHost;
    status: jest.Mock;
    json: jest.Mock;
  } {
    const json = jest.fn();
    const status = jest.fn().mockReturnValue({ json });
    const response = { status } as unknown as Response;
    const request = {
      url,
      headers: requestId ? { "x-request-id": requestId } : {},
    } as unknown as Request;

    const host = {
      switchToHttp: () => ({
        getResponse: () => response,
        getRequest: () => request,
      }),
    } as ArgumentsHost;

    return { host, status, json };
  }

  it("wraps validation failures in the standard error envelope", () => {
    const { host, status, json } = createHost("/auth/login", "req-1");

    filter.catch(
      new BadRequestException(["email must be an email", "password too short"]),
      host,
    );

    expect(status).toHaveBeenCalledWith(HttpStatus.BAD_REQUEST);
    expect(json).toHaveBeenCalledWith({
      error: expect.objectContaining({
        code: "BAD_REQUEST",
        statusCode: HttpStatus.BAD_REQUEST,
        message: "email must be an email; password too short",
        path: "/auth/login",
        requestId: "req-1",
        details: {
          validationErrors: ["email must be an email", "password too short"],
        },
      }),
    });
  });

  it("preserves explicit domain codes and details", () => {
    const { host, json } = createHost("/sync/push");

    filter.catch(
      new ConflictException({
        code: "STALE_WRITE",
        message: "The client revision is stale.",
        details: { serverRevision: 42 },
      }),
      host,
    );

    expect(json).toHaveBeenCalledWith({
      error: expect.objectContaining({
        code: "STALE_WRITE",
        statusCode: HttpStatus.CONFLICT,
        message: "The client revision is stale.",
        path: "/sync/push",
        requestId: null,
        details: {
          details: { serverRevision: 42 },
        },
      }),
    });
  });

  it("masks unexpected errors as internal server errors", () => {
    const { host, status, json } = createHost("/health");

    filter.catch(new Error("db password leaked"), host);

    expect(status).toHaveBeenCalledWith(HttpStatus.INTERNAL_SERVER_ERROR);
    expect(json).toHaveBeenCalledWith({
      error: expect.objectContaining({
        code: "INTERNAL_SERVER_ERROR",
        statusCode: HttpStatus.INTERNAL_SERVER_ERROR,
        message: "Internal server error.",
        path: "/health",
        requestId: null,
      }),
    });
  });
});
